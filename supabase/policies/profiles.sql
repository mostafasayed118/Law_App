-- policies/profiles.sql — P2 reviewed policy (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Source of truth: docs/p2_schema_rls_design.md §5.2 (gate-approved).
-- Backout: git revert of this policy commit (design §7).
--
-- Own-row only (matrix §2). No INSERT (signup trigger owns creation), no
-- DELETE (delete_my_account RPC owns removal, D-05). No authority fields
-- updatable: the grant in 01 limits UPDATE to (display_name, locale).

create policy profiles_select_own on public.profiles
  for select
  using (auth.uid() = user_id);

create policy profiles_update_own on public.profiles
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
