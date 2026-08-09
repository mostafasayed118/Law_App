-- rpc/_down.sql — consolidated backout for the entire P2 RPC surface
-- (REVIEWED — rollback standby; not run on dev). Mirrors README rollback row "rpc/*.sql -> _down.sql".
--
-- Hardened 2026-08-03 (REVIEWED — rollback standby; not run on dev): the backout now also
-- revokes the per-function EXECUTE grants the RPC files gave to
-- `authenticated`, so a full rollback restores the default-deny posture
-- instead of leaving an orphaned grant surface.

begin;

revoke execute on all functions in schema public from authenticated;
revoke execute on all functions in schema public from anon, public;

drop function if exists public.create_organization(text);
drop function if exists public.accept_invitation(text);
drop function if exists public.invite_member(uuid, text, public.org_role);
drop function if exists public.resend_invitation(uuid);
drop function if exists public.revoke_invitation(uuid);
drop function if exists public.change_member_role(uuid, uuid, public.org_role);
drop function if exists public.suspend_membership(uuid, uuid);
drop function if exists public.reactivate_membership(uuid, uuid);
drop function if exists public.remove_membership(uuid, uuid);
drop function if exists public.delete_my_account();
drop function if exists public.list_organizations_metadata();
drop function if exists public.list_members_metadata();
drop function if exists public.suspend_membership_platform(uuid, uuid);
drop function if exists public.reactivate_membership_platform(uuid, uuid);
drop function if exists public.delete_demo_account(uuid);
drop function if exists public.read_org_audit(uuid);
drop function if exists public.read_platform_audit();
drop function if exists public.list_org_members_metadata(uuid);
drop function if exists public.send_message(uuid, text);
drop function if exists public.create_matter(uuid, text, text, uuid, uuid);

-- The revokes above run first so the drops below are the final privilege
-- reset: functions are gone and no execute grant survives in any role.

commit;
