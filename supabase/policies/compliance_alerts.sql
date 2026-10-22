-- policies/compliance_alerts.sql — compliance-alert read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §4
--                + docs/superpowers/plans/2026-10-22-compliance.md Task 2.
-- Backout: git revert of this policy commit; the table drop in
-- migrations/24_compliance_alerts.down.sql removes it with the table.
--
-- SELECT: a compliance_alerts row is readable iff the reader holds an ACTIVE
-- membership in the row's organization. The list surface also goes through
-- list_compliance_alerts, which re-asserts the same gate server-side.
--
-- No INSERT/UPDATE/DELETE policy: mutations are RPC-only from day one
-- (spec §1 principle 1). The policy deliberately has no role carve-out —
-- every active member of the org reads the alert queue, while create/resolve
-- authority stays partner/compliance_officer inside the RPCs.

create policy compliance_alerts_select_org on public.compliance_alerts
  for select using (public.is_active_member(organization_id));
