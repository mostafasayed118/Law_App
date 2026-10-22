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
drop function if exists public.list_organizations_metadata(int, int);
drop function if exists public.list_members_metadata();
drop function if exists public.list_members_metadata(int, int);
drop function if exists public.suspend_membership_platform(uuid, uuid);
drop function if exists public.reactivate_membership_platform(uuid, uuid);
drop function if exists public.delete_demo_account(uuid);
drop function if exists public.read_org_audit(uuid);
drop function if exists public.read_org_audit(uuid, int, int);
drop function if exists public.read_platform_audit();
drop function if exists public.read_platform_audit(int, int);
drop function if exists public.list_org_members_metadata(uuid);
drop function if exists public.send_message(uuid, text);
drop function if exists public.create_matter(uuid, text, text, uuid, uuid);
drop function if exists public.create_task(uuid, text, uuid);
drop function if exists public.advance_task_status(uuid, text);
drop function if exists public.assign_task(uuid, uuid);
drop function if exists public.acknowledge_task(uuid);
drop function if exists public.book_consultation(uuid, text, text, text);
drop function if exists public.register_matter_file(uuid, text, text, bigint, text);
drop function if exists public.delete_matter_file(uuid);
drop function if exists public.initiate_invoice_payment(uuid);
drop function if exists public.get_invoice_payment_status(uuid);
drop function if exists public.attach_paymob_order(uuid, text);
drop function if exists public.apply_paymob_transaction(text, text, text, bigint, text, text);
drop function if exists public.record_payment_callback_rejected(text);
drop function if exists public.list_stale_pending_payments(interval, integer);
drop function if exists public.list_matter_assignable_members(uuid);
drop function if exists public.list_attorney_profiles(text, boolean, integer);
drop function if exists public.get_attorney_profile(uuid);
drop function if exists public.create_attorney_profile(text, text, text, text[], text[], text, integer, text);
drop function if exists public.update_attorney_profile(uuid, text, text, text, text[], text[], text, integer, text, text);
drop function if exists public.deactivate_attorney_profile(uuid);
drop function if exists public.create_approval_request(uuid, uuid, text, text, text);
drop function if exists public.decide_approval_request(uuid, text, text);
drop function if exists public.cancel_approval_request(uuid);
drop function if exists public.list_approval_requests(uuid, text);
drop function if exists public.create_compliance_alert(uuid, uuid, text, text, text, text, timestamptz);
drop function if exists public.acknowledge_compliance_alert(uuid);
drop function if exists public.resolve_compliance_alert(uuid, text);
drop function if exists public.list_compliance_alerts(uuid, text, text);
drop function if exists public.start_research_run(uuid, uuid, text);
drop function if exists public.complete_research_run(uuid, text, text, text, jsonb);
drop function if exists public.list_research_runs(uuid);
drop function if exists public.list_research_findings(uuid);

-- The revokes above run first so the drops below are the final privilege
-- reset: functions are gone and no execute grant survives in any role.

commit;
