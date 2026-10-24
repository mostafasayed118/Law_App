-- policies/approval_requests.sql — participant-scoped approval read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §3
--                + docs/superpowers/plans/2026-10-22-approvals.md Task 2
--                + docs/live_apply_2026-10-24_audit_remediation.md
-- Backout: restore the pre-27 org-member predicate (see the live-apply doc).
--
-- SELECT: an approval_requests row is readable iff the reader holds an ACTIVE
-- membership in the row's organization AND is a partner, the requester, the
-- decider, or a reader of the linked matter (assigned client/attorney,
-- creator, or partner). An org role alone no longer exposes another member's
-- request. The list surface goes through list_approval_requests, which
-- re-asserts the same participant gate server-side.
--
-- No INSERT/UPDATE/DELETE policy: mutations are RPC-only from day one
-- (spec §1 principle 1). Decision authority stays partner-only inside
-- decide_approval_request.

drop policy if exists approval_requests_select_org on public.approval_requests;

create policy approval_requests_select_org on public.approval_requests
  for select
  using (
    public.is_active_member(organization_id)
    and (
      public.has_org_role(organization_id, 'partner')
      or requested_by = auth.uid()
      or decided_by = auth.uid()
      or public.can_read_matter(matter_id, organization_id)
    )
  );
