-- policies/compliance_alert_events.sql — alert-event read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §4
--                + docs/superpowers/plans/2026-10-22-compliance.md Task 2.
-- Backout: git revert of this policy commit; the table drop in
-- migrations/24_compliance_alerts.down.sql removes it with the table.
--
-- SELECT: an event row is readable iff the reader holds an ACTIVE membership
-- in the event's organization (the same gate as its parent alert). Events are
-- append-only and are written only by the audited RPCs in the same
-- transaction as the state change; there is no client write grant.

create policy compliance_alert_events_select_org on public.compliance_alert_events
  for select using (public.is_active_member(organization_id));
