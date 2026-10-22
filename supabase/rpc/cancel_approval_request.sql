-- rpc/cancel_approval_request.sql — audited approval cancellation (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §3
--                + docs/superpowers/plans/2026-10-22-approvals.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- Gates (row locked FOR UPDATE):
--   - the request must exist ('approval request not found');
--   - it must still be pending ('approval request is not pending');
--   - the caller is the requester OR a partner of the request's organization
--     ('permission denied' otherwise — another client cannot cancel).
--
-- Cancel is terminal: status becomes 'cancelled', the cancel event and the
-- redacted audit row are written in the same transaction. decided_by /
-- decided_at stay null — cancellation is not a decision.

create or replace function public.cancel_approval_request(
  p_id uuid
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_org       uuid;
  v_status    text;
  v_requester uuid;
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
  if not (v_requester is not null and v_requester = auth.uid())
     and not public.has_org_role(v_org, 'partner') then
    raise exception 'permission denied';
  end if;

  update public.approval_requests
     set status     = 'cancelled',
         updated_at = now()
   where id = p_id;

  insert into public.approval_events
    (request_id, organization_id, action, actor_id)
  values
    (p_id, v_org, 'cancelled', auth.uid());

  -- §8 audit (contract): redacted summary only.
  perform public.write_audit(
    'approval:cancel', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'approval_request',
    p_resource_id      => p_id,
    p_redacted_summary => 'approval request cancelled'
  );
end;
$$;

revoke execute on function public.cancel_approval_request(uuid) from public, anon;
grant execute on function public.cancel_approval_request(uuid) to authenticated;
