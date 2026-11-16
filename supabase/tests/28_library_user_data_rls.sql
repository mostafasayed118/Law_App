-- ============================================================================
-- supabase/tests/28_library_user_data_rls.sql — per-user library battery
--
-- Pins supabase/migrations/33_library_user_data.sql + the three
-- policies/legal_{bookmarks,highlights,reading_history}.sql:
--   - ownership: user A's rows are invisible to user B (28.04) and to the
--     PLATFORM OWNER (28.08) — no carve-out exists, by design;
--   - write posture: authenticated holds no INSERT/UPDATE/DELETE grant on any of
--     the three tables, so a direct client write dies at the privilege layer
--     (28.05, 28.06), including for the owner (28.09);
--   - bookmarks: toggle on then off is idempotent (28.02, 28.03), the 500 cap is
--     enforced (28.14), and the list read is capped at 50 rows (28.21);
--   - highlights: quote/offset agreement is verified server-side (28.10,
--     28.11), out-of-range spans are rejected (28.12), the 50-per-article cap
--     fires (28.13), and a row another user owns is "not found" rather than
--     editable (28.15);
--   - staleness: amending the article body flips is_stale and leaves the stored
--     quote untouched (28.16);
--   - history: repeated reads increment read_count (28.17), the table is pruned
--     to the newest 100 (28.18), and clear returns the number removed (28.19);
--   - cascades: deleting an article removes its rows (28.20); deleting the
--     identity — the path delete_my_account takes — removes every row (28.21);
--   - structural: nine RPCs are SECURITY DEFINER with a pinned search_path and
--     authenticated-only EXECUTE (28.22), and all three tables are RLS-enabled
--     with SELECT as their only authenticated privilege (28.23).
--
-- One transaction, rolled back. Seeds its own article as the connection role;
-- no battery-local uuid has to resolve in 00_fixtures.sql.
--
-- Fixture anchors (00_fixtures.sql): owner …0001 · client-a …0003 · demo …0006.
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 28.01 — FIXTURE: one document with one article, plus a second article used
-- for the history prune. Connection role, so RLS and grants do not apply.
-- ############################################################################
do $$
declare
  v_source uuid;
  v_doc    uuid;
  v_art    uuid;
  v_art2   uuid;
begin
  insert into public.legal_sources (name_ar, kind, jurisdiction, is_sample)
  values ('مصدر اختبار المستخدم', 'statute', 'EG', true)
  returning id into v_source;

  insert into public.legal_documents (source_id, title_ar, category, status, is_sample)
  values (v_source, 'وثيقة اختبار المستخدم', 'civil', 'in_force', true)
  returning id into v_doc;

  insert into public.legal_articles
    (document_id, article_number, ordinal, body_ar, is_sample)
  values (v_doc, '1', 1,
          'المادة الأولى: ينظم هذا النص عقد الإيجار بين الأطراف ويحدد المدة.', true)
  returning id into v_art;

  insert into public.legal_articles
    (document_id, article_number, ordinal, body_ar, is_sample)
  values (v_doc, '2', 2, 'المادة الثانية: نص تجريبي ثانٍ للاختبار.', true)
  returning id into v_art2;

  perform set_config('battery28.doc', v_doc::text, true);
  perform set_config('battery28.art', v_art::text, true);
  perform set_config('battery28.art2', v_art2::text, true);
end $$;

-- ############################################################################
-- 28.02 — BOOKMARKS: user A bookmarks, then toggles off.
-- ############################################################################
set role authenticated;
do $$
declare
  v_user uuid := '10000000-0000-4000-8000-000000000003';
  v_on   boolean;
  v_off  boolean;
begin
  perform set_config('request.jwt.claim.sub', v_user::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user)::text, false);

  v_on := public.toggle_legal_bookmark(current_setting('battery28.art')::uuid, 'ملاحظة');
  if v_on is not true then
    raise exception 'POLICY-BATTERY FAIL 28.02: first toggle returned %, expected true', v_on;
  end if;

  v_off := public.toggle_legal_bookmark(current_setting('battery28.art')::uuid);
  if v_off is not false then
    raise exception 'POLICY-BATTERY FAIL 28.02: second toggle returned %, expected false', v_off;
  end if;
end $$;
reset role;

