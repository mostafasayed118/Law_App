-- rpc/reactivate_membership.sql — P2 reviewed RPC (REVIEWED, NOT APPLIED)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + matrix §3 (D-06).
-- Backout: rpc/_down.sql.
--
-- Partner of the org reactivates a suspended membership in that org.
-- Role is preserved; status returns to 'active'. Audited.

create or replace function public.reactivate_membership(
  p_organization_id uuid,
  p_user_id         uuid
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.has_org_role(p_organization_id, 'partner') then
    raise exception 'permission denied';
  end if;

  update public.memberships
     set status = 'active', updated_at = now()
   where organization_id = p_organization_id
     and user_id = p_user_id
     and status = 'suspended';
  if not found then
    raise exception 'suspended membership not found in this organization';
  end if;

  perform public.write_audit(
    'membership:reactivate', 'allowed',
    p_organization_id => p_organization_id,
    p_resource_type => 'membership',
    p_resource_id => p_user_id,
    p_redacted_summary => 'membership reactivated'
  );
end;
$$;

revoke execute on function public.reactivate_membership(uuid, uuid) from public, anon;
grant execute on function public.reactivate_membership(uuid, uuid) to authenticated;
