-- rpc/create_organization.sql — P2 reviewed RPC (REVIEWED, NOT APPLIED)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + §4.3/D-08.
-- Backout: rpc/_down.sql.
--
-- Creates the org and makes the caller its initial partner (D-08: server
-- sets created_by = auth.uid(); client supplies only the name). Audited.

create or replace function public.create_organization(p_name text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_org_id uuid;
begin
  if p_name is null or trim(p_name) = '' then
    raise exception 'organization name is required';
  end if;

  insert into public.organizations (name, created_by)
  values (trim(p_name), auth.uid())
  returning id into v_org_id;

  insert into public.memberships (organization_id, user_id, role, status, created_by)
  values (v_org_id, auth.uid(), 'partner', 'active', auth.uid());

  perform public.write_audit(
    'organization:create', 'allowed',
    p_organization_id => v_org_id,
    p_resource_type => 'organization',
    p_resource_id => v_org_id,
    p_redacted_summary => 'org created; creator made partner'
  );

  return v_org_id;
end;
$$;

revoke execute on function public.create_organization(text) from public, anon;
grant execute on function public.create_organization(text) to authenticated;
