-- rpc/create_task.sql — audited task create (NOT APPLIED — rehearsal only)
-- Source of truth: task/approval-writes Gate 3 spec (2026-09-27).
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- The task board's first WRITE path (the board was a read-only synthetic
-- surface): creates a matter-scoped task in status 'todo', with an optional
-- assignee. Follows the create_matter (F2) + send_message (D-SM) precedents:
--   gate — the caller must resolve through the matter with the org equality
--          AND be an active member of the matter's org AND be assigned
--          (client or attorney) on the matter (the send_message D-SM1 shape
--          minus one hop: task -> matter directly). An unreadable matter =
--          typed denial (Q4: no existence oracle).
--   F2-D4 — an assignee must be an ACTIVE MEMBER of the org
--          (dead-assignment guard — queries public.memberships directly,
--          NOT is_active_member(), which is auth.uid()-self-scoped).
--   F2-D2 — the platform owner is never assignable (derived from
--          platform_config, self-updating, the battery-12 pattern).
--   validation — title trimmed non-empty (mirror create_matter), raised
--          with the check_violation errcode (the Batch B send_message
--          convention — the SQLSTATE matches the title CHECK mapping
--          contract, so client classifiers treat all validation denies
--          identically).
--
-- §8 audit: every successful create writes a redacted summary ('task
-- created' — never the title), same implicit transaction as the insert.

create or replace function public.create_task(
  p_matter_id    uuid,
  p_title        text,
  p_assignee_id  uuid default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_org  uuid;
  v_task uuid;
  v_owner uuid;
  v_row  jsonb;
begin
  -- Assignment gate: the matter must resolve with org equality AND the
  -- caller active + assigned (the send_message D-SM1 shape, one hop).
  select m.organization_id into v_org
    from public.matters m
   where m.id = p_matter_id
     and public.is_active_member(m.organization_id)
     and (m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid());
  if v_org is null then
    raise exception 'permission denied';
  end if;

  if p_title is null or trim(p_title) = '' then
    raise exception 'task title is required' using errcode = 'check_violation';
  end if;

  -- F2-D2: the platform owner is never assignable.
  if p_assignee_id is not null then
    select owner_user_id into v_owner from public.platform_config limit 1;
    if p_assignee_id = v_owner then
      raise exception 'platform owner cannot be assigned to a task' using errcode = 'check_violation';
    end if;

    -- F2-D4: the assignee must be an active member of the org.
    if not exists (
      select 1 from public.memberships
       where organization_id = v_org
         and user_id = p_assignee_id
         and status = 'active'
    ) then
      raise exception 'assignee must be an active member of the organization' using errcode = 'check_violation';
    end if;
  end if;

  insert into public.tasks
    (organization_id, matter_id, title, status, assignee_id)
  values
    (v_org, p_matter_id, trim(p_title), 'todo', p_assignee_id)
  returning id into v_task;

  -- §8 audit (contract): redacted summary only — never the title.
  perform public.write_audit(
    'task:create', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'task',
    p_resource_id      => v_task,
    p_redacted_summary => 'task created'
  );

  -- D-SM2: return the persisted row (plus the embedded matter title the
  -- client's read projection carries), never a bare id — the gateway maps
  -- the response directly with no follow-up re-read.
  select to_jsonb(t) || jsonb_build_object(
           'matters', jsonb_build_object('title', m.title))
    into v_row
    from public.tasks t
    join public.matters m on m.id = t.matter_id
   where t.id = v_task;
  return v_row;
end;
$$;

revoke execute on function public.create_task(uuid, text, uuid) from public, anon;
grant execute on function public.create_task(uuid, text, uuid) to authenticated;
