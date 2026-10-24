-- rpc/list_approval_requests.sql — org-scoped approval listing (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §3
--                + docs/superpowers/plans/2026-10-22-approvals.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- READ-ONLY. Gates: an ACTIVE membership in p_organization_id (membership is
-- re-derived server-side, never inferred from the argument), and each row
-- must pass the participant rule: partner, requester, decider, or a reader of
-- the linked matter. p_status null returns every readable request in the org;
-- otherwise the exact status is applied. Results are newest first
-- (created_at desc); the composite index approval_requests_org_status serves
-- the shape.
--
-- No writes, no audit row: this is a read path. No parameter carries a
-- default (the open PostgREST incident).

create or replace function public.list_approval_requests(
  p_organization_id uuid,
  p_status          text
) returns setof public.approval_requests
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_member(p_organization_id) then
    raise exception 'permission denied';
  end if;

  return query
    select r.*
      from public.approval_requests r
     where r.organization_id = p_organization_id
       and (
         public.has_org_role(r.organization_id, 'partner')
         or r.requested_by = auth.uid()
         or r.decided_by = auth.uid()
         or public.can_read_matter(r.matter_id, r.organization_id)
       )
       and (p_status is null or r.status = p_status)
     order by r.created_at desc;
end;
$$;

revoke execute on function public.list_approval_requests(uuid, text) from public, anon;
grant execute on function public.list_approval_requests(uuid, text) to authenticated;
