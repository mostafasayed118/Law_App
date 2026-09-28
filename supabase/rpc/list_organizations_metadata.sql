-- rpc/list_organizations_metadata.sql — P1.3 bounded (HIGH-fix follow-up).
-- SUPERSEDES the P2 zero-arg version (REVIEWED & APPLIED — dev project, 2026-08-01).
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + matrix §5 (Addendum).
-- Backout: rpc/_down.sql.
--
-- **APPLIED to the dev project (law_project) 2026-09-28** under owner
-- decision OI-D4: only `list_organizations_metadata(integer, integer)`
-- exists remotely (old zero-arg dropped), EXECUTE on authenticated-only,
-- cap code verified in the live body, and a zero-arg probe routes to the
-- new signature (denied at the owner gate as designed — no audit row
-- written). The shipped client keeps calling zero-arg, which the defaults
-- cover; the 03-battery positive
-- (`select ... from list_organizations_metadata()`) is unaffected.
--
-- What changed and why (HIGH-3): this was the last unbounded platform-admin
-- RPC — it returned the ENTIRE organizations table with no LIMIT. The function
-- now takes p_limit/p_offset with a server-side hard cap of 500 (the same
-- P1.3 pattern as read_platform_audit / list_members_metadata / read_org_audit):
-- the client cannot ask past the cap, and the server never returns more than
-- the cap even for a compromised caller.
--
-- The old zero-arg signature is DROPPED, not left as an overload — leaving it
-- would keep the unbounded path callable.
--
-- platform_owner_admin-only metadata read: organization id/name/timestamps.
-- Identity/membership metadata ONLY — never matter/document/message content
-- (there are no such tables in P2; the boundary holds structurally). The
-- read itself is audited (matrix §6). Client has no direct grant on
-- organizations beyond active-membership select, so this is the only
-- cross-org listing path.

create or replace function public.list_organizations_metadata(
  p_limit  int default 200,
  p_offset int default 0
)
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

  -- Server-side bounds: the client's page size is clamped to the cap, so no
  -- caller (compromised or buggy) can widen the read.
  p_limit  := least(greatest(coalesce(p_limit, 200), 1), 500);
  p_offset := greatest(coalesce(p_offset, 0), 0);

  return query
    select o.id, o.name, o.created_at
      from public.organizations o
     order by o.created_at
     limit p_limit offset p_offset;
end;
$$;

drop function if exists public.list_organizations_metadata();

revoke execute on function public.list_organizations_metadata(int, int) from public, anon;
grant execute on function public.list_organizations_metadata(int, int) to authenticated;
