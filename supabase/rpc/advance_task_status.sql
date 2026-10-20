-- rpc/advance_task_status.sql — audited task status advance (NOT APPLIED —
-- rehearsal only)
-- Source of truth: task/approval-writes Gate 3 spec (2026-09-27).
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- Moves one task along its lifecycle. The transition check runs IN-TRANSACTION
-- (the row is locked by the gated select … for update): two concurrent
-- advancers serialize, and each sees the latest status — last-writer-wins
-- on legal moves, never a jump over the lifecycle.
--
-- Legal transitions (client TaskStatus enum-name mapping: in_progress <->
-- inProgress — the status CHECK is the mapping contract):
--   todo        -> in_progress | blocked
--   in_progress -> blocked | done
--   blocked     -> todo | in_progress
--   done        -> (terminal — any advance is refused)
-- Gate: the caller resolves through the task's matter exactly like
-- create_task (active member + assigned). Unknown target statuses and
-- illegal transitions raise with the check_violation errcode (Batch B
-- convention). §8 audit: redacted 'task status advanced' on success only.

create or replace function public.advance_task_status(
  p_task_id    uuid,
  p_to_status  text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_org     uuid;
  v_current text;
  v_allowed boolean := false;
  v_row     jsonb;
begin
  -- Assignment gate through the task's matter (locked row — concurrent
  -- advancers serialize here).
  select m.organization_id, t.status into v_org, v_current
    from public.tasks t
    join public.matters m
      on m.id = t.matter_id
     and m.organization_id = t.organization_id
   where t.id = p_task_id
     and public.is_active_member(m.organization_id)
     and (m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid())
   for update of t;
  if v_org is null then
    raise exception 'permission denied';
  end if;

  if p_to_status is null
     or p_to_status not in ('todo', 'in_progress', 'blocked', 'done') then
    raise exception 'unknown task status' using errcode = 'check_violation';
  end if;

  v_allowed :=
    (v_current = 'todo'        and p_to_status in ('in_progress', 'blocked'))
    or (v_current = 'in_progress' and p_to_status in ('blocked', 'done'))
    or (v_current = 'blocked'     and p_to_status in ('todo', 'in_progress'));
  -- 'done' is terminal: no arm matches, so any advance from done is refused.
  if not v_allowed then
    raise exception 'illegal task status transition' using errcode = 'check_violation';
  end if;

  update public.tasks
     set status = p_to_status,
         updated_at = now()
   where id = p_task_id;

  -- §8 audit (contract): redacted summary only — never the title.
  perform public.write_audit(
    'task:advance', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'task',
    p_resource_id      => p_task_id,
    p_redacted_summary => 'task status advanced'
  );

  -- D-SM2: the persisted row, never the bare status — the client maps it
  -- directly with no follow-up re-read.
  select to_jsonb(t) || jsonb_build_object(
           'matters', jsonb_build_object('title', m.title))
    into v_row
    from public.tasks t
    join public.matters m on m.id = t.matter_id
   where t.id = p_task_id;
  return v_row;
end;
$$;

revoke execute on function public.advance_task_status(uuid, text) from public, anon;
grant execute on function public.advance_task_status(uuid, text) to authenticated;
