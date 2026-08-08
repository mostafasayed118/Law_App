-- ============================================================================
-- supabase/tests/09_realtime_push.sql — realtime live-delivery battery (T3)
-- Source: docs/realtime_push_gate_review_2026-08-08.md §4 (the deny-rows
-- contract) + docs/realtime_push_real_data_plan_2026-08-08.md (D-LV1/D-LV2/
-- D-LV5) + docs/send_message_gate_review_2026-08-08.md Q6 (D-SM3 — the
-- direct-INSERT revocation, RE-SCOPED 2026-08-08 by the audited send-message
-- slice).
--
-- Proves the live-delivery slice's two-layer mechanism + the write-path
-- handover to the audited RPC:
--   1. PUBLICATION MEMBERSHIP (D-LV2 — the ENABLEMENT layer): exactly the
--      messages table sits in the supabase_realtime publication — count 1
--      for messages, and the publication holds nothing else. postgres_changes
--      can only deliver rows of a published table; the pin keeps D-P0C1(b)
--      teeth (no accidental table exposure via realtime).
--   2. THE WRITE SURFACE HANDOVER (D-SM3 — the send-message slice): the
--      INSERT-policy group that lived here (09.03–09.09, messages_insert_
--      assigned positives + deny rows) MOVED to the audited
--      send_message RPC battery (10_send_message_rls.sql — the in-function
--      gate is now the write authorization; every send is §8-audited). This
--      file keeps the two revocation pins: a raw direct INSERT by an
--      assigned role is now denied at the PRIVILEGE layer (the grant is
--      revoked), and messages_insert_assigned no longer exists in
--      pg_policies (policies 11 -> 10).
--   3. THE BODY CHECK (privileged half): an empty body is rejected by the
--      schema CHECK even for a privileged writer, so no write path
--      (composer/RPC/seed) can ever insert a message the client's
--      Message.body (non-empty) cannot map (the 08.10 read-side twin).
--   4. DELIVERY EQUIVALENCE (D-LV3 / the matrix §6 row): after an insert,
--      a role-impersonated read under the SAME gate (messages_select_assigned,
--      08) returns the delivered row for the assigned readers (attorney +
--      client) and 0 for the suspended / cross-org / owner / stranger
--      readers — the delivery gate is the read gate (Q2). HONEST LIMIT:
--      this is the RLS proxy for live websocket delivery (postgres_changes
--      adheres to the underlying SELECT policy — the documented Realtime
--      RLS mechanism); the real channel round-trip is the env-gated client
--      slice (D-LV4, plan T7), never claimed here.
--
-- Run AFTER 00_fixtures.sql, under psql -v ON_ERROR_STOP=1, by
-- scripts/verify_policy_tests.sh (which applies 09_realtime_push.sql +
-- policies/messages_insert.sql + rpc/send_message.sql — the latter now
-- carries the D-SM3 revocation — to the rehearsal project first). Same
-- impersonation pattern as 08: set_config request.jwt.* for auth.uid().
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- Privileged-path half (runs as the connection role — postgres): the facts
-- no client role can observe because it holds no INSERT/DELETE grant.
-- ############################################################################

-- CHECK 09.01 — POS (D-LV2 enablement): the messages table is a member of
-- the supabase_realtime publication. postgres_changes can deliver messages
-- rows only because this membership exists (the 09 migration ships it).
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from pg_publication_tables
   where pubname = 'supabase_realtime'
     and schemaname = 'public'
     and tablename = 'messages';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 09.01: messages membership in supabase_realtime is %, want 1', v_cnt;
  end if;
end $$;

-- CHECK 09.02 — POS (D-LV2 / D-P0C1(b) teeth): the publication holds
-- EXACTLY the messages table — nothing else. Adding any other table to the
-- publication would trip this pin loudly (the forward-pin contract moved
-- from "live delivery absent" to "messages present + nothing else").
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from pg_publication_tables
   where pubname = 'supabase_realtime';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 09.02: supabase_realtime holds % table(s), want exactly 1 (messages)', v_cnt;
  end if;
end $$;

-- CHECK 09.10 — NEG (privileged half): the body CHECK is the mapping
-- contract — an empty body is rejected even by a privileged writer, so no
-- write path (composer/RPC/seed) can ever insert a message the client's
-- Message.body (non-empty) cannot map (the 08.10 read-side twin, applied
-- to the write surface; the RPC-path twin is 10.09).
begin;
do $$
begin
  begin
    insert into public.messages
      (id, organization_id, thread_id, author_display_name, body)
    values
      ('90000000-0000-4000-8000-00000000fff2', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'Demo attorney', '');
    raise exception 'POLICY-BATTERY FAIL 09.10: body CHECK accepted an empty body on insert';
  exception when check_violation then
    null; -- expected: CHECK rejected ''
  end;
