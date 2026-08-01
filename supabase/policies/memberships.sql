-- policies/memberships.sql — P2 reviewed policy (REVIEWED, NOT APPLIED)
-- Source of truth: docs/p2_schema_rls_design.md §5.2 (gate-approved).
-- Backout: git revert of this policy commit (design §7).
--
-- SELECT: members see their org's roster; own row always visible. The roster
-- branch is gated on active membership of THAT org (tenant isolation).
-- No INSERT/UPDATE/DELETE: role/status changes go through partner/owner RPCs
-- with audit (D-06). The client can never write role/status/created_by.

create policy memberships_select_org_roster on public.memberships
  for select
  using (public.is_active_member(organization_id) or auth.uid() = user_id);
