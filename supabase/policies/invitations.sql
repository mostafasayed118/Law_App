-- policies/invitations.sql — P2 reviewed policy (REVIEWED, NOT APPLIED)
-- Source of truth: docs/p2_schema_rls_design.md §5.2 (gate-approved).
-- Backout: git revert of this policy commit (design §7).
--
-- SELECT: partner of the org sees its invites (matrix §3 "Resend / revoke a
-- pending invite" requires partner to view them). No INSERT/UPDATE/DELETE:
-- invite/resend/revoke all go through partner-gated RPCs with audit (D-10a).

create policy invitations_select_partner on public.invitations
  for select
  using (public.has_org_role(organization_id, 'partner'));
