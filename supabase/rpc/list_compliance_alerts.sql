-- rpc/list_compliance_alerts.sql — org-scoped alert listing (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §4
--                + docs/superpowers/plans/2026-10-22-compliance.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- READ-ONLY. Gates: an ACTIVE membership in p_organization_id (membership is
-- re-derived server-side, never inferred from the argument), and each row
-- must pass the participant rule: partner, compliance_officer, creator, or a
-- reader of the linked matter. p_status null returns every readable alert in
-- the org; otherwise the exact status is applied. p_severity behaves the same
-- way. Results are newest first (created_at desc); compliance_alerts_org_status
-- serves the shape.
--
-- No writes, no audit row: this is a read path. Bounded 2026-10-24 (D2):
-- p_limit/p_offset default to 200/0 and are clamped server-side to 1..500
-- and >= 0. The original arguments keep their positions and the page
-- parameters are additive, so the existing named-argument callers stay
-- compatible.

create or replace function public.list_compliance_alerts(
  p_organization_id uuid,
  p_status          text,
  p_severity        text,
  p_limit           int default 200,
  p_offset          int default 0
) returns setof public.compliance_alerts
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_member(p_organization_id) then
    raise exception 'permission denied';
  end if;

  p_limit  := least(greatest(coalesce(p_limit, 200), 1), 500);
  p_offset := greatest(coalesce(p_offset, 0), 0);

  return query
    select a.*
      from public.compliance_alerts a
     where a.organization_id = p_organization_id
       and (
         public.has_org_role(a.organization_id, 'partner')
         or public.has_org_role(a.organization_id, 'compliance_officer')
         or a.created_by = auth.uid()
         or public.can_read_matter(a.matter_id, a.organization_id)
       )
       and (p_status is null or a.status = p_status)
       and (p_severity is null or a.severity = p_severity)
     order by a.created_at desc
     limit p_limit offset p_offset;
end;
$$;

drop function if exists public.list_compliance_alerts(uuid, text, text);

revoke execute on function public.list_compliance_alerts(uuid, text, text, int, int) from public, anon;
grant execute on function public.list_compliance_alerts(uuid, text, text, int, int) to authenticated;
