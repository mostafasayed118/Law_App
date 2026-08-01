-- rpc/accept_invitation.sql — P2 reviewed RPC (REVIEWED, NOT APPLIED)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + §4.5 (D-10a).
-- Backout: rpc/_down.sql.
--
-- Redeems the one-time token: sha-256(hash) match, status pending,
-- unexpired, and the caller's email matches the invited email (D-10a).
-- Binds identity (accepted_by/accepted_at) and creates the membership with
-- the SERVER-OWNED role from the invitation — the client never chooses a
-- role here (contract §6). Single-use by the status guard.
-- Generic 'invalid invitation' for every failure mode (no enumeration).

create or replace function public.accept_invitation(p_token text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_inv        public.invitations%rowtype;
  v_membership uuid;
begin
  select * into v_inv
    from public.invitations
   where token_hash = encode(digest(p_token, 'sha256'), 'hex')
     and status = 'pending'
   limit 1;

  -- Precondition: the JWT must carry an 'email' claim (anon-key GoTrue
  -- setup). Without it the match always fails with the generic denial —
  -- intentional (no enumeration), but a known precondition, not a silent
  -- failure. README refinement #8.
  if not found
     or v_inv.expires_at <= now()
     or lower(v_inv.email) <> lower(coalesce(auth.jwt() ->> 'email', '')) then
    raise exception 'invalid invitation';
  end if;

  insert into public.memberships (organization_id, user_id, role, status, created_by)
  values (v_inv.organization_id, auth.uid(), v_inv.role, 'active', auth.uid())
  returning id into v_membership;

  update public.invitations
     set status = 'accepted', accepted_by = auth.uid(), accepted_at = now()
   where id = v_inv.id;

  perform public.write_audit(
    'invitation:accept', 'allowed',
    p_organization_id => v_inv.organization_id,
    p_resource_type => 'invitation',
    p_resource_id => v_inv.id,
    p_redacted_summary => 'invitation accepted; membership created (role server-owned)'
  );

  return v_membership;
end;
$$;

revoke execute on function public.accept_invitation(text) from public, anon;
grant execute on function public.accept_invitation(text) to authenticated;
