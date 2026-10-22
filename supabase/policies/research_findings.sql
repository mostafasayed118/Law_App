-- policies/research_findings.sql — research-findings read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §5
--                + docs/superpowers/plans/2026-10-22-research.md Task 2.
-- Backout: git revert of this policy commit; the table drop in
-- migrations/25_research.down.sql removes it with the table.
--
-- SELECT: a research_findings row is readable iff the reader holds an ACTIVE
-- membership in the finding's organization (copied from its run). The list
-- surface also goes through list_research_findings, which gates on the
-- run's organization server-side.
--
-- No INSERT/UPDATE/DELETE policy: findings are written only by the
-- service-role-only complete_research_run RPC.

create policy research_findings_select_org on public.research_findings
  for select using (public.is_active_member(organization_id));
