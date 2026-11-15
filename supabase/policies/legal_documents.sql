-- policies/legal_documents.sql — Legal Library document read/write policy
-- Backout: git revert of this policy commit; the table drop in
-- migrations/32_legal_library.down.sql removes it with the table.
--
-- SELECT: any AUTHENTICATED user (global reference data, no membership test).
-- INSERT/UPDATE/DELETE: the platform owner only, via is_platform_owner().
-- Anon holds no SELECT grant, so the policy is never reached by anon traffic.

create policy legal_documents_select_authenticated on public.legal_documents
  for select
  to authenticated
  using (true);

create policy legal_documents_insert_platform_owner on public.legal_documents
  for insert
  to authenticated
  with check (public.is_platform_owner());

create policy legal_documents_update_platform_owner on public.legal_documents
  for update
  to authenticated
  using (public.is_platform_owner())
  with check (public.is_platform_owner());

create policy legal_documents_delete_platform_owner on public.legal_documents
  for delete
  to authenticated
  using (public.is_platform_owner());
