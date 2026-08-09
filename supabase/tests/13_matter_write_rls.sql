-- ============================================================================
-- supabase/tests/13_matter_write_rls.sql — matter-write battery (F-01 step 2)
-- (docs/f01_step2_matter_write_design_2026-08-09.md F2-D1/D2/D3/D4 + §6)
--
-- The first matter-WRITE battery: pins create_matter (supabase/rpc/create_matter.sql)
-- and the categorical trigger (supabase/migrations/11_matter_write.sql):
--   - the platform owner is NEVER assignable (F2-D2 at the RPC + F2-D3 at the
--     trigger — the Q4 residual state cannot be created through any path);
--   - the creator must be an active partner of the org (F2-D1);
--   - assignees must be active members of the org (F2-D4);
--   - §8: allowed creates are audited with a redacted summary; denied
--     creates write no audit row (the 10.09 pattern);
--   - the trigger is NARROW (non-owner assignments still insert AND update —
--     the demo-seed path stays viable; 13.05/13.15);
--   - the UPDATE arm is pinned (13.14/13.15 — re-assignment to the owner is
--     refused, non-owner re-assignment succeeds);
--   - F2-D5: assignments nullable at creation — the orphan create succeeds
--     and is invisible to every role under RLS (13.16).
--
-- Run AFTER 00_fixtures.sql + 12_owner_assignment.sql by
-- scripts/verify_policy_tests.sh (last in the run_battery loop).
-- Fixture anchors (00_fixtures.sql): owner 10000000-…-0001 · partner-a …-0002
-- · client-a …-0003 · partner-b …-0004 · suspended-a …-0005 · orphan …-0007
-- · org-a 20000000-…-0001 · org-b 20000000-…-0002 (matters baseline = 6).
--
-- Role handling: the trigger-layer blocks (13.04/13.05) run as the
-- connection role (postgres) — authenticated holds NO INSERT grant on
-- matters (04 Q5), so the direct-insert checks must run privileged, and the
-- trigger fires for the connection role too (the point of F2-D3). The RPC
-- blocks run under `set role authenticated` with JWT impersonation (the
-- 01/02/03 pattern).
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- 13.04 — NEG (trigger layer, connection role): a DIRECT INSERT that assigns
-- the platform owner is refused by the trigger — no path can create the Q4
-- residual state, even off the RPC. (Runs before `set role authenticated`.)
-- ############################################################################
begin;
do $$
begin
  begin
    insert into public.matters
      (organization_id, title, practice_area, assigned_client_id)
    values
      ('20000000-0000-4000-8000-000000000001', '13.04 probe', 'corporate',
       '10000000-0000-4000-8000-000000000001'); -- the platform owner
    raise exception 'POLICY-BATTERY FAIL 13.04: direct INSERT with owner assignment bypassed the trigger';
  exception when others then
    if sqlerrm <> 'platform owner cannot be assigned to a matter' then
      raise exception 'POLICY-BATTERY FAIL 13.04: unexpected error (want the trigger refusal): %', sqlerrm;
    end if;
  end;
end $$;
rollback;

-- ############################################################################
-- 13.05 — POS (trigger narrowness, connection role): a DIRECT INSERT with
-- NON-owner assignees still succeeds — the trigger refuses owner assignments
-- only, so the demo-seed path stays viable. (Rolled back.)
-- ############################################################################
begin;
do $$
declare
  v_cnt bigint;
begin
  insert into public.matters
    (organization_id, title, practice_area, assigned_client_id, assigned_attorney_id)
  values
    ('20000000-0000-4000-8000-000000000001', '13.05 probe', 'corporate',
     '10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002');
  select count(*) into v_cnt from public.matters where title = '13.05 probe';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 13.05: trigger refused a non-owner assignment (want 1 row, got %)', v_cnt;
  end if;
end $$;
rollback;

-- ############################################################################
-- RPC blocks — run as authenticated with JWT impersonation.
-- ############################################################################
set role authenticated;

-- ############################################################################
-- 13.01 — POS (F2-D1/F2-D4 happy path): partner-a creates a matter in org-a
-- with client-a (client) + partner-a (attorney) — both active members of
-- org-a. The returned id resolves to exactly one row visible to the assigned
-- attorney (RLS grants partner-a as assigned attorney). (Rolled back.)
-- ############################################################################
begin;
do $$
declare
  v_id  uuid;
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select public.create_matter(
    '20000000-0000-4000-8000-000000000001', '13.01 probe', 'corporate',
    '10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002')
    into v_id;
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 13.01: create_matter returned a null id';
  end if;
  select count(*) into v_cnt from public.matters where id = v_id;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 13.01: created matter not readable by its assigned attorney (want 1 row, got %)', v_cnt;
  end if;
end $$;
rollback;

