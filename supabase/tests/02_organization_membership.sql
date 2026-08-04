-- ============================================================================
-- supabase/tests/02_organization_membership.sql — P0C.1 battery, matrix §3
-- rows (docs/permission_matrix.md §3, contract §9: every row ≥1 positive + ≥1
-- negative; the 2026-08-03 hardening guards — last-partner lockout,
-- existing-member invite rejection, self-removal refusal — are pinned here
-- too, per the r5 rehearsal scope). Source:
-- docs/p0_closure_scope_2026-08-05.md slice P0C.1 (AC-1).
--
-- Run AFTER 00_fixtures.sql, under psql -v ON_ERROR_STOP=1, by
-- scripts/verify_policy_tests.sh. Same impersonation pattern as 01.
--
-- Mutating RPC positives are wrapped in begin/rollback transactions: the
-- check verifies the in-transaction effect, then the rollback restores the
-- fixture baseline so no later check depends on a mutation's side effect
-- (audit rows roll back with the transaction). Read-only rows and negative
-- rows run bare.
-- ============================================================================

\set ON_ERROR_STOP on

set role authenticated;

-- ############################################################################
-- §3 — View own org's member list
-- ############################################################################

-- CHECK 02.01 — POS: partner_a (active, org-a) sees org-a's roster: 4 rows.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.memberships
   where organization_id = '20000000-0000-4000-8000-000000000001';
  if v_cnt <> 4 then
    raise exception 'POLICY-BATTERY FAIL 02.01: org-a roster for active member must be 4 rows, got %', v_cnt;
  end if;
end $$;

-- CHECK 02.02 — POS: member_a (client, active) also sees org-a's roster
-- (every active member, not just partners — matrix §3 "View own org's member
-- list | ✅ client").
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.memberships
   where organization_id = '20000000-0000-4000-8000-000000000001';
  if v_cnt <> 4 then
    raise exception 'POLICY-BATTERY FAIL 02.02: org-a roster for active client must be 4 rows, got %', v_cnt;
  end if;
end $$;

-- CHECK 02.03 — NEG: member_a (org-a) selects org-b's roster — 0 rows (tenant
-- isolation: an org-a member cannot read org-b data by changing a parameter).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.memberships
   where organization_id = '20000000-0000-4000-8000-000000000002';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 02.03: cross-org roster visible, got % rows', v_cnt;
  end if;
end $$;

-- CHECK 02.04 — NEG: suspended_a (partner, but SUSPENDED) sees only its own
-- row — the org roster is gone for it (stale session cannot project
-- capabilities; active_membership() filters status='active').
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select count(*) into v_cnt
    from public.memberships
   where organization_id = '20000000-0000-4000-8000-000000000001';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 02.04: suspended member saw % roster rows, want only its own (1)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- §3 — View own org (organizations SELECT policy)
-- ############################################################################

-- CHECK 02.05 — POS: member_a sees org-a's organizations row (1).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.organizations
   where id = '20000000-0000-4000-8000-000000000001';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 02.05: own-org row must be visible, got %', v_cnt;
  end if;
end $$;

-- CHECK 02.06 — NEG: member_a cannot see org-b's organizations row.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.organizations
   where id = '20000000-0000-4000-8000-000000000002';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 02.06: foreign org row visible, got %', v_cnt;
  end if;
end $$;

-- ############################################################################
-- §3 — Invite / resend / revoke a pending invite
-- ############################################################################

-- CHECK 02.07 — POS: partner_a invites a fresh address into org-a — a 64-hex
-- one-time token is returned and a pending invitation row exists.
begin;
do $$
declare
  v_token text; v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_token := public.invite_member(
    '20000000-0000-4000-8000-000000000001', 'fresh@org-a.test', 'client');
  if v_token is null or length(v_token) <> 64 then
    raise exception 'POLICY-BATTERY FAIL 02.07: invite did not return a 64-hex token';
  end if;
  select count(*) into v_cnt
    from public.invitations
   where organization_id = '20000000-0000-4000-8000-000000000001'
     and email = 'fresh@org-a.test' and status = 'pending';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 02.07: invited row not pending';
  end if;
end $$;
rollback;

-- CHECK 02.08 — NEG: a client (non-partner) cannot invite (generic denial).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.invite_member(
      '20000000-0000-4000-8000-000000000001', 'x@org-a.test', 'client');
    raise exception 'POLICY-BATTERY FAIL 02.08: client invited a member';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.08: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 02.09 — NEG: partner_a cannot invite into org-b (cross-org).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.invite_member(
      '20000000-0000-4000-8000-000000000002', 'x@org-b.test', 'client');
    raise exception 'POLICY-BATTERY FAIL 02.09: partner_a invited into org-b';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.09: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 02.10 — NEG (hardening 2026-08-03): inviting an email that already
