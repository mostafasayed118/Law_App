-- rpc/remove_membership.sql — P2 reviewed RPC (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + matrix §3 (D-06).
-- Backout: rpc/_down.sql.
--
-- Partner of the org removes a member from that org. Status transitions to
-- 'removed' (soft removal — never a DELETE, audit trail preserved, and
-- removed memberships no longer authorize anything via active_membership()).
-- A member cannot remove themselves via this RPC (use delete_my_account for
-- self-deletion, D-05). Audited.
--
-- Hardened 2026-08-03 (HARDENED & APPLIED — dev project, 2026-08-03): the org must retain at
-- least one active partner after the removal, closing the same zero-partner
-- lockout that change_member_role now guards (audit finding).

create or replace function public.remove_membership(
  p_organization_id uuid,
  p_user_id         uuid
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() = p_user_id then
    raise exception 'cannot remove yourself; use delete_my_account';
  end if;
  if not public.has_org_role(p_organization_id, 'partner') then
    raise exception 'permission denied';
  end if;

  -- Last-partner guard: removing the org's only active partner locks the
  -- org out of membership management.
  if exists (
    select 1
      from public.memberships
     where organization_id = p_organization_id
       and user_id = p_user_id
       and role = 'partner'
       and status = 'active'
  ) and not exists (
    select 1
      from public.memberships
     where organization_id = p_organization_id
       and role = 'partner'
       and status = 'active'
       and user_id <> p_user_id
     limit 1
  ) then
    raise exception 'organization must retain at least one active partner';
  end if;

  update public.memberships
     set status = 'removed', updated_at = now()
   where organization_id = p_organization_id
     and user_id = p_user_id
     and status <> 'removed';
  if not found then
    raise exception 'membership not found in this organization';
  end if;

  perform public.write_audit(
    'membership:remove', 'allowed',
    p_organization_id => p_organization_id,
    p_resource_type => 'membership',
    p_resource_id => p_user_id,
    p_redacted_summary => 'membership removed'
  );
end;
$$;

revoke execute on function public.remove_membership(uuid, uuid) from public, anon;
grant execute on function public.remove_membership(uuid, uuid) to authenticated;