end $$;
rollback;

-- CHECK 09.11 + 09.12 + 09.13 + 09.14 — DELIVERY EQUIVALENCE (D-LV3 /
-- matrix §6 row, privileged temp-row half): insert a temp message on
-- thread 1 (matter 1 — partner-a's assigned matter) as the privileged
-- writer, then impersonate readers under the SAME gate the Realtime RLS
-- delivery uses (messages_select_assigned). The assigned readers (partner-a
-- attorney, client-a client) see the delivered row; the suspended /
-- cross-org / owner / stranger readers see 0 — exactly the events a
-- postgres_changes channel would deliver to each (a subscription for an
-- org/matter the session no longer has access to delivers nothing). All
-- temp rows roll back.
begin;
insert into public.messages
  (id, organization_id, thread_id, author_display_name, body, created_at, updated_at)
values
  ('90000000-0000-4000-8000-00000000fff1', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'Demo attorney', 'Demo delivery-equivalence message', now(), now());

-- CHECK 09.11 — POS: the ASSIGNED attorney (partner-a, attorney on matter 1)
-- sees the delivered row — the channel fires for the authorized session.
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.messages
   where id = '90000000-0000-4000-8000-00000000fff1';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 09.11: assigned attorney did not receive the delivered message';
  end if;
end $$;

-- CHECK 09.13 — POS: the ASSIGNED client (client-a, client on matter 1)
-- sees the delivered row too — both assigned roles receive delivery.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.messages
   where id = '90000000-0000-4000-8000-00000000fff1';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 09.13: assigned client did not receive the delivered message';
  end if;
end $$;

-- CHECK 09.12 — NEG: the suspended / cross-org / owner readers each see 0 —
-- a subscription for an org/matter the session no longer has access to
-- delivers nothing (the matrix §6 row, now enforced).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select count(*) into v_cnt
    from public.messages
   where id = '90000000-0000-4000-8000-00000000fff1';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 09.12: suspended reader received the delivered message';
  end if;
end $$;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_cnt
    from public.messages
   where id = '90000000-0000-4000-8000-00000000fff1';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 09.12: cross-org reader received the delivered message';
  end if;
end $$;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt
    from public.messages
   where id = '90000000-0000-4000-8000-00000000fff1';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 09.12: platform_owner_admin received the delivered message';
  end if;
end $$;

-- CHECK 09.14 — NEG: the stranger (demo — no memberships at all) sees 0 —
-- no membership means no delivery under any assignment.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000006', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000006"}', false);
  select count(*) into v_cnt
    from public.messages
   where id = '90000000-0000-4000-8000-00000000fff1';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 09.14: stranger received the delivered message';
  end if;
end $$;
reset role;
rollback;

-- ############################################################################
-- D-SM3 revocation pins (the write surface moved to the audited RPC — the
-- INSERT-policy group that previously lived here is now 10_send_message_rls.sql).
-- ############################################################################

-- CHECK 09.15 — NEG (D-SM3, privilege layer): the authenticated INSERT
-- grant on messages is REVOKED — even the assigned attorney's raw direct
-- INSERT is now denied before RLS is ever consulted. Every write must go
-- through send_message (which re-asserts the gate + writes the audit row).
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    insert into public.messages
      (id, organization_id, thread_id, author_display_name, body)
    values
      ('90000000-0000-4000-8000-00000000fff3', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'Demo attorney', 'D-SM3 raw-insert attempt');
    raise exception 'POLICY-BATTERY FAIL 09.15: direct INSERT on messages still allowed after the D-SM3 revocation';
  exception when insufficient_privilege then
    null; -- expected: revoked grant (SQLSTATE 42501)
  end;
end $$;
reset role;

-- CHECK 09.16 — NEG (D-SM3, policy gone): messages_insert_assigned no
-- longer exists in pg_policies — the write authorization now lives only in
-- the send_message function's in-function gate (10.04–10.08 deny rows).
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from pg_policies
   where schemaname = 'public'
     and tablename = 'messages'
     and policyname = 'messages_insert_assigned';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 09.16: messages_insert_assigned still present after the D-SM3 drop';
  end if;
end $$;
