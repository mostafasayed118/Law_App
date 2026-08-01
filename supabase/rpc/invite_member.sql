-- rpc/invite_member.sql — P2 reviewed RPC (REVIEWED, NOT APPLIED)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + §4.5 (D-10a, D-06).
-- Backout: rpc/_down.sql.
-- R-1 (amended, rehearsal finding): pgcrypto calls qualified as extensions.* —
-- pgcrypto lives in the `extensions` schema on this hosting, and the unqualified
-- forms fail under the pinned search_path = public. Verified in the rehearsal.
--
-- Partner of the org invites a new member. The role is validated server-side
-- (never elevated beyond an MVP org role; org_role enum enforces the set).
-- The literal token is returned to the inviter exactly once; only its
-- sha-256 hash is stored (Q2). 7-day expiry, single-use (D-10a).
-- The pending unique partial index enforces one pending invite per (org, email).

create or replace function public.invite_member(
  p_organization_id uuid,
  p_email           text,
  p_role            public.org_role
) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_token text;
begin
  if not public.has_org_role(p_organization_id, 'partner') then
    raise exception 'permission denied';
  end if;
  if p_email is null or position('@' in p_email) = 0 then
    raise exception 'a valid email is required';
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');

  insert into public.invitations (
    organization_id, email, role, token_hash, expires_at, created_by
  ) values (
    p_organization_id,
    lower(trim(p_email)),
    p_role,
    encode(extensions.digest(v_token, 'sha256'), 'hex'),
    now() + interval '7 days',
    auth.uid()
  );

  perform public.write_audit(
    'invitation:create', 'allowed',
    p_organization_id => p_organization_id,
    p_resource_type => 'invitation',
    p_redacted_summary => 'invite issued (token hash only stored)'
  );

  return v_token;  -- shown to the inviter exactly once; never persisted/derived again
end;
$$;

revoke execute on function public.invite_member(uuid, text, public.org_role) from public, anon;
grant execute on function public.invite_member(uuid, text, public.org_role) to authenticated;
