-- policies/research_runs.sql — research-run read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §5
--                + docs/superpowers/plans/2026-10-22-research.md Task 2.
-- Backout: git revert of this policy commit; the table drop in
-- migrations/25_research.down.sql removes it with the table.
--
-- SELECT: a research_runs row is readable iff the reader holds an ACTIVE
-- membership in the run's organization. The list surface also goes through
-- list_research_runs, which re-asserts the same gate server-side.
--
-- No INSERT/UPDATE/DELETE policy: mutations are RPC-only (spec §1 principle
-- 1). Starting requires attorney/partner; completion is service-role only.

create policy research_runs_select_org on public.research_runs
  for select using (public.is_active_member(organization_id));
