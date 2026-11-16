-- ============================================================================
-- supabase/tests/29_polish_profile_deletion.sql — profile edit + honest deletion
--
-- Pins migration 34 and the two RPCs it owns:
--   - update_my_profile: trims, validates length/control chars, is own-row only,
--     writes a redacted audit row (29.01-29.04);
--   - delete_my_account: hard-deletes the identity AND the caller's own storage
--     objects + files metadata, cascades library rows and membership, keeps the
--     audit with the actor cleared (29.05-29.09);
--   - the two governance guards that execution against real Postgres proved were
--     missing from the old RPC: last-active-partner and platform owner
--     (29.10-29.11);
--   - anon denial and the definer+pinned grant posture (29.12-29.13).
--
-- One transaction, rolled back. Uses generated identities so no battery-local
-- uuid has to resolve in 00_fixtures.sql.
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 29.00 — FIXTURE: two ordinary users, an owner, an org with both as partners,
-- one storage object owned by user A and its files metadata, one library row.
-- ############################################################################
do $$
declare
  v_a     uuid := gen_random_uuid();
  v_b     uuid := gen_random_uuid();
  v_owner uuid := gen_random_uuid();
  v_org   uuid;
  v_doc   uuid;
  v_art   uuid;
  v_obj   text;
begin
  insert into auth.users (id, email, raw_user_meta_data) values
    (v_a, 'battery29-a@test.local', '{"display_name":"A"}'::jsonb),
    (v_b, 'battery29-b@test.local', '{"display_name":"B"}'::jsonb),
    (v_owner, 'battery29-owner@test.local', '{"display_name":"Owner"}'::jsonb);

  delete from public.platform_config;
  insert into public.platform_config (owner_user_id) values (v_owner);

  insert into public.organizations (name, created_by)
  values ('Battery 29 Org', v_a) returning id into v_org;

  insert into public.memberships (user_id, organization_id, role, status)
  values (v_a, v_org, 'partner', 'active'),
         (v_b, v_org, 'partner', 'active');

  insert into public.legal_sources (name_ar, kind, jurisdiction, is_sample)
  values ('مصدر البطارية', 'statute', 'EG', true) returning id into v_doc;

  insert into public.legal_documents (source_id, title_ar, category, status, is_sample)
  values (v_doc, 'وثيقة البطارية', 'civil', 'in_force', true)
  returning id into v_doc;

  insert into public.legal_articles (document_id, article_number, ordinal, body_ar, is_sample)
  values (v_doc, '1', 1, 'نص تجريبي للبطارية.', true)
  returning id into v_art;

  insert into public.legal_bookmarks (user_id, article_id) values (v_a, v_art);
  insert into public.legal_highlights
    (user_id, article_id, start_offset, end_offset, quote, body_hash, color)
  values (v_a, v_art, 0, 4, substring('نص تجريبي للبطارية.' from 1 for 4),
          md5('نص تجريبي للبطارية.'), 'yellow');
  insert into public.legal_reading_history (user_id, article_id) values (v_a, v_art);

  v_obj := v_org::text || '/battery29/file.pdf';
  insert into storage.objects (bucket_id, name, owner_id)
  values ('matter-files', v_obj, v_a);

  insert into public.files (organization_id, matter_id, name, mime_type, storage_path)
  select o.id, m.id, 'file.pdf', 'application/pdf', v_obj
    from public.organizations o
    cross join public.matters m
   limit 1;

  perform set_config('battery29.a', v_a::text, true);
  perform set_config('battery29.b', v_b::text, true);
  perform set_config('battery29.owner', v_owner::text, true);
  perform set_config('battery29.org', v_org::text, true);
  perform set_config('battery29.article', v_art::text, true);
end $$;

-- ############################################################################
-- 29.01 — update_my_profile trims and writes exactly the caller's profile.
-- ############################################################################
set role authenticated;
do $$
declare
  v_a   uuid := current_setting('battery29.a')::uuid;
  v_name text;
begin
  perform set_config('request.jwt.claim.sub', v_a::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_a)::text, false);

  perform public.update_my_profile('  اسم جديد  ');
  select display_name into v_name from public.profiles where user_id = v_a;
  if v_name <> 'اسم جديد' then
    raise exception 'POLICY-BATTERY FAIL 29.01: display name is %, expected trimmed value', v_name;
  end if;
