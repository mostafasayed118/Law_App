-- rpc/list_research_findings.sql — run-scoped findings listing (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §5
--                + docs/superpowers/plans/2026-10-22-research.md Task 3.
-- Backout: rpc/_down.sql / migrations/25_research.down.sql.
--
-- READ-ONLY. Gate: the run must exist and the caller must hold an ACTIVE
-- membership in the run's organization. A cross-org caller gets the same
-- typed 'permission denied'. Results are ordered by sort_order; id is the
-- deterministic tie-break. No parameter defaults.

create or replace function public.list_research_findings(
  p_run_id uuid
) returns setof public.research_findings
language plpgsql security definer set search_path = public as $$
declare
  v_organization_id uuid;
begin
  select r.organization_id into v_organization_id
    from public.research_runs r
   where r.id = p_run_id;

  if v_organization_id is null then
    raise exception 'research run not found';
  end if;

  if not public.is_active_member(v_organization_id) then
    raise exception 'permission denied';
  end if;

  return query
    select f.*
      from public.research_findings f
     where f.run_id = p_run_id
       and f.organization_id = v_organization_id
     order by f.sort_order asc, f.id asc;
end;
$$;

revoke execute on function public.list_research_findings(uuid) from public, anon;
grant execute on function public.list_research_findings(uuid) to authenticated;
