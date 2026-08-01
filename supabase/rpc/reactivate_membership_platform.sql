-- rpc/reactivate_membership_platform.sql — P2 reviewed RPC (REVIEWED, NOT APPLIED)
-- Source of truth: docs/permission_matrix.md §3 owner row ("Suspend / reactivate
-- a membership | ✅ (any org)") — ADDED to complete the signed matrix row that
-- design §5.3's list omitted (design listed only suspend_membership_platform).
-- Flagged in supabase/README.md refinement #2; owner can veto before apply.
-- Backout: rpc/_down.sql.
--
-- platform_owner_admin-only: reactivates a suspended membership in ANY org
-- (matrix §3 owner row: any org, metadata-level action). Role is preserved;
-- status returns to 'active'. Audited with the owner actor (owner not
-- audit-exempt). The platform boundary still holds: no role changes, no
-- removes, no content (matrix §5).

create or replace function public.reactivate_membership_platform(
  p_organization_id uuid,
  p_user_id         uuid
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_owner() then
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
    'platform:reactivate_membership', 'allowed',
    p_organization_id => p_organization_id,
    p_resource_type => 'membership',
    p_resource_id => p_user_id,
    p_redacted_summary => 'membership reactivated by platform owner'
  );
end;
$$;

revoke execute on function public.reactivate_membership_platform(uuid, uuid) from public, anon;
grant execute on function public.reactivate_membership_platform(uuid, uuid) to authenticated;