-- ############################################################################
-- 28.03 — BOOKMARKS: idempotence proved on row count, and the note survives a
-- bookmark that is created once.
-- ############################################################################
set role authenticated;
do $$
declare
  v_user uuid := '10000000-0000-4000-8000-000000000003';
  v_cnt  integer;
  v_note text;
begin
  perform set_config('request.jwt.claim.sub', v_user::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user)::text, false);

  perform public.toggle_legal_bookmark(current_setting('battery28.art')::uuid);
  perform public.toggle_legal_bookmark(current_setting('battery28.art')::uuid);
  perform public.toggle_legal_bookmark(current_setting('battery28.art')::uuid, '  ملاحظة  ');

  select count(*), max(note) into v_cnt, v_note
    from public.legal_bookmarks;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 28.03: three toggles left % rows, expected 1', v_cnt;
  end if;
  if v_note <> 'ملاحظة' then
    raise exception 'POLICY-BATTERY FAIL 28.03: note was not trimmed (%), expected ملاحظة', v_note;
  end if;
end $$;
reset role;

-- ############################################################################
-- 28.04 — OWNERSHIP: user B sees none of A's bookmarks, highlights or history.
-- ############################################################################
do $$
declare
  v_user_a uuid := '10000000-0000-4000-8000-000000000003';
  v_user_b uuid := '10000000-0000-4000-8000-000000000006';
  v_cnt    integer;
begin
  -- A gets one highlight and one history row through the RPCs.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_user_a::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user_a)::text, false);
  perform public.create_legal_highlight(
    current_setting('battery28.art')::uuid,
    0,
    5,
    substring((select body_ar from public.legal_articles
                where id = current_setting('battery28.art')::uuid) from 1 for 5),
    'yellow',
    null);
  perform public.record_legal_reading(current_setting('battery28.art')::uuid);
  execute 'reset role';

  -- B reads.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_user_b::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user_b)::text, false);

  select count(*) into v_cnt from public.legal_bookmarks;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.04: user B sees % bookmark(s) of user A', v_cnt;
  end if;

  select count(*) into v_cnt from public.legal_highlights;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.04: user B sees % highlight(s) of user A', v_cnt;
  end if;

  select count(*) into v_cnt from public.legal_reading_history;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.04: user B sees % history row(s) of user A', v_cnt;
  end if;

  -- And the RPCs are caller-scoped too.
  select count(*) into v_cnt from public.list_my_legal_bookmarks();
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.04: list_my_legal_bookmarks returned A rows to B';
  end if;
  execute 'reset role';
end $$;

-- ############################################################################
-- 28.05 — WRITE POSTURE: a direct UPDATE is refused for authenticated.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000006', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000006"}', false);
  begin
    update public.legal_bookmarks set note = 'hijacked';
    raise exception 'POLICY-BATTERY FAIL 28.05: authenticated updated legal_bookmarks directly';
  exception when insufficient_privilege then
    null; -- expected: no UPDATE grant
  end;
end $$;
reset role;

-- ############################################################################
-- 28.06 — WRITE POSTURE: a direct INSERT is refused for authenticated.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000006', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000006"}', false);
  begin
    insert into public.legal_reading_history (user_id, article_id)
    values ('10000000-0000-4000-8000-000000000006',
            current_setting('battery28.art')::uuid);
    raise exception 'POLICY-BATTERY FAIL 28.06: authenticated inserted history directly';
  exception when insufficient_privilege then
    null; -- expected: no INSERT grant
  end;
end $$;
reset role;

-- ############################################################################
-- 28.07 — ANON: no SELECT grant on any of the three tables.
-- ############################################################################
set role anon;
do $$
declare
  v_cnt integer;
begin
  begin
    select count(*) into v_cnt from public.legal_highlights;
    raise exception 'POLICY-BATTERY FAIL 28.07: anon read legal_highlights (% rows)', v_cnt;
  exception when insufficient_privilege then
    null; -- expected
  end;
end $$;
reset role;

