-- ============================================================================
-- supabase/tests/21_task_assignable_members_rls.sql — assignable-members battery
--
-- Pins supabase/rpc/list_matter_assignable_members.sql — the task-assignment
-- picker's read path:
--   - matter-gate positives: the assigned client (21.01) and the assigned
--     attorney on an attorney-only matter (21.02) each see the active org
--     roster, ordered, with non-empty display names;
--   - matter-gate denials returning ZERO rows (no existence oracle):
--     org-role-alone for a partner (21.03) and a client (21.04), cross-org
--     (21.05), suspended (21.06), platform owner (21.07), and a guessed
--     matter id (21.09);
--   - anon is denied at the privilege layer (21.08) and the EXECUTE grants
--     are pinned structurally (21.12);
--   - the platform owner is excluded from the roster even while an ACTIVE
--     member — proven with a privileged in-txn temp membership for the owner
--     (the whole battery rolls back; no fixture file is changed) (21.10);
--   - the output contract is exactly user_id uuid + display_name text
--     (21.11), and the read writes NO audit row (21.13).
--
-- The whole battery runs in ONE transaction and ROLLS BACK. The RPC is
-- read-only; 21.10's temp membership seed is the only write and never
-- persists.
--
-- Fixture anchors (00_fixtures.sql): owner …-0001 · partner-a …-0002 (org-a
-- partner, assigned attorney on matters 1–3) · client-a …-0003 (assigned
-- client on matters 1–2) · partner-b …-0004 (org-b ONLY, assigned attorney
-- on org-a matter 5) · suspended-a …-0005 (suspended, assigned attorney on
-- matter 6) · orphan …-0007 (org-a client, assigned on matter 4) · org-a
-- 20000000-…-0001 · matters 40000000-…-0001/0003/0004/0005/0006.
--
-- Expected org-a ACTIVE roster: Client A (…-0003), Orphan Member (…-0007),
-- Partner A (…-0002) — suspended-a is not active and the owner is not an
-- org-a member in the seeded baseline.
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 21.01 — POS (assigned client): client-a is an active org-a member AND the
-- assigned client on matter 1. The roster is the three ACTIVE org-a members,
-- ordered by display_name then user_id; every name is non-empty; the
-- suspended member and the platform owner are absent.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt   bigint;
  v_blank bigint;
  v_ids   uuid[];
  v_names text[];
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*),
         count(*) filter (where display_name is null or btrim(display_name) = ''),
         array_agg(user_id order by display_name, user_id),
         array_agg(display_name order by display_name, user_id)
    into v_cnt, v_blank, v_ids, v_names
    from public.list_matter_assignable_members('40000000-0000-4000-8000-000000000001');
  if v_cnt <> 3 then
    raise exception 'POLICY-BATTERY FAIL 21.01: client-a sees % assignable members, want 3', v_cnt;
  end if;
  if v_blank <> 0 then
    raise exception 'POLICY-BATTERY FAIL 21.01: % roster row(s) carry a null/blank display name', v_blank;
  end if;
  if v_names is distinct from array['Client A', 'Orphan Member', 'Partner A'] then
    raise exception 'POLICY-BATTERY FAIL 21.01: roster order/names drift: %', v_names;
  end if;
  if v_ids is distinct from array[
       '10000000-0000-4000-8000-000000000003',
       '10000000-0000-4000-8000-000000000007',
       '10000000-0000-4000-8000-000000000002']::uuid[] then
    raise exception 'POLICY-BATTERY FAIL 21.01: roster ids drift: %', v_ids;
  end if;
  if '10000000-0000-4000-8000-000000000005' = any(v_ids)
     or '10000000-0000-4000-8000-000000000001' = any(v_ids) then
    raise exception 'POLICY-BATTERY FAIL 21.01: suspended/owner id leaked into the roster: %', v_ids;
  end if;
end $$;
reset role;

-- ############################################################################
-- 21.02 — POS (assigned attorney, attorney-only matter): partner-a is the
-- assigned attorney on matter 3 (no assigned client) and an active org-a
-- member — the same three-member roster is returned.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt   bigint;
  v_names text[];
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*), array_agg(display_name order by display_name, user_id)
    into v_cnt, v_names
    from public.list_matter_assignable_members('40000000-0000-4000-8000-000000000003');
  if v_cnt <> 3 then
    raise exception 'POLICY-BATTERY FAIL 21.02: assigned attorney sees % assignable members, want 3', v_cnt;
  end if;
  if v_names is distinct from array['Client A', 'Orphan Member', 'Partner A'] then
    raise exception 'POLICY-BATTERY FAIL 21.02: attorney roster order/names drift: %', v_names;
  end if;
