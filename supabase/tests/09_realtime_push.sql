-- ============================================================================
-- supabase/tests/09_realtime_push.sql — realtime live-delivery battery (T3)
-- Source: docs/realtime_push_gate_review_2026-08-08.md §4 (the deny-rows
-- contract) + docs/realtime_push_real_data_plan_2026-08-08.md (D-LV1/D-LV2/
-- D-LV5).
--
-- Proves the live-delivery slice's two-layer mechanism:
--   1. PUBLICATION MEMBERSHIP (D-LV2 — the ENABLEMENT layer): exactly the
--      messages table sits in the supabase_realtime publication — count 1
--      for messages, and the publication holds nothing else. postgres_changes
--      can only deliver rows of a published table; the pin keeps D-P0C1(b)
--      teeth (no accidental table exposure via realtime).
--   2. THE INSERT POLICY (D-LV1 — the event source): `messages_insert_assigned`
--      is the write gate — a row may be inserted iff the writer is an ACTIVE
--      MEMBER of the row's org AND exists through thread → matter with the
--      THREE-WAY org equality AND is assigned (client or attorney) on the
--      matter. Deny rows pinned here:
--        - assigned attorney / assigned client on the THREAD'S MATTER -> the
--          ONLY grant (positives: partner-a + client-a on thread 1 / matter 1);
--        - org role alone (member, no assignment on that matter) -> deny;
--        - cross-org (assigned on an org-a matter, member of org-b only) ->
--          deny (is_active_member tests the message's org);
--        - suspended membership -> deny (stale access);
--        - platform_owner_admin -> deny, always (never assigned, Q5);
--        - unauthenticated -> deny (no INSERT grant);
--        - empty body -> the schema CHECK rejects it even for a privileged
--          writer (privileged-path half; the client has no DELETE grant).
--   3. DELIVERY EQUIVALENCE (D-LV3 / the matrix §6 row): after an insert,
--      a role-impersonated read under the SAME gate (messages_select_assigned,
--      08) returns the delivered row for the assigned reader and 0 for the
--      suspended / cross-org / owner reader — the delivery gate is the read
--      gate (Q2). HONEST LIMIT: this is the RLS proxy for live websocket
--      delivery (postgres_changes adheres to the underlying SELECT policy —
--      the documented Realtime RLS mechanism); the real channel round-trip
--      is the env-gated client slice (D-LV4, plan T7), never claimed here.
--
-- Run AFTER 00_fixtures.sql, under psql -v ON_ERROR_STOP=1, by
-- scripts/verify_policy_tests.sh (which applies 09_realtime_push.sql +
-- policies/messages_insert.sql to the rehearsal project first). Same
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
-- to the write surface).
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

