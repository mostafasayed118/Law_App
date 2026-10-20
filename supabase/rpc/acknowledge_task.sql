-- rpc/acknowledge_task.sql — audited task acknowledgement (NOT APPLIED —
-- rehearsal only)
-- Source of truth: task/approval-writes Gate 3 spec (2026-09-27).
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- The assignee's "I saw it": stamps acknowledged_at/by on one task.
-- Gate (narrower than the sibling RPCs, by design): the caller must BE the
-- task's assignee AND an active member of the task's org — a non-assignee
-- (even one assigned on the matter) is denied with 'permission denied', so
-- acknowledgement is always a first-person statement. Idempotent: a repeat
-- ack refreshes the stamp and writes another audit row (each ack is a real
-- statement, same as each send is a real message). §8 audit: redacted
-- 'task acknowledged' on success only.

create or replace function public.acknowledge_task(
  p_task_id uuid
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_org uuid;
  v_row jsonb;
begin
  select m.organization_id into v_org
    from public.tasks t
    join public.matters m
      on m.id = t.matter_id
     and m.organization_id = t.organization_id
   where t.id = p_task_id
     and t.assignee_id = auth.uid()
     and public.is_active_member(m.organization_id);
  if v_org is null then
    raise exception 'permission denied';
  end if;

  update public.tasks
     set acknowledged_at = now(),
         acknowledged_by = auth.uid(),
         updated_at = now()
   where id = p_task_id;

  -- §8 audit (contract): redacted summary only.
  perform public.write_audit(
    'task:acknowledge', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'task',
    p_resource_id      => p_task_id,
    p_redacted_summary => 'task acknowledged'
  );

  -- D-SM2: the persisted row, never void — the client maps it directly.
  select to_jsonb(t) || jsonb_build_object(
           'matters', jsonb_build_object('title', m.title))
    into v_row
    from public.tasks t
    join public.matters m on m.id = t.matter_id
   where t.id = p_task_id;
  return v_row;
end;
$$;

revoke execute on function public.acknowledge_task(uuid) from public, anon;
grant execute on function public.acknowledge_task(uuid) to authenticated;