-- holds a membership row in the org is refused — no dead-end invite.
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.invite_member(
      '20000000-0000-4000-8000-000000000001', 'client-a@org-a.test', 'client');
    raise exception 'POLICY-BATTERY FAIL 02.10: existing-member invite issued';
  exception when others then
    if sqlerrm <> 'user already has a membership in this organization' then
      raise exception 'POLICY-BATTERY FAIL 02.10: unexpected error (want existing-member refusal): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 02.11 — POS: partner_a resends the fixture pending invite — token
-- rotated, expiry reset (verified in-transaction, then rolled back).
begin;
do $$
declare
  v_token text; v_hash text; v_exp bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_token := public.resend_invitation('30000000-0000-4000-8000-000000000001');
  if v_token is null or length(v_token) <> 64 then
    raise exception 'POLICY-BATTERY FAIL 02.11: resend did not rotate to a 64-hex token';
  end if;
  select token_hash, extract(epoch from (expires_at - created_at))::bigint
    into v_hash, v_exp
    from public.invitations
   where id = '30000000-0000-4000-8000-000000000001';
  if v_hash = repeat('a', 64) then
    raise exception 'POLICY-BATTERY FAIL 02.11: resend did not rotate token_hash';
  end if;
  if v_exp < 6 * 24 * 3600 then
    raise exception 'POLICY-BATTERY FAIL 02.11: resend did not reset the 7-day expiry';
  end if;
end $$;
rollback;

-- CHECK 02.12 — POS: partner_a revokes the fixture pending invite (status
-- transition, never a DELETE), verified in-transaction then rolled back.
begin;
do $$
declare
  v_status public.invitation_status; v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.revoke_invitation('30000000-0000-4000-8000-000000000001');
  select status into v_status
    from public.invitations
   where id = '30000000-0000-4000-8000-000000000001';
  if v_status <> 'revoked' then
    raise exception 'POLICY-BATTERY FAIL 02.12: revoke did not transition to revoked (got %)', v_status;
  end if;
  select count(*) into v_cnt from public.invitations where id = '30000000-0000-4000-8000-000000000001';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 02.12: revoke deleted the row instead of transitioning status';
  end if;
end $$;
rollback;

