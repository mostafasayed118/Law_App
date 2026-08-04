-- ============================================================================
-- supabase/tests/03_platform_owner_boundary.sql — P0C.1 battery, matrix §5
-- (docs/permission_matrix.md §5 + the RATIFIED 2026-08-05 addendum) and the
-- P0-closure deny-rows:
--   D-P0C1  two-part deny-row: (a) the owner cannot exceed identity/membership
--           metadata through ANY existing grant or RPC path (AC-2a); (b) the
--           content-table forward pin is structural (no matter/document/
--           message tables exist — asserted by scripts/verify_policy_tests.sh).
--   D-P0C3  single-account bound: a second platform_config owner row is
--           unreachable (AC-3).
--   D-P0C4  audit surfacing stays RPC-only; reads self-audit (AC-4).
-- Source: docs/p0_closure_scope_2026-08-05.md slice P0C.1.
--
-- Run AFTER 00_fixtures.sql, under psql -v ON_ERROR_STOP=1, by
-- scripts/verify_policy_tests.sh. Same impersonation pattern as 01/02.
--
-- Owner-verified effects that a client role cannot observe directly
-- (audit_events has no grant; memberships are RLS-filtered) are observed via
-- the audited RPCs' own output (read_platform_audit returns action +
-- actor_user_id) or the target member's own row (a member always sees their
-- own membership row). Where a check needs an observable the client surface
-- cannot provide, the comment says so and the pin is the RPC's clean
-- execution + audit row — the RPC body's final statement is the mutation,
-- so a failed mutation would raise and fail the check.
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- D-P0C3 — single-account bound, privileged-path half (defense in depth)
-- ############################################################################
-- Runs as the connection role (postgres). A SECOND owner row is impossible
-- even for a privileged role: the primary-key on id=true collides. This is
-- the backstop under the client-side grant absence (03.18) — no reachable
-- path exists at any privilege level.
begin;
do $$
begin
  begin
    insert into public.platform_config (owner_user_id)
    values ('10000000-0000-4000-8000-000000000002');
    raise exception 'POLICY-BATTERY FAIL 03.D-P0C3a: a second platform_config owner row was created';
  exception when unique_violation or check_violation then
    null; -- single-row constraint holds: expected
  end;
end $$;
rollback;

set role authenticated;

-- ############################################################################
-- §5 — Owner surface positives (the bounded "May" list)
-- ############################################################################

-- CHECK 03.01 — POS: owner lists all organizations' metadata (2 rows), audited.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt from public.list_organizations_metadata();
  if v_cnt <> 2 then
    raise exception 'POLICY-BATTERY FAIL 03.01: owner listed % orgs, want 2', v_cnt;
  end if;
end $$;

-- CHECK 03.02 — POS: owner lists members + identity/membership metadata only
-- (5 memberships; the output columns are the bounded metadata set).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt from public.list_members_metadata();
  if v_cnt <> 5 then
    raise exception 'POLICY-BATTERY FAIL 03.02: owner listed % members, want 5', v_cnt;
  end if;
end $$;

-- CHECK 03.03 — POS: owner suspends then reactivates a membership in ANY org
-- (org-b here — the matrix §3 owner row "any org, metadata-level action").
-- The target member's own row is the observable (every member sees their own
-- membership row); verified in-transaction then rolled back.
begin;
do $$
declare
  v_s public.membership_status; v_a public.membership_status;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  perform public.suspend_membership_platform(
    '20000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000004');
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select status into v_s
    from public.memberships
   where user_id = '10000000-0000-4000-8000-000000000004';
  if v_s <> 'suspended' then
    raise exception 'POLICY-BATTERY FAIL 03.03: platform suspend did not apply (got %)', v_s;
  end if;
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  perform public.reactivate_membership_platform(
    '20000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000004');
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select status into v_a
    from public.memberships
   where user_id = '10000000-0000-4000-8000-000000000004';
  if v_a <> 'active' then
    raise exception 'POLICY-BATTERY FAIL 03.03: platform reactivate did not restore active (got %)', v_a;
  end if;
end $$;
rollback;

