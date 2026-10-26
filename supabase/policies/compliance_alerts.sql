-- policies/compliance_alerts.sql — participant-scoped alert read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §4
--                + docs/superpowers/plans/2026-10-22-compliance.md Task 2
--                + docs/live_apply_2026-10-24_audit_remediation.md
-- Backout: restore the pre-27 org-member predicate (see the live-apply doc).
--
-- SELECT: a compliance_alerts row is readable iff the reader holds an ACTIVE
-- membership in the row's organization AND is a partner,
-- a compliance_officer, the creator, or a reader of the linked matter
-- (assigned client/attorney, creator, or partner). An org role alone no
-- longer exposes another member's alert. The list surface goes through
-- list_compliance_alerts, which re-asserts the same participant gate
-- server-side.
--
-- No INSERT/UPDATE/DELETE policy: mutations are RPC-only from day one
-- (spec §1 principle 1). Create/resolve authority stays partner/
-- compliance_officer inside the RPCs.

drop policy if exists compliance_alerts_select_org on public.compliance_alerts;

create policy compliance_alerts_select_org on public.compliance_alerts
  for select
  using (
    public.is_active_member(organization_id)
    and (
      public.has_org_role(organization_id, 'partner')
      or public.has_org_role(organization_id, 'compliance_officer')
      or created_by = auth.uid()
      or public.can_read_matter(matter_id, organization_id)
    )
  );
