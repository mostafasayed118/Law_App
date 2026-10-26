-- policies/research_runs.sql — participant-scoped research-run read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §5
--                + docs/superpowers/plans/2026-10-22-research.md Task 2
--                + docs/live_apply_2026-10-24_audit_remediation.md
-- Backout: restore the pre-27 org-member predicate (see the live-apply doc).
--
-- SELECT: a research_runs row is readable iff the reader holds an ACTIVE
-- membership in the run's organization AND is the requester, a partner, or a
-- reader of the linked matter (assigned client/attorney, creator, or
-- partner). The list surface goes through list_research_runs, which
-- re-asserts the same participant gate server-side.
--
-- No INSERT/UPDATE/DELETE policy: mutations are RPC-only (spec §1 principle
-- 1). Starting requires attorney/partner; completion is service-role only.

drop policy if exists research_runs_select_org on public.research_runs;

create policy research_runs_select_org on public.research_runs
  for select
  using (
    public.is_active_member(organization_id)
    and (
      requested_by = auth.uid()
      or public.has_org_role(organization_id, 'partner')
      or public.can_read_matter(matter_id, organization_id)
    )
  );
