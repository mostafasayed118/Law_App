-- rpc/mark_video_session_live.sql — audited scheduled -> live transition (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §6
--                + docs/superpowers/plans/2026-10-22-video.md Task 3.
-- Backout: rpc/_down.sql / migrations/26_video_sessions.down.sql.
--
-- Gates (row locked FOR UPDATE):
--   - the session must exist ('video session not found');
--   - public.can_access_video_session must pass ('permission denied'): the
--     caller is an active member of the session's organization AND a partner,
--     the creator, a linked-matter reader, or the linked booking's client;
--   - ended/cancelled raises 'video session has already ended';
--   - only 'scheduled' can transition; a live session raises
--     'video session is not scheduled'.
--
-- The update stamps started_at = now() and updated_at = now(); the redacted
-- audit row is written in the same transaction.

create or replace function public.mark_video_session_live(
  p_id uuid
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_org    uuid;
  v_status text;
begin
  select s.organization_id, s.status
    into v_org, v_status
    from public.video_sessions s
   where s.id = p_id
     for update;

  if v_org is null then
    raise exception 'video session not found';
  end if;
  if not public.can_access_video_session(p_id) then
    raise exception 'permission denied';
  end if;
  if v_status in ('ended', 'cancelled') then
    raise exception 'video session has already ended';
  end if;
  if v_status <> 'scheduled' then
    raise exception 'video session is not scheduled';
  end if;

  update public.video_sessions
     set status     = 'live',
         started_at = now(),
         updated_at = now()
   where id = p_id;

  perform public.write_audit(
    'video_session:live', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'video_session',
    p_resource_id      => p_id,
    p_redacted_summary => 'video session started'
  );
end;
$$;

revoke execute on function public.mark_video_session_live(uuid) from public, anon;
grant execute on function public.mark_video_session_live(uuid) to authenticated;
