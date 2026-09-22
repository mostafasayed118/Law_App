-- rpc/read_platform_audit.sql — P1.3 bounded (2026-09-22). SUPERSEDES the P2 zero-arg
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

create or replace function public.read_platform_audit(
  p_limit  int default 200,
  p_offset int default 0
)
returns table (
  id               bigint,
  actor_user_id    uuid,
  action           text,
  outcome          text,
  organization_id  uuid,
  resource_type    text,
  resource_id      uuid,
  correlation_id   uuid,
  redacted_summary text,
  server_timestamp timestamptz
)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;

  perform public.write_audit(
    'platform:read_audit', 'allowed',
    p_resource_type => 'audit_events',
    p_redacted_summary => 'cross-org audit rows read by platform owner'
  );

  -- Server-side bounds: the client's page size is clamped to the cap, so no
  -- caller (compromised or buggy) can widen the read.
  p_limit  := least(greatest(coalesce(p_limit, 200), 1), 500);
  p_offset := greatest(coalesce(p_offset, 0), 0);

  return query
    select a.id, a.actor_user_id, a.action, a.outcome, a.organization_id,
           a.resource_type, a.resource_id, a.correlation_id,
           a.redacted_summary, a.server_timestamp
      from public.audit_events a
     order by a.server_timestamp desc
     limit p_limit offset p_offset;
end;
$$;

drop function if exists public.read_platform_audit();

revoke execute on function public.read_platform_audit(int, int) from public, anon;
grant execute on function public.read_platform_audit(int, int) to authenticated;
