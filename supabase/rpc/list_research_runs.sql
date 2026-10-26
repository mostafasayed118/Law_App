-- rpc/list_research_runs.sql — org-scoped research-run listing (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §5
--                + docs/superpowers/plans/2026-10-22-research.md Task 3.
-- Backout: rpc/_down.sql / migrations/25_research.down.sql.
--
-- READ-ONLY. Gates: an ACTIVE membership in p_organization_id (membership is
-- re-derived server-side, never inferred from the argument), and each row
-- must pass the participant rule: requester, partner, or a reader of the
-- linked matter. Results are newest first; id is the deterministic tie-break.
-- Bounded 2026-10-24 (D2): p_limit/p_offset default to 200/0 and are clamped
-- server-side to 1..500 and >= 0.

create or replace function public.list_research_runs(
  p_organization_id uuid,
  p_limit           int default 200,
  p_offset          int default 0
) returns setof public.research_runs
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_member(p_organization_id) then
    raise exception 'permission denied';
  end if;

  p_limit  := least(greatest(coalesce(p_limit, 200), 1), 500);
  p_offset := greatest(coalesce(p_offset, 0), 0);

  return query
    select r.*
      from public.research_runs r
     where r.organization_id = p_organization_id
       and (
         r.requested_by = auth.uid()
         or public.has_org_role(r.organization_id, 'partner')
         or public.can_read_matter(r.matter_id, r.organization_id)
       )
     order by r.created_at desc, r.id desc
     limit p_limit offset p_offset;
end;
$$;

drop function if exists public.list_research_runs(uuid);

revoke execute on function public.list_research_runs(uuid, int, int) from public, anon;
grant execute on function public.list_research_runs(uuid, int, int) to authenticated;