-- ############################################################################
-- 13.02 — NEG (F2-D2): the platform owner as assigned CLIENT is refused by
-- the RPC with the typed message; no row is created.
-- ############################################################################
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_matter(
      '20000000-0000-4000-8000-000000000001', '13.02 probe', 'corporate',
      '10000000-0000-4000-8000-000000000001', null); -- owner as client
    raise exception 'POLICY-BATTERY FAIL 13.02: owner assignment accepted by create_matter';
  exception when others then
    if sqlerrm <> 'platform owner cannot be assigned to a matter' then
      raise exception 'POLICY-BATTERY FAIL 13.02: unexpected error (want the owner refusal): %', sqlerrm;
    end if;
  end;
  select count(*) into v_cnt from public.matters where title = '13.02 probe';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 13.02: a denied create left a row behind (got %)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 13.03 — NEG (F2-D2): the platform owner as assigned ATTORNEY is refused;
-- no row is created.
-- ############################################################################
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_matter(
      '20000000-0000-4000-8000-000000000001', '13.03 probe', 'corporate',
      null, '10000000-0000-4000-8000-000000000001'); -- owner as attorney
    raise exception 'POLICY-BATTERY FAIL 13.03: owner assignment accepted by create_matter';
  exception when others then
    if sqlerrm <> 'platform owner cannot be assigned to a matter' then
      raise exception 'POLICY-BATTERY FAIL 13.03: unexpected error (want the owner refusal): %', sqlerrm;
    end if;
  end;
  select count(*) into v_cnt from public.matters where title = '13.03 probe';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 13.03: a denied create left a row behind (got %)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 13.06 — NEG (§8): a DENIED create writes NO 'matter:create' audit row (the
-- 10.09 pattern — the RPC raises before write_audit).
-- ############################################################################
do $$
declare
  v_before bigint; v_after bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_before
    from public.read_org_audit('20000000-0000-4000-8000-000000000001')
   where action = 'matter:create';
  begin
    perform public.create_matter(
      '20000000-0000-4000-8000-000000000001', '13.06 probe', 'corporate',
      '10000000-0000-4000-8000-000000000001', null); -- owner as client -> denied
    raise exception 'POLICY-BATTERY FAIL 13.06: owner assignment accepted by create_matter';
  exception when others then
    if sqlerrm <> 'platform owner cannot be assigned to a matter' then
      raise exception 'POLICY-BATTERY FAIL 13.06: unexpected error (want the owner refusal): %', sqlerrm;
    end if;
  end;
  select count(*) into v_after
    from public.read_org_audit('20000000-0000-4000-8000-000000000001')
   where action = 'matter:create';
  if v_after <> v_before then
    raise exception 'POLICY-BATTERY FAIL 13.06: a denied create wrote an audit row (% -> %)', v_before, v_after;
  end if;
end $$;

-- ############################################################################
-- 13.07 — POS (§8): an ALLOWED create writes exactly one 'matter:create'
-- audit row with the REDACTED summary 'matter created' (never the title).
-- (Rolled back — the audit row rolls back with the create.)
-- ############################################################################
begin;
do $$
declare
  v_id bigint; v_summary text;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.create_matter(
    '20000000-0000-4000-8000-000000000001', '13.07 probe', 'corporate',
    '10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002');
  select count(*), max(redacted_summary) into v_id, v_summary
    from public.read_org_audit('20000000-0000-4000-8000-000000000001')
   where action = 'matter:create';
  if v_id <> 1 then
    raise exception 'POLICY-BATTERY FAIL 13.07: allowed create audit rows, want 1, got %', v_id;
  end if;
  if v_summary <> 'matter created' then
    raise exception 'POLICY-BATTERY FAIL 13.07: audit summary must be redacted (got %)', v_summary;
  end if;
end $$;
rollback;

-- ############################################################################
-- 13.08 — NEG (F2-D1): a NON-partner (client-a) cannot create a matter
-- (generic 'permission denied'; no row).
-- ############################################################################
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.create_matter(
      '20000000-0000-4000-8000-000000000001', '13.08 probe', 'corporate', null, null);
    raise exception 'POLICY-BATTERY FAIL 13.08: non-partner created a matter';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 13.08: unexpected error (want permission denied): %', sqlerrm;
    end if;
  end;
  select count(*) into v_cnt from public.matters where title = '13.08 probe';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 13.08: a denied create left a row behind (got %)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 13.09 — NEG (F2-D4): an assignee who is NOT an active member of the org is
-- refused (partner-b holds no org-a membership — a dead assignment would be
-- unreadable by the assignee). No row.
-- ############################################################################
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_matter(
      '20000000-0000-4000-8000-000000000001', '13.09 probe', 'corporate',
      null, '10000000-0000-4000-8000-000000000004'); -- partner-b (org-b only)
    raise exception 'POLICY-BATTERY FAIL 13.09: non-member attorney assignment accepted';
  exception when others then
    if sqlerrm <> 'assigned attorney must be an active member of the organization' then
      raise exception 'POLICY-BATTERY FAIL 13.09: unexpected error (want the member guard): %', sqlerrm;
    end if;
  end;
  select count(*) into v_cnt from public.matters where title = '13.09 probe';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 13.09: a denied create left a row behind (got %)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 13.10 — NEG (F2-D4): a SUSPENDED membership is not active — suspended-a
