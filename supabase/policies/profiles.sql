-- policies/profiles.sql — P2 reviewed policy (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Source of truth: docs/p2_schema_rls_design.md §5.2 (gate-approved); the
-- UPDATE half is superseded by supabase/migrations/30_profiles_mutations_rpc_only.sql
-- (2026-10-26), now the source of truth for the RPC-only posture.
-- Backout: git revert of this policy commit (design §7); migration 30's down
-- file restores the pre-30 UPDATE surface.
--
-- Own-row only (matrix §2) for SELECT. No INSERT (signup trigger owns
-- creation), no UPDATE or DELETE: all profiles mutations are RPC-only (Q5).
-- Migration 30 revoked the direct UPDATE ACL and dropped the former
-- profiles_update_own policy; this file no longer declares it.

create policy profiles_select_own on public.profiles
  for select
  using (auth.uid() = user_id);