end $$;
reset role;

-- ############################################################################
-- 21.03 — NEG (org-role-alone, partner): partner-a is an ACTIVE org-a partner
-- but is NOT assigned on matter 4 (assigned client is orphan) — zero rows.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.list_matter_assignable_members('40000000-0000-4000-8000-000000000004');
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 21.03: org-role-alone partner saw % rows, want 0', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 21.04 — NEG (org-role-alone, client): client-a is an ACTIVE org-a member
-- but is NOT assigned on matter 4 — zero rows.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.list_matter_assignable_members('40000000-0000-4000-8000-000000000004');
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 21.04: org-role-alone client saw % rows, want 0', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 21.05 — NEG (cross-org): partner-b is assigned attorney on org-a matter 5
-- but an ACTIVE member of org-b ONLY — zero rows (the gate tests the matter's
-- org, not the assignment alone).
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_cnt
    from public.list_matter_assignable_members('40000000-0000-4000-8000-000000000005');
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 21.05: cross-org caller saw % rows, want 0', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 21.06 — NEG (stale access): suspended-a IS the assigned attorney on matter
-- 6 but its org-a membership is 'suspended' — zero rows.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select count(*) into v_cnt
    from public.list_matter_assignable_members('40000000-0000-4000-8000-000000000006');
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 21.06: suspended caller saw % rows, want 0', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 21.07 — NEG (platform owner): the owner is never assigned on any matter and
-- holds no org membership — zero rows, no owner carve-out.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt
    from public.list_matter_assignable_members('40000000-0000-4000-8000-000000000001');
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 21.07: platform owner saw % rows, want 0', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 21.08 — NEG (unauthenticated): anon holds NO EXECUTE grant — denied at the
-- privilege layer before the function body runs.
-- ############################################################################
set role anon;
do $$
declare
  v_cnt bigint;
begin
  begin
    select count(*) into v_cnt
      from public.list_matter_assignable_members('40000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 21.08: anon call succeeded (% rows)', v_cnt;
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
end $$;
reset role;

-- ############################################################################
-- 21.09 — NEG (guessed matter id): a client-a call on a matter id that exists
-- NOWHERE returns zero rows — same shape as an unauthorized matter (no
-- existence oracle).
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.list_matter_assignable_members('40000000-0000-4000-8000-00000000ffff');
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 21.09: guessed matter id returned % rows, want 0', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 21.10 — POS (platform owner excluded from the roster): seed a TEMP active
-- org-a membership for the fixture owner IN THIS TRANSACTION so the
-- exclusion is non-vacuous (the owner is now an active member). As client-a
-- on matter 1 the roster must still be the three NON-OWNER members — not
-- four — and must not contain the owner id. The whole battery rolls back, so
-- the seeded membership never persists.
-- ############################################################################
do $$
declare
  v_cnt bigint;
begin
  insert into public.memberships
    (organization_id, user_id, role, status, created_by, created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001',
     '10000000-0000-4000-8000-000000000001',
     'client', 'active',
     '10000000-0000-4000-8000-000000000002', now(), now());
  get diagnostics v_cnt = row_count;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 21.10: owner membership seed inserted % rows, want 1', v_cnt;
  end if;
  select count(*) into v_cnt
    from public.memberships
   where organization_id = '20000000-0000-4000-8000-000000000001'
     and user_id = '10000000-0000-4000-8000-000000000001'
     and status = 'active';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 21.10: owner membership seed missing (want 1 row, got %)', v_cnt;
  end if;
end $$;

set role authenticated;
do $$
declare
  v_cnt   bigint;
  v_ids   uuid[];
  v_names text[];
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*),
         array_agg(user_id order by display_name, user_id),
         array_agg(display_name order by display_name, user_id)
    into v_cnt, v_ids, v_names
    from public.list_matter_assignable_members('40000000-0000-4000-8000-000000000001');
  if v_cnt <> 3 then
    raise exception 'POLICY-BATTERY FAIL 21.10: active-member owner not excluded (% roster rows, want 3)', v_cnt;
  end if;
  if v_names is distinct from array['Client A', 'Orphan Member', 'Partner A'] then
    raise exception 'POLICY-BATTERY FAIL 21.10: roster drift with an active owner member: %', v_names;
  end if;
  if '10000000-0000-4000-8000-000000000001' = any(v_ids) then
    raise exception 'POLICY-BATTERY FAIL 21.10: platform owner id leaked into the roster: %', v_ids;
  end if;
