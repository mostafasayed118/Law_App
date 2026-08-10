-- policies/matters.sql — matters read policy (REVIEWED & APPLIED — dev project, 2026-08-07)
-- Source of truth: docs/matters_real_data_plan_2026-08-07.md (D-MR1)
--                + docs/matters_rls_gate_review_2026-08-07.md (§4 deny-rows).
-- Backout: git revert of this policy commit (rollback_plan.md design §7).
--
-- SELECT: a matter row is readable iff the reader is an ACTIVE MEMBER of the
-- matter's organization AND is the assigned client or assigned attorney.
-- This enforces the matrix §4 contract exactly:
--   - "org role alone (no matter assignment)"  -> deny, every role (no
--     assignment match -> false);
--   - cross-org denied (membership is tested against THIS org, via
--     is_active_member(organization_id));
--   - suspended/removed memberships never authorize (is_active_member is
--     the status = 'active' rule, 02_rls_functions);
--   - platform_owner_admin denied, always (owner accounts are never
--     assigned; no carve-out exists, Q4).
-- Uses the existing self-scoped is_active_member() helper — already
-- EXECUTE-granted to authenticated (R-4 grants in 02_rls_functions.sql), so
-- no new function grant is introduced.
-- No INSERT/UPDATE/DELETE policy: this slice is read-only (Q5).

create policy matters_select_assigned on public.matters
  for select
  using (
    public.is_active_member(organization_id)
    and (assigned_client_id = auth.uid() or assigned_attorney_id = auth.uid())
  );
