-- rpc/end_video_session.sql — audited terminal transition (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §6
--                + docs/superpowers/plans/2026-10-22-video.md Task 3.
-- Backout: rpc/_down.sql / migrations/26_video_sessions.down.sql.
--
-- Gates (row locked FOR UPDATE):
--   - the session must exist ('video session not found');
--   - the caller must be an ACTIVE MEMBER of the session's organization
--     ('permission denied');
--   - ended/cancelled raises 'video session has already ended';
--   - only 'scheduled' or 'live' can transition ('video session is not
--     scheduled' otherwise);
--   - the caller must be the creator or a PARTNER of the org
--     ('permission denied' otherwise — an unrelated client cannot end a call).
--
-- The update stamps ended_at = now() and updated_at = now(); the redacted
-- audit row is written in the same transaction. No recording/transcription
-- state exists in v1.

create or replace function public.end_video_session(
  p_id uuid
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_org        uuid;
  v_status     text;
  v_created_by uuid;
begin
  select s.organization_id, s.status, s.created_by
    into v_org, v_status, v_created_by
    from public.video_sessions s
   where s.id = p_id
     for update;

  if v_org is null then
    raise exception 'video session not found';
  end if;
  if not public.is_active_member(v_org) then
    raise exception 'permission denied';
  end if;
  if v_status in ('ended', 'cancelled') then
    raise exception 'video session has already ended';
  end if;
  if v_status not in ('scheduled', 'live') then
    raise exception 'video session is not scheduled';
  end if;
  if not (v_created_by is not null and v_created_by = auth.uid())
     and not public.has_org_role(v_org, 'partner') then
    raise exception 'permission denied';
  end if;

  update public.video_sessions
     set status     = 'ended',
         ended_at   = now(),
         updated_at = now()
   where id = p_id;

  perform public.write_audit(
    'video_session:end', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'video_session',
    p_resource_id      => p_id,
    p_redacted_summary => 'video session ended'
  );
end;
$$;

revoke execute on function public.end_video_session(uuid) from public, anon;
grant execute on function public.end_video_session(uuid) to authenticated;
