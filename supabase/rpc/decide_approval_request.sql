-- rpc/decide_approval_request.sql — audited approval decision (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §3
--                + docs/superpowers/plans/2026-10-22-approvals.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- Gates, in order (the row is locked FOR UPDATE, so concurrent deciders
-- serialize and each sees the latest status):
--   - the request must exist ('approval request not found');
--   - it must still be pending ('approval request is not pending');
--   - the caller must be a PARTNER of the request's organization — there is
--     no 'admin' org role; the platform owner holds no membership and is
--     denied;
--   - the caller must never be the requester, even as a partner;
--   - the decision must be approved | rejected (check_violation otherwise);
--   - rejected requires a note of at least 2 trimmed characters.
--
-- The status update, the decision event, and the redacted audit row are one
-- transaction. The audit outcome carries the decision value ('approved' or
-- 'rejected'); the summary is fixed and never contains the title or note.

create or replace function public.decide_approval_request(
  p_id       uuid,
  p_decision text,
  p_note     text
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_org       uuid;
  v_status    text;
  v_requester uuid;
  v_note      text;
begin
  select r.organization_id, r.status, r.requested_by
    into v_org, v_status, v_requester
    from public.approval_requests r
   where r.id = p_id
     for update;

  if v_org is null then
    raise exception 'approval request not found';
  end if;
  if v_status <> 'pending' then
    raise exception 'approval request is not pending';
  end if;
  if not public.has_org_role(v_org, 'partner') then
    raise exception 'permission denied';
  end if;
  if v_requester is not null and v_requester = auth.uid() then
    raise exception 'permission denied';
  end if;

  if p_decision is null or p_decision not in ('approved', 'rejected') then
    raise exception 'invalid approval decision' using errcode = 'check_violation';
  end if;

  v_note := nullif(trim(p_note), '');
  if p_decision = 'rejected' and (v_note is null or length(v_note) < 2) then
    raise exception 'a rejection note is required';
  end if;

  update public.approval_requests
     set status        = p_decision,
         decided_by    = auth.uid(),
         decided_at    = now(),
         decision_note = v_note,
         updated_at    = now()
   where id = p_id;

  insert into public.approval_events
    (request_id, organization_id, action, actor_id, note)
  values
    (p_id, v_org, p_decision, auth.uid(), v_note);

  -- §8 audit (contract): the outcome is the decision; the summary is fixed.
  perform public.write_audit(
    'approval:decide', p_decision,
    p_organization_id  => v_org,
    p_resource_type    => 'approval_request',
    p_resource_id      => p_id,
    p_redacted_summary => 'approval request decided'
  );
end;
$$;

revoke execute on function public.decide_approval_request(uuid, text, text) from public, anon;
grant execute on function public.decide_approval_request(uuid, text, text) to authenticated;
