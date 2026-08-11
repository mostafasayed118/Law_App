-- ============================================================================
-- supabase/tests/15_notification_producer_rls.sql — notification producer
-- battery (T3). Source: docs/notification_feed_producer_gate_review_2026-08-11.md
-- §3 Q1-Q6 (REVIEWED 0f95125) + docs/notification_feed_producer_slice_plan_
-- 2026-08-11.md (D-P1..D-P6, RATIFIED cdd7ab4).
--
-- Proves the audit-mirror trigger (migrations/15_notification_producer.sql):
--   - D-P1/D-P2 map — matter:create and message:create with
--     outcome='allowed' produce EXACTLY ONE org-scoped notification row
--     (delta-based, review Q5), visible to the org's members THROUGH the
--     shipped notifications_select_org gate (review Q3 — no backdoor);
--   - D-P3 redaction — the summary is the FIXED map string, never the
--     matter title or message body (structural redaction, the D-N3 mirror);
--   - D-P6 atomicity — the mirror runs in the SAME transaction as the
--     audit row: a rolled-back event's feed row vanishes with it (residue
--     checks after every rollback);
--   - filters — outcome='denied' / unmapped action / NULL-org events
--     produce nothing (review Q2: NULL-org identity events are skipped,
--     never synthesized);
--   - D-P4 — the mirror function is trigger-invoked only: EXECUTE revoked
--     from client roles (the write_audit precedent).
--
-- Runs AFTER 00_fixtures.sql + batteries 01-14, under psql
-- -v ON_ERROR_STOP=1, by scripts/verify_policy_tests.sh (which applies
-- migrations/15_notification_producer.sql to the rehearsal project
-- first). Same impersonation pattern as 10/13: set_config request.jwt.*
-- for auth.uid(); the RPC calls run under `set role authenticated`.
--
-- Battery-14 interplay (the D-P6 re-pin): battery 10's two COMMITTED sends
-- produce exactly 2 org-a 'new message in thread' rows before this battery
-- runs — the 15.02 baseline (captured via a session GUC) and the battery-14
-- 6/6/1 re-pin both account for them deterministically; battery 13's
-- creates are rolled back, so no persistent matter:create producer rows
-- exist here. All UUID literals in this file resolve in 00_fixtures.sql.
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- 15.01 — POS (matter:create map): partner-a creates a matter in org-a; the
-- audit-mirror produces EXACTLY ONE org-a notification with the fixed D-P3
-- content, visible through the shipped org gate; the title never leaks;
-- the whole chain rolls back with the event (D-P6 atomicity).
-- ############################################################################

-- Each harness battery runs in its own psql session (fresh as the
-- connection role — postgres), so the privileged half needs no reset up
-- front; the RPC + RLS half switches to authenticated only around the
-- checks that need it. `reset role` is placed AFTER `rollback` because
-- set/reset role is transactional — an in-transaction reset would be
-- undone by the rollback, leaving the residue check under the wrong role.
set role authenticated;
begin;
do $$
declare
  v_id   uuid;
  v_cnt  bigint;
  v_cat  text;
  v_type text;
  v_sum  text;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select public.create_matter(
    '20000000-0000-4000-8000-000000000001', '15.01 title probe — must never leak', 'corporate',
    '10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002')
    into v_id;
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 15.01: create_matter returned null';
  end if;

  -- Gate visibility (review Q3): the produced row flows through
  -- notifications_select_org — visible to an org-a member under RLS,
  -- exactly one row (the fixed summary is unique to this map).
  select count(*) into v_cnt from public.notifications
   where summary = 'Demo notification — matter created';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 15.01: produced matter row seen % times via the org gate, want 1', v_cnt;
  end if;

  select category, type, summary into v_cat, v_type, v_sum
    from public.notifications
   where summary = 'Demo notification — matter created';
  if v_cat is null or v_cat <> 'activity' or v_type is null or v_type <> 'matter_updated' then
    raise exception 'POLICY-BATTERY FAIL 15.01: produced matter row category/type %,% — want activity/matter_updated', v_cat, v_type;
  end if;
  if v_sum like '%must never leak%' then
    raise exception 'POLICY-BATTERY FAIL 15.01: matter title leaked into the notification summary (D-P3 redaction)';
  end if;
end $$;
rollback;
reset role;

-- Residue (privileged half): the feed row vanished with the rolled-back
-- event — D-P6 atomicity, exactly zero rows with the unique map summary.
do $$
declare v_cnt bigint;
begin
  select count(*) into v_cnt from public.notifications
   where summary = 'Demo notification — matter created';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 15.01: feed row survived the rolled-back matter:create (atomicity)';
  end if;
end $$;

-- ############################################################################
-- 15.02 — POS (message:create map): partner-a (assigned attorney) sends on
-- thread 1 (matter 1, org-a); the mirror produces exactly one org-a
-- 'new message in thread' row (delta against the battery-10 baseline,
-- captured in a session GUC); the body never leaks; D-P6 residue check.
-- ############################################################################

-- Privileged half: capture the pre-send baseline (battery 10's two committed
-- sends = 2 org-a rows; the GUC survives the txn + role switch below).
do $$
begin
  perform set_config(
    'b15.msg_base',
    (select count(*)::text from public.notifications where summary = 'new message in thread'),
    false);