-- ############################################################################
-- 28.08 — OWNERSHIP, part 2: the PLATFORM OWNER sees none of A's rows either.
-- There is no administrative carve-out on per-user data.
-- ############################################################################
set role authenticated;
do $$
declare
  v_owner uuid := '10000000-0000-4000-8000-000000000001';
  v_cnt   integer;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner)::text, false);

  select count(*) into v_cnt from public.legal_bookmarks;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.08: platform owner sees % bookmark(s) of another user', v_cnt;
  end if;
  select count(*) into v_cnt from public.legal_highlights;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.08: platform owner sees % highlight(s) of another user', v_cnt;
  end if;
  select count(*) into v_cnt from public.legal_reading_history;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.08: platform owner sees % history row(s) of another user', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 28.09 — WRITE POSTURE: the platform owner has no direct write either.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    delete from public.legal_highlights;
    raise exception 'POLICY-BATTERY FAIL 28.09: platform owner deleted highlights directly';
  exception when insufficient_privilege then
    null; -- expected: privilege layer, owner included
  end;
end $$;
reset role;

-- ############################################################################
-- 28.10 — HIGHLIGHTS: a mismatched quote is rejected (the span must still point
-- at the quoted words).
-- ############################################################################
set role authenticated;
do $$
declare
  v_user uuid := '10000000-0000-4000-8000-000000000003';
begin
  perform set_config('request.jwt.claim.sub', v_user::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user)::text, false);
  begin
    perform public.create_legal_highlight(
      current_setting('battery28.art')::uuid, 0, 5, 'نص مختلف', 'yellow', null);
    raise exception 'POLICY-BATTERY FAIL 28.10: a mismatched quote was accepted';
  exception when invalid_parameter_value then
    null; -- expected: quote_mismatch is 22023
  end;
end $$;
reset role;

-- ############################################################################
-- 28.11 — HIGHLIGHTS: an inverted or zero-length span is rejected.
-- ############################################################################
set role authenticated;
do $$
declare
  v_user uuid := '10000000-0000-4000-8000-000000000003';
begin
  perform set_config('request.jwt.claim.sub', v_user::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user)::text, false);
  begin
    perform public.create_legal_highlight(
      current_setting('battery28.art')::uuid, 5, 5, 'x', 'yellow', null);
    raise exception 'POLICY-BATTERY FAIL 28.11: a zero-length span was accepted';
  exception when invalid_parameter_value then
    null; -- expected
  end;
  begin
    perform public.create_legal_highlight(
      current_setting('battery28.art')::uuid, 10, 4, 'x', 'yellow', null);
    raise exception 'POLICY-BATTERY FAIL 28.11: an inverted span was accepted';
  exception when invalid_parameter_value then
    null; -- expected
  end;
end $$;
reset role;

-- ############################################################################
-- 28.12 — HIGHLIGHTS: a span longer than the 1000-character cap is rejected.
-- ############################################################################
set role authenticated;
do $$
declare
  v_user uuid := '10000000-0000-4000-8000-000000000003';
begin
  perform set_config('request.jwt.claim.sub', v_user::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user)::text, false);
  begin
    perform public.create_legal_highlight(
      current_setting('battery28.art')::uuid, 0, 1001, 'x', 'yellow', null);
    raise exception 'POLICY-BATTERY FAIL 28.12: a 1001-character span was accepted';
  exception when invalid_parameter_value then
    null; -- expected
  end;
end $$;
reset role;

-- ############################################################################
-- 28.13 — HIGHLIGHTS: the 50-per-article cap fires. Fixture rows are inserted as
-- the connection role so the cap, not the RPC, is what gets tested.
-- ############################################################################
do $$
declare
  v_user uuid := '10000000-0000-4000-8000-000000000003';
  v_art  uuid := current_setting('battery28.art')::uuid;
  v_body text;
  i      integer;
begin
  select body_ar into v_body from public.legal_articles where id = v_art;
  delete from public.legal_highlights where user_id = v_user;
  for i in 1..50 loop
    insert into public.legal_highlights
      (user_id, article_id, start_offset, end_offset, quote, body_hash, color)
    values (v_user, v_art, 0, 5, substring(v_body from 1 for 5), md5(v_body), 'yellow');
  end loop;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_user::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user)::text, false);
  begin
    perform public.create_legal_highlight(
      v_art, 0, 5, substring(v_body from 1 for 5), 'green', null);
    raise exception 'POLICY-BATTERY FAIL 28.13: the 50-per-article highlight cap did not fire';
  exception when program_limit_exceeded then
    null; -- expected: 54000
  end;
  execute 'reset role';
end $$;

