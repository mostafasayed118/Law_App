-- ============================================================================
-- supabase/tests/14_notification_rls.sql — notification-feed policy battery (T3)
-- Source: docs/notification_feed_gate_review_2026-08-11.md §3 Q2/Q3/Q6 (the
-- deny-rows contract) + docs/notification_feed_scope_2026-08-11.md
-- (D-N1..D-N7) + docs/notification_feed_slice_plan_2026-08-11.md §4.
--
-- Proves `notifications_select_org` (the organizations-gate — org
-- METADATA, not matter content, review Q2) against the matrix §4
-- "View notifications (metadata)" cell split (review Q3):
--   - every ACTIVE MEMBER of the org (partner AND client — the
--     no-role-hierarchy pin) -> the ONLY grant (positive count pins:
--     partner-a 6, client-a 6, partner-b 1 — org scoping by count;
--     RE-PINNED for the producer slice, D-P6: battery 10's two committed
--     sends produce exactly 2 org-a producer rows before this battery
--     runs — 4+2=6 — battery 13's creates are rolled back, org-b
--     untouched);
--   - cross-org (member of org-b only) -> org-a rows denied (count pin);
--   - non-member / platform_owner_admin (owner 0001, no membership by
--     construction, D-P0C3) -> denied, always (D-P0C1(a) deny-always);
--   - suspended membership -> denied (stale access, is_active_member =
--     the status = 'active' rule);
--   - unauthenticated -> denied (no grant);
--   - category CHECK (D-N4 mapping contract) -> a producer cannot insert
--     an unmapped category (privileged-path half; no client INSERT grant
--     exists at all);
--   - org-delete cascade -> dropping the org removes its notifications
--     (FK on delete cascade), pinned in a rolled-back txn.
-- D-N3 structural note: the battery asserts READ behavior only — the
-- table carries NO user-identity / content / raw-text columns at all
-- (redaction is structural, review Q1), so no check can ever touch PII.
-- No write cells exist in v1 (D-N2/D-N6, review Q4) — there is nothing
-- to test for INSERT/UPDATE/DELETE beyond the privilege absence (anon).
--
-- Run AFTER 00_fixtures.sql, under psql -v ON_ERROR_STOP=1, by
-- scripts/verify_policy_tests.sh (which applies 14_notifications.sql +
-- policies/notifications.sql to the rehearsal project first). Same
-- impersonation pattern as 01/02/03/04/05/10/11: set_config
-- request.jwt.* for auth.uid().
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- Privileged-path half (runs as the connection role — postgres): the facts
-- no client role can observe because it holds no INSERT/DELETE grant.
-- ############################################################################

-- CHECK 14.08 — NEG (privileged half): the category CHECK is the D-N4
-- mapping contract — an unmapped category is rejected even by a privileged
-- writer, so no future producer slice (seed/RPC) can ever insert a
-- category the client's Notification.category enum cannot render.
begin;
do $$
begin
  begin
    insert into public.notifications
      (id, organization_id, category, type, summary, server_timestamp, is_read)
    values
      ('b0000000-0000-4000-8000-00000000ffff', '20000000-0000-4000-8000-000000000001', 'urgent', 'matter_updated', 'Bad category', now(), false);
    raise exception 'POLICY-BATTERY FAIL 14.08: category CHECK accepted an unmapped value';
  exception when check_violation then
    null; -- expected: CHECK rejected 'urgent'
  end;
end $$;
rollback;

-- CHECK 14.09 — POS (privileged half): org-delete cascade — dropping the
-- organization removes its notifications (FK on delete cascade), so an org
-- teardown can never strand orphaned notification rows. Uses a TEMP org +
-- temp notification so the cascade is actually exercised without touching
-- the seeded org-a/org-b baseline (the 11.12 pattern, adapted to the
-- notifications org-FK).
begin;
do $$
declare
  v_org uuid := '20000000-0000-4000-8000-00000000fffe';
  v_cnt bigint;
begin
  insert into public.organizations (id, name, created_at)
  values (v_org, 'Cascade Temp Org', now());
  insert into public.notifications
    (id, organization_id, category, type, summary, server_timestamp, is_read)
  values
    ('b0000000-0000-4000-8000-00000000fff1', v_org, 'system', 'system_maintenance', 'Cascade temp notification', now(), false);
  delete from public.organizations where id = v_org;
  select count(*) into v_cnt
    from public.notifications
   where organization_id = v_org;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 14.09: % notifications survived the org delete', v_cnt;
  end if;
end $$;
rollback;

