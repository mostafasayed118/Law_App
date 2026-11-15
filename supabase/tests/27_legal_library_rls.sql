-- ============================================================================
-- supabase/tests/27_legal_library_rls.sql — Legal Library slice 1 battery
--
-- Pins supabase/migrations/32_legal_library.sql + supabase/policies/legal_*.sql:
--   - read posture: any authenticated user reads the global library (27.02),
--     anon is denied at the privilege layer (27.03);
--   - write posture: an authenticated non-owner cannot insert (27.04),
--     update (27.05) or delete (27.06); the platform owner can do all three
--     (27.09, 27.10, 27.11);
--   - normalisation: a bare-alef query reaches a hamza spelling and tashkeel
--     is ignored (27.12, 27.13); the article-stripped half of search_text
--     makes "ايجار" reach "الايجار" (27.14);
--   - search contract: an unknown term returns nothing (27.15), an empty
--     query is an empty result and not an error (27.16), a query over 200
--     characters is rejected (27.17), and the limit is hard-capped at 50
--     while total_count still reports the full match set (27.18);
--   - category filter narrows the hit set (27.19);
--   - detail reads: get_legal_document returns the articles in ordinal order
--     including a "5 مكرر" style number (27.20) and get_legal_article exposes
--     its prev/next neighbours (27.21);
--   - structural posture: the four RPCs are SECURITY DEFINER with a pinned
--     search_path (27.22), authenticated holds EXECUTE and anon does not
--     (27.23), and all three tables are RLS-enabled (27.24).
--
-- The battery runs in ONE transaction and ROLLS BACK. It seeds its own rows
-- (the rehearsal never applies supabase/seed/), starts from an empty library,
-- and leaves nothing behind. Row ids are generated at run time and carried
-- between blocks through transaction-local settings, so no battery-local uuid
-- has to resolve in 00_fixtures.sql.
--
-- Fixture anchors (00_fixtures.sql): owner …0001 (platform owner) ·
-- client-a …0003 (active org-a client, not an owner) · demo …0006 (no
-- membership — the global-library read must not depend on membership).
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 27.01 — FIXTURE: one civil document with a "5 مكرر" article, one labour
-- document, and a 55-article document used only for the limit-cap check.
-- Inserted as the connection role, so RLS does not apply to the fixture.
-- ############################################################################
do $$
declare
  v_source uuid;
  v_civil  uuid;
  v_labour uuid;
  v_bulk   uuid;
