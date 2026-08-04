-- ============================================================================
-- supabase/tests/01_identity_session.sql — P0C.1 battery, matrix §2 rows
-- (docs/permission_matrix.md §2 + §2 addendum rows for
--  list_org_members_metadata, contract §9: every row ≥1 positive + ≥1
--  negative). Source: docs/p0_closure_scope_2026-08-05.md slice P0C.1 (AC-1).
--
-- Run AFTER 00_fixtures.sql, under psql -v ON_ERROR_STOP=1, by
-- scripts/verify_policy_tests.sh. Role impersonation is the standard Supabase
-- RLS test pattern used by the P2 r1–r5 rehearsals (r4 evidence §1):
--   set role authenticated/anon  +  set_config('request.jwt.claim.sub'|'request.jwt.claims', …)
-- auth.uid() reads the request.jwt GUCs; RLS policies and grants apply under
-- the impersonated role. Both claim GUCs are set (version compatibility:
-- r4 used request.jwt.claims, r5 used request.jwt.claim.sub).
--
-- Every check is a DO block; a failing check raises a message starting
-- POLICY-BATTERY FAIL so the harness can surface the named row. Denials that
-- must raise (grant/RLS/RPC guards) catch the expected error class; a check
-- that reaches its trailing raise is a genuine failure.
-- ============================================================================

\set ON_ERROR_STOP on

-- Actor section: every check below the set_config lines runs as that user.
set role authenticated;

-- ############################################################################
-- §2 — View own profile
-- ############################################################################

-- CHECK 01.01 — POS: member_a reads their own profile (exactly 1 row).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt from public.profiles;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 01.01: own-profile SELECT must return 1 row, got %', v_cnt;
  end if;
end $$;

-- CHECK 01.02 — NEG: member_a cannot read partner_b's profile row (0 rows).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.profiles
   where user_id = '10000000-0000-4000-8000-000000000004';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 01.02: another user''s profile visible, got % rows', v_cnt;
  end if;
end $$;

-- CHECK 01.03 — NEG (D-T6 pair, matrix §2 addendum): partner_a's raw SELECT on
-- a same-org member's profile returns 0 rows — own-row-only for every
-- non-owner role; list_org_members_metadata is the ONLY widened path.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.profiles
   where user_id = '10000000-0000-4000-8000-000000000003';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 01.03: D-T6 violated — partner saw a raw member profile row';
  end if;
end $$;

-- ############################################################################
-- §2 — Edit own profile
-- ############################################################################

-- CHECK 01.04 — POS: member_a updates their own display_name (1 row affected),
-- then restores it (the battery leaves fixture state clean).
do $$
declare
  v_rows bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  update public.profiles set display_name = 'Edited by battery'
   where user_id = auth.uid();
  get diagnostics v_rows = row_count;
  if v_rows <> 1 then
    raise exception 'POLICY-BATTERY FAIL 01.04: own-profile UPDATE affected % rows, want 1', v_rows;
  end if;
  update public.profiles set display_name = 'Client A'
   where user_id = auth.uid();
end $$;

-- CHECK 01.05 — NEG: member_a cannot move their profile onto another identity
-- (UPDATE ... SET user_id = <other> is denied — the column-level UPDATE grant
-- covers only (display_name, locale), so touching user_id fails at the grant
-- layer, never silently rewritten).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    update public.profiles
       set user_id = '10000000-0000-4000-8000-000000000004'
     where user_id = auth.uid();
    raise exception 'POLICY-BATTERY FAIL 01.05: UPDATE transferring own profile row to another identity succeeded';
  exception when insufficient_privilege then
    null; -- expected: UPDATE touches a non-granted column (user_id) — denied
  end;
end $$;

-- CHECK 01.06 — NEG: member_a cannot edit another user's profile (0 rows
-- visible to the UPDATE's USING clause).
do $$
declare
  v_rows bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  update public.profiles set display_name = 'Hijacked'
   where user_id = '10000000-0000-4000-8000-000000000004';
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then
    raise exception 'POLICY-BATTERY FAIL 01.06: UPDATE touched % foreign profile rows, want 0', v_rows;
  end if;
end $$;

-- ############################################################################
-- §2 addendum — list_org_members_metadata (Phase 3 R1 RPC)
-- ############################################################################

-- CHECK 01.07 — POS: partner_a reads org-a's roster via the RPC: 4 members +
-- 1 pending invite = 5 rows, with member display_name/locale resolved and the
-- invited row carrying its invitation_id + invited email (no token material —
-- the function returns no token_hash column at all).
do $$
declare
  v_total bigint; v_member bigint; v_invited bigint; v_tokenish bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_total
    from public.list_org_members_metadata('20000000-0000-4000-8000-000000000001');
  if v_total <> 5 then
    raise exception 'POLICY-BATTERY FAIL 01.07: partner roster RPC returned % rows, want 5 (4 members + 1 pending invite)', v_total;
  end if;
  select count(*) into v_member
    from public.list_org_members_metadata('20000000-0000-4000-8000-000000000001')
   where user_id = '10000000-0000-4000-8000-000000000003'
     and display_name = 'Client A' and locale = 'en' and email is null;
  if v_member <> 1 then
    raise exception 'POLICY-BATTERY FAIL 01.07: member row missing display_name/locale resolution';
  end if;
  select count(*) into v_invited
    from public.list_org_members_metadata('20000000-0000-4000-8000-000000000001')
   where invitation_id = '30000000-0000-4000-8000-000000000001'
     and email = 'invite-pending@org-a.test' and status = 'invited';
  if v_invited <> 1 then
    raise exception 'POLICY-BATTERY FAIL 01.07: pending invite row missing invitation_id/email/status';
  end if;
  -- No token-like or credential-like material in any column of the RPC output.
  select count(*) into v_tokenish
    from public.list_org_members_metadata('20000000-0000-4000-8000-000000000001')
   where coalesce(display_name,'') ~ '[a-f0-9]{20,}'
      or coalesce(email,'') ~ '[a-f0-9]{20,}';
  if v_tokenish <> 0 then
    raise exception 'POLICY-BATTERY FAIL 01.07: RPC output leaked token-like material';
  end if;