-- cannot be assigned. No row.
-- ############################################################################
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_matter(
      '20000000-0000-4000-8000-000000000001', '13.10 probe', 'corporate',
      '10000000-0000-4000-8000-000000000005', null); -- suspended-a (status = suspended)
    raise exception 'POLICY-BATTERY FAIL 13.10: suspended-member client assignment accepted';
  exception when others then
    if sqlerrm <> 'assigned client must be an active member of the organization' then
      raise exception 'POLICY-BATTERY FAIL 13.10: unexpected error (want the member guard): %', sqlerrm;
    end if;
  end;
  select count(*) into v_cnt from public.matters where title = '13.10 probe';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 13.10: a denied create left a row behind (got %)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 13.11 — NEG (F2-D1 cross-org): a partner of org-a cannot create a matter in
-- org-b (has_org_role(org-b,'partner') is false — D-08 tenant isolation). No
-- row.
-- ############################################################################
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_matter(
      '20000000-0000-4000-8000-000000000002', '13.11 probe', 'corporate', null, null);
    raise exception 'POLICY-BATTERY FAIL 13.11: cross-org create accepted';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 13.11: unexpected error (want permission denied): %', sqlerrm;
    end if;
  end;
  select count(*) into v_cnt from public.matters where title = '13.11 probe';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 13.11: a denied create left a row behind (got %)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 13.13 — NEG (anon): an UNAUTHENTICATED caller cannot create a matter — no
-- EXECUTE grant on create_matter (revoke from public, anon; the 10.08
-- pattern). The privilege layer denies before any gate runs.
-- ############################################################################
set role anon;
do $$
begin
  begin
    perform public.create_matter(
      '20000000-0000-4000-8000-000000000001', '13.13 probe', 'corporate', null, null);
    raise exception 'POLICY-BATTERY FAIL 13.13: anon created a matter';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
end $$;
set role authenticated;

-- ############################################################################
-- 13.12 — NEG (validation): a blank title is refused ('matter title is
-- required'). No row.
-- ############################################################################
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_matter(
      '20000000-0000-4000-8000-000000000001', '   ', 'corporate', null, null);
    raise exception 'POLICY-BATTERY FAIL 13.12: blank title accepted';
  exception when others then
    if sqlerrm <> 'matter title is required' then
      raise exception 'POLICY-BATTERY FAIL 13.12: unexpected error (want the title validation): %', sqlerrm;
    end if;
  end;
  select count(*) into v_cnt from public.matters where title = '   ';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 13.12: a denied create left a row behind (got %)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 13.14 — NEG (trigger UPDATE arm, connection role — review finding R-1): an
-- UPDATE that RE-ASSIGNS an existing matter's client to the platform owner
-- is refused by the trigger — the categorical deny covers the update path
-- too (the trigger is BEFORE INSERT OR UPDATE, not just creation). (Rolled
-- back.)
-- ############################################################################
reset role;
begin;
do $$
begin
  begin
    update public.matters
       set assigned_client_id = '10000000-0000-4000-8000-000000000001' -- the platform owner
     where id = '40000000-0000-4000-8000-000000000001'; -- Matter 1 (org-a)
    raise exception 'POLICY-BATTERY FAIL 13.14: UPDATE reassigning to the owner bypassed the trigger';
  exception when others then
    if sqlerrm <> 'platform owner cannot be assigned to a matter' then
      raise exception 'POLICY-BATTERY FAIL 13.14: unexpected error (want the trigger refusal): %', sqlerrm;
    end if;
  end;
end $$;
rollback;

-- ############################################################################
-- 13.15 — POS (trigger UPDATE-arm narrowness, connection role — review
-- finding R-1): an UPDATE reassigning to NON-owner assignees still succeeds.
-- (Rolled back.)
-- ############################################################################
begin;
do $$
declare
  v_cnt bigint;
begin
  update public.matters
     set assigned_client_id   = '10000000-0000-4000-8000-000000000003', -- client-a
         assigned_attorney_id = '10000000-0000-4000-8000-000000000002'  -- partner-a
   where id = '40000000-0000-4000-8000-000000000001';
  select count(*) into v_cnt from public.matters
   where id = '40000000-0000-4000-8000-000000000001'
     and assigned_client_id = '10000000-0000-4000-8000-000000000003';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 13.15: trigger refused a non-owner UPDATE (want 1 row, got %)', v_cnt;
  end if;
end $$;
rollback;

-- ############################################################################
-- 13.16 — POS (F2-D5, review finding R-2): a partner may create a matter
-- with NO assignments (assignments nullable at creation — the orphan row;
-- invisible to every role, since the read gate is assignment-based, its
-- creator included, under RLS — the invoice-orphan 11 semantics). The RPC
-- returns the id. (Rolled back — the audit row rolls back with the create.)
-- ############################################################################
set role authenticated;
begin;
do $$
declare
  v_id  uuid;
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select public.create_matter(
    '20000000-0000-4000-8000-000000000001', '13.16 probe', 'corporate', null, null)
    into v_id;
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 13.16: orphan create returned a null id';
  end if;
  select count(*) into v_cnt from public.matters where id = v_id;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 13.16: orphan matter visible to its creator under RLS (want 0, got %)', v_cnt;
  end if;
end $$;
rollback;