begin
  insert into public.legal_sources (name_ar, name_en, kind, jurisdiction, is_sample)
  values ('مصدر اختبار', 'Battery Source', 'statute', 'EG', true)
  returning id into v_source;

  insert into public.legal_documents
    (source_id, title_ar, title_en, official_number, year, category, status,
     summary_ar, published_at, is_sample)
  values (v_source, 'قانون الإيجار التجريبي', 'Battery Lease Law', 'BT-1', 2020,
          'civil', 'in_force', 'ملخص تجريبي.', '2020-01-01', true)
  returning id into v_civil;

  insert into public.legal_documents
    (source_id, title_ar, title_en, official_number, year, category, status,
     summary_ar, published_at, is_sample)
  values (v_source, 'لائحة العمل التجريبية', 'Battery Labour Regulation', 'BT-2',
          2021, 'labor', 'amended', 'ملخص تجريبي.', '2021-01-01', true)
  returning id into v_labour;

  insert into public.legal_documents
    (source_id, title_ar, official_number, year, category, status, is_sample)
  values (v_source, 'وثيقة الحد الأقصى', 'BT-3', 2022, 'other', 'unknown', true)
  returning id into v_bulk;

  insert into public.legal_articles
    (document_id, article_number, ordinal, heading_ar, body_ar, is_sample)
  values
    (v_civil, '1', 1, 'نطاق التطبيق',
     'ينظم هذا النص عقد الإيجار بين الأطراف ويحدد مدة الإيجار.', true),
    (v_civil, '2', 2, 'الإنهاء',
     'يجوز إنهاء العقد بإخطار كتابي مسبق.', true),
    (v_civil, '3', 3, 'الأجرة',
     'تُحدد الأجرة سنوياً باتفاق الطرفين.', true),
    (v_civil, '4', 4, 'الالتزامات',
     'يلتزم المستأجر بالمحافظة على العين المؤجرة.', true),
    (v_civil, '5', 5, 'التنازل',
     'لا يجوز التنازل عن العقد دون موافقة كتابية.', true),
    (v_civil, '5 مكرر', 6, 'أحكام انتقالية',
     'تُطبق الأحكام الانتقالية على العقود السارية.', true),
    (v_labour, '1', 1, 'نطاق التطبيق',
     'ينظم هذا النص علاقة العمل بين صاحب العمل والعامل.', true),
    (v_labour, '2', 2, 'الأجر',
     'يستحق العامل أجره في المواعيد المتفق عليها.', true);

  -- 55 short articles sharing one phrase, for the limit-cap assertion. The
  -- wording keeps the bare "الحد" token so both search arms can reach it.
  insert into public.legal_articles
    (document_id, article_number, ordinal, body_ar, is_sample)
  select v_bulk, g::text, g, 'مادة تجريبية عن الحد الأقصى رقم ' || g, true
    from generate_series(1, 55) as g;

  perform set_config('battery27.civil', v_civil::text, true);
  perform set_config('battery27.labour', v_labour::text, true);
  perform set_config('battery27.bulk', v_bulk::text, true);
end $$;

-- ############################################################################
-- 27.02 — READ (non-owner, no membership): client-a is an active org-a
-- client. The library is global, so the read must not depend on membership;
-- demo …0006 has NO membership at all and must also read. Both are covered
-- here: client-a reads first, demo reads in the same block.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt integer;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt from public.legal_articles;
  if v_cnt <> 63 then
    raise exception 'POLICY-BATTERY FAIL 27.02: client-a read % articles, expected 63', v_cnt;
  end if;

  -- No membership at all: still readable, because the content is global.
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000006', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000006"}', false);
  select count(*) into v_cnt from public.legal_articles;
  if v_cnt <> 63 then
    raise exception 'POLICY-BATTERY FAIL 27.02: demo account (no membership) read % articles, expected 63', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.03 — READ (anon): anon holds no SELECT grant, so the table is
-- unreachable at the privilege layer, not merely filtered by RLS.
-- ############################################################################
set role anon;
do $$
declare
  v_cnt integer;
begin
  begin
    select count(*) into v_cnt from public.legal_articles;
    raise exception 'POLICY-BATTERY FAIL 27.03: anon select succeeded (% rows)', v_cnt;
  exception when insufficient_privilege then
    null; -- expected: no table grant
  end;
end $$;
reset role;

-- ############################################################################
-- 27.04 — WRITE (non-owner insert): an authenticated client cannot create a
-- document. Expect an RLS violation, and no row created.
-- ############################################################################
set role authenticated;
do $$
declare
  v_before integer;
  v_after  integer;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_before from public.legal_documents;
  begin
    insert into public.legal_documents
      (source_id, title_ar, category, status, is_sample)
    select id, 'محاولة غير مصرح بها', 'civil', 'unknown', true
      from public.legal_sources limit 1;
    raise exception 'POLICY-BATTERY FAIL 27.04: a non-owner inserted a legal document';
  exception when insufficient_privilege then
    null; -- expected: RLS with check denies
  end;
  select count(*) into v_after from public.legal_documents;
  if v_after <> v_before then
    raise exception 'POLICY-BATTERY FAIL 27.04: row count moved from % to % after a denied insert',
      v_before, v_after;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.05 — WRITE (non-owner update): the UPDATE is filtered by RLS, so zero
