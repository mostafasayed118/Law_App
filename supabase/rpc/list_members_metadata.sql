-- rpc/list_members_metadata.sql — P1.3 bounded (2026-09-22). SUPERSEDES the P2 zero-arg
-- version (REVIEWED & APPLIED — dev project, 2026-08-01).
--
-- **NOT YET APPLIED.** Owner decision OI-D4 authorizes the apply through the
-- owner's path after the standard rehearsal → apply → battery re-run. Until
-- this file is applied, the shipped client must keep calling the zero-arg
-- signature; the client's p_limit/p_offset flip lands in the same release as
-- the apply (an argument the function does not accept yet is a hard RPC error).
--
-- What changed and why (audit 2026-09-21, H-8): the platform-admin RPCs were
-- the one path meeting the "unbounded query that will grow without limit"
-- definition — read_platform_audit returned the ENTIRE audit_events table and
-- is itself self-amplifying (each read appends a row to the table it read).
-- Every function now takes p_limit/p_offset with a server-side hard cap of
-- 500: the client cannot ask past the cap, and the server never returns more
-- than the cap even for a compromised caller.
--
-- The old zero-arg signature is DROPPED, not left as an overload — leaving it
-- would keep the unbounded path callable.
-- Backout: rpc/_down.sql.

create or replace function public.list_members_metadata(
  p_limit  int default 200,
  p_offset int default 0
)
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

  -- Server-side bounds: the client's page size is clamped to the cap, so no
  -- caller (compromised or buggy) can widen the read.
  p_limit  := least(greatest(coalesce(p_limit, 200), 1), 500);
  p_offset := greatest(coalesce(p_offset, 0), 0);

  return query
    select m.organization_id, m.user_id,
           p.display_name, p.locale,
           m.role, m.status, m.created_at, m.updated_at
      from public.memberships m
      join public.profiles p on p.user_id = m.user_id
     order by m.organization_id, m.user_id
     limit p_limit offset p_offset;
end;
$$;

drop function if exists public.list_members_metadata();

revoke execute on function public.list_members_metadata(int, int) from public, anon;
grant execute on function public.list_members_metadata(int, int) to authenticated;
