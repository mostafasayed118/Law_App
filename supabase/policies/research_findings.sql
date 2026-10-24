-- policies/research_findings.sql — run-gated research-findings read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §5
--                + docs/superpowers/plans/2026-10-22-research.md Task 2
--                + docs/live_apply_2026-10-24_audit_remediation.md
-- Backout: restore the pre-27 org-member predicate (see the live-apply doc).
--
-- SELECT: a research_findings row is readable only when its parent run is
-- readable by the same participant rule as research_runs_select_org
-- (requester, partner, or matter reader). The finding's organization_id is
-- copied from its run, and the explicit organization match keeps the parent
-- lookup scoped to the finding's own org. The list surface goes through
-- list_research_findings, which re-asserts the same run gate server-side.
--
-- No INSERT/UPDATE/DELETE policy: findings are written only by the
-- service-role-only complete_research_run RPC.

drop policy if exists research_findings_select_org on public.research_findings;

create policy research_findings_select_org on public.research_findings
  for select
  using (
    public.is_active_member(organization_id)
    and exists (
      select 1
        from public.research_runs r
       where r.id = research_findings.run_id
         and r.organization_id = research_findings.organization_id
         and (
           r.requested_by = auth.uid()
           or public.has_org_role(organization_id, 'partner')
           or public.can_read_matter(r.matter_id, r.organization_id)
         )
    )
  );
