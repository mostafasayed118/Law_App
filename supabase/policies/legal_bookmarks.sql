-- policies/legal_bookmarks.sql — per-user bookmark read policy
-- Backout: git revert of this policy commit; the table drop in
-- migrations/33_library_user_data.down.sql removes it with the table.
--
-- SELECT: a bookmark is readable iff it belongs to the caller. There is no
-- organization scope and NO platform-owner carve-out: reading another person's
-- saved articles is a privacy breach, not administration.
--
-- No INSERT/UPDATE/DELETE policy and no write grant: every mutation is an RPC
-- (toggle_legal_bookmark), so a direct client write fails at the privilege
-- layer before any policy is consulted.

create policy legal_bookmarks_select_own on public.legal_bookmarks
  for select
  to authenticated
  using (user_id = auth.uid());