end $$;

-- CHECK 01.08 — POS (audited read, design §7): the partner roster read wrote
-- its own 'partner:list_org_members' audit row.
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from public.audit_events
   where action = 'partner:list_org_members' and outcome = 'allowed';
  if v_cnt < 1 then
    raise exception 'POLICY-BATTERY FAIL 01.08: partner roster read was not audited';
  end if;
end $$;

-- CHECK 01.09 — NEG: a client (non-partner) is denied the RPC entirely —
-- own-row-only does not apply; the call is denied (generic 'permission
-- denied', no enumeration).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform * from public.list_org_members_metadata('20000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 01.09: client called partner roster RPC';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 01.09: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 01.10 — NEG: cross-org — partner_a with org-b's id is denied with the
-- same generic message as a nonexistent org (no enumeration).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform * from public.list_org_members_metadata('20000000-0000-4000-8000-000000000002');
    raise exception 'POLICY-BATTERY FAIL 01.10: partner_a read org-b roster';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 01.10: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 01.11 — NEG: a suspended partner is denied the RPC — stale client
-- session notwithstanding (active_membership() filters status='active').
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  begin
    perform * from public.list_org_members_metadata('20000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 01.11: suspended partner read the roster';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 01.11: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 01.12 — NEG (D-P0C1/§5): the platform owner (no partner membership)
-- is denied the partner RPC — is_platform_owner() is not a bypass; the owner
-- surface stays list_members_metadata.
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform * from public.list_org_members_metadata('20000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 01.12: owner called partner roster RPC';
  exception when others then
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 01.12: unexpected error (want generic denial): %', sqlerrm;
    end if;
  end;
end $$;

-- CHECK 01.13 — POS/NEG pair (orphan-membership defense): a membership whose
-- profiles row is missing still appears in the RPC roster with the static
-- fallback '(no profile)'/'en' — no row dropped, no error — AND the fallback
-- never contains uuid/email material. The profile row is restored after the
-- probe so fixture state stays clean.
--
-- The DELETE + restore run as the connection role (postgres) via reset role:
-- authenticated holds only `select, update (display_name, locale)` on profiles
-- (01_org_schema.sql) — no INSERT/DELETE grant and no DELETE policy exist, by
-- design — so those two statements must NOT run under the impersonated role.
-- Only the RPC verification runs as partner_a.
reset role;
delete from public.profiles
 where user_id = '10000000-0000-4000-8000-000000000007';
set role authenticated;

do $$
declare
  v_orphan bigint; v_static bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);

  select count(*) into v_orphan
    from public.list_org_members_metadata('20000000-0000-4000-8000-000000000001')
   where user_id = '10000000-0000-4000-8000-000000000007'
     and display_name = '(no profile)' and locale = 'en';
  if v_orphan <> 1 then
    raise exception 'POLICY-BATTERY FAIL 01.13: orphan membership dropped or fallback wrong (want 1 row, (no profile)/en)';
  end if;

  -- Negative half: the fallback is static — no uuid, email, or hex blob in
  -- any display_name of the RPC output.
  select count(*) into v_static
    from public.list_org_members_metadata('20000000-0000-4000-8000-000000000001')
   where display_name ~ '[@-]' or display_name ~ '[a-f0-9]{8,}';
  if v_static <> 0 then
    raise exception 'POLICY-BATTERY FAIL 01.13: fallback leaked uuid/email-like material';
  end if;
end $$;

-- Restore the fixture profile row (privileged role again).
reset role;
insert into public.profiles (user_id, display_name, locale, created_at, updated_at)
values ('10000000-0000-4000-8000-000000000007', 'Orphan Member', 'en', now(), now())
on conflict (user_id) do nothing;
set role authenticated;

-- ############################################################################
-- §2 — anon (no session) — every protected row denies, not empty-success
-- ############################################################################
set role anon;

-- CHECK 01.14 — NEG: anon SELECT on profiles is denied (no grant — denied,
-- never empty-success).
do $$
begin
  begin
    perform count(*) from public.profiles;
    raise exception 'POLICY-BATTERY FAIL 01.14: anon SELECT on profiles succeeded';
  exception when insufficient_privilege then
    null; -- expected
  end;
end $$;

-- CHECK 01.15 — NEG: anon SELECT on memberships is denied.
do $$
begin
  begin
    perform count(*) from public.memberships;
    raise exception 'POLICY-BATTERY FAIL 01.15: anon SELECT on memberships succeeded';
  exception when insufficient_privilege then
    null; -- expected
  end;
end $$;

-- Back to the authenticated surface for the remaining files (harmless; each
-- battery file re-declares its own role section).
set role authenticated;
