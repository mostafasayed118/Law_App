-- policies/notifications.sql — notification-feed read policy (DRAFT — T3 artifact, NOT applied)
-- Source of truth: docs/notification_feed_scope_2026-08-11.md (D-N1..D-N7, DECIDED)
--                + docs/notification_feed_gate_review_2026-08-11.md (Q1-Q6, REVIEWED).
-- Backout: git revert of this policy commit (rollback_plan.md design §7).
--
-- SELECT: a notification METADATA row is readable iff the reader is an
-- ACTIVE MEMBER of the row's organization (the organizations-gate,
-- review Q2). Notifications are ORG METADATA, not matter content — so
-- the grant is the proven public.is_active_member(organization_id)
-- predicate (the org-audit / member surfaces posture), NOT the
-- matter-assignment exists-subquery. Concretely:
--   - every active member (client or partner) of the org reads the org's
--     feed — no role hierarchy in the feed (review Q3: "partner role
--     reads the same as any active member");
--   - cross-org denied (is_active_member tests the row's org);
--   - suspended/removed memberships never authorize (is_active_member is
--     the status = 'active' rule, 02_rls_functions);
--   - platform_owner_admin deny-ALWAYS posture (D-P0C1(a), review Q3):
--     owner accounts hold no membership by construction (the
--     single-account bound, D-P0C3), so the predicate denies — no
--     carve-out exists. RESIDUAL (recorded in the battery, the 11.08
--     mirror): if an owner account were ever granted a membership, this
--     policy WOULD grant — the categorical deny is an operational
--     invariant, not a policy guarantee; fixtures never create that state.
-- No new function surface — is_active_member is already EXECUTE-granted
-- to authenticated (R-4 grants in 02_rls_functions.sql).
-- No INSERT/UPDATE/DELETE policy: this slice is read-only (D-N2/D-N6,
-- review Q4); no read-flag RPC exists in v1 (is_read is display metadata,
-- seeded false, never mutated); no push/delivery surface at all.

create policy notifications_select_org on public.notifications
  for select
  using (
    public.is_active_member(organization_id)
  );
