-- policies/compliance_alert_events.sql — parent-gated alert-event read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §4
--                + docs/superpowers/plans/2026-10-22-compliance.md Task 2
--                + docs/live_apply_2026-10-24_audit_remediation.md
-- Backout: restore the pre-27 org-member predicate (see the live-apply doc).
--
-- SELECT: an event row is readable only when its parent alert is readable
-- under compliance_alerts_select_org. Events are append-only and are written
-- only by the audited RPCs in the same transaction as the state change;
-- there is no client write grant. The participant gate is the parent row's,
-- so an unrelated active member cannot read the trail of an alert they cannot
-- read.

drop policy if exists compliance_alert_events_select_org on public.compliance_alert_events;

create policy compliance_alert_events_select_org on public.compliance_alert_events
  for select
  using (
    exists (
      select 1
        from public.compliance_alerts a
       where a.id = compliance_alert_events.alert_id
         and a.organization_id = compliance_alert_events.organization_id
         and public.is_active_member(a.organization_id)
         and (
           public.has_org_role(a.organization_id, 'partner')
           or public.has_org_role(a.organization_id, 'compliance_officer')
           or a.created_by = auth.uid()
           or public.can_read_matter(a.matter_id, a.organization_id)
         )
    )
  );
