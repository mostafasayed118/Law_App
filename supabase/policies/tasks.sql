-- policies/tasks.sql — task-board read policy (NOT APPLIED — rehearsal only)
-- Source of truth: task/approval-writes Gate 3 spec (2026-09-27).
-- Backout: git revert of this policy commit (rollback_plan.md design §7).
--
-- SELECT: a task row is readable iff the reader is an ACTIVE MEMBER of the
-- task's organization AND is assigned (client or attorney) on the task's
-- MATTER. The messages policy (policies/messages.sql) extended one hop
-- (thread -> matter); this one anchors DIRECTLY on the matter (task ->
-- matter is a single hop), so the exists subquery is shorter but the
-- contract is identical:
--   - the THREE-WAY shape is two-way here (tasks.organization_id =
--     m.organization_id — the org gate comes from the matter's
--     AUTHORITATIVE org, never the denormalized column, so a task is never
--     readable when its matter is not; the org-mismatch battery row pins
--     it);
--   - "org role alone (no matter assignment)" -> deny, every role;
--   - cross-org denied (is_active_member tests the task's org, and the
--     exists requires the task's org to MATCH the matter's org);
--   - suspended/removed memberships never authorize (is_active_member is
--     the status = 'active' rule, 02_rls_functions);
--   - platform_owner_admin denied, always (owner accounts are never
--     assigned; no carve-out exists — the F-01 invariant, pinned by
--     battery 12.11 for the new assignee_id column).
-- No new function surface — is_active_member is already EXECUTE-granted to
-- authenticated (R-4 grants in 02_rls_functions.sql). No INSERT/UPDATE/
-- DELETE policy: mutations are RPC-only from day one (the D-SM3 posture —
-- no direct-INSERT grant is ever issued, so no revocation slice is needed).

create policy tasks_select_assigned on public.tasks
  for select
  using (
    public.is_active_member(organization_id)
    and exists (
      select 1
      from public.matters m
      where m.id = tasks.matter_id
        and tasks.organization_id = m.organization_id
        and (
          m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid()
        )
    )
  );