-- rows are affected and the title is unchanged.
-- ############################################################################
set role authenticated;
do $$
declare
  v_rows    integer;
  v_title   text;
  v_civil   uuid := current_setting('battery27.civil')::uuid;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  update public.legal_documents set title_ar = 'عنوان معدل'
   where id = v_civil;
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then
    raise exception 'POLICY-BATTERY FAIL 27.05: a non-owner updated % document row(s)', v_rows;
  end if;
  select title_ar into v_title from public.legal_documents where id = v_civil;
  if v_title <> 'قانون الإيجار التجريبي' then
    raise exception 'POLICY-BATTERY FAIL 27.05: title changed to % after a denied update', v_title;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.06 — WRITE (non-owner delete): zero rows affected, row still present.
-- ############################################################################
set role authenticated;
do $$
declare
  v_rows integer;
  v_cnt  integer;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  delete from public.legal_documents
   where id = current_setting('battery27.civil')::uuid;
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then
    raise exception 'POLICY-BATTERY FAIL 27.06: a non-owner deleted % document row(s)', v_rows;
  end if;
  select count(*) into v_cnt from public.legal_documents
   where id = current_setting('battery27.civil')::uuid;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 27.06: the document disappeared after a denied delete';
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.07 — WRITE (non-owner insert into legal_articles): same boundary on the
-- article table, which is the one a future bookmark slice will join against.
-- ############################################################################
set role authenticated;
do $$
declare
  v_rows integer;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  insert into public.legal_articles
    (document_id, article_number, ordinal, body_ar, is_sample)
  values (current_setting('battery27.civil')::uuid, '99', 99,
          'محاولة إدراج غير مصرح بها', true);
  get diagnostics v_rows = row_count;
  raise exception 'POLICY-BATTERY FAIL 27.07: a non-owner inserted an article (% rows)', v_rows;
exception when insufficient_privilege then
  null; -- expected: RLS with check denies
end $$;
reset role;

-- ############################################################################
-- 27.08 — WRITE (non-owner insert into legal_sources)
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  insert into public.legal_sources (name_ar, kind, jurisdiction, is_sample)
  values ('مصدر غير مصرح', 'statute', 'EG', true);
  raise exception 'POLICY-BATTERY FAIL 27.08: a non-owner inserted a legal source';
exception when insufficient_privilege then
  null; -- expected
end $$;
reset role;

-- ############################################################################
-- 27.09 — WRITE (platform owner insert): the owner creates a document and the
-- row is visible afterwards. This is the boundary the importer will rely on.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  insert into public.legal_documents
    (source_id, title_ar, category, status, is_sample)
  select id, 'وثيقة أنشأها المالك', 'other', 'unknown', false
    from public.legal_sources limit 1
  returning id into v_id;
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 27.09: the platform owner could not insert a document';
  end if;
  perform set_config('battery27.owner_doc', v_id::text, true);
end $$;
reset role;

-- ############################################################################
-- 27.10 — WRITE (platform owner update)
-- ############################################################################
set role authenticated;
do $$
declare
  v_rows  integer;
  v_title text;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  update public.legal_documents set title_ar = 'وثيقة عدلها المالك'
   where id = current_setting('battery27.owner_doc')::uuid;
  get diagnostics v_rows = row_count;
  if v_rows <> 1 then
    raise exception 'POLICY-BATTERY FAIL 27.10: the owner updated % rows, expected 1', v_rows;
  end if;
  select title_ar into v_title from public.legal_documents
   where id = current_setting('battery27.owner_doc')::uuid;
  if v_title <> 'وثيقة عدلها المالك' then
    raise exception 'POLICY-BATTERY FAIL 27.10: the owner update did not land (%)', v_title;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.11 — WRITE (platform owner delete)
-- ############################################################################
set role authenticated;
do $$
declare
  v_rows integer;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  delete from public.legal_documents
   where id = current_setting('battery27.owner_doc')::uuid;
  get diagnostics v_rows = row_count;
  if v_rows <> 1 then
    raise exception 'POLICY-BATTERY FAIL 27.11: the owner deleted % rows, expected 1', v_rows;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.12 — SEARCH: a bare-alef query reaches the hamza spelling. The fixture
