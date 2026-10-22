-- ============================================================================
-- supabase/tests/22_attorney_directory_rls.sql — attorney-directory battery
--
-- Pins the discovery slice (supabase/migrations/22_attorney_directory.sql +
-- supabase/policies/attorney_profiles.sql + the five supabase/rpc/*attorney*
-- functions):
--   - owner-only writes: create/update/deactivate succeed for the platform
--     owner and raise 'permission denied' for an active org partner, with no
--     row and no audit row written by the denied attempts (22.02, 22.12);
--   - read policy: an ACTIVE member of any org sees ACTIVE rows only
--     (22.03, 22.04, 22.08); suspended and no-membership callers see zero
--     rows; anon is denied at the privilege layer (22.05);
--   - owner listing: p_include_inactive = true returns the inactive row,
--     the default listing hides it (22.09), and a non-owner asking for
--     inactive rows is denied rather than silently downgraded (22.10);
--   - search: the trimmed query matches display_name / city / specialty,
--     never surfaces an inactive row, and an unknown term returns zero rows
--     (22.11);
--   - detail: an inactive profile is 'not found' to a non-owner (22.14) and
--     an active profile returns its full row (22.15);
--   - the directory is platform-level by design: an active org-b partner
--     reads the same active directory as org-a members (22.16);
--   - structural posture: all five functions are SECURITY DEFINER with a
--     pinned search_path, no parameter carries a default, authenticated holds
--     EXECUTE, anon does not; the table is RLS-enabled and authenticated
--     holds SELECT only — no INSERT/UPDATE/DELETE grant (22.17, 22.18);
--   - §8 audit: exactly the four successful writes are audited, every
--     summary is the fixed redacted string, and no attempt writes a row on
--     denial (22.19, 22.20, 22.21).
--
-- The whole battery runs in ONE transaction and ROLLS BACK: it starts from an
-- empty attorney_profiles table (no fixture seeds it) and leaves nothing
-- behind for any later battery.
--
-- Fixture anchors (00_fixtures.sql): owner 10000000-…-0001 · partner-a
-- …-0002 (org-a partner, active) · client-a …-0003 (org-a client, active) ·
-- partner-b …-0004 (org-b partner, active — cross-org by design) ·
-- suspended-a …-0005 (org-a membership suspended) · demo …-0006 (no
-- membership at all).
--
-- Role handling: every behavior block runs under `set role authenticated`
-- with JWT impersonation (the 01/02/03 pattern); audit rows and seed
-- verification run as the connection role (authenticated holds NO SELECT on
-- audit_events and no direct write grant on attorney_profiles).
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 22.01 — POS (owner create): the platform owner creates Alpha through the
-- RPC. The returned id is non-null and saved for the later deactivate/get
-- checks.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  v_id := public.create_attorney_profile(
    '  Battery Attorney Alpha  ',
    '  Corporate counsel  ',
    '  Demo bio for the directory battery.  ',
    array['corporate', 'civil']::text[],
    array['Arabic', 'English']::text[],
    '  Cairo  ',
    12,
    '  https://example.test/alpha.png  ');
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 22.01: create_attorney_profile returned a null id';
  end if;
  perform set_config('battery22.alpha', v_id::text, true);
end $$;
reset role;

-- 22.01 (privileged verification) — the row persists with the trimmed values,
-- the creator stamp, status active, and exactly one redacted audit row.
do $$
declare
  v_id      uuid := current_setting('battery22.alpha')::uuid;
  v_row     public.attorney_profiles;
  v_audits  bigint;
  v_summary text;
begin
  select * into v_row from public.attorney_profiles where id = v_id;
  if not found then
    raise exception 'POLICY-BATTERY FAIL 22.01: created profile row missing';
  end if;
  if v_row.display_name <> 'Battery Attorney Alpha'
     or v_row.headline <> 'Corporate counsel'
     or v_row.city <> 'Cairo'
     or v_row.avatar_url <> 'https://example.test/alpha.png'
     or v_row.years_experience <> 12
     or v_row.status <> 'active'
     or v_row.created_by <> '10000000-0000-4000-8000-000000000001'
     or v_row.specialties <> array['corporate', 'civil']::text[]
     or v_row.languages <> array['Arabic', 'English']::text[] then
    raise exception 'POLICY-BATTERY FAIL 22.01: created row shape/trim drift: %', row_to_json(v_row);
  end if;

  select count(*), max(redacted_summary) into v_audits, v_summary
    from public.audit_events
   where action = 'attorney_profile:create'
     and outcome = 'allowed'
     and resource_id = v_id
     and resource_type = 'attorney_profile';
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.01: create audit rows = %, want 1', v_audits;
  end if;
  if v_summary is distinct from 'attorney profile created' then
    raise exception 'POLICY-BATTERY FAIL 22.01: create audit summary drift: %', v_summary;
  end if;
  if v_summary like '%Alpha%' or v_summary like '%Cairo%' or v_summary like '%Corporate%' then
    raise exception 'POLICY-BATTERY FAIL 22.01: create audit summary leaked profile content: %', v_summary;
  end if;
end $$;

-- ############################################################################
-- 22.02 — NEG (non-owner create): partner-a is an ACTIVE org-a partner but
-- NOT the platform owner — the write gate raises before any insert/audit.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_attorney_profile(
      'Battery Attorney Forbidden', 'Partner attempt', null,
      array['corporate']::text[], array['Arabic']::text[], 'Cairo', 5, null);
    raise exception 'POLICY-BATTERY FAIL 22.02: non-owner create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 22.02: non-owner create raised "%" instead of permission denied', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- 22.02 (privileged verification) — no row and no create-audit row was
-- written by the denied attempt.
do $$
declare
  v_rows   bigint;
  v_audits bigint;
begin
  select count(*) into v_rows from public.attorney_profiles;
  if v_rows <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.02: denied create left % rows, want 1', v_rows;
  end if;
  select count(*) into v_audits
    from public.audit_events where action = 'attorney_profile:create';
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.02: denied create wrote an audit row (% total), want 1', v_audits;
  end if;
end $$;

-- ############################################################################
-- 22.03 — POS (active member read): client-a is an active org-a member and
-- sees the active Alpha row through the direct select policy.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.attorney_profiles
   where id = current_setting('battery22.alpha')::uuid;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.03: active member sees % rows, want 1', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 22.04 — NEG (no read gate): suspended-a holds a SUSPENDED org-a membership
-- and demo holds NO membership — both see zero directory rows.
-- ############################################################################
set role authenticated;
do $$
declare
  v_susp bigint;
  v_none bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select count(*) into v_susp from public.attorney_profiles;
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000006', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000006"}', false);
  select count(*) into v_none from public.attorney_profiles;
  if v_susp <> 0 then
    raise exception 'POLICY-BATTERY FAIL 22.04: suspended caller sees % directory rows, want 0', v_susp;
  end if;
  if v_none <> 0 then
    raise exception 'POLICY-BATTERY FAIL 22.04: no-membership caller sees % directory rows, want 0', v_none;
  end if;
end $$;
reset role;

-- ############################################################################
-- 22.05 — NEG (unauthenticated): anon holds no SELECT grant on the table —
-- denied at the privilege layer before RLS evaluates.
-- ############################################################################
set role anon;
do $$
declare
  v_cnt bigint;
begin
  begin
    select count(*) into v_cnt from public.attorney_profiles;
    raise exception 'POLICY-BATTERY FAIL 22.05: anon select succeeded (% rows)', v_cnt;
  exception when insufficient_privilege then
    null; -- expected: no table grant
  end;
end $$;
reset role;

-- ############################################################################
-- 22.06 — POS (owner create, second profile): Beta carries the searchable
-- city/specialty values used by 22.11 and the update target for 22.12/22.13.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  v_id := public.create_attorney_profile(
    'Battery Attorney Beta',
    'Family mediator',
    null,
    array['family', 'tax']::text[],
    array['Arabic']::text[],
    'Cairo',
    8,
    null);
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 22.06: second owner create returned a null id';
  end if;
  perform set_config('battery22.beta', v_id::text, true);
end $$;
reset role;

-- ############################################################################
-- 22.07 — NEG (non-owner deactivate): partner-a's deactivate raises
-- 'permission denied' and Alpha stays active.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.deactivate_attorney_profile(current_setting('battery22.alpha')::uuid);
    raise exception 'POLICY-BATTERY FAIL 22.07: non-owner deactivate succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 22.07: non-owner deactivate raised "%" instead of permission denied', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_status text;
begin
  select status into v_status
    from public.attorney_profiles
   where id = current_setting('battery22.alpha')::uuid;
  if v_status is distinct from 'active' then
    raise exception 'POLICY-BATTERY FAIL 22.07: denied deactivate changed status to %', v_status;
  end if;
end $$;

-- ############################################################################
-- 22.08 — POS (owner deactivate): Alpha flips to inactive; the direct select
-- policy hides it from an active member immediately.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  perform public.deactivate_attorney_profile(current_setting('battery22.alpha')::uuid);
end $$;
reset role;

do $$
declare
  v_status text;
begin
  select status into v_status
    from public.attorney_profiles
   where id = current_setting('battery22.alpha')::uuid;
  if v_status is distinct from 'inactive' then
    raise exception 'POLICY-BATTERY FAIL 22.08: owner deactivate left status %, want inactive', v_status;
  end if;
end $$;

set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.attorney_profiles
   where id = current_setting('battery22.alpha')::uuid;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 22.08: deactivated row still visible to an active member';
  end if;
end $$;
reset role;

-- ############################################################################
-- 22.09 — POS (owner listing): p_include_inactive = true returns both rows;
-- the default listing returns only the active Beta row.
-- ############################################################################
set role authenticated;
do $$
declare
  v_all     bigint;
  v_active  bigint;
  v_hidden  bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_all
    from public.list_attorney_profiles(null, true, 100);
  select count(*) into v_active
    from public.list_attorney_profiles(null, false, 100);
  select count(*) into v_hidden
    from public.list_attorney_profiles(null, true, 100)
   where id = current_setting('battery22.alpha')::uuid;
  if v_all <> 2 then
    raise exception 'POLICY-BATTERY FAIL 22.09: owner include-inactive listing = %, want 2', v_all;
  end if;
  if v_active <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.09: owner default listing = %, want 1', v_active;
  end if;
  if v_hidden <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.09: include-inactive listing omitted the inactive row';
  end if;
end $$;
reset role;

-- ############################################################################
-- 22.10 — NEG (non-owner include-inactive): partner-a asking for inactive
-- rows is denied explicitly (never silently downgraded).
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform count(*) from public.list_attorney_profiles(null, true, 100);
    raise exception 'POLICY-BATTERY FAIL 22.10: non-owner include-inactive listing succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 22.10: non-owner include-inactive raised "%" instead of permission denied', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- ############################################################################
-- 22.11 — POS/NEG (search): name / city / specialty each match Beta only;
-- the inactive Alpha never appears; an unknown term returns zero rows.
-- ############################################################################
set role authenticated;
do $$
declare
  v_name  bigint;
  v_city  bigint;
  v_spec  bigint;
  v_hid   bigint;
  v_none  bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_name from public.list_attorney_profiles('  Beta  ', false, 100);
  select count(*) into v_city from public.list_attorney_profiles('Cairo', false, 100);
  select count(*) into v_spec from public.list_attorney_profiles('tax', false, 100);
  select count(*) into v_hid  from public.list_attorney_profiles('Alpha', false, 100);
  select count(*) into v_none from public.list_attorney_profiles('no-such-term-zzz', false, 100);
  if v_name <> 1 or v_city <> 1 or v_spec <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.11: search counts name/city/specialty = %/%/%, want 1/1/1', v_name, v_city, v_spec;
  end if;
  if v_hid <> 0 then
    raise exception 'POLICY-BATTERY FAIL 22.11: inactive row surfaced through search (% rows)', v_hid;
  end if;
  if v_none <> 0 then
    raise exception 'POLICY-BATTERY FAIL 22.11: unknown term returned % rows, want 0', v_none;
  end if;
end $$;
reset role;

-- ############################################################################
-- 22.12 — NEG (non-owner update): partner-a's update raises and Beta's row is
-- unchanged.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.update_attorney_profile(
      current_setting('battery22.beta')::uuid,
      'Hijacked Attorney', 'Hijacked headline', null,
      array['corporate']::text[], array['Arabic']::text[], 'Cairo', 1, null, 'active');
    raise exception 'POLICY-BATTERY FAIL 22.12: non-owner update succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 22.12: non-owner update raised "%" instead of permission denied', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_row public.attorney_profiles;
begin
  select * into v_row
    from public.attorney_profiles
   where id = current_setting('battery22.beta')::uuid;
  if v_row.display_name <> 'Battery Attorney Beta'
     or v_row.headline <> 'Family mediator'
     or v_row.years_experience <> 8 then
    raise exception 'POLICY-BATTERY FAIL 22.12: denied update changed the row: %', row_to_json(v_row);
  end if;
end $$;

-- ############################################################################
-- 22.13 — POS (owner update): the full-row replace lands trimmed values, a
-- null status keeps the row active, and exactly one update audit row exists.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  perform public.update_attorney_profile(
    current_setting('battery22.beta')::uuid,
    '  Battery Attorney Beta II  ',
    '  Updated headline  ',
    null,
    array['family', 'tax', 'corporate']::text[],
    array['Arabic', 'English']::text[],
    '  Giza  ',
    9,
    '  https://example.test/beta.png  ',
    null);
end $$;
reset role;

do $$
declare
  v_row     public.attorney_profiles;
  v_audits  bigint;
  v_summary text;
begin
  select * into v_row
    from public.attorney_profiles
   where id = current_setting('battery22.beta')::uuid;
  if v_row.display_name <> 'Battery Attorney Beta II'
     or v_row.headline <> 'Updated headline'
     or v_row.city <> 'Giza'
     or v_row.years_experience <> 9
     or v_row.avatar_url <> 'https://example.test/beta.png'
     or v_row.status <> 'active'
     or v_row.specialties <> array['family', 'tax', 'corporate']::text[]
     or v_row.languages <> array['Arabic', 'English']::text[] then
    raise exception 'POLICY-BATTERY FAIL 22.13: updated row shape/trim drift: %', row_to_json(v_row);
  end if;

  select count(*), max(redacted_summary) into v_audits, v_summary
    from public.audit_events
   where action = 'attorney_profile:update'
     and outcome = 'allowed'
     and resource_id = current_setting('battery22.beta')::uuid;
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.13: update audit rows = %, want 1', v_audits;
  end if;
  if v_summary is distinct from 'attorney profile updated' then
    raise exception 'POLICY-BATTERY FAIL 22.13: update audit summary drift: %', v_summary;
  end if;
end $$;

-- ############################################################################
-- 22.14 — NEG (inactive detail): an active member asking for the inactive
-- Alpha gets the same 'not found' as a missing id — no existence oracle.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.get_attorney_profile(current_setting('battery22.alpha')::uuid);
    raise exception 'POLICY-BATTERY FAIL 22.14: inactive profile readable by a non-owner';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'attorney profile not found' then
      raise exception 'POLICY-BATTERY FAIL 22.14: inactive detail raised "%" instead of not found', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- ############################################################################
-- 22.15 — POS (active detail): an active member reads the full Beta row.
-- ############################################################################
set role authenticated;
do $$
declare
  v_row public.attorney_profiles;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_row := public.get_attorney_profile(current_setting('battery22.beta')::uuid);
  if v_row.id <> current_setting('battery22.beta')::uuid
     or v_row.display_name <> 'Battery Attorney Beta II'
     or v_row.status <> 'active'
     or not ('tax' = any(v_row.specialties)) then
    raise exception 'POLICY-BATTERY FAIL 22.15: active detail shape drift: %', row_to_json(v_row);
  end if;
end $$;
reset role;

-- ############################################################################
-- 22.16 — POS (cross-org by design): partner-b is an active org-b partner,
-- holds no org-a membership, and still reads the platform-level directory.
-- ############################################################################
set role authenticated;
do $$
declare
  v_rows bigint;
  v_row  public.attorney_profiles;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_rows from public.attorney_profiles;
  v_row := public.get_attorney_profile(current_setting('battery22.beta')::uuid);
  if v_rows <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.16: cross-org member sees % active rows, want 1', v_rows;
  end if;
  if v_row.display_name <> 'Battery Attorney Beta II' then
    raise exception 'POLICY-BATTERY FAIL 22.16: cross-org detail drift: %', v_row.display_name;
  end if;
end $$;
reset role;

-- ############################################################################
-- 22.17 — POS (structural posture): all five functions are SECURITY DEFINER,
-- pin search_path = public, carry no parameter default, grant EXECUTE to
-- authenticated and not to anon.
-- ############################################################################
do $$
declare
  r      record;
  v_oid  oid;
  v_cnt  bigint;
  v_bad  bigint;
begin
  for r in
    select * from (values
      ('list_attorney_profiles',     'p_query text, p_include_inactive boolean, p_limit integer'),
      ('get_attorney_profile',       'p_id uuid'),
      ('create_attorney_profile',    'p_display_name text, p_headline text, p_bio text, p_specialties text[], p_languages text[], p_city text, p_years_experience integer, p_avatar_url text'),
      ('update_attorney_profile',    'p_id uuid, p_display_name text, p_headline text, p_bio text, p_specialties text[], p_languages text[], p_city text, p_years_experience integer, p_avatar_url text, p_status text'),
      ('deactivate_attorney_profile','p_id uuid')
    ) as t(fn, args)
  loop
    select p.oid into v_oid
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = r.fn
       and pg_get_function_arguments(p.oid) = r.args;
    if v_oid is null then
      raise exception 'POLICY-BATTERY FAIL 22.17: function %.%(%) missing', 'public', r.fn, r.args;
    end if;
    if not (select prosecdef from pg_proc where oid = v_oid) then
      raise exception 'POLICY-BATTERY FAIL 22.17: %.% is not SECURITY DEFINER', 'public', r.fn;
    end if;
    if not (select coalesce(proconfig, '{}'::text[]) @> array['search_path=public']::text[] from pg_proc where oid = v_oid) then
      raise exception 'POLICY-BATTERY FAIL 22.17: %.% does not pin search_path = public', 'public', r.fn;
    end if;
    if has_function_privilege('anon', v_oid, 'EXECUTE') then
      raise exception 'POLICY-BATTERY FAIL 22.17: anon holds EXECUTE on %', r.fn;
    end if;
    if not has_function_privilege('authenticated', v_oid, 'EXECUTE') then
      raise exception 'POLICY-BATTERY FAIL 22.17: authenticated lacks EXECUTE on %', r.fn;
    end if;
  end loop;

  select count(*) into v_cnt
    from information_schema.parameters p
    join information_schema.routines r
      on r.specific_schema = p.specific_schema
     and r.specific_name = p.specific_name
   where r.routine_schema = 'public'
     and r.routine_name in ('list_attorney_profiles', 'get_attorney_profile',
                            'create_attorney_profile', 'update_attorney_profile',
                            'deactivate_attorney_profile');
  if v_cnt = 0 then
    raise exception 'POLICY-BATTERY FAIL 22.17: no parameters found for the five functions';
  end if;
  select count(*) into v_bad
    from information_schema.parameters p
    join information_schema.routines r
      on r.specific_schema = p.specific_schema
     and r.specific_name = p.specific_name
   where r.routine_schema = 'public'
     and r.routine_name in ('list_attorney_profiles', 'get_attorney_profile',
                            'create_attorney_profile', 'update_attorney_profile',
                            'deactivate_attorney_profile')
     and p.parameter_default is not null;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 22.17: % parameter default(s) present (PostgREST incident rule)', v_bad;
  end if;
end $$;

-- ############################################################################
-- 22.18 — POS (table posture): RLS enabled, authenticated SELECT only,
-- no direct INSERT/UPDATE/DELETE, anon holds nothing.
-- ############################################################################
do $$
begin
  if not (select relrowsecurity from pg_class where oid = 'public.attorney_profiles'::regclass) then
    raise exception 'POLICY-BATTERY FAIL 22.18: RLS is not enabled';
  end if;
  if not has_table_privilege('authenticated', 'public.attorney_profiles', 'SELECT') then
    raise exception 'POLICY-BATTERY FAIL 22.18: authenticated lacks SELECT';
  end if;
  if has_table_privilege('authenticated', 'public.attorney_profiles', 'INSERT')
     or has_table_privilege('authenticated', 'public.attorney_profiles', 'UPDATE')
     or has_table_privilege('authenticated', 'public.attorney_profiles', 'DELETE') then
    raise exception 'POLICY-BATTERY FAIL 22.18: authenticated holds a direct write privilege';
  end if;
  if has_table_privilege('anon', 'public.attorney_profiles', 'SELECT')
     or has_table_privilege('anon', 'public.attorney_profiles', 'INSERT')
     or has_table_privilege('anon', 'public.attorney_profiles', 'UPDATE')
     or has_table_privilege('anon', 'public.attorney_profiles', 'DELETE') then
    raise exception 'POLICY-BATTERY FAIL 22.18: anon holds a table privilege';
  end if;
  if (select count(*) from pg_policies
       where schemaname = 'public' and tablename = 'attorney_profiles') <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.18: attorney_profiles must carry exactly one policy';
  end if;
end $$;

-- ############################################################################
-- 22.19 — NEG (missing id): the owner updating a random uuid raises
-- 'attorney profile not found' and writes no audit row.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.update_attorney_profile(
      gen_random_uuid(), 'Ghost Attorney', null, null,
      array[]::text[], array[]::text[], null, null, null, null);
    raise exception 'POLICY-BATTERY FAIL 22.19: update on a missing id succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'attorney profile not found' then
      raise exception 'POLICY-BATTERY FAIL 22.19: missing-id update raised "%" instead of not found', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_audits bigint;
begin
  select count(*) into v_audits
    from public.audit_events where action = 'attorney_profile:update';
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.19: missing-id update wrote an audit row (% total), want 1', v_audits;
  end if;
end $$;

-- ############################################################################
-- 22.20 — NEG (deactivate terminal): a random id and the already-inactive
-- Alpha both raise; neither writes an audit row.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.deactivate_attorney_profile(gen_random_uuid());
    raise exception 'POLICY-BATTERY FAIL 22.20: deactivate on a missing id succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'attorney profile not found or already inactive' then
      raise exception 'POLICY-BATTERY FAIL 22.20: missing-id deactivate raised "%"', sqlerrm;
    end if;
  end;
  begin
    perform public.deactivate_attorney_profile(current_setting('battery22.alpha')::uuid);
    raise exception 'POLICY-BATTERY FAIL 22.20: deactivating an inactive profile succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'attorney profile not found or already inactive' then
      raise exception 'POLICY-BATTERY FAIL 22.20: already-inactive deactivate raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_audits bigint;
begin
  select count(*) into v_audits
    from public.audit_events where action = 'attorney_profile:deactivate';
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 22.20: denied deactivates wrote an audit row (% total), want 1', v_audits;
  end if;
end $$;

-- ############################################################################
-- 22.21 — NEG/POS (§8 final pin): exactly four attorney_profile:* audit rows
-- exist (create x2, update x1, deactivate x1); every summary is a fixed
-- redacted string with no profile content.
-- ############################################################################
do $$
declare
  v_total  bigint;
  v_leaked bigint;
begin
  select count(*) into v_total
    from public.audit_events where action like 'attorney_profile:%';
  if v_total <> 4 then
    raise exception 'POLICY-BATTERY FAIL 22.21: attorney_profile:* audit rows = %, want exactly 4 (only successful writes are audited)', v_total;
  end if;
  select count(*) into v_leaked
    from public.audit_events
   where action like 'attorney_profile:%'
     and (redacted_summary like '%Battery%'
          or redacted_summary like '%Cairo%'
          or redacted_summary like '%Giza%'
          or redacted_summary like '%Corporate%'
          or redacted_summary like '%Family%'
          or redacted_summary like '%Tax%');
  if v_leaked <> 0 then
    raise exception 'POLICY-BATTERY FAIL 22.21: % audit summary(ies) leaked profile content', v_leaked;
  end if;
  if (select count(*) from public.audit_events
       where action like 'attorney_profile:%' and outcome <> 'allowed') <> 0 then
    raise exception 'POLICY-BATTERY FAIL 22.21: a denied attempt wrote an audit row';
  end if;
end $$;

rollback;