-- CHECK 09.11 + 09.12 — DELIVERY EQUIVALENCE (D-LV3 / matrix §6 row,
-- privileged temp-row half): insert a temp message on thread 1 (matter 1 —
-- partner-a's assigned matter) as the privileged writer, then impersonate
-- readers under the SAME gate the Realtime RLS delivery uses
-- (messages_select_assigned). The assigned reader (partner-a) sees the
-- delivered row; the suspended / cross-org / owner readers see 0 — exactly
-- the events a postgres_changes channel would deliver to each (a
-- subscription for an org/matter the session no longer has access to
-- delivers nothing). All temp rows roll back.
begin;
insert into public.messages
  (id, organization_id, thread_id, author_display_name, body, created_at, updated_at)
values
  ('90000000-0000-4000-8000-00000000fff1', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'Demo attorney', 'Demo delivery-equivalence message', now(), now());

-- CHECK 09.11 — POS: the ASSIGNED reader (partner-a, attorney on matter 1)
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
    raise exception 'POLICY-BATTERY FAIL 09.11: assigned reader did not receive the delivered message';
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
reset role;
rollback;

set role authenticated;

-- ############################################################################
-- INSERT positives — assigned attorney / assigned client ON THE THREAD'S
-- MATTER, active member of the row's org (the ONLY grant, D-LV1).
-- ############################################################################

-- CHECK 09.03 — POS: partner-a (org-a, partner/active, assigned attorney on
-- matter 1) inserts a message on thread 1 (matter 1) — the WITH CHECK passes
-- and the row persists. Rolled back so the seeded 21-message baseline and
-- the 08 mapping-consistency pin stay intact.
begin;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  insert into public.messages
    (id, organization_id, thread_id, author_display_name, body)
  values
    ('90000000-0000-4000-8000-00000000fff3', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'Demo attorney', 'Demo live-delivery message');
  select count(*) into v_cnt
    from public.messages
   where id = '90000000-0000-4000-8000-00000000fff3';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 09.03: assigned attorney insert did not persist';
  end if;
end $$;
rollback;

-- CHECK 09.04 — POS: client-a (org-a, client/active, assigned client on
-- matter 1) inserts on the same thread — the client side of the write gate.
begin;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  insert into public.messages
    (id, organization_id, thread_id, author_display_name, body)
  values
    ('90000000-0000-4000-8000-00000000fff4', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'Demo client', 'Demo live-delivery message');
  select count(*) into v_cnt
    from public.messages
   where id = '90000000-0000-4000-8000-00000000fff4';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 09.04: assigned client insert did not persist';
  end if;
end $$;
rollback;

-- ############################################################################
-- INSERT negatives — the matrix §4 write-row deny rows.
-- ############################################################################

-- CHECK 09.05 — NEG (org role alone): partner-a is an ACTIVE org-a partner
-- but has NO assignment on matter 4 — inserting on thread 4 (its thread)
-- is denied, proving "an org role alone never grants the write" (deny for
-- every role; mirrors 08.04 on the write surface).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    insert into public.messages
      (id, organization_id, thread_id, author_display_name, body)
    values
      ('90000000-0000-4000-8000-00000000fff5', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000004', 'Demo partner', 'Org-role-alone write attempt');
    raise exception 'POLICY-BATTERY FAIL 09.05: org-role-alone insert succeeded';
  exception when insufficient_privilege then
    null; -- expected: RLS violation (SQLSTATE 42501)
  end;
end $$;

-- CHECK 09.06 — NEG (cross-org): partner-b is assigned as attorney on an
-- org-a matter (5) but is an ACTIVE member of org-b ONLY — is_active_member
-- tests the message's org (org-a), so the assignment grants nothing on the
-- write path either (mirrors 08.06).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    insert into public.messages
      (id, organization_id, thread_id, author_display_name, body)
    values
      ('90000000-0000-4000-8000-00000000fff6', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000005', 'Demo partner', 'Cross-org write attempt');
    raise exception 'POLICY-BATTERY FAIL 09.06: cross-org insert succeeded';
  exception when insufficient_privilege then
    null; -- expected: RLS violation
  end;
end $$;

-- CHECK 09.07 — NEG (stale access): suspended-a IS assigned as attorney on
-- matter 6 but its org-a membership is 'suspended' — is_active_member is the
-- status = 'active' rule, so the assignment grants nothing on the write
-- path (mirrors 08.07).
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  begin
    insert into public.messages
      (id, organization_id, thread_id, author_display_name, body)
    values
      ('90000000-0000-4000-8000-00000000fff7', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000006', 'Demo counsel', 'Stale-access write attempt');
    raise exception 'POLICY-BATTERY FAIL 09.07: suspended insert succeeded';
  exception when insufficient_privilege then
    null; -- expected: RLS violation
  end;
end $$;

-- CHECK 09.08 — NEG (platform_owner_admin): the owner (0001) is never
-- assigned on any matter, so the thread→matter gate denies its inserts
-- always. RESIDUAL (design review Q5, recorded): if an owner account were
-- ever assigned on a matter, this policy WOULD grant — the categorical
-- matrix deny is an operational invariant, not a policy guarantee; fixtures
-- never create that state.
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    insert into public.messages
      (id, organization_id, thread_id, author_display_name, body)
    values
      ('90000000-0000-4000-8000-00000000fff8', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'Demo owner', 'Owner write attempt');
    raise exception 'POLICY-BATTERY FAIL 09.08: platform_owner_admin insert succeeded';
  exception when insufficient_privilege then
    null; -- expected: RLS violation
  end;
end $$;

-- CHECK 09.09 — NEG (unauthenticated): anon holds NO INSERT grant on
-- messages (09's grant is to authenticated only), so a raw insert is denied
-- at the privilege layer — double-denied with the null-auth.uid() policy.
set role anon;
do $$
begin
  begin
    insert into public.messages
      (id, organization_id, thread_id, author_display_name, body)
    values
      ('90000000-0000-4000-8000-00000000fff9', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'Demo anon', 'Anon write attempt');
    raise exception 'POLICY-BATTERY FAIL 09.09: anon raw INSERT on messages succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
end $$;
set role authenticated;