-- CHECK 14.10 — POS (privileged half, structural): the redaction posture is
-- STRUCTURAL (review Q1, the D-BI1 mirror) — the table's column inventory is
-- EXACTLY id, organization_id, category, type, summary, server_timestamp,
-- is_read. No user-identity column, no content column, no raw-text column
-- can ever be added without this pin failing first: the D-N3 redaction
-- constraint is enforced by schema, not by producer discipline.
begin;
do $$
declare
  v_cols text := '';
begin
  select string_agg(column_name, ',' order by column_name)
    into v_cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'notifications';
  if v_cols <> 'category,id,is_read,organization_id,server_timestamp,summary,type' then
    raise exception 'POLICY-BATTERY FAIL 14.10: notifications columns changed — got %, want the redacted-metadata set exactly', v_cols;
  end if;
end $$;
rollback;

set role authenticated;

-- ############################################################################
-- Positives — every ACTIVE MEMBER of the org reads the org's feed (the ONLY
-- grant, review Q2/Q3). The count pins prove org scoping BY COUNT: org-a
-- rows are invisible to org-b members and vice versa.
-- ############################################################################

-- CHECK 14.01 — POS: partner-a (org-a, partner/active) sees exactly its
-- six org-a notifications (4 seeded + 2 producer rows from battery 10's
-- committed sends — the D-P6 re-pin) and no org-b rows — the
-- organizations-gate grants by membership, not by role breadth.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt from public.notifications;
  if v_cnt <> 6 then
    raise exception 'POLICY-BATTERY FAIL 14.01: org-a partner saw % notifications, want 6', v_cnt;
  end if;
end $$;

-- CHECK 14.02 — POS: client-a (org-a, client/active) sees exactly the same
-- six org-a rows (4 seeded + 2 producer rows — the D-P6 re-pin) — the
-- no-role-hierarchy pin (review Q3: "partner role reads the same as any
-- active member"; there is no role hierarchy in the feed).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt from public.notifications;
  if v_cnt <> 6 then
    raise exception 'POLICY-BATTERY FAIL 14.02: org-a client saw % notifications, want 6', v_cnt;
  end if;
end $$;

-- CHECK 14.03 — POS: partner-b (org-b, partner/active) sees exactly its one
-- org-b notification — the org-scoping pin: org-a rows are invisible to
-- him even though he is an active member of org-b (and is assigned as
-- attorney on an org-a matter — assignment grants NOTHING on the feed,
-- review Q2: the feed is org metadata, not matter content).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_cnt from public.notifications;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 14.03: org-b partner saw % notifications, want 1', v_cnt;
  end if;
end $$;

-- ############################################################################
-- Negatives — the matrix §4 deny rows.
-- ############################################################################

-- CHECK 14.04 — NEG (cross-org, count-scoped): partner-b (org-b member
-- ONLY) reads the org-a rows explicitly — is_active_member tests the row's
-- org (org-a, where he holds no membership), so every org-a row is denied.
-- The count-scope makes the denial non-vacuous (there ARE org-a rows to
-- miss; 14.01 proved he cannot see them by total count, this check proves
-- the org-a subset specifically).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_cnt
    from public.notifications
   where organization_id = '20000000-0000-4000-8000-000000000001';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 14.04: cross-org member saw % org-a notifications, want 0', v_cnt;
  end if;
end $$;

-- CHECK 14.05 — NEG (platform_owner_admin deny-ALWAYS / non-member): the
-- owner (0001) holds NO membership in any org (the single-account bound,
-- D-P0C3 — the platform_config owner row is not a membership), so
-- is_active_member denies every row. RESIDUAL (design review Q3, the 11.08
-- mirror, recorded): if an owner account were ever granted a membership,
-- this policy WOULD grant — the categorical deny is an operational
-- invariant (fixtures never create that state), not a policy guarantee.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt from public.notifications;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 14.05: platform_owner_admin saw % notifications, want 0', v_cnt;
  end if;
end $$;

-- CHECK 14.06 — NEG (stale access): suspended-a is an org-a MEMBER but its
-- membership status is 'suspended' — is_active_member is the status =
-- 'active' rule (02_rls_functions), so membership alone grants nothing; a
-- suspended member's stale access to the org feed is denied.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select count(*) into v_cnt from public.notifications;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 14.06: suspended member saw % notifications, want 0', v_cnt;
  end if;
end $$;

-- CHECK 14.07 — NEG (unauthenticated): anon holds NO grant on
-- public.notifications (the 01-pattern default-deny revoke), so a raw read
-- is denied at the privilege layer — double-denied with the null-auth.uid()
-- policy.
set role anon;
do $$
begin
  begin
    perform count(*) from public.notifications;
    raise exception 'POLICY-BATTERY FAIL 14.07: anon raw SELECT on notifications succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
end $$;
set role authenticated;
