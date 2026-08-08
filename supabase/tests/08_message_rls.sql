-- ============================================================================
-- supabase/tests/08_message_rls.sql — realtime policy battery (T3)
-- Source: docs/realtime_rls_gate_review_2026-08-08.md §4 (the deny-rows
-- contract) + docs/realtime_real_data_plan_2026-08-08.md (D-RT1/D-RT2).
--
-- Proves `messages_select_assigned` against the matrix §4 "Read a
-- document/message body" row (line 143 — consummated here for
-- client/attorney): individual message rows are readable iff the reader is
-- an active member of the message's org AND assigned (client or attorney)
-- on the message's THREAD's matter:
--   - assigned client / assigned attorney ON THE THREAD'S MATTER, active
--     member of the thread's org -> the ONLY grant (positives + row-count
--     pins: client-a 3 [threads 1+2: 1+2], partner-a 6 [threads 1+2+3:
--     1+2+3], orphan 4 [thread 4]);
--   - org role alone (member, no matter assignment) -> deny, every role;
--   - org-mismatch (D-RT2 load-bearing three-way clause): a message whose
--     organization_id != its thread's org (which equals its matter's org)
--     denies for every role (a message is never readable when its thread
--     is not) — privileged temp-row half, NON-VACUOUS: partner-a
--     demonstrably reads messages on org-a threads (08.02 counts 6), so
--     the 08.05 deny is specifically the clause;
--   - cross-org (assigned on an org-a matter, member of org-b only) -> deny;
--   - suspended membership -> deny (stale access);
--   - platform_owner_admin (never assigned) -> deny, always (Q4 residual);
--   - unauthenticated -> deny (no grant);
--   - body CHECK (mapping contract) -> a write path cannot insert an empty
--     body (privileged-path half; the client has no INSERT grant);
--   - thread-delete cascade -> dropping the thread removes its messages
--     (FK on delete cascade), pinned in a rolled-back txn;
--   - mapping consistency (08.12): every thread's live message count equals
--     its message_count column — the seeded reality matches the metadata
--     the client renders.
--
-- Run AFTER 00_fixtures.sql, under psql -v ON_ERROR_STOP=1, by
-- scripts/verify_policy_tests.sh (which applies 08_messages.sql +
-- policies/messages.sql to the rehearsal project first). Same
-- impersonation pattern as 01/02/03/04/05/06/07: set_config
-- request.jwt.* for auth.uid().
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- Privileged-path half (runs as the connection role — postgres): the facts
-- no client role can observe because it holds no INSERT/DELETE grant.
-- ############################################################################

-- CHECK 08.10 — NEG (privileged half): the body CHECK is the mapping
-- contract — an empty body is rejected even by a privileged writer, so no
-- future write path (RPC/seed) can ever insert a message the client's
-- Message.body (non-empty) cannot map.
begin;
do $$
begin
  begin
    insert into public.messages
      (id, organization_id, thread_id, author_display_name, body)
    values
      ('90000000-0000-4000-8000-00000000ffff', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'Demo client', '');
    raise exception 'POLICY-BATTERY FAIL 08.10: body CHECK accepted an empty body';
  exception when check_violation then
    null; -- expected: CHECK rejected ''
  end;
end $$;
rollback;

-- CHECK 08.11 — POS (privileged half): thread-delete cascade — dropping the
-- thread removes its messages (FK on delete cascade), so a thread teardown
-- can never strand orphaned message rows. Deletes thread-1 (which holds
-- fixture message 1-1) so the cascade is actually exercised, not vacuous.
begin;
do $$
declare
  v_cnt bigint;
begin
  delete from public.message_threads where id = '60000000-0000-4000-8000-000000000001';
  select count(*) into v_cnt
    from public.messages
   where thread_id = '60000000-0000-4000-8000-000000000001';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 08.11: % messages survived the thread delete', v_cnt;
  end if;
end $$;
rollback;

-- CHECK 08.05 — NEG (privileged half, org-mismatch / D-RT2 load-bearing
-- three-way clause): insert a temp org-b matter assigned to partner-a, a
-- temp org-b thread on it, then a temp MESSAGE whose organization_id (org-a)
-- does NOT match its thread's org (org-b). Partner-a is an org-a member AND
-- assigned on the matter — without the three-way equality the exists would
-- grant; the clause must deny, proving "a message is never readable when
-- its thread is not" (matrix line 148). NON-VACUOUS: partner-a reads
-- messages on org-a threads generally (08.02 -> 6), so this deny is the
-- clause, not blanket non-access. All temp rows roll back.
begin;
insert into public.matters
  (id, organization_id, title, practice_area, status, assigned_attorney_id, created_at, updated_at)
values
  ('40000000-0000-4000-8000-00000000fffb', '20000000-0000-4000-8000-000000000002', 'Mismatch matter', 'civil', 'open', '10000000-0000-4000-8000-000000000002', now(), now());
insert into public.message_threads
  (id, organization_id, matter_id, title, message_count, created_at, updated_at)