-- body says "الإيجار"; the query says "الايجار".
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt integer;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt from public.search_legal_library('الايجار');
  if v_cnt < 1 then
    raise exception 'POLICY-BATTERY FAIL 27.12: a bare-alef query matched % rows, expected at least 1', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.13 — SEARCH: tashkeel is ignored (query carries a fatha the body lacks).
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt integer;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt from public.search_legal_library('الإيجَار');
  if v_cnt < 1 then
    raise exception 'POLICY-BATTERY FAIL 27.13: a diacritised query matched % rows, expected at least 1', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.14 — SEARCH: the article-stripped half of search_text lets a query
-- WITHOUT the Arabic article reach a body that has it ("ايجار" -> "الايجار").
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt integer;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt from public.search_legal_library('ايجار');
  if v_cnt < 1 then
    raise exception 'POLICY-BATTERY FAIL 27.14: "ايجار" matched % rows, expected the "الايجار" articles', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.15 — SEARCH: an unknown term returns nothing rather than everything.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt integer;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.search_legal_library('zzzznonexistentterm');
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 27.15: an unknown term returned % rows, expected 0', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.16 — SEARCH: an empty or whitespace query is an empty result, never an
-- error (the surface renders its no-query arm off this).
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt integer;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt from public.search_legal_library('');
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 27.16: an empty query returned % rows', v_cnt;
  end if;
  select count(*) into v_cnt from public.search_legal_library('   ');
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 27.16: a whitespace query returned % rows', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.17 — SEARCH: a query longer than 200 characters is rejected with
-- invalid_parameter_value rather than silently truncated.
-- ############################################################################
set role authenticated;
do $$
declare
  v_long text := repeat('ا', 201);
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform count(*) from public.search_legal_library(v_long);
    raise exception 'POLICY-BATTERY FAIL 27.17: a 201-character query was accepted';
  exception when invalid_parameter_value then
    null; -- expected
  end;
end $$;
reset role;

-- ############################################################################
-- 27.18 — SEARCH: the limit is hard-capped at 50 while total_count still
-- reports the full match set (55 articles share the phrase).
-- ############################################################################
set role authenticated;
do $$
declare
  v_rows  integer;
  v_total bigint;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*), max(total_count) into v_rows, v_total
    from public.search_legal_library('الحد الأقصى', null, 999, 0);
  if v_rows <> 50 then
    raise exception 'POLICY-BATTERY FAIL 27.18: the limit cap returned % rows, expected 50', v_rows;
  end if;
  if v_total <> 55 then
    raise exception 'POLICY-BATTERY FAIL 27.18: total_count was %, expected 55', v_total;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.19 — SEARCH: the category filter narrows the hit set to that category.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt integer;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.search_legal_library('العقد', 'labor', 50, 0);
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 27.19: a labour-filtered query returned the civil rows (%)', v_cnt;
  end if;
  select count(*) into v_cnt
    from public.search_legal_library('العمل', 'labor', 50, 0);
  if v_cnt < 1 then
    raise exception 'POLICY-BATTERY FAIL 27.19: a labour-filtered query missed the labour article';
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.20 — DETAIL: get_legal_document returns the articles in ordinal order,
-- including the text-numbered "5 مكرر" row.
-- ############################################################################
set role authenticated;
do $$
declare
  v_max    integer;
  v_first  text;
  v_bis    text;
  v_total  bigint;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);

  select max(ordinal), max(article_total)
    into v_max, v_total
    from public.get_legal_document(current_setting('battery27.civil')::uuid);
  if v_max <> 6 then
    raise exception 'POLICY-BATTERY FAIL 27.20: last ordinal was %, expected 6', v_max;
  end if;
  if v_total <> 6 then
    raise exception 'POLICY-BATTERY FAIL 27.20: article_total was %, expected 6', v_total;
  end if;

  select article_number into v_first
    from public.get_legal_document(current_setting('battery27.civil')::uuid)
   order by ordinal limit 1;
  if v_first <> '1' then
    raise exception 'POLICY-BATTERY FAIL 27.20: first article was %, expected 1', v_first;
  end if;

  select article_number into v_bis
    from public.get_legal_document(current_setting('battery27.civil')::uuid)
   where ordinal = 6;
  if v_bis <> '5 مكرر' then
    raise exception 'POLICY-BATTERY FAIL 27.20: ordinal 6 was %, expected "5 مكرر"', v_bis;
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.21 — DETAIL: get_legal_article exposes prev/next neighbours, and the
-- first article has no predecessor.
-- ############################################################################
set role authenticated;
do $$
declare
  v_first_id uuid;
  v_prev     uuid;
  v_next     uuid;
