-- policies/legal_sources.sql — Legal Library source read/write policy
-- Backout: git revert of this policy commit; the table drop in
-- migrations/32_legal_library.down.sql removes it with the table.
--
-- SELECT: any AUTHENTICATED user. The library is global reference data, not
-- tenant data, so the policy deliberately does not consult `memberships` —
-- an attorney and a client of different firms read the same statute list.
-- Anon is denied at the privilege layer (no SELECT grant).
--
-- INSERT/UPDATE/DELETE: the platform owner only. Reuses is_platform_owner()
-- from migration 02, the same boundary migrations 03/27 established for
-- platform-level configuration. No client write path exists in this slice;
-- the policies exist so the boundary is declared and testable rather than
-- implied by the absence of a grant.

create policy legal_sources_select_authenticated on public.legal_sources
  for select
  to authenticated
  using (true);

create policy legal_sources_insert_platform_owner on public.legal_sources
  for insert
  to authenticated
  with check (public.is_platform_owner());

create policy legal_sources_update_platform_owner on public.legal_sources
  for update
  to authenticated
  using (public.is_platform_owner())
  with check (public.is_platform_owner());

create policy legal_sources_delete_platform_owner on public.legal_sources
  for delete
  to authenticated
  using (public.is_platform_owner());