values
  ('60000000-0000-4000-8000-00000000fffd', '20000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-00000000fffb', 'Mismatch thread', 1, now(), now());
insert into public.messages
  (id, organization_id, thread_id, author_display_name, body, created_at, updated_at)
values
  ('90000000-0000-4000-8000-00000000fffe', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-00000000fffd', 'Demo client', 'Mismatch message', now(), now());
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.messages
   where id = '90000000-0000-4000-8000-00000000fffe';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 08.05: org-mismatch message was readable';
  end if;
end $$;
reset role;
rollback;

set role authenticated;

-- ############################################################################
-- Positives — assigned client / assigned attorney ON THE THREAD'S MATTER,
-- active member of the thread's org (the ONLY grant, matrix §4 line 143).
-- ############################################################################

-- CHECK 08.01 — POS: client-a (org-a, client/active) sees exactly the
-- messages of its two assigned-client matters' threads (threads 1 + 2 =
-- 1 + 2 = 3) and no others.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt from public.messages;
  if v_cnt <> 3 then
    raise exception 'POLICY-BATTERY FAIL 08.01: assigned client saw % messages, want 3', v_cnt;
  end if;
end $$;

-- CHECK 08.02 — POS: partner-a (org-a, partner/active) sees exactly the
-- messages of its three assigned-attorney matters' threads (threads 1 + 2 +
-- 3 = 1 + 2 + 3 = 6) — the count proves no blanket org/thread access
-- (thread-4's messages, on the matter partner-a is not assigned to, are NOT
-- visible).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt from public.messages;
  if v_cnt <> 6 then
    raise exception 'POLICY-BATTERY FAIL 08.02: assigned attorney saw % messages, want 6', v_cnt;
  end if;
end $$;

-- CHECK 08.03 — POS: orphan (org-a, client/active) sees exactly the
-- messages of its one assigned-client matter's thread (thread 4 = 4) — a
-- row is granted by matter assignment, not by membership breadth.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  select count(*) into v_cnt from public.messages;
  if v_cnt <> 4 then
    raise exception 'POLICY-BATTERY FAIL 08.03: assigned client (orphan) saw % messages, want 4', v_cnt;
  end if;
end $$;

-- ############################################################################
-- Negatives — the matrix §4 deny rows.
-- ############################################################################

-- CHECK 08.04 — NEG (org role alone): partner-a is an ACTIVE org-a partner
-- but has NO assignment on matter-4 — its thread's messages (thread-4) are
-- denied, proving "an org role alone never grants message access" (deny for
-- every role).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.messages
   where thread_id = '60000000-0000-4000-8000-000000000004';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 08.04: org-role-alone partner read an unassigned matter''s messages';
  end if;
end $$;

-- CHECK 08.06 — NEG (cross-org): partner-b is assigned as attorney on an
-- org-a matter (5) but is an active member of org-b ONLY — membership is
-- tested against the message's org (the matter's authoritative org), so the
-- assignment grants nothing.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_cnt from public.messages;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 08.06: cross-org user saw % messages, want 0', v_cnt;
  end if;
end $$;

-- CHECK 08.07 — NEG (stale access): suspended-a is ASSIGNED as attorney on
-- matter-6 but its org-a membership is 'suspended' — is_active_member is the
-- status = 'active' rule, so the assignment grants nothing (the 02 hardening
-- guard extended to individual messages).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select count(*) into v_cnt from public.messages;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 08.07: suspended member saw % messages, want 0', v_cnt;
  end if;
end $$;

-- CHECK 08.08 — NEG (platform_owner_admin): the owner (0001) is never
-- assigned on any matter, so the thread→matter gate denies its messages
-- always. RESIDUAL (design review Q4, recorded): if an owner account were
-- ever assigned on a matter, this policy WOULD grant — the categorical
-- matrix deny is an operational invariant, not a policy guarantee; fixtures
-- never create that state.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt from public.messages;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 08.08: platform_owner_admin saw % messages, want 0', v_cnt;
  end if;
end $$;

-- CHECK 08.09 — NEG (unauthenticated): anon holds NO grant on messages (the
-- 01-pattern default-deny revoke), so a raw read is denied at the privilege
-- layer — double-denied with the null-auth.uid() policy.
set role anon;
do $$
begin
  begin
    perform count(*) from public.messages;
    raise exception 'POLICY-BATTERY FAIL 08.09: anon raw SELECT on messages succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
end $$;
set role authenticated;

-- CHECK 08.12 — POS (mapping consistency, privileged half): every thread's
-- live message count equals its message_count column — the seeded reality
-- matches the metadata the client renders (schema-as-mapping-contract; a
-- drift between the two would surface here, not silently in the UI).
begin;
do $$
declare
  v_bad bigint;
begin
  select count(*) into v_bad
    from public.message_threads t
    left join lateral (
      select count(*) as live_count from public.messages m
       where m.thread_id = t.id
    ) mc on true
   where mc.live_count is distinct from t.message_count;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 08.12: % thread(s) whose message count != message_count column', v_bad;
  end if;
end $$;
rollback;
