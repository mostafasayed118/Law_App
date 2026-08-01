-- rpc/_down.sql — consolidated backout for the entire P2 RPC surface
-- (REVIEWED — rollback standby; not run on dev). Mirrors README rollback row "rpc/*.sql -> _down.sql".

begin;

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

-- Note: dropping the functions does not drop the per-function execute grants
-- granted to `authenticated`; run `revoke execute on all functions in schema
-- public from authenticated;` if a full privilege reset is desired. The
-- RPC-specific revoke-from-public/anon lines in each file are idempotent.

commit;
