-- ============================================================================
-- supabase/tests/16_notification_read_flag.sql — notification read-flag
-- write battery (T3). Source: docs/notification_read_flag_slice_plan_
-- 2026-09-02.md (D-F1..D-F7, owner-approved 2026-09-02).
--
-- Proves the D-N6 write RPC (migrations/16_notification_read_flag.sql):
--   - D-F1 gate — an active member flips ONLY own-org, still-unread rows;
--     the exact flipped count is returned; is_read persists; foreign-org
--     ids are silently untouched (never an error to the caller's own rows);
--   - D-F2 audit — one notification:mark_read / allowed row per distinct
--     org of the FLIPPED rows, redacted generic summary, no id in the
--     summary; no audit row on a zero-flip call;
--   - D-F4 idempotency — re-marking read rows returns 0;
--   - D-F4/D-P2 interplay — the mark-read audit does NOT re-produce a feed
--     row (the action is outside the producer's D-P2 map);
--   - D-F3 — the function is the ONLY write path: no UPDATE grant on the
--     table exists and EXECUTE is granted to authenticated only (anon
--     denied; the RPC-EXECUTE pin moves 20 -> 21).
--
-- Runs AFTER 00_fixtures.sql + batteries 01-15, under psql
-- -v ON_ERROR_STOP=1, by scripts/verify_policy_tests.sh (which applies
-- migrations/16_notification_read_flag.sql to the rehearsal project
-- first). Same impersonation pattern as 14/15: set_config request.jwt.*
-- for auth.uid(); the RPC call runs under `set role authenticated`.
-- All UUID literals resolve in 00_fixtures.sql (org-a …0001, org-b …0002;
-- partner-a …0002, partner-b …0004, suspended …0005, demo …0006).
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- Privileged-path half (runs as the connection role — postgres): the facts
-- no client role can observe because the table carries no UPDATE grant.
-- ############################################################################

-- CHECK 16.05 — NEG (privileged half, structural): the D-F3 line — the RPC
-- is the ONLY write path. The table's privilege inventory carries NO UPDATE
-- grant for any client role (the send_message D-SM3 mirror): a future
-- un-audited direct-INSERT/UPDATE path cannot reappear without this pin
-- failing first.
do $$
declare
  v_upd int;
begin
  select count(*) into v_upd
    from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'notifications'
     and privilege_type in ('UPDATE', 'INSERT', 'DELETE')
     and grantee in ('anon', 'authenticated');
  if v_upd <> 0 then
    raise exception 'POLICY-BATTERY FAIL 16.05: % client write grants exist on notifications — the RPC must be the only write path (D-F3)', v_upd;
  end if;
end $$;

-- CHECK 16.06 — POS (privileged half, structural): the D-F3 EXECUTE shape —
-- mark_notifications_read is callable by authenticated, denied to anon and
-- public (the RPC-EXECUTE pin 20 -> 21 lives in the harness's structural
-- checks; this is the function-level pairing of 15.06).
do $$
begin
  if (not (select has_function_privilege('authenticated', 'public.mark_notifications_read(uuid[])', 'EXECUTE'))) then
    raise exception 'POLICY-BATTERY FAIL 16.06: authenticated lost EXECUTE on mark_notifications_read';
  end if;
  if (select has_function_privilege('anon', 'public.mark_notifications_read(uuid[])', 'EXECUTE')) then
    raise exception 'POLICY-BATTERY FAIL 16.06: anon holds EXECUTE on mark_notifications_read';
  end if;
end $$;

-- ############################################################################
-- RPC half (impersonated member calls under `set role authenticated`).
-- ############################################################################

-- CHECK 16.01 — POS (D-F1 gate + D-F2 audit + D-F4 interplay): partner-a
-- (org-a active member) marks two org-a rows read — exact count 2, is_read
-- persists, one redacted audit row, and NO feed row is produced from the
-- mark-read audit (the D-P2 map excludes notification:mark_read).
begin;
do $$
declare
  v_cnt     bigint;
  v_flipped int;
  v_audits  bigint;
  v_id1 uuid := 'b0000000-0000-4000-8000-000000001601';
  v_id2 uuid := 'b0000000-0000-4000-8000-000000001602';
begin
  -- Seed two org-a unread rows as the privileged fixture writer.
  insert into public.notifications
    (id, organization_id, category, type, summary, server_timestamp, is_read)
  values
    (v_id1, '20000000-0000-4000-8000-000000000001', 'activity', 'matter_updated', '16.01 seed row one', now(), false),
    (v_id2, '20000000-0000-4000-8000-000000000001', 'activity', 'message_received', '16.01 seed row two', now(), false);

  select count(*) into v_cnt from public.notifications where is_read = false;
  perform set_config('battery16.baseline', v_cnt::text, true);

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select public.mark_notifications_read(array[v_id1, v_id2]) into v_flipped;
  if v_flipped <> 2 then
    raise exception 'POLICY-BATTERY FAIL 16.01: mark returned %, want 2', v_flipped;
  end if;

  -- is_read persists (read through the org gate under the member role).
  select count(*) into v_cnt from public.notifications where id in (v_id1, v_id2) and is_read = true;
  if v_cnt <> 2 then
    raise exception 'POLICY-BATTERY FAIL 16.01: % of 2 rows read after the mark', v_cnt;
  end if;

  -- D-F2: exactly ONE audit row for org-a, redacted summary, no id inside.
  select count(*) into v_audits from public.audit_events
   where action = 'notification:mark_read' and outcome = 'allowed'
     and organization_id = '20000000-0000-4000-8000-000000000001'
     and redacted_summary = 'notification read state updated';
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 16.01: % mark_read audit rows, want 1', v_audits;
  end if;
  if exists (
    select 1 from public.audit_events
     where action = 'notification:mark_read'
       and redacted_summary like '%1601%'
  ) then
    raise exception 'POLICY-BATTERY FAIL 16.01: the mark_read audit summary leaked an id';
  end if;

  -- D-F4 interplay: the total notifications count did not grow — the
  -- mark-read audit produced NO feed row.
  select count(*) into v_cnt from public.notifications;
  if v_cnt::text <> current_setting('battery16.baseline') then
    raise exception 'POLICY-BATTERY FAIL 16.01: the mark-read audit produced a feed row (count moved from % to %)', current_setting('battery16.baseline'), v_cnt;
  end if;

  -- D-F4 idempotency: re-marking the same rows flips 0 and writes no new
  -- audit row.
  select public.mark_notifications_read(array[v_id1, v_id2]) into v_flipped;
  if v_flipped <> 0 then
    raise exception 'POLICY-BATTERY FAIL 16.01: idempotent re-mark returned %, want 0', v_flipped;
  end if;
  select count(*) into v_audits from public.audit_events
   where action = 'notification:mark_read';
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 16.01: re-mark wrote an extra audit row (% total)', v_audits;
  end if;
end $$;
rollback;

-- CHECK 16.02 — NEG (D-F1 cross-org): partner-b (org-b active member) marks
-- an org-a row and an org-b row — EXACTLY the org-b row flips; the org-a
-- row is silently untouched; the audit row is org-b's only.
begin;
do $$
declare
  v_cnt     bigint;
  v_flipped int;
  v_id_a uuid := 'b0000000-0000-4000-8000-000000001603';
  v_id_b uuid := 'b0000000-0000-4000-8000-000000001604';
begin
  insert into public.notifications
    (id, organization_id, category, type, summary, server_timestamp, is_read)
  values
    (v_id_a, '20000000-0000-4000-8000-000000000001', 'activity', 'matter_updated', '16.02 org-a row', now(), false),
    (v_id_b, '20000000-0000-4000-8000-000000000002', 'activity', 'matter_updated', '16.02 org-b row', now(), false);

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select public.mark_notifications_read(array[v_id_a, v_id_b]) into v_flipped;
  if v_flipped <> 1 then
    raise exception 'POLICY-BATTERY FAIL 16.02: cross-org mark returned %, want 1', v_flipped;
  end if;

  select count(*) into v_cnt from public.notifications where id = v_id_b and is_read = true;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 16.02: the caller''s own-org row did not flip';
  end if;
  select count(*) into v_cnt from public.notifications where id = v_id_a and is_read = false;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 16.02: the foreign-org row was mutated';
  end if;

  select count(*) into v_cnt from public.audit_events
   where action = 'notification:mark_read'
     and organization_id = '20000000-0000-4000-8000-000000000002';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 16.02: % org-b audit rows, want 1', v_cnt;
  end if;
end $$;
rollback;

-- CHECK 16.03 — NEG (D-F1 non-member + suspended): a caller with no
-- membership and a suspended member flip 0 rows and write no audit row.
begin;
do $$
declare
  v_cnt     bigint;
  v_flipped int;
  v_id      uuid := 'b0000000-0000-4000-8000-000000001605';
begin
  insert into public.notifications
    (id, organization_id, category, type, summary, server_timestamp, is_read)
  values
    (v_id, '20000000-0000-4000-8000-000000000001', 'system', 'system_maintenance', '16.03 seed row', now(), false);

  -- Demo account (…0006): no membership anywhere.
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000006', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000006"}', false);
  select public.mark_notifications_read(array[v_id]) into v_flipped;
  if v_flipped <> 0 then
    raise exception 'POLICY-BATTERY FAIL 16.03: a non-member flipped % rows', v_flipped;
  end if;

  -- Suspended member (…0005): stale access, is_active_member = false.
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select public.mark_notifications_read(array[v_id]) into v_flipped;
  if v_flipped <> 0 then
    raise exception 'POLICY-BATTERY FAIL 16.03: a suspended member flipped % rows', v_flipped;
  end if;

  select count(*) into v_cnt from public.audit_events
   where action = 'notification:mark_read';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 16.03: a denied call wrote an audit row (% rows)', v_cnt;
  end if;
end $$;
rollback;

-- CHECK 16.04 — NEG (D-F3 anon EXECUTE denial): the function is revoked
-- from anon; the direct call fails at the privilege layer (the 09.15
-- privilege-deny precedent).
begin;
do $$
begin
  set role anon;
  begin
    perform public.mark_notifications_read(array[]::uuid[]);
    raise exception 'POLICY-BATTERY FAIL 16.04: anon EXECUTE was permitted';
  exception when insufficient_privilege then
    null; -- expected: EXECUTE revoked from anon (D-F3)
  end;
end $$;
rollback;
