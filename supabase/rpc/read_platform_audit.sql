-- rpc/read_platform_audit.sql — P2 reviewed RPC (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Source of truth: docs/p2_schema_rls_design.md §5.2 + matrix §6 + README
-- refinement #2.
-- Backout: rpc/_down.sql.
--
-- platform_owner_admin-only cross-org audit read. Matrix §6: "platform_owner
-- _admin reading the audit table is itself an audited action" — impossible
-- with a raw SELECT policy, hence the RPC. The owner's own read is audited
-- with the owner actor (owner is not audit-exempt). Redacted fields only.

create or replace function public.read_platform_audit()
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

  return query
    select a.id, a.actor_user_id, a.action, a.outcome, a.organization_id,
           a.resource_type, a.resource_id, a.correlation_id,
           a.redacted_summary, a.server_timestamp
      from public.audit_events a
     order by a.server_timestamp desc;
end;
$$;

revoke execute on function public.read_platform_audit() from public, anon;
grant execute on function public.read_platform_audit() to authenticated;
