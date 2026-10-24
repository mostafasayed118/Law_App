-- policies/approval_events.sql — parent-gated approval-event read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §3
--                + docs/superpowers/plans/2026-10-22-approvals.md Task 2
--                + docs/live_apply_2026-10-24_audit_remediation.md
-- Backout: restore the pre-27 org-member predicate (see the live-apply doc).
--
-- SELECT: an approval_events row is readable only when its parent request is
-- readable under approval_requests_select_org. The event trail is append-only
-- and carries the denormalized organization_id, but the participant gate is
-- the parent row's, so an unrelated active member cannot read the events of a
-- request they cannot read.
--
-- No INSERT/UPDATE/DELETE policy: events are written only by the audited
-- security-definer RPCs, in the same transaction as the state change.

drop policy if exists approval_events_select_org on public.approval_events;

create policy approval_events_select_org on public.approval_events
  for select
  using (
    exists (
      select 1
        from public.approval_requests r
       where r.id = approval_events.request_id
         and r.organization_id = approval_events.organization_id
         and public.is_active_member(r.organization_id)
         and (
           public.has_org_role(r.organization_id, 'partner')
           or r.requested_by = auth.uid()
           or r.decided_by = auth.uid()
           or public.can_read_matter(r.matter_id, r.organization_id)
         )
    )
  );
