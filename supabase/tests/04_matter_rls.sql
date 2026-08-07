-- ============================================================================
-- supabase/tests/04_matter_rls.sql — real-matters policy battery (T3)
-- Source: docs/matters_rls_gate_review_2026-08-07.md §4 (the deny-rows
-- contract) + docs/matters_real_data_plan_2026-08-07.md (D-MR1).
--
-- Proves `matters_select_assigned` against the matrix §4 matter rows:
--   - assigned client / assigned attorney of an org they actively belong to
--     -> the ONLY grant (positive rows + row-count pins);
--   - org role alone (no assignment)           -> deny, every role;
--   - cross-org (assigned on an org-a matter, member of org-b only) -> deny;
--   - suspended membership in the matter's org -> deny (stale access);
--   - platform_owner_admin (never assigned)    -> deny, always (Q4 residual);
--   - unauthenticated                          -> deny (no grant);
--   - practice_area CHECK (mapping contract)   -> a write path cannot insert
--     an unmapped value (privileged-path half; the client has no INSERT
--     grant, so the CHECK is pinned at the postgres role);
--   - org-delete cascade                       -> dropping the org removes
--     its matters (FK on delete cascade), pinned in a rolled-back txn.
--
-- Run AFTER 00_fixtures.sql, under psql -v ON_ERROR_STOP=1, by
-- scripts/verify_policy_tests.sh (which applies 04_matters.sql +
-- policies/matters.sql to the rehearsal project first). Same impersonation
-- pattern as 01/02/03: set_config request.jwt.* for auth.uid().
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- Privileged-path half (runs as the connection role — postgres): the two
-- facts no client role can observe because it holds no INSERT/DELETE grant.
-- ############################################################################

-- CHECK 04.09 — NEG (privileged half): the practice_area CHECK is the mapping
-- contract — an unmapped value is rejected even by a privileged writer, so no
-- future write path (RPC/seed) can ever insert a value the client's
-- PracticeArea enum cannot map.
begin;
do $$
begin
  begin
    insert into public.matters
      (id, organization_id, title, practice_area)
    values
      ('40000000-0000-4000-8000-00000000ffff', '20000000-0000-4000-8000-000000000001', 'Bad area', 'tax');
    raise exception 'POLICY-BATTERY FAIL 04.09: practice_area CHECK accepted an unmapped value';
  exception when check_violation then
    null; -- expected: CHECK rejected 'tax'
  end;
end $$;
rollback;

-- CHECK 04.10 — POS (privileged half): org-delete cascade — dropping the org
-- removes its matters (FK on delete cascade), so an org teardown can never
-- strand orphaned matter rows.
begin;
do $$
declare
  v_cnt bigint;
begin
  delete from public.organizations where id = '20000000-0000-4000-8000-000000000002';
  select count(*) into v_cnt
    from public.matters
   where organization_id = '20000000-0000-4000-8000-000000000002';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 04.10: % org-b matters survived the org delete', v_cnt;
  end if;
end $$;
rollback;

set role authenticated;

-- ############################################################################
-- Positives — assigned client / assigned attorney of an org they actively
-- belong to (the ONLY grant, matrix §4).
-- ############################################################################

-- CHECK 04.01 — POS: client-a (org-a, client/active) sees exactly its two
-- assigned-client matters (1, 2) and no others.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt from public.matters;
  if v_cnt <> 2 then
    raise exception 'POLICY-BATTERY FAIL 04.01: assigned client saw % matters, want 2', v_cnt;
  end if;
end $$;

-- CHECK 04.02 — POS: partner-a (org-a, partner/active) sees exactly its three
-- assigned-attorney matters (1, 2, 3) — the attorney-assignment grant holds
-- regardless of role, and the count proves no blanket org access (matter-4,
-- where partner-a has no assignment, is NOT visible).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt from public.matters;
  if v_cnt <> 3 then
    raise exception 'POLICY-BATTERY FAIL 04.02: assigned attorney saw % matters, want 3', v_cnt;
  end if;
end $$;

-- CHECK 04.03 — POS: orphan (org-a, client/active, unassigned elsewhere) sees
-- exactly its one assigned-client matter (4) — a row is granted by
-- assignment, not by membership breadth.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  select count(*) into v_cnt from public.matters;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 04.03: assigned client (orphan) saw % matters, want 1', v_cnt;
  end if;
end $$;

-- ############################################################################
-- Negatives — the matrix §4 deny rows.
-- ############################################################################

-- CHECK 04.04 — NEG (org role alone): partner-a is an ACTIVE org-a partner
-- but has NO assignment on matter-4 — the specific row is denied, proving
-- "an org role alone never grants matter access" (deny for every role).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.matters
   where id = '40000000-0000-4000-8000-000000000004';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 04.04: org-role-alone partner read an unassigned org-a matter';
  end if;
end $$;

-- CHECK 04.05 — NEG (cross-org): partner-b is assigned as attorney on an
-- org-a matter (5) but is an active member of org-b ONLY — membership is
-- tested against the matter's own org, so the assignment grants nothing.
-- Also proves the reverse direction of the matrix line "a matter in org-a
-- cannot be accessed by an otherwise-authorized member of org-b".
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_cnt from public.matters;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 04.05: cross-org user saw % matters, want 0', v_cnt;
  end if;
end $$;

-- CHECK 04.06 — NEG (stale access): suspended-a is ASSIGNED as attorney on
-- matter-6 but its org-a membership is 'suspended' — is_active_member is the
-- status = 'active' rule, so the assignment grants nothing (stale-access
-- deny, the 02 hardening guard extended to matters).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select count(*) into v_cnt from public.matters;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 04.06: suspended member saw % matters, want 0', v_cnt;
  end if;
end $$;

-- CHECK 04.07 — NEG (platform_owner_admin): the owner (0001) is never
-- assigned on any matter, so the assignment gate denies always. RESIDUAL
-- (design review Q4, recorded): if an owner account were ever assigned, this
-- policy WOULD grant — the categorical matrix deny is an operational
-- invariant, not a policy guarantee; fixtures never create that state.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt from public.matters;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 04.07: platform_owner_admin saw % matters, want 0', v_cnt;
  end if;
end $$;

-- CHECK 04.08 — NEG (unauthenticated): anon holds NO grant on matters (the
-- 01-pattern default-deny revoke), so a raw read is denied at the privilege
-- layer — double-denied with the null-auth.uid() policy.
set role anon;
do $$
begin
  begin
    perform count(*) from public.matters;
    raise exception 'POLICY-BATTERY FAIL 04.08: anon raw SELECT on matters succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
end $$;
set role authenticated;