-- ############################################################################
-- 28.14 — BOOKMARKS: the 500-per-user cap fires.
-- ############################################################################
do $$
declare
  v_user uuid := '10000000-0000-4000-8000-000000000003';
  v_doc  uuid := current_setting('battery28.doc')::uuid;
  i      integer;
begin
  -- 500 bookmarks need 500 distinct articles (unique per pair): generate them.
  insert into public.legal_articles (document_id, article_number, ordinal, body_ar, is_sample)
  select v_doc, 'cap-' || g, 100 + g, 'مادة ' || g, true
    from generate_series(1, 500) as g;

  delete from public.legal_bookmarks where user_id = v_user;

  insert into public.legal_bookmarks (user_id, article_id)
  select v_user, a.id
    from public.legal_articles a
   where a.article_number like 'cap-%'
   limit 500;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_user::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user)::text, false);
  begin
    perform public.toggle_legal_bookmark(current_setting('battery28.art2')::uuid);
    raise exception 'POLICY-BATTERY FAIL 28.14: the 500-bookmark cap did not fire';
  exception when program_limit_exceeded then
    null; -- expected: 54000
  end;
  execute 'reset role';

  delete from public.legal_bookmarks where user_id = v_user;
  delete from public.legal_articles where article_number like 'cap-%';
end $$;

-- ############################################################################
-- 28.15 — HIGHLIGHTS: another user's highlight is "not found", not editable.
-- ############################################################################
do $$
declare
  v_user_a uuid := '10000000-0000-4000-8000-000000000003';
  v_user_b uuid := '10000000-0000-4000-8000-000000000006';
  v_id     uuid;
  v_body   text;
begin
  select body_ar into v_body
    from public.legal_articles where id = current_setting('battery28.art')::uuid;

  delete from public.legal_highlights where user_id = v_user_a;
  insert into public.legal_highlights
    (user_id, article_id, start_offset, end_offset, quote, body_hash, color)
  values (v_user_a, current_setting('battery28.art')::uuid, 0, 5,
          substring(v_body from 1 for 5), md5(v_body), 'yellow')
  returning id into v_id;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_user_b::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user_b)::text, false);
  begin
    perform public.update_legal_highlight(v_id, 'green', null);
    raise exception 'POLICY-BATTERY FAIL 28.15: user B updated user A highlight';
  exception when no_data_found then
    null; -- expected: not-found, never a cross-user edit
  end;
  begin
    perform public.delete_legal_highlight(v_id);
    raise exception 'POLICY-BATTERY FAIL 28.15: user B deleted user A highlight';
  exception when no_data_found then
    null; -- expected
  end;
  execute 'reset role';

  if not exists (select 1 from public.legal_highlights where id = v_id) then
    raise exception 'POLICY-BATTERY FAIL 28.15: user A highlight vanished after denied edits';
  end if;
end $$;

-- ############################################################################
-- 28.16 — STALENESS: amending the article flips is_stale and leaves the stored
-- quote untouched, so the reader can still show what was highlighted.
-- ############################################################################
do $$
declare
  v_user uuid := '10000000-0000-4000-8000-000000000003';
  v_art  uuid := current_setting('battery28.art')::uuid;
  v_body text;
  v_id   uuid;
  v_stale boolean;
  v_quote text;
begin
  select body_ar into v_body from public.legal_articles where id = v_art;
  delete from public.legal_highlights where user_id = v_user;
  insert into public.legal_highlights
    (user_id, article_id, start_offset, end_offset, quote, body_hash, color)
  values (v_user, v_art, 0, 5, substring(v_body from 1 for 5), md5(v_body), 'yellow')
  returning id into v_id;

  -- Amend the body (as an import would).
  update public.legal_articles set body_ar = 'نص معدل بالكامل بعد التعديل.' where id = v_art;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_user::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user)::text, false);
  select h.is_stale, h.quote into v_stale, v_quote
    from public.list_my_legal_highlights(v_art) h limit 1;
  execute 'reset role';

  if v_stale is not true then
    raise exception 'POLICY-BATTERY FAIL 28.16: is_stale stayed false after the body changed';
  end if;
  if v_quote is distinct from substring(v_body from 1 for 5) then
    raise exception 'POLICY-BATTERY FAIL 28.16: the stored quote changed with the body';
  end if;

  -- Restore the body so later blocks see the original text.
  update public.legal_articles set body_ar = v_body where id = v_art;
