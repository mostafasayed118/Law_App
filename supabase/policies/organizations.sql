-- policies/organizations.sql — P2 reviewed policy (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Source of truth: docs/p2_schema_rls_design.md §5.2 (gate-approved).
-- Backout: git revert of this policy commit (design §7).
--
-- SELECT only for active members of that org. The org id is resolved from
-- the authenticated membership via active_membership(org) — never from a
-- client-supplied value (tenant isolation rule, contract §2 #3).
-- No INSERT (create_organization RPC owns creation, D-08), no UPDATE/DELETE
-- (not MVP actions).

create policy organizations_select_active_member on public.organizations
  for select
  using (public.is_active_member(id));
