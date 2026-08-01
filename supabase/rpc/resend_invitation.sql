-- rpc/resend_invitation.sql — P2 reviewed RPC (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + §4.5 (D-10a).
-- Backout: rpc/_down.sql.
-- R-1 (amended, rehearsal finding): pgcrypto calls qualified as extensions.* —
-- pgcrypto lives in the `extensions` schema on this hosting, and the unqualified
-- forms fail under the pinned search_path = public. Verified in the rehearsal.
--
-- Partner of the org rotates an existing PENDING invite's token and expiry
-- (resend). A new literal token is returned once; only its hash is stored
-- (Q2). Expired/revoked/accepted invites are not resendable — re-invite or
-- revoke instead. The unique partial index on pending (org, email) is
-- unaffected: this updates the same row.

create or replace function public.resend_invitation(p_invitation_id uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_inv   public.invitations%rowtype;
  v_token text;
begin
  select * into v_inv from public.invitations where id = p_invitation_id;
  if not found then
    raise exception 'invitation not found';
  end if;
  if not public.has_org_role(v_inv.organization_id, 'partner') then
    raise exception 'permission denied';
  end if;
  if v_inv.status <> 'pending' then
    raise exception 'only pending invitations can be resent';
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  update public.invitations
     set token_hash = encode(extensions.digest(v_token, 'sha256'), 'hex'),
         expires_at = now() + interval '7 days'
   where id = p_invitation_id;

  perform public.write_audit(
    'invitation:resend', 'allowed',
    p_organization_id => v_inv.organization_id,
    p_resource_type => 'invitation',
    p_resource_id => p_invitation_id,
    p_redacted_summary => 'invite resent (token rotated, hash only stored)'
  );

  return v_token;
end;
$$;

revoke execute on function public.resend_invitation(uuid) from public, anon;
grant execute on function public.resend_invitation(uuid) to authenticated;