-- CHECK 02.13 — NEG: a client cannot revoke (generic denial).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.revoke_invitation('30000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 02.13: client revoked an invite';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.13: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 02.14 — NEG: partner_b (org-b) cannot revoke org-a's invite
-- (cross-org — the guard reads the invite's own organization).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    perform public.revoke_invitation('30000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 02.14: partner_b revoked org-a''s invite';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.14: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- ############################################################################
-- §3 — Change a member's role
-- ############################################################################

-- CHECK 02.15 — POS: partner_a changes member_a's role client -> attorney
-- (verified in-transaction, then rolled back).
begin;
do $$
declare
  v_role public.org_role;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.change_member_role(
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000003', 'attorney');
  select role into v_role
    from public.memberships
   where organization_id = '20000000-0000-4000-8000-000000000001'
     and user_id = '10000000-0000-4000-8000-000000000003';
  if v_role <> 'attorney' then
    raise exception 'POLICY-BATTERY FAIL 02.15: role change did not apply (got %)', v_role;
  end if;
end $$;
rollback;

-- CHECK 02.16 — NEG: a client cannot change roles (generic denial).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.change_member_role(
      '20000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000005', 'client');
    raise exception 'POLICY-BATTERY FAIL 02.16: client changed a role';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.16: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 02.17 — NEG: partner_a cannot change a role in org-b (cross-org).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.change_member_role(
      '20000000-0000-4000-8000-000000000002',
      '10000000-0000-4000-8000-000000000004', 'client');
    raise exception 'POLICY-BATTERY FAIL 02.17: partner_a changed a role in org-b';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.17: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 02.18 — NEG (hardening 2026-08-03): demoting the org's LAST active
-- partner is refused (org-a's only active partner is partner_a; suspended_a
-- does not count).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.change_member_role(
      '20000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002', 'client');
    raise exception 'POLICY-BATTERY FAIL 02.18: last active partner demoted';
  exception when others then
    if sqlerrm <> 'organization must retain at least one active partner' then
      raise exception 'POLICY-BATTERY FAIL 02.18: unexpected error (want last-partner refusal): %', sqlerrm;
    end if;
  end;
end $$;

-- ############################################################################
-- §3 — Suspend / reactivate a membership
-- ############################################################################

-- CHECK 02.19 — POS: partner_a suspends then reactivates member_a — status
-- returns to 'active' (verified in-transaction, then rolled back).
begin;
do $$
declare
  v_s public.membership_status; v_a public.membership_status;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.suspend_membership(
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000003');
  select status into v_s
    from public.memberships
   where organization_id = '20000000-0000-4000-8000-000000000001'
     and user_id = '10000000-0000-4000-8000-000000000003';
  if v_s <> 'suspended' then
    raise exception 'POLICY-BATTERY FAIL 02.19: suspend did not apply (got %)', v_s;
  end if;
  perform public.reactivate_membership(
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000003');
  select status into v_a
    from public.memberships
   where organization_id = '20000000-0000-4000-8000-000000000001'
     and user_id = '10000000-0000-4000-8000-000000000003';
  if v_a <> 'active' then
    raise exception 'POLICY-BATTERY FAIL 02.19: reactivate did not restore active (got %)', v_a;
  end if;
end $$;
rollback;

-- CHECK 02.20 — NEG: a client cannot suspend (generic denial).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.suspend_membership(
      '20000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000005');
    raise exception 'POLICY-BATTERY FAIL 02.20: client suspended a membership';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.20: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 02.21 — NEG: partner_a cannot suspend a membership in org-b
-- (cross-org).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.suspend_membership(
      '20000000-0000-4000-8000-000000000002',
      '10000000-0000-4000-8000-000000000004');
    raise exception 'POLICY-BATTERY FAIL 02.21: partner_a suspended an org-b membership';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.21: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- ############################################################################
-- §3 — Remove a member
-- ############################################################################

-- CHECK 02.22 — POS: partner_a removes member_a — status 'removed', row kept
-- (soft removal, audit trail preserved), verified in-transaction, rolled back.
begin;
do $$
declare
  v_s public.membership_status; v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.remove_membership(
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000003');
  select status into v_s
    from public.memberships
   where organization_id = '20000000-0000-4000-8000-000000000001'
     and user_id = '10000000-0000-4000-8000-000000000003';
  if v_s <> 'removed' then
    raise exception 'POLICY-BATTERY FAIL 02.22: remove did not transition to removed (got %)', v_s;
  end if;
  select count(*) into v_cnt
    from public.memberships
   where organization_id = '20000000-0000-4000-8000-000000000001'
     and user_id = '10000000-0000-4000-8000-000000000003';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 02.22: removal deleted the row instead of soft-transitioning';
  end if;
end $$;
rollback;

-- CHECK 02.23 — NEG: self-removal is refused (D-05: use delete_my_account).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.remove_membership(
      '20000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002');
    raise exception 'POLICY-BATTERY FAIL 02.23: partner removed self via remove_membership';
  exception when others then
    if sqlerrm <> 'cannot remove yourself; use delete_my_account' then
      raise exception 'POLICY-BATTERY FAIL 02.23: unexpected error (want self-removal refusal): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 02.24 — NEG: partner_a cannot remove an org-b member (cross-org).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.remove_membership(
      '20000000-0000-4000-8000-000000000002',
      '10000000-0000-4000-8000-000000000004');
    raise exception 'POLICY-BATTERY FAIL 02.24: partner_a removed an org-b member';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.24: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- ############################################################################
-- §3 — Create an organization (D-08)
-- ############################################################################

-- CHECK 02.25 — POS: any authenticated user may create an org; the creator is
-- made its initial active partner (server-set, never client-supplied),
-- verified in-transaction then rolled back.
begin;
do $$
declare
  v_org uuid; v_role public.org_role; v_status public.membership_status;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_org := public.create_organization('Scratch Org');
  if v_org is null then
    raise exception 'POLICY-BATTERY FAIL 02.25: create_organization returned null';
  end if;
  select role, status into v_role, v_status
    from public.memberships
   where organization_id = v_org and user_id = auth.uid();
  if v_role <> 'partner' or v_status <> 'active' then
    raise exception 'POLICY-BATTERY FAIL 02.25: creator not made active partner (%)', v_role || '/' || v_status;
  end if;
end $$;
rollback;

-- ############################################################################
-- §3 — Owner columns that DENY (owner capability creep guard, matrix §3)
-- ############################################################################

-- CHECK 02.26 — NEG: the platform owner cannot use the PARTNER invite path
-- (matrix §3 owner cell: ❌ deny).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.invite_member(
      '20000000-0000-4000-8000-000000000001', 'x@org-a.test', 'client');
    raise exception 'POLICY-BATTERY FAIL 02.26: owner invited a member via the partner path';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.26: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 02.27 — NEG: the owner cannot change roles via the partner path.
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.change_member_role(
      '20000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000003', 'attorney');
    raise exception 'POLICY-BATTERY FAIL 02.27: owner changed a role via the partner path';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.27: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 02.28 — NEG: the owner cannot remove a member via the partner path.
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.remove_membership(
      '20000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000003');
    raise exception 'POLICY-BATTERY FAIL 02.28: owner removed a member via the partner path';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.28: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 02.29 — NEG: the owner cannot suspend via the partner path (the owner
-- surface is suspend_membership_platform, proven positive in 03).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.suspend_membership(
      '20000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000003');
    raise exception 'POLICY-BATTERY FAIL 02.29: owner suspended via the partner path';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 02.29: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;
