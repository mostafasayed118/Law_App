-- rpc/delete_demo_account.sql — P2 reviewed RPC (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + matrix §3/§5 (Addendum).
-- Backout: rpc/_down.sql.
--
-- platform_owner_admin-only: deletes a SYNTHETIC DEMO account (matrix §3,
-- the one row that is owner-only). Mirrors delete_my_account's D-05 semantics
-- (audit written before deletion; actor FK set null; audit survives). It is
-- gated on is_platform_owner() AND refuses auth.uid() (self-deletion must go
-- through delete_my_account). Audited with the owner actor.

create or replace function public.delete_demo_account(p_user_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'cannot delete your own account via this path; use delete_my_account';
  end if;
  -- Synthetic-only guard (audit 2026-10-28, M3): without it the platform
  -- owner could hard-delete any real client/attorney and cascade their
  -- memberships, matters and profile. Real-account deletion must go through
  -- delete_my_account or an explicit data-request procedure.
  if not exists (
    select 1
      from auth.users u
     where u.id = p_user_id
       and (u.email like '%@legalhub.test' or u.email like '%@legalhub.local')
  ) then
    raise exception 'target is not a synthetic demo account';
  end if;

  perform public.write_audit(
    'platform:delete_demo_account', 'allowed',
    p_resource_type => 'profile',
    p_resource_id => p_user_id,
    p_redacted_summary => 'synthetic demo account deleted by platform owner'
  );

  delete from auth.users where id = p_user_id;
end;
$$;

revoke execute on function public.delete_demo_account(uuid) from public, anon;
grant execute on function public.delete_demo_account(uuid) to authenticated;
