-- rpc/list_compliance_alerts.sql — org-scoped alert listing (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §4
--                + docs/superpowers/plans/2026-10-22-compliance.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- READ-ONLY. Gate: an ACTIVE membership in p_organization_id (membership is
-- re-derived server-side, never inferred from the argument). p_status null
-- returns every alert in the org; otherwise the exact status is applied.
-- p_severity behaves the same way. Results are newest first (created_at
-- desc); compliance_alerts_org_status serves the shape.
--
-- No writes, no audit row: this is a read path. No parameter carries a
-- default (the open PostgREST incident).

create or replace function public.list_compliance_alerts(
  p_organization_id uuid,
  p_status          text,
  p_severity        text
) returns setof public.compliance_alerts
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_member(p_organization_id) then
    raise exception 'permission denied';
  end if;

  return query
    select a.*
      from public.compliance_alerts a
     where a.organization_id = p_organization_id
       and (p_status is null or a.status = p_status)
       and (p_severity is null or a.severity = p_severity)
     order by a.created_at desc;
end;
$$;

revoke execute on function public.list_compliance_alerts(uuid, text, text) from public, anon;
grant execute on function public.list_compliance_alerts(uuid, text, text) to authenticated;
