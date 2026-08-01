-- rpc/read_org_audit.sql — P2 reviewed RPC (REVIEWED, NOT APPLIED)
-- Source of truth: docs/p2_schema_rls_design.md §5.2/§5.3 + README refinement #2.
-- Backout: rpc/_down.sql.
--
-- Contract §8 scope-checked audit read, implemented as an RPC so the read
-- itself is auditable (a raw SELECT policy cannot audit a read). Partner of
-- the org reads that org's audit rows only; the listing is itself audited.
-- Returns redacted summary + correlation id — no credentials/content.

create or replace function public.read_org_audit(p_organization_id uuid)
returns table (
  id               bigint,
  action           text,
  outcome          text,
  resource_type    text,
  resource_id      uuid,
  correlation_id   uuid,
  redacted_summary text,
  server_timestamp timestamptz
)
language plpgsql security definer set search_path = public as $$
begin
  if not public.has_org_role(p_organization_id, 'partner') then
    raise exception 'permission denied';
  end if;

  perform public.write_audit(
    'audit:read_org', 'allowed',
    p_organization_id => p_organization_id,
    p_resource_type => 'audit_events',
    p_redacted_summary => 'org audit rows read by partner'
  );

  return query
    select a.id, a.action, a.outcome, a.resource_type, a.resource_id,
           a.correlation_id, a.redacted_summary, a.server_timestamp
      from public.audit_events a
     where a.organization_id = p_organization_id
     order by a.server_timestamp desc;
end;
$$;

revoke execute on function public.read_org_audit(uuid) from public, anon;
grant execute on function public.read_org_audit(uuid) to authenticated;
