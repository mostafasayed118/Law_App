-- policies/approval_requests.sql — approval-request read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §3
--                + docs/superpowers/plans/2026-10-22-approvals.md Task 2.
-- Backout: git revert of this policy commit; the table drop in
-- migrations/23_approvals.down.sql removes it with the table.
--
-- SELECT: an approval_requests row is readable iff the reader holds an ACTIVE
-- membership in the row's organization. The list surface also goes through
-- list_approval_requests, which re-asserts the same gate server-side.
--
-- No INSERT/UPDATE/DELETE policy: mutations are RPC-only from day one
-- (spec §1 principle 1). The policy deliberately has no partner carve-out —
-- every active member of the org reads the queue, while decision authority
-- stays partner-only inside decide_approval_request.

create policy approval_requests_select_org on public.approval_requests
  for select using (public.is_active_member(organization_id));
