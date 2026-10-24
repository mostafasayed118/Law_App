-- rpc/list_research_findings.sql — run-scoped findings listing (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §5
--                + docs/superpowers/plans/2026-10-22-research.md Task 3.
-- Backout: rpc/_down.sql / migrations/25_research.down.sql.
--
-- READ-ONLY. Gates: the run must exist ('research run not found'); the caller
-- must hold an ACTIVE membership in the run's organization and pass the same
-- participant rule as the run policy (requester, partner, or a reader of the
-- run's matter). A cross-org or unrelated caller gets the typed
-- 'permission denied'. Results are ordered by sort_order; id is the
-- deterministic tie-break. No parameter defaults.

create or replace function public.list_research_findings(
  p_run_id uuid
) returns setof public.research_findings
language plpgsql security definer set search_path = public as $$
declare
  v_run public.research_runs;
begin
  select r.* into v_run
    from public.research_runs r
   where r.id = p_run_id;

  if not found then
    raise exception 'research run not found';
  end if;

  if not public.is_active_member(v_run.organization_id) then
    raise exception 'permission denied';
  end if;

  if not (
    coalesce(v_run.requested_by = auth.uid(), false)
    or public.has_org_role(v_run.organization_id, 'partner')
    or public.can_read_matter(v_run.matter_id, v_run.organization_id)
  ) then
    raise exception 'permission denied';
  end if;

  return query
    select f.*
      from public.research_findings f
     where f.run_id = p_run_id
       and f.organization_id = v_run.organization_id
     order by f.sort_order asc, f.id asc;
end;
$$;

revoke execute on function public.list_research_findings(uuid) from public, anon;
grant execute on function public.list_research_findings(uuid) to authenticated;
