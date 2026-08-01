-- rpc/suspend_membership_platform.sql — P2 reviewed RPC (REVIEWED, NOT APPLIED)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + matrix §3/§5 (Addendum).
-- Backout: rpc/_down.sql.
--
-- platform_owner_admin-only: suspends a membership in ANY org (matrix §3:
-- owner row = any org, metadata-level action). It cannot change roles,
-- remove members, or touch content — the platform boundary (matrix §5).
-- Audited with the platform_owner_admin actor (owner is not audit-exempt).

create or replace function public.suspend_membership_platform(
  p_organization_id uuid,
  p_user_id         uuid
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;

  update public.memberships
     set status = 'suspended', updated_at = now()
   where organization_id = p_organization_id
     and user_id = p_user_id
     and status = 'active';
  if not found then
    raise exception 'active membership not found in this organization';
  end if;

  perform public.write_audit(
    'platform:suspend_membership', 'allowed',
    p_organization_id => p_organization_id,
    p_resource_type => 'membership',
    p_resource_id => p_user_id,
    p_redacted_summary => 'membership suspended by platform owner'
  );
end;
$$;

revoke execute on function public.suspend_membership_platform(uuid, uuid) from public, anon;
grant execute on function public.suspend_membership_platform(uuid, uuid) to authenticated;
