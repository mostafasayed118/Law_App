-- rpc/list_video_sessions.sql — org-scoped video-session listing (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §6
--                + docs/superpowers/plans/2026-10-22-video.md Task 3.
-- Backout: rpc/_down.sql / migrations/26_video_sessions.down.sql.
--
-- READ-ONLY. Gates: an ACTIVE membership in p_organization_id (membership is
-- re-derived server-side, never inferred from the argument), and every
-- returned row must pass public.can_access_video_session: partner, creator,
-- linked-matter reader, or the linked booking's client. An unrelated active
-- member gets the membership check but no rows. Results are newest first
-- (created_at desc); the composite index video_sessions_org_created serves
-- the shape.
--
-- No writes, no audit row: this is a read path. Bounded 2026-10-24 (D2):
-- p_limit/p_offset default to 200/0 and are clamped server-side to 1..500
-- and >= 0; the original arguments keep their positions, so named-argument
-- callers stay compatible.

create or replace function public.list_video_sessions(
  p_organization_id uuid,
  p_limit           int default 200,
  p_offset          int default 0
) returns setof public.video_sessions
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_member(p_organization_id) then
    raise exception 'permission denied';
  end if;

  p_limit  := least(greatest(coalesce(p_limit, 200), 1), 500);
  p_offset := greatest(coalesce(p_offset, 0), 0);

  return query
    select s.*
      from public.video_sessions s
     where s.organization_id = p_organization_id
       and public.can_access_video_session(s.id)
     order by s.created_at desc
     limit p_limit offset p_offset;
end;
$$;

drop function if exists public.list_video_sessions(uuid);

revoke execute on function public.list_video_sessions(uuid, int, int) from public, anon;
grant execute on function public.list_video_sessions(uuid, int, int) to authenticated;
