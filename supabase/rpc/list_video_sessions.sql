-- rpc/list_video_sessions.sql — org-scoped video-session listing (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §6
--                + docs/superpowers/plans/2026-10-22-video.md Task 3.
-- Backout: rpc/_down.sql / migrations/26_video_sessions.down.sql.
--
-- READ-ONLY. Gate: an ACTIVE membership in p_organization_id (membership is
-- re-derived server-side, never inferred from the argument). Results are
-- newest first (created_at desc); the composite index
-- video_sessions_org_created serves the shape.
--
-- No writes, no audit row: this is a read path. No parameter carries a
-- default (the open PostgREST incident).

create or replace function public.list_video_sessions(
  p_organization_id uuid
) returns setof public.video_sessions
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_member(p_organization_id) then
    raise exception 'permission denied';
  end if;

  return query
    select s.*
      from public.video_sessions s
     where s.organization_id = p_organization_id
     order by s.created_at desc;
end;
$$;

revoke execute on function public.list_video_sessions(uuid) from public, anon;
grant execute on function public.list_video_sessions(uuid) to authenticated;