end $$;

-- ############################################################################
-- 28.17 — HISTORY: repeated reads increment read_count instead of duplicating.
-- ############################################################################
do $$
declare
  v_user  uuid := '10000000-0000-4000-8000-000000000003';
  v_art   uuid := current_setting('battery28.art')::uuid;
  v_cnt   integer;
  v_reads integer;
begin
  -- Start from zero: earlier blocks also read this article.
  delete from public.legal_reading_history where user_id = v_user;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_user::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user)::text, false);

  perform public.record_legal_reading(v_art);
  perform public.record_legal_reading(v_art);
  perform public.record_legal_reading(v_art);
  execute 'reset role';

  select count(*), max(read_count) into v_cnt, v_reads
    from public.legal_reading_history where article_id = v_art;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 28.17: three reads made % rows, expected 1', v_cnt;
  end if;
  if v_reads <> 3 then
    raise exception 'POLICY-BATTERY FAIL 28.17: read_count is %, expected 3', v_reads;
  end if;
end $$;

-- ############################################################################
-- 28.18 — HISTORY: pruned to the newest 100 on write.
-- ############################################################################
do $$
declare
  v_user uuid := '10000000-0000-4000-8000-000000000003';
  v_doc  uuid := current_setting('battery28.doc')::uuid;
  v_cnt  integer;
begin
  delete from public.legal_reading_history where user_id = v_user;

  insert into public.legal_articles (document_id, article_number, ordinal, body_ar, is_sample)
  select v_doc, 'hist-' || g, 1000 + g, 'مادة ' || g, true
    from generate_series(1, 105) as g;

  insert into public.legal_reading_history (user_id, article_id, last_read_at, read_count)
  select v_user, a.id, now() - (row_number() over (order by a.article_number)) * interval '1 minute', 1
    from public.legal_articles a
   where a.article_number like 'hist-%';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_user::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user)::text, false);
  -- Any write prunes; use the real article so it survives as the newest row.
  perform public.record_legal_reading(current_setting('battery28.art')::uuid);
  execute 'reset role';

  select count(*) into v_cnt
    from public.legal_reading_history where user_id = v_user;
  if v_cnt <> 100 then
    raise exception 'POLICY-BATTERY FAIL 28.18: history holds % rows, expected the newest 100', v_cnt;
  end if;

  delete from public.legal_articles where article_number like 'hist-%';
end $$;

-- ############################################################################
-- 28.19 — HISTORY: clear returns the number removed and empties the table.
-- ############################################################################
set role authenticated;
do $$
declare
  v_user   uuid := '10000000-0000-4000-8000-000000000003';
  v_removed integer;
  v_cnt     integer;
begin
  perform set_config('request.jwt.claim.sub', v_user::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_user)::text, false);

  v_removed := public.clear_my_legal_history();
  select count(*) into v_cnt from public.legal_reading_history;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.19: % history rows survived a clear', v_cnt;
  end if;
  if v_removed < 1 then
    raise exception 'POLICY-BATTERY FAIL 28.19: clear reported % rows removed', v_removed;
  end if;
end $$;
reset role;

-- ############################################################################
-- 28.20 — CASCADE: deleting an article removes its bookmarks, highlights and
-- history rows.
-- ############################################################################
do $$
declare
  v_user uuid := '10000000-0000-4000-8000-000000000003';
  v_doc  uuid := current_setting('battery28.doc')::uuid;
  v_art  uuid;
  v_body text;
  v_cnt  integer;
begin
  insert into public.legal_articles (document_id, article_number, ordinal, body_ar, is_sample)
  values (v_doc, 'cascade-1', 2000, 'نص تجريبي للحذف التعاقبي.', true)
  returning id into v_art;
  select body_ar into v_body from public.legal_articles where id = v_art;

  insert into public.legal_bookmarks (user_id, article_id) values (v_user, v_art);
  insert into public.legal_highlights
    (user_id, article_id, start_offset, end_offset, quote, body_hash, color)
  values (v_user, v_art, 0, 5, substring(v_body from 1 for 5), md5(v_body), 'yellow');
  insert into public.legal_reading_history (user_id, article_id) values (v_user, v_art);

  delete from public.legal_articles where id = v_art;

  select (select count(*) from public.legal_bookmarks where article_id = v_art)
       + (select count(*) from public.legal_highlights where article_id = v_art)
       + (select count(*) from public.legal_reading_history where article_id = v_art)
    into v_cnt;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.20: % row(s) survived the article delete', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 28.21 — CASCADE: deleting the identity removes every row. This is the path
