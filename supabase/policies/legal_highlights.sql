-- policies/legal_highlights.sql — per-user highlight read policy
-- Backout: git revert of this policy commit; the table drop in
-- migrations/33_library_user_data.down.sql removes it with the table.
--
-- SELECT: own rows only. A highlight is a reader's private annotation, so the
-- policy has no owner carve-out and no cross-user path at all.
--
-- No write policy and no write grant: create/update/delete are the three RPCs in
-- migration 33, each of which derives the caller from auth.uid() and never
-- accepts a user id parameter.

create policy legal_highlights_select_own on public.legal_highlights
  for select
  to authenticated
  using (user_id = auth.uid());