end $$;
reset role;

-- ############################################################################
-- 21.11 — POS (structural output contract): exactly one IN parameter and
-- exactly two OUT columns — user_id uuid, display_name text. No email, token,
-- or role column can ride along unnoticed.
-- ############################################################################
do $$
declare
  v_out_cnt bigint;
  v_in_cnt  bigint;
  v_shape   text;
begin
  select count(*) filter (where p.parameter_mode = 'OUT'),
         count(*) filter (where p.parameter_mode = 'IN'),
         string_agg(p.parameter_name || ' ' || p.data_type, ', ' order by p.ordinal_position)
           filter (where p.parameter_mode = 'OUT')
    into v_out_cnt, v_in_cnt, v_shape
    from information_schema.parameters p
    join information_schema.routines r
      on r.specific_schema = p.specific_schema
     and r.specific_name = p.specific_name
   where r.routine_schema = 'public'
     and r.routine_name = 'list_matter_assignable_members';
  if v_out_cnt <> 2 or v_shape is distinct from 'user_id uuid, display_name text' then
    raise exception 'POLICY-BATTERY FAIL 21.11: output contract drift (OUT count %, shape %)', v_out_cnt, v_shape;
  end if;
  if v_in_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 21.11: input arity drift (want 1 IN param, got %)', v_in_cnt;
  end if;
end $$;

-- ############################################################################
-- 21.12 — POS (structural posture): the function is SECURITY DEFINER and
-- STABLE, authenticated holds EXECUTE, and anon does not.
-- ############################################################################
do $$
declare
  v_oid    oid;
  v_secdef boolean;
  v_vol    text;
begin
  select p.oid, p.prosecdef, p.provolatile::text
    into v_oid, v_secdef, v_vol
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'list_matter_assignable_members'
     and pg_get_function_identity_arguments(p.oid) = 'p_matter_id uuid';
  if v_oid is null then
    raise exception 'POLICY-BATTERY FAIL 21.12: function missing from public';
  end if;
  if not v_secdef then
    raise exception 'POLICY-BATTERY FAIL 21.12: function is not SECURITY DEFINER';
  end if;
  if v_vol <> 's' then
    raise exception 'POLICY-BATTERY FAIL 21.12: function is not STABLE (provolatile=%)', v_vol;
  end if;
  if has_function_privilege('anon', v_oid, 'EXECUTE') then
    raise exception 'POLICY-BATTERY FAIL 21.12: anon holds EXECUTE';
  end if;
  if not has_function_privilege('authenticated', v_oid, 'EXECUTE') then
    raise exception 'POLICY-BATTERY FAIL 21.12: authenticated lacks EXECUTE';
  end if;
end $$;

-- ############################################################################
-- 21.13 — NEG (no audit row): the roster read is side-effect free. Count the
-- audit table before and after a successful call; the delta must be zero.
-- ############################################################################
do $$
declare
  v_before bigint;
begin
  select count(*) into v_before from public.audit_events;
  perform set_config('battery21.audit_before', v_before::text, true);
end $$;

set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.list_matter_assignable_members('40000000-0000-4000-8000-000000000001');
  if v_cnt <> 3 then
    raise exception 'POLICY-BATTERY FAIL 21.13: successful roster call returned % rows, want 3', v_cnt;
  end if;
end $$;
reset role;

do $$
declare
  v_before bigint;
  v_after  bigint;
begin
  v_before := current_setting('battery21.audit_before')::bigint;
  select count(*) into v_after from public.audit_events;
  if v_after <> v_before then
    raise exception 'POLICY-BATTERY FAIL 21.13: read-only roster RPC wrote % audit row(s)', v_after - v_before;
  end if;
end $$;

rollback;