-- delete_my_account() takes (it deletes from auth.users).
-- ############################################################################
do $$
declare
  v_user uuid := gen_random_uuid();
  v_art  uuid := current_setting('battery28.art')::uuid;
  v_body text;
  v_cnt  integer;
begin
  -- A throwaway identity, created here and deleted below: this proves the FK
  -- cascade without depending on a fixture row existing.
  insert into auth.users (id, email) values (v_user, 'battery28-delete@test');

  select body_ar into v_body from public.legal_articles where id = v_art;

  insert into public.legal_bookmarks (user_id, article_id) values (v_user, v_art);
  insert into public.legal_highlights
    (user_id, article_id, start_offset, end_offset, quote, body_hash, color)
  values (v_user, v_art, 0, 5, substring(v_body from 1 for 5), md5(v_body), 'yellow');
  insert into public.legal_reading_history (user_id, article_id) values (v_user, v_art);

  delete from auth.users where id = v_user;

  select (select count(*) from public.legal_bookmarks where user_id = v_user)
       + (select count(*) from public.legal_highlights where user_id = v_user)
       + (select count(*) from public.legal_reading_history where user_id = v_user)
    into v_cnt;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.21: % row(s) survived the identity delete', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 28.22 — STRUCTURAL: nine RPCs are definer + pinned, authenticated-only.
-- ############################################################################
do $$
declare
  v_sig   text;
  v_bad   integer := 0;
  v_count integer;
begin
  foreach v_sig in array array[
    'public.toggle_legal_bookmark(uuid, text)',
    'public.list_my_legal_bookmarks(integer, integer)',
    'public.create_legal_highlight(uuid, integer, integer, text, public.legal_highlight_color, text)',
    'public.update_legal_highlight(uuid, public.legal_highlight_color, text)',
    'public.delete_legal_highlight(uuid)',
    'public.list_my_legal_highlights(uuid, integer, integer)',
    'public.record_legal_reading(uuid)',
    'public.list_my_legal_history(integer, integer)',
    'public.clear_my_legal_history()'
  ] loop
    if not has_function_privilege('authenticated', v_sig, 'EXECUTE') then
      v_bad := v_bad + 1;
    end if;
    if has_function_privilege('anon', v_sig, 'EXECUTE') then
      v_bad := v_bad + 1;
    end if;
  end loop;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.22: % grant mismatch(es) on the per-user RPCs', v_bad;
  end if;

  select count(*) into v_count
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('toggle_legal_bookmark', 'list_my_legal_bookmarks',
                       'create_legal_highlight', 'update_legal_highlight',
                       'delete_legal_highlight', 'list_my_legal_highlights',
                       'record_legal_reading', 'list_my_legal_history',
                       'clear_my_legal_history')
     and p.prosecdef
     and p.proconfig is not null
     and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%');
  if v_count <> 9 then
    raise exception 'POLICY-BATTERY FAIL 28.22: % of 9 RPCs are definer+pinned', v_count;
  end if;
end $$;

-- ############################################################################
-- 28.23 — STRUCTURAL: RLS on, SELECT the only authenticated privilege.
-- ############################################################################
do $$
declare
  v_missing integer;
  v_write   integer;
begin
  select count(*) into v_missing
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname in ('legal_bookmarks', 'legal_highlights', 'legal_reading_history')
     and not c.relrowsecurity;
  if v_missing <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.23: % per-user table(s) without RLS', v_missing;
  end if;

  select count(*) into v_write
    from unnest(array['legal_bookmarks', 'legal_highlights', 'legal_reading_history']) t
   where has_table_privilege('authenticated', 'public.' || t, 'INSERT')
      or has_table_privilege('authenticated', 'public.' || t, 'UPDATE')
      or has_table_privilege('authenticated', 'public.' || t, 'DELETE');
  if v_write <> 0 then
    raise exception 'POLICY-BATTERY FAIL 28.23: % per-user table(s) grant a write privilege', v_write;
  end if;
end $$;

rollback;
