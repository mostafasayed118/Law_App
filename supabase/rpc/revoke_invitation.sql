-- rpc/revoke_invitation.sql — P2 reviewed RPC (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + §4.5 (D-10a).
-- Backout: rpc/_down.sql.
--
-- Partner of the org revokes a PENDING invite (status transition, never a
-- DELETE — audit trail preserved). A revoked token can no longer be redeemed.

create or replace function public.revoke_invitation(p_invitation_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_inv public.invitations%rowtype;
begin
  select * into v_inv from public.invitations where id = p_invitation_id;
  if not found then
    raise exception 'invitation not found';
  end if;
  if not public.has_org_role(v_inv.organization_id, 'partner') then
    raise exception 'permission denied';
  end if;
  if v_inv.status <> 'pending' then
    raise exception 'only pending invitations can be revoked';
  end if;

  update public.invitations set status = 'revoked' where id = p_invitation_id;

  perform public.write_audit(
    'invitation:revoke', 'allowed',
    p_organization_id => v_inv.organization_id,
    p_resource_type => 'invitation',
    p_resource_id => p_invitation_id,
    p_redacted_summary => 'invite revoked'
  );
end;
$$;

revoke execute on function public.revoke_invitation(uuid) from public, anon;
grant execute on function public.revoke_invitation(uuid) to authenticated;