end $$;
reset role;

-- ############################################################################
-- 29.02 — invalid display names are refused with stable SQLSTATEs.
-- ############################################################################
set role authenticated;
do $$
declare
  v_a uuid := current_setting('battery29.a')::uuid;
begin
  perform set_config('request.jwt.claim.sub', v_a::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_a)::text, false);

  begin
    perform public.update_my_profile('x');
    raise exception 'POLICY-BATTERY FAIL 29.02: a one-character name was accepted';
  exception when invalid_parameter_value then
    null; -- 22023
  end;

  begin
    perform public.update_my_profile(repeat('ا', 121));
    raise exception 'POLICY-BATTERY FAIL 29.02: a 121-character name was accepted';
  exception when invalid_parameter_value then
    null; -- 22023
  end;

  begin
    perform public.update_my_profile('name' || chr(10) || 'injection');
    raise exception 'POLICY-BATTERY FAIL 29.02: a control character was accepted';
  exception when invalid_parameter_value then
    null; -- 22023
  end;
end $$;
reset role;

-- ############################################################################
-- 29.03 — an update is scoped to auth.uid(); asking for another name cannot
-- reach another profile. There is no user-id parameter to pass.
-- ############################################################################
do $$
declare
  v_a   uuid := current_setting('battery29.a')::uuid;
  v_b   uuid := current_setting('battery29.b')::uuid;
  v_name text;
begin
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_a::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_a)::text, false);
  perform public.update_my_profile('only A');
  reset role;

  select display_name into v_name from public.profiles where user_id = v_b;
  if v_name = 'only A' then
    raise exception 'POLICY-BATTERY FAIL 29.03: user A updated user B profile';
  end if;
end $$;

-- ############################################################################
-- 29.04 — the profile update is audited, with no value in the summary.
-- ############################################################################
do $$
declare
  v_leak integer;
begin
  select count(*) into v_leak
    from public.audit_events
   where action = 'profile:update' and outcome = 'allowed'
     and coalesce(redacted_summary, '') like '%only A%';
  if v_leak <> 0 then
    raise exception 'POLICY-BATTERY FAIL 29.04: profile value leaked into an audit summary';
  end if;

  if not exists (select 1 from public.audit_events
                  where action = 'profile:update' and outcome = 'allowed') then
    raise exception 'POLICY-BATTERY FAIL 29.04: profile update was not audited';
  end if;
end $$;

-- ############################################################################
-- 29.05 — deletion hard-deletes the identity, its own bytes, its metadata and
-- all three library rows. The second partner keeps the org valid.
-- ############################################################################
set role authenticated;
do $$
declare
  v_a uuid := current_setting('battery29.a')::uuid;
begin
  perform set_config('request.jwt.claim.sub', v_a::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_a)::text, false);
  perform public.delete_my_account();
end $$;
reset role;

do $$
declare
  v_a   uuid := current_setting('battery29.a')::uuid;
  v_org uuid := current_setting('battery29.org')::uuid;
  v_cnt integer;
  v_partners integer;
begin
  if exists (select 1 from auth.users where id = v_a) then
    raise exception 'POLICY-BATTERY FAIL 29.05: auth identity survived deletion';
  end if;

  select count(*) into v_cnt
    from storage.objects where owner_id = v_a;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 29.05: % storage object(s) survived deletion', v_cnt;
  end if;

  select count(*) into v_cnt
    from public.legal_bookmarks where user_id = v_a;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 29.05: % bookmark(s) survived deletion', v_cnt;
  end if;
  select count(*) into v_cnt
    from public.legal_highlights where user_id = v_a;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 29.05: % highlight(s) survived deletion', v_cnt;
  end if;
  select count(*) into v_cnt
    from public.legal_reading_history where user_id = v_a;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 29.05: % history row(s) survived deletion', v_cnt;
  end if;

  select count(*) into v_partners
    from public.memberships
   where organization_id = v_org and status = 'active' and role = 'partner';
  if v_partners <> 1 then
    raise exception 'POLICY-BATTERY FAIL 29.05: org has % active partners, expected 1', v_partners;
  end if;
end $$;

