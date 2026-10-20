-- rpc/assign_task.sql — audited task (re-)assignment (NOT APPLIED —
-- rehearsal only)
-- Source of truth: task/approval-writes Gate 3 spec (2026-09-27).
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- Assigns (or, with a null assignee, unassigns) one task. The assignee
-- guards are create_task's F2-D2/F2-D4 verbatim: the platform owner is
-- never assignable, and a non-null assignee must be an ACTIVE MEMBER of
-- the task's org (memberships queried directly — is_active_member() is
-- auth.uid()-self-scoped). Gate: caller resolves through the task's
-- matter (active member + assigned), same as create_task. §8 audit:
-- redacted 'task assigned' on success only.

create or replace function public.assign_task(
  p_task_id     uuid,
  p_assignee_id uuid
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_org   uuid;
  v_owner uuid;
  v_row   jsonb;
begin
  select m.organization_id into v_org
    from public.tasks t
    join public.matters m
      on m.id = t.matter_id
     and m.organization_id = t.organization_id
   where t.id = p_task_id
     and public.is_active_member(m.organization_id)
     and (m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid());
  if v_org is null then
    raise exception 'permission denied';
  end if;

  if p_assignee_id is not null then
    -- F2-D2: the platform owner is never assignable.
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

  -- A new assignee's receipt is outstanding, never inherited: clear the
  -- acknowledgement whenever the assignee actually changes (unassign
  -- included). Re-assigning the same person keeps the existing stamp.
  update public.tasks
     set assignee_id = p_assignee_id,
         acknowledged_at = case
           when assignee_id is distinct from p_assignee_id then null
           else acknowledged_at
         end,
         acknowledged_by = case
           when assignee_id is distinct from p_assignee_id then null
           else acknowledged_by
         end,
         updated_at = now()
   where id = p_task_id;

  -- §8 audit (contract): redacted summary only — never the title/assignee.
  perform public.write_audit(
    'task:assign', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'task',
    p_resource_id      => p_task_id,
    p_redacted_summary => 'task assigned'
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

revoke execute on function public.assign_task(uuid, uuid) from public, anon;
grant execute on function public.assign_task(uuid, uuid) to authenticated;
