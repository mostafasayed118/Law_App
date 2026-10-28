-- rpc/create_video_session.sql — audited video-session creation (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §6
--                + docs/superpowers/plans/2026-10-22-video.md Task 3.
-- Backout: rpc/_down.sql / migrations/26_video_sessions.down.sql.
--
-- Gates, in order:
--   - the caller must be an ACTIVE MEMBER of p_organization_id;
--   - the caller's org role must be partner or attorney (session authority);
--   - an attorney must name a matter (plan global constraint: "attorney only
--     on a matter they can read"); a partner may create an org-level session
--     without one;
--   - when p_matter_id is supplied, the matter must belong to the SAME org
--     and be readable by the caller: assigned client, assigned attorney, the
--     matter's creator, or a partner of that org. An unreadable or cross-org
--     matter is a typed 'permission denied' (no existence oracle);
--   - when p_booking_id is supplied, the booking must belong to the SAME org.
--     consultations carries no organization_id, so the only schema-level
--     association is the booking client's ACTIVE membership in the org; a
--     booking owned by a non-member is denied.
--
-- The room name is generated server-side as 'room_' || 32 lowercase hex
-- characters (the table CHECK is the shape contract), status starts at
-- 'scheduled', and the insert stamps created_by = auth.uid(). The audit row
-- carries a fixed redacted summary — never a room name or the schedule.

create or replace function public.create_video_session(
  p_organization_id uuid,
  p_matter_id       uuid,
  p_booking_id      uuid,
  p_scheduled_at    timestamptz
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_room text;
  v_id   uuid;
begin
  if not public.is_active_member(p_organization_id) then
    raise exception 'permission denied';
  end if;

  if not (public.has_org_role(p_organization_id, 'partner')
          or public.has_org_role(p_organization_id, 'attorney')) then
    raise exception 'permission denied';
  end if;

  if not public.has_org_role(p_organization_id, 'partner')
     and p_matter_id is null then
    raise exception 'permission denied';
  end if;

  if p_matter_id is not null then
    if not exists (
      select 1
        from public.matters m
       where m.id = p_matter_id
         and m.organization_id = p_organization_id
         and (m.assigned_client_id = auth.uid()
              or m.assigned_attorney_id = auth.uid()
              or m.created_by = auth.uid()
              or public.has_org_role(p_organization_id, 'partner'))
    ) then
      raise exception 'permission denied';
    end if;
  end if;

  if p_booking_id is not null then
    if not exists (
      select 1
        from public.consultations c
        join public.memberships m
          on m.user_id = c.client_user_id
         and m.organization_id = p_organization_id
         and m.status = 'active'
       where c.id = p_booking_id
    ) then
      raise exception 'permission denied';
    end if;
  end if;

  if p_scheduled_at is null or p_scheduled_at < now() then
    raise exception 'scheduled_at must be in the future'
      using errcode = 'check_violation';
  end if;

  v_room := 'room_' || replace(gen_random_uuid()::text, '-', '');

  insert into public.video_sessions
    (organization_id, matter_id, booking_id, room_name, provider, status,
     scheduled_at, created_by)
  values
    (p_organization_id, p_matter_id, p_booking_id, v_room, 'livekit', 'scheduled',
     p_scheduled_at, auth.uid())
  returning id into v_id;

  perform public.write_audit(
    'video_session:create', 'allowed',
    p_organization_id  => p_organization_id,
    p_resource_type    => 'video_session',
    p_resource_id      => v_id,
    p_redacted_summary => 'video session created'
  );

  return v_id;
end;
$$;

revoke execute on function public.create_video_session(uuid, uuid, uuid, timestamptz) from public, anon;
grant execute on function public.create_video_session(uuid, uuid, uuid, timestamptz) to authenticated;
