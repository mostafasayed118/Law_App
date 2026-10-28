-- 30_profiles_mutations_rpc_only.sql — close the last direct mutation path
-- (NOT APPLIED)
-- Source of truth: docs/live_apply_2026-10-26_audit_followups.md
--
-- The schema contract (01_org_schema.sql: "mutations are RPC-only, Q5") left
-- exactly one direct client mutation on profiles: the narrow column UPDATE
-- grant from 01 plus the profiles_update_own policy as shipped before this
-- change (the policy-source file no longer declares it). This migration
-- revokes both, so every profiles mutation goes through a SECURITY DEFINER
-- path (the signup trigger INSERT, the delete_my_account RPC).
--
-- Verified before writing (2026-10-26, HEAD 0b52374):
--   * No Dart client path writes the table: `from('profiles')` has zero hits
--     in lib/ and test/ (reads go through RPCs / the own-row SELECT only).
--   * No RPC updates profiles: the only SQL mutations are the signup trigger
--     INSERT (SECURITY DEFINER) and test fixtures; delete_my_account deletes
--     auth.users and lets the FK cascade.
--   * Every supabase/rpc/*.sql body is SECURITY DEFINER (the only file
--     without the marker is rpc/_down.sql, which defines no function), so the
--     SELECT joins in list_org_members_metadata / list_members_metadata /
--     send_message do not depend on an authenticated UPDATE grant.
--
-- 01 granted UPDATE at COLUMN level (`grant select, update (display_name,
-- locale) ...`), which is a separate ACL layer from the table-level privilege;
-- both revokes are issued so the contract cannot be satisfied by the leftover
-- column ACL.
--
-- Companion repo changes landed in the same change (no live apply performed):
-- supabase/policies/profiles.sql no longer declares profiles_update_own, and
-- supabase/tests/01_identity_session.sql CHECK 01.04-01.06 assert the new
-- denial contract (SQLSTATE 42501). This migration remains the DB source of
-- truth for the revoke.
--
-- Backout: 30_profiles_mutations_rpc_only.down.sql restores the narrow grant
-- and the pre-30 policy; the down file is now the policy's only declaration.

begin;

revoke update on public.profiles from authenticated;
revoke update (display_name, locale) on public.profiles from authenticated;

drop policy if exists profiles_update_own on public.profiles;

commit;