end $$;

set role authenticated;
begin;
do $$
declare
  v_id    uuid;
  v_base  bigint;
  v_after bigint;
  v_cat   text;
  v_type  text;
  v_sum   text;
begin
  v_base := current_setting('b15.msg_base', true)::bigint;
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select public.send_message(
    '60000000-0000-4000-8000-000000000001', '15.02 body probe — must never leak')
    into v_id;
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 15.02: send_message returned null';
  end if;

  select count(*) into v_after from public.notifications
   where summary = 'new message in thread';
  if v_after <> v_base + 1 then
    raise exception 'POLICY-BATTERY FAIL 15.02: producer delta %, want % (message:create map)', v_after, v_base + 1;
  end if;

  select category, type, summary into v_cat, v_type, v_sum
    from public.notifications
   where summary = 'new message in thread'
   order by server_timestamp desc limit 1;
  if v_cat is null or v_cat <> 'activity' or v_type is null or v_type <> 'message_received' then
    raise exception 'POLICY-BATTERY FAIL 15.02: produced message row category/type %,% — want activity/message_received', v_cat, v_type;
  end if;
  if v_sum like '%must never leak%' then
    raise exception 'POLICY-BATTERY FAIL 15.02: message body leaked into the notification summary (D-P3 redaction)';
  end if;
end $$;
rollback;
reset role;

-- Residue (privileged half): back to the pre-send baseline — D-P6 atomicity.
do $$
declare v_base bigint; v_now bigint;
begin
  v_base := current_setting('b15.msg_base', true)::bigint;
  select count(*) into v_now from public.notifications
   where summary = 'new message in thread';
  if v_now <> v_base then
    raise exception 'POLICY-BATTERY FAIL 15.02: feed row survived the rolled-back message:create (want %, got %)', v_base, v_now;
  end if;
end $$;

-- ############################################################################
-- 15.03..15.05 — NEG filters (privileged half: audit-row inserts only a
-- client role can never make): outcome='denied' / unmapped action /
-- NULL-org events produce NOTHING — the D-P2 map, review Q2.
-- ############################################################################

-- CHECK 15.03 — NEG (outcome filter): 'matter:create'/'denied' mirrors nothing.
begin;
do $$
declare v_before bigint; v_after bigint;
begin
  select count(*) into v_before from public.notifications;
  insert into public.audit_events
    (actor_user_id, action, outcome, organization_id, resource_type, resource_id, redacted_summary)
  values
    ('10000000-0000-4000-8000-000000000002', 'matter:create', 'denied',
     '20000000-0000-4000-8000-000000000001', 'matter', null, 'matter created');
  select count(*) into v_after from public.notifications;
  if v_after <> v_before then
    raise exception 'POLICY-BATTERY FAIL 15.03: denied event produced a notification (want no delta)';
  end if;
end $$;
rollback;

-- CHECK 15.04 — NEG (action map): an unmapped action with outcome='allowed'
-- (membership:create — an org event outside the v1 map) mirrors nothing.
begin;
do $$
declare v_before bigint; v_after bigint;
begin
  select count(*) into v_before from public.notifications;
  insert into public.audit_events
    (actor_user_id, action, outcome, organization_id, resource_type, resource_id, redacted_summary)
  values
    ('10000000-0000-4000-8000-000000000002', 'membership:create', 'allowed',
     '20000000-0000-4000-8000-000000000001', 'membership', null, 'member joined');
  select count(*) into v_after from public.notifications;
  if v_after <> v_before then
    raise exception 'POLICY-BATTERY FAIL 15.04: unmapped action produced a notification (want no delta)';
  end if;
end $$;
rollback;

-- CHECK 15.05 — NEG (NULL-org skip): an identity-level matter:create audit
-- row with NO org is skipped, never synthesized (the is not null guard —
-- a NULL-org mirror attempt would crash the NOT NULL org FK, not filter).
begin;
do $$
declare v_before bigint; v_after bigint;
begin
  select count(*) into v_before from public.notifications;
  insert into public.audit_events
    (actor_user_id, action, outcome, organization_id, resource_type, resource_id, redacted_summary)
  values
    ('10000000-0000-4000-8000-000000000002', 'matter:create', 'allowed',
     null, 'matter', null, 'matter created');
  select count(*) into v_after from public.notifications;
  if v_after <> v_before then
    raise exception 'POLICY-BATTERY FAIL 15.05: NULL-org event produced a notification (want no delta)';
  end if;
end $$;
rollback;

-- CHECK 15.06 — NEG (D-P4): the mirror function is trigger-invoked only —
-- EXECUTE revoked from client roles (the write_audit precedent). This is
-- the RPC-EXECUTE-stays-20 pin at the function level: the producer is a
-- server mechanism, not a client surface.
do $$
begin
  if (select has_function_privilege('authenticated', 'public.mirror_audit_to_notifications()', 'EXECUTE')) then
    raise exception 'POLICY-BATTERY FAIL 15.06: mirror function EXECUTE granted to authenticated (D-P4)';
  end if;
end $$;