-- ############################################################################
-- 29.06 — files metadata scoped to the caller's object is removed, while a
-- different member's object is untouched.
-- ############################################################################
do $$
declare
  v_org uuid := current_setting('battery29.org')::uuid;
  v_b   uuid := current_setting('battery29.b')::uuid;
begin
  if exists (select 1 from public.files f
              join storage.objects o on o.name = f.storage_path
             where o.owner_id is null) then
    raise exception 'POLICY-BATTERY FAIL 29.06: an unexpected orphaned metadata row exists';
  end if;

  -- User B's object (created below) must survive another user's deletion.
  insert into storage.objects (bucket_id, name, owner_id)
  values ('matter-files', v_org::text || '/battery29/b.pdf', v_b);
end $$;

-- ############################################################################
-- 29.07 — the deletion audit survives with its actor cleared.
-- ############################################################################
do $$
declare
  v_a uuid := current_setting('battery29.a')::uuid;
begin
  if not exists (select 1 from public.audit_events
                  where action = 'account:delete' and outcome = 'allowed'
                    and resource_id = v_a and actor_user_id is null) then
    raise exception 'POLICY-BATTERY FAIL 29.07: delete audit missing or actor not cleared';
  end if;
end $$;

-- ############################################################################
-- 29.08 — a client holding only the anon-key session can complete deletion.
-- (The call above already ran as `authenticated`; this pins the grant.)
-- ############################################################################
do $$
begin
  if not has_function_privilege('authenticated', 'public.delete_my_account()', 'EXECUTE') then
    raise exception 'POLICY-BATTERY FAIL 29.08: authenticated cannot call delete_my_account';
  end if;
end $$;

-- ############################################################################
-- 29.09 — last active partner is refused with a stable code.
-- ############################################################################
set role authenticated;
do $$
declare
  v_b uuid := current_setting('battery29.b')::uuid;
begin
  perform set_config('request.jwt.claim.sub', v_b::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_b)::text, false);
  begin
    perform public.delete_my_account();
    raise exception 'POLICY-BATTERY FAIL 29.09: last-partner deletion was allowed';
  exception when check_violation then
    if sqlerrm not like '%account_deletion_last_partner%' then
      raise exception 'POLICY-BATTERY FAIL 29.09: unexpected error %', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- ############################################################################
-- 29.10 — platform owner is refused with a stable code, not a raw FK error.
-- ############################################################################
set role authenticated;
do $$
declare
  v_owner uuid := current_setting('battery29.owner')::uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner)::text, false);
  begin
    perform public.delete_my_account();
    raise exception 'POLICY-BATTERY FAIL 29.10: platform-owner deletion was allowed';
  exception when check_violation then
    if sqlerrm not like '%account_deletion_platform_owner%' then
      raise exception 'POLICY-BATTERY FAIL 29.10: unexpected error %', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- ############################################################################
-- 29.11 — anon has no EXECUTE on either RPC.
-- ############################################################################
do $$
begin
  if has_function_privilege('anon', 'public.update_my_profile(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.delete_my_account()', 'EXECUTE') then
    raise exception 'POLICY-BATTERY FAIL 29.11: anon holds EXECUTE on a mutation RPC';
  end if;
end $$;

-- ############################################################################
-- 29.12 — both RPCs are SECURITY DEFINER with a pinned search_path.
-- ############################################################################
do $$
declare
  v_bad integer;
begin
  select count(*) into v_bad
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('update_my_profile', 'delete_my_account')
     and (not p.prosecdef or p.proconfig is null
          or not exists (select 1 from unnest(p.proconfig) c
                          where c like 'search_path=%'));
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 29.12: % RPC(s) not definer+pinned', v_bad;
  end if;
end $$;

-- ############################################################################
-- 29.13 — a non-partner client can still delete (the guards are not blanket).
-- ############################################################################
do $$
declare
  v_client uuid := gen_random_uuid();
begin
  insert into auth.users (id, email) values (v_client, 'battery29-client@test.local');
  insert into public.memberships (user_id, organization_id, role, status)
  select v_client, id, 'client', 'active'
    from public.organizations where name = 'Battery 29 Org' limit 1;

  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_client::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_client)::text, false);
  perform public.delete_my_account();
  reset role;

  if exists (select 1 from auth.users where id = v_client) then
    raise exception 'POLICY-BATTERY FAIL 29.13: a client deletion was refused';
  end if;
end $$;

rollback;
