-- 02_rls_functions.down.sql — backout for 02_rls_functions.sql
-- (REVIEWED — rollback standby; not run on dev)

begin;

drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop function if exists public.expire_stale_invitations();
drop function if exists public.write_audit(
  text, text, uuid, text, uuid, uuid, text, uuid
);
drop function if exists public.is_platform_owner();
drop function if exists public.has_org_role(uuid, public.org_role);
drop function if exists public.is_active_member(uuid);
drop function if exists public.active_membership(uuid);

-- Revert the R-3 default-privileges hardening so the down sequence restores
-- the hosting's byte-equal baseline (pg_default_acl back to Supabase default).
alter default privileges in schema public
  grant execute on functions to anon, authenticated;

commit;
