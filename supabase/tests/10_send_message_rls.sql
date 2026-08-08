-- ============================================================================
-- supabase/tests/10_send_message_rls.sql — audited message-send battery (T3)
-- Source: docs/send_message_gate_review_2026-08-08.md §4 (the function spec
-- + deny rows) + docs/send_message_rpc_plan_2026-08-08.md (D-SM1..D-SM3).
--
-- Proves the audited write path (D-SM1/D-SM2/D-SM3): send_message is now
-- the ONLY message write path — the direct INSERT grant is revoked and
-- messages_insert_assigned dropped (09.15/09.16 pin that half). This file
-- pins the RPC half:
--   1. POSITIVES — the assigned attorney / assigned client send on their
--      thread's matter and the row persists with the D-RT4 stored author
--      name (from profiles — the handle_new_user mirror of the client
--      session's display-name source).
--   2. AUDIT (§8, Q3) — every successful send writes a message:create/
--      allowed row with the actor, the message resource id, and a
--      REDACTED summary ('message sent' — never the body).
--   3. DENY ROWS — the in-function gate re-asserts the exact
--      messages_insert_assigned authorization (D-SM1: is_active_member AND
--      thread->matter three-way org equality AND assigned client/attorney):
--      org-role-alone / cross-org / suspended / owner / anon each denied.
--   4. BODY CHECK — an empty body is rejected (messages_body_check) even
--      through the RPC (the write-side mapping contract twin of 08.10).
--   5. §8 NEGATIVE — a denied send writes NO audit row: after all the deny
--      rows, exactly the two positive sends' audit rows exist.
--
-- Run AFTER 00_fixtures.sql .. 09_realtime_push.sql, under psql
-- -v ON_ERROR_STOP=1, by scripts/verify_policy_tests.sh (which applies
-- rpc/send_message.sql — the function + EXECUTE grant + the D-SM3
-- revocation — to the rehearsal project first). Same impersonation pattern
-- as 08/09: set_config request.jwt.* for auth.uid(); the denied sends raise
-- the in-function 'permission denied', matched by message so the battery's
-- own FAIL raise always propagates.
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- POSITIVES — assigned attorney / assigned client send on the thread's matter.
-- ############################################################################

-- CHECK 10.01 — POS: partner-a (org-a, partner/active, assigned attorney on
-- matter 1) sends on thread 1 (matter 1). The RPC returns the new message
-- id, the row persists, and the stored author is the D-RT4 name from
-- profiles ('Partner A' — never PII, the client-session source). The row is
-- deliberately NOT rolled back: its audit row is asserted by 10.03/10.10.
set role authenticated;
do $$
declare
  v_id     uuid;
  v_author text;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select public.send_message('60000000-0000-4000-8000-000000000001', 'Demo audited-send message (attorney)') into v_id;
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 10.01: send_message returned no id';
  end if;
  select author_display_name into v_author
    from public.messages
   where id = v_id;
  if v_author <> 'Partner A' then
    raise exception 'POLICY-BATTERY FAIL 10.01: stored author is %, want Partner A (D-RT4 profiles source)', v_author;
  end if;
end $$;
reset role;

-- CHECK 10.02 — POS: client-a (org-a, client/active, assigned client on
-- matter 1) sends on the same thread — the client side of the audited gate.
set role authenticated;
do $$
declare
  v_id     uuid;
  v_author text;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select public.send_message('60000000-0000-4000-8000-000000000001', 'Demo audited-send message (client)') into v_id;
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 10.02: send_message returned no id';
  end if;
  select author_display_name into v_author
    from public.messages
   where id = v_id;
  if v_author <> 'Client A' then
    raise exception 'POLICY-BATTERY FAIL 10.02: stored author is %, want Client A (D-RT4 profiles source)', v_author;
  end if;
end $$;
reset role;

-- CHECK 10.03 — POS (§8 audit shape, Q3): the two successful sends produced
-- message:create/allowed rows with the actor, the message resource id, and
-- the REDACTED summary 'message sent' — contract §8 coverage by
-- construction (the privileged observer reads audit_events; no client role
-- holds a direct grant, D-P0C4).
do $$
declare
  v_shape bigint;
begin
  select count(*) into v_shape
    from public.audit_events
   where action = 'message:create'
     and outcome = 'allowed'
     and resource_type = 'message'
     and resource_id is not null
     and redacted_summary = 'message sent';
  if v_shape <> 2 then
    raise exception 'POLICY-BATTERY FAIL 10.03: redacted message:create audit rows = %, want 2 (attorney + client sends)', v_shape;
  end if;
end $$;

-- ############################################################################
-- DENY ROWS — the in-function gate (D-SM1). Each denial raises the RPC's
-- 'permission denied' BEFORE anything is written; the battery matches by
-- message so its own FAIL raise always propagates.
-- ############################################################################

-- CHECK 10.04 — NEG (org role alone): partner-a is an ACTIVE org-a partner
-- but has NO assignment on matter 4 — sending on thread 4 is denied by the
-- in-function gate, proving "an org role alone never grants the write".
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.send_message('60000000-0000-4000-8000-000000000004', 'Org-role-alone send attempt');
    raise exception 'POLICY-BATTERY FAIL 10.04: org-role-alone send succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: the in-function permission-denied raise
  end;
end $$;
reset role;

-- CHECK 10.05 — NEG (cross-org): partner-b is assigned as attorney on an
-- org-a matter (5) but is an ACTIVE member of org-b ONLY — the gate's
-- is_active_member tests the thread's org (org-a), so the assignment grants
-- nothing through the RPC either.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    perform public.send_message('60000000-0000-4000-8000-000000000001', 'Cross-org send attempt');
    raise exception 'POLICY-BATTERY FAIL 10.05: cross-org send succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: the in-function permission-denied raise
  end;
end $$;
reset role;

-- CHECK 10.06 — NEG (stale access): suspended-a IS assigned as attorney on
-- matter 6 but its org-a membership is 'suspended' — the gate's
-- is_active_member arm (status = 'active') denies the send.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  begin
    perform public.send_message('60000000-0000-4000-8000-000000000006', 'Stale-access send attempt');
    raise exception 'POLICY-BATTERY FAIL 10.06: suspended send succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: the in-function permission-denied raise
  end;
end $$;
reset role;

-- CHECK 10.07 — NEG (platform_owner_admin): the owner (0001) is never
-- assigned on any matter, so the gate denies its sends always. RESIDUAL
-- (design review Q5, recorded): if an owner account were ever assigned on a
-- matter, the gate WOULD grant — the categorical matrix deny is an
-- operational invariant, not a mechanism guarantee; fixtures never create
-- that state.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.send_message('60000000-0000-4000-8000-000000000001', 'Owner send attempt');
    raise exception 'POLICY-BATTERY FAIL 10.07: platform_owner_admin send succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: the in-function permission-denied raise
  end;
end $$;
reset role;

-- CHECK 10.08 — NEG (unauthenticated): anon holds NO EXECUTE grant on
-- send_message (the RPC file grants authenticated only), so the call is
-- denied at the privilege layer before the function body runs.
set role anon;
do $$
begin
  begin
    perform public.send_message('60000000-0000-4000-8000-000000000001', 'Anon send attempt');
    raise exception 'POLICY-BATTERY FAIL 10.08: anon send succeeded';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
end $$;
set role authenticated;

-- CHECK 10.09 — NEG (body CHECK through the RPC): an empty body is rejected
-- by messages_body_check even on the audited path — the function passes
-- p_body through and the schema CHECK fires (the write-side mapping
-- contract; the privileged twin is 09.10). Nothing is written.
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    select public.send_message('60000000-0000-4000-8000-000000000001', '') into v_id;
    raise exception 'POLICY-BATTERY FAIL 10.09: empty-body send succeeded';
  exception when check_violation then
    null; -- expected: messages_body_check
  end;
end $$;
reset role;

-- CHECK 10.10 — NEG (§8 negative): after all the deny rows, exactly the two
-- positive sends' audit rows exist — a denied send writes NO audit row
-- (the gate raises before the insert and the write_audit call).
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from public.audit_events
   where action = 'message:create';
  if v_cnt <> 2 then
    raise exception 'POLICY-BATTERY FAIL 10.10: message:create audit rows = % after the deny rows, want exactly 2 (only successful sends are audited)', v_cnt;
  end if;
end $$;