-- CHECK 03.04 — POS: owner deletes a synthetic demo account. The observable
-- is the audited 'platform:delete_demo_account' row (audit_events has no
-- client grant, and the physical auth.users delete is the RPC's final
-- statement — a failure would raise). Verified in-transaction, rolled back.
begin;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  perform public.delete_demo_account('10000000-0000-4000-8000-000000000006');
  select count(*) into v_cnt
    from public.read_platform_audit()
   where action = 'platform:delete_demo_account'
     and resource_id = '10000000-0000-4000-8000-000000000006';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 03.04: demo-account delete not audited (delete RPC did not complete)';
  end if;
end $$;
rollback;

-- CHECK 03.05 — POS (matrix §5 "every action produces an audit record... it
-- is not exempt from auditing just because it's the owner's own account"):
-- the owner's list actions produced 'platform:' audit rows with the OWNER
-- actor.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt
    from public.read_platform_audit()
   where action like 'platform:%'
     and actor_user_id = '10000000-0000-4000-8000-000000000001';
  if v_cnt < 2 then
    raise exception 'POLICY-BATTERY FAIL 03.05: owner actions not audited with the owner actor (want >= 2 rows, got %)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- D-P0C1(a) — owner deny-rows: the owner cannot exceed identity/membership
-- metadata through ANY existing grant or RPC path (AC-2a). The owner's
-- direct table surface is exactly its own profile row; every other table is
-- empty-success (RLS) or denied (no grant); no internal helper is
-- client-callable; no partner/org RPC accepts the owner.
-- ############################################################################

-- CHECK 03.06 — NEG: owner direct SELECT on profiles returns exactly its own
-- row (own-row-only applies to the owner too — no "admin sees all profiles").
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt from public.profiles;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 03.06: owner saw % profile rows, want only its own (1)', v_cnt;
  end if;
end $$;

-- CHECK 03.07 — NEG: owner direct SELECT on memberships returns 0 rows (no
-- membership; the roster policy grants nothing to a non-member).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt from public.memberships;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 03.07: owner saw % membership rows, want 0', v_cnt;
  end if;
end $$;

-- CHECK 03.08 — NEG: owner direct SELECT on organizations returns 0 rows.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt from public.organizations;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 03.08: owner saw % organization rows, want 0', v_cnt;
  end if;
end $$;

-- CHECK 03.09 — NEG: owner direct SELECT on invitations returns 0 rows.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt from public.invitations;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 03.09: owner saw % invitation rows, want 0', v_cnt;
  end if;
end $$;

-- CHECK 03.10 — NEG: owner direct SELECT on audit_events is DENIED (no grant
-- exists — the audit surface is RPC-only, D-P0C4; a raw read cannot audit
-- itself).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform count(*) from public.audit_events;
    raise exception 'POLICY-BATTERY FAIL 03.10: owner raw SELECT on audit_events succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
end $$;

-- CHECK 03.11 — NEG: owner direct SELECT on platform_config is DENIED — the
-- owner capability is never client-readable (read by is_platform_owner()
-- inside security-definer bodies only).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform count(*) from public.platform_config;
    raise exception 'POLICY-BATTERY FAIL 03.11: owner raw SELECT on platform_config succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
end $$;

-- CHECK 03.12 — NEG: the owner cannot directly EXECUTE is_platform_owner()
-- (EXECUTE revoked from authenticated — the helper is callable from
-- security-definer RPC bodies only; a client cannot probe the capability).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.is_platform_owner();
    raise exception 'POLICY-BATTERY FAIL 03.12: owner called is_platform_owner() directly';
  exception when insufficient_privilege then
    null; -- expected: EXECUTE revoked
  end;
end $$;

-- CHECK 03.13 — NEG: no client (including the owner) can EXECUTE write_audit
-- — audit rows cannot be forged by any caller (audit-integrity, contract §8).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.write_audit('forged', 'allowed');
    raise exception 'POLICY-BATTERY FAIL 03.13: client called write_audit() directly';
  exception when insufficient_privilege then
    null; -- expected: EXECUTE revoked
  end;
end $$;

-- CHECK 03.14 — NEG: the owner cannot EXECUTE active_membership() (helper is
-- invoked from security-definer bodies only; not a client endpoint).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform * from public.active_membership('20000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 03.14: owner called active_membership() directly';
  exception when insufficient_privilege then
    null; -- expected: EXECUTE revoked
  end;
end $$;

-- CHECK 03.15 — NEG: the owner cannot read org audit via the partner RPC
-- (read_org_audit requires has_org_role 'partner'; is_platform_owner() is
-- not a bypass).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform count(*) from public.read_org_audit('20000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 03.15: owner read org audit via the partner RPC';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 03.15: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 03.16 — NEG: the owner cannot read platform audit RPC grants beyond
-- identity/metadata — already pinned structurally; here the partner-roster
-- denial for the owner (01.12) and the two platform-audit negatives below
-- complete the "no RPC path exceeds the boundary" sweep. (Content tables do
-- not exist; the D-P0C1b forward pin is asserted by the harness.)

-- ############################################################################
-- D-P0C3 — single-account bound, client-path half (AC-3)
-- ############################################################################

-- CHECK 03.17 — NEG: no authenticated role (owner included) can INSERT a
-- second platform_config row — no grant exists, so the only reachable path
-- denies.
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    insert into public.platform_config (owner_user_id)
    values ('10000000-0000-4000-8000-000000000003');
    raise exception 'POLICY-BATTERY FAIL 03.17: authenticated INSERT into platform_config succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
end $$;

-- ############################################################################
-- D-P0C4 — audit surfacing stays RPC-only (AC-4)
-- ############################################################################

-- CHECK 03.18 — POS: read_platform_audit self-audits — the owner's read
-- produced its own 'platform:read_audit' row with the owner actor (matrix
-- §6: the owner reading audit is itself an audited action).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  perform count(*) from public.read_platform_audit();
  select count(*) into v_cnt
    from public.read_platform_audit()
   where action = 'platform:read_audit'
     and actor_user_id = '10000000-0000-4000-8000-000000000001';
  if v_cnt < 1 then
    raise exception 'POLICY-BATTERY FAIL 03.18: platform audit read was not self-audited';
  end if;
end $$;

-- CHECK 03.19 — POS: read_org_audit self-audits — a partner's org-a audit
-- read produced its own 'audit:read_org' row for org-a.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.read_org_audit('20000000-0000-4000-8000-000000000001')
   where action = 'audit:read_org';
  if v_cnt < 1 then
    raise exception 'POLICY-BATTERY FAIL 03.19: org audit read was not self-audited';
  end if;
end $$;

-- CHECK 03.20 — NEG: a non-owner cannot read platform audit (generic denial).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform count(*) from public.read_platform_audit();
    raise exception 'POLICY-BATTERY FAIL 03.20: client read platform audit';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 03.20: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 03.21 — NEG: a non-partner cannot read org audit (generic denial).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform count(*) from public.read_org_audit('20000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 03.21: client read org audit';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 03.21: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 03.22 — NEG: audit_events is append-only — a direct UPDATE is denied
-- for every client role (rows are written by write_audit only).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    update public.audit_events set outcome = 'tampered';
    raise exception 'POLICY-BATTERY FAIL 03.22: direct UPDATE on audit_events succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
end $$;

-- CHECK 03.23 — NEG: audit_events is append-only — a direct INSERT is denied.
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    insert into public.audit_events (action, outcome) values ('forged', 'allowed');
    raise exception 'POLICY-BATTERY FAIL 03.23: direct INSERT into audit_events succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
end $$;

-- CHECK 03.24 — NEG: the owner cannot delete a demo account through the
-- PARTNER/self paths that the boundary forbids: delete_demo_account refuses
-- self-deletion (D-05 semantics — the owner's own account is removed only by
-- delete_my_account).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.delete_demo_account('10000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 03.24: owner self-deleted via delete_demo_account';
  exception when others then
    if sqlerrm <> 'cannot delete your own account via this path; use delete_my_account' then
      raise exception 'POLICY-BATTERY FAIL 03.24: unexpected error (want self-delete refusal): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 03.25 — NEG: a non-owner cannot delete a demo account (the owner
-- surface is exclusive — generic denial).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.delete_demo_account('10000000-0000-4000-8000-000000000006');
    raise exception 'POLICY-BATTERY FAIL 03.25: client deleted a demo account';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 03.25: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 03.26 — NEG: a non-owner cannot suspend/reactivate via the platform
-- RPCs (the owner surface is exclusive).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.suspend_membership_platform(
      '20000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000003');
    raise exception 'POLICY-BATTERY FAIL 03.26: client suspended via the platform RPC';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 03.26: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 03.27 — NEG: a non-owner cannot list members via the platform RPC.
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform count(*) from public.list_members_metadata();
    raise exception 'POLICY-BATTERY FAIL 03.27: client listed members via the platform RPC';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 03.27: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;
