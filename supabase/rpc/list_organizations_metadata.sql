-- rpc/list_organizations_metadata.sql — P2 reviewed RPC (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + matrix §5 (Addendum).
-- Backout: rpc/_down.sql.
--
-- platform_owner_admin-only metadata read: organization id/name/timestamps.
-- Identity/membership metadata ONLY — never matter/document/message content
-- (there are no such tables in P2; the boundary holds structurally). The
-- read itself is audited (matrix §6). Client has no direct grant on
-- organizations beyond active-membership select, so this is the only
-- cross-org listing path.

create or replace function public.list_organizations_metadata()
returns table (
  organization_id uuid,
  name            text,
  created_at      timestamptz
)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;

  perform public.write_audit(
    'platform:list_organizations', 'allowed',
    p_resource_type => 'organization',
    p_redacted_summary => 'metadata listing of all organizations'
  );

  return query
    select o.id, o.name, o.created_at
      from public.organizations o
     order by o.created_at;
end;
$$;

revoke execute on function public.list_organizations_metadata() from public, anon;
grant execute on function public.list_organizations_metadata() to authenticated;
