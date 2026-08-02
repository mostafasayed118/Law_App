-- rpc/list_members_metadata.sql — P2 reviewed RPC (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + matrix §5 (Addendum).
-- Backout: rpc/_down.sql.
--
-- platform_owner_admin-only metadata read: members across orgs with identity
-- (display_name, locale) + membership metadata (role, status, timestamps).
-- Identity/membership metadata ONLY — never matter/document/message content.
-- The read itself is audited (matrix §6). No direct SELECT grant exists on
-- audit or content tables; this is the bounded platform surface.

create or replace function public.list_members_metadata()
returns table (
  organization_id uuid,
  user_id         uuid,
  display_name    text,
  locale          text,
  role            public.org_role,
  status          public.membership_status,
  created_at      timestamptz,
  updated_at      timestamptz
)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;

  perform public.write_audit(
    'platform:list_members', 'allowed',
    p_resource_type => 'membership',
    p_redacted_summary => 'metadata listing of all memberships'
  );

  return query
    select m.organization_id, m.user_id,
           p.display_name, p.locale,
           m.role, m.status, m.created_at, m.updated_at
      from public.memberships m
      join public.profiles p on p.user_id = m.user_id
     order by m.organization_id, m.user_id;
end;
$$;

revoke execute on function public.list_members_metadata() from public, anon;
grant execute on function public.list_members_metadata() to authenticated;
