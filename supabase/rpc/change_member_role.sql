-- rpc/change_member_role.sql — P2 reviewed RPC (REVIEWED, NOT APPLIED)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + §4.4 (D-06).
-- Backout: rpc/_down.sql.
--
-- Partner of the org changes a member's role in THAT org. The target
-- membership must be in the same org the caller partners (tenant isolation:
-- a partner in org-a cannot change a role in org-b). Audited.

create or replace function public.change_member_role(
  p_organization_id uuid,
  p_user_id         uuid,
  p_role            public.org_role
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_old_role public.org_role;
begin
  if not public.has_org_role(p_organization_id, 'partner') then
    raise exception 'permission denied';
  end if;

  select role into v_old_role
    from public.memberships
   where organization_id = p_organization_id
     and user_id = p_user_id;
  if not found then
    raise exception 'membership not found in this organization';
  end if;

  update public.memberships
     set role = p_role, updated_at = now()
   where organization_id = p_organization_id
     and user_id = p_user_id;

  perform public.write_audit(
    'membership:role_change', 'allowed',
    p_organization_id => p_organization_id,
    p_resource_type => 'membership',
    p_resource_id => p_user_id,
    p_redacted_summary => 'role changed ' || v_old_role || ' -> ' || p_role
  );
end;
$$;

revoke execute on function public.change_member_role(uuid, uuid, public.org_role) from public, anon;
grant execute on function public.change_member_role(uuid, uuid, public.org_role) to authenticated;