begin
  perform set_config('request.jwt.claim.sub',
                     '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims',
                     '{"sub":"10000000-0000-4000-8000-000000000003"}', false);

  select article_id into v_first_id
    from public.get_legal_document(current_setting('battery27.civil')::uuid)
   order by ordinal limit 1;

  select prev_article_id, next_article_id into v_prev, v_next
    from public.get_legal_article(v_first_id);
  if v_prev is not null then
    raise exception 'POLICY-BATTERY FAIL 27.21: the first article reported a predecessor';
  end if;
  if v_next is null then
    raise exception 'POLICY-BATTERY FAIL 27.21: the first article reported no successor';
  end if;
end $$;
reset role;

-- ############################################################################
-- 27.22 — STRUCTURAL: the four RPCs are SECURITY DEFINER with a pinned
-- search_path (the repo's audited-RPC posture).
-- ############################################################################
do $$
declare
  v_bad integer;
begin
  select count(*) into v_bad
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('search_legal_library', 'list_legal_documents',
                       'get_legal_document', 'get_legal_article')
     and (not p.prosecdef
          or p.proconfig is null
          or not exists (select 1 from unnest(p.proconfig) c
                          where c like 'search\\_path=%'));
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 27.22: % library RPC(s) are not definer+pinned', v_bad;
  end if;

  select count(*) into v_bad
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('search_legal_library', 'list_legal_documents',
                       'get_legal_document', 'get_legal_article');
  if v_bad <> 4 then
    raise exception 'POLICY-BATTERY FAIL 27.22: expected 4 library RPCs, found %', v_bad;
  end if;
end $$;

-- ############################################################################
-- 27.23 — STRUCTURAL: authenticated holds EXECUTE on every library RPC; anon
-- holds none.
-- ############################################################################
do $$
declare
  v_sig text;
  v_bad integer := 0;
begin
  foreach v_sig in array array[
    'public.search_legal_library(text, public.legal_category, integer, integer)',
    'public.list_legal_documents(public.legal_category, integer, integer)',
    'public.get_legal_document(uuid, integer)',
    'public.get_legal_article(uuid)'
  ] loop
    if not has_function_privilege('authenticated', v_sig, 'EXECUTE') then
      v_bad := v_bad + 1;
    end if;
    if has_function_privilege('anon', v_sig, 'EXECUTE') then
      v_bad := v_bad + 1;
    end if;
  end loop;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 27.23: % grant mismatch(es) on the library RPCs', v_bad;
  end if;
end $$;

-- ############################################################################
-- 27.24 — STRUCTURAL: all three tables are RLS-enabled.
-- ############################################################################
do $$
declare
  v_missing integer;
begin
  select count(*) into v_missing
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname in ('legal_sources', 'legal_documents', 'legal_articles')
     and not c.relrowsecurity;
  if v_missing <> 0 then
    raise exception 'POLICY-BATTERY FAIL 27.24: % library table(s) without RLS', v_missing;
  end if;
end $$;

rollback;
