-- rpc/get_video_session.sql — single video-session read (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §6
--                + docs/superpowers/plans/2026-10-22-video.md Task 3.
-- Backout: rpc/_down.sql / migrations/26_video_sessions.down.sql.
--
-- READ-ONLY. Gates:
--   - the session must exist ('video session not found');
--   - the caller must be an ACTIVE MEMBER of the session's organization
--     ('permission denied').
--
-- Returns the full row. No audit row: read path. No parameter defaults.

create or replace function public.get_video_session(
  p_id uuid
) returns public.video_sessions
language plpgsql security definer set search_path = public as $$
declare
  v_row public.video_sessions;
begin
  select s.* into v_row
    from public.video_sessions s
   where s.id = p_id;

  if not found then
    raise exception 'video session not found';
  end if;
  if not public.is_active_member(v_row.organization_id) then
    raise exception 'permission denied';
  end if;

  return v_row;
end;
$$;

revoke execute on function public.get_video_session(uuid) from public, anon;
grant execute on function public.get_video_session(uuid) to authenticated;
