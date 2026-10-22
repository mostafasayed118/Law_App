-- rpc/acknowledge_compliance_alert.sql — audited acknowledgement (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §4
--                + docs/superpowers/plans/2026-10-22-compliance.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- Gates (row locked FOR UPDATE, so concurrent acknowledgers serialize):
--   - the alert must exist ('compliance alert not found');
--   - the caller must be an ACTIVE MEMBER of the alert's organization —
--     acknowledgement is deliberately broader than create/resolve;
--   - the alert must still be 'open'; a resolved alert raises the typed
--     terminal error and an acknowledged one raises its own typed error.
--
-- acknowledged_by / acknowledged_at are stamped from auth.uid()/now(), never
-- from arguments. The event and the redacted audit row are one transaction
-- with the state change. There is no automated legal verification here or
-- anywhere else in this slice.

create or replace function public.acknowledge_compliance_alert(
  p_id uuid
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_org    uuid;
  v_status text;
begin
  select a.organization_id, a.status
    into v_org, v_status
    from public.compliance_alerts a
   where a.id = p_id
     for update;

  if v_org is null then
    raise exception 'compliance alert not found';
  end if;
  if not public.is_active_member(v_org) then
    raise exception 'permission denied';
  end if;
  if v_status = 'resolved' then
    raise exception 'compliance alert is already resolved';
  end if;
  if v_status = 'acknowledged' then
    raise exception 'compliance alert is already acknowledged';
  end if;

  update public.compliance_alerts
     set status          = 'acknowledged',
         acknowledged_by = auth.uid(),
         acknowledged_at = now(),
         updated_at      = now()
   where id = p_id;

  insert into public.compliance_alert_events
    (alert_id, organization_id, action, actor_id)
  values
    (p_id, v_org, 'acknowledged', auth.uid());

  -- §8 audit (contract): fixed redacted summary.
  perform public.write_audit(
    'compliance_alert:acknowledge', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'compliance_alert',
    p_resource_id      => p_id,
    p_redacted_summary => 'compliance alert acknowledged'
  );
end;
$$;

revoke execute on function public.acknowledge_compliance_alert(uuid) from public, anon;
grant execute on function public.acknowledge_compliance_alert(uuid) to authenticated;
