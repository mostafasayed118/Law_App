-- policies/approval_events.sql — approval-event read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §3
--                + docs/superpowers/plans/2026-10-22-approvals.md Task 2.
-- Backout: git revert of this policy commit; the table drop in
-- migrations/23_approvals.down.sql removes it with the table.
--
-- SELECT: an approval_events row is readable iff the reader holds an ACTIVE
-- membership in the row's organization. The event trail is append-only and
-- carries the denormalized organization_id so the policy needs no join.
--
-- No INSERT/UPDATE/DELETE policy: events are written only by the audited
-- security-definer RPCs, in the same transaction as the state change.

create policy approval_events_select_org on public.approval_events
  for select using (public.is_active_member(organization_id));
