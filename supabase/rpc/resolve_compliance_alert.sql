-- rpc/resolve_compliance_alert.sql — audited resolution (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §4
--                + docs/superpowers/plans/2026-10-22-compliance.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- Gates (row locked FOR UPDATE):
--   - the alert must exist ('compliance alert not found');
--   - the caller must be an ACTIVE MEMBER of the alert's organization;
--   - the caller must be a PARTNER or COMPLIANCE OFFICER of that org —
--     a client is denied even though it may acknowledge;
--   - a resolved alert raises 'compliance alert is already resolved';
--   - an optional note is trimmed, empty becomes null, and is bounded at 2000
--     characters (check_violation, mirroring the table CHECK).
--
-- Resolution is terminal: status becomes 'resolved', resolved_by/at are
-- stamped from auth.uid()/now(), and the event + redacted audit row are one
-- transaction with the state change. No automated legal verification is
-- claimed anywhere.

create or replace function public.resolve_compliance_alert(
  p_id   uuid,
  p_note text
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_org    uuid;
  v_status text;
  v_note   text;
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
  if not (public.has_org_role(v_org, 'partner')
          or public.has_org_role(v_org, 'compliance_officer')) then
    raise exception 'permission denied';
  end if;

  v_note := nullif(trim(p_note), '');
  if v_note is not null and length(v_note) > 2000 then
    raise exception 'compliance alert note is too long' using errcode = 'check_violation';
  end if;

  update public.compliance_alerts
     set status      = 'resolved',
         resolved_by = auth.uid(),
         resolved_at = now(),
         updated_at  = now()
   where id = p_id;

  insert into public.compliance_alert_events
    (alert_id, organization_id, action, actor_id, note)
  values
    (p_id, v_org, 'resolved', auth.uid(), v_note);

  -- §8 audit (contract): fixed redacted summary; the note never reaches it.
  perform public.write_audit(
    'compliance_alert:resolve', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'compliance_alert',
    p_resource_id      => p_id,
    p_redacted_summary => 'compliance alert resolved'
  );
end;
$$;

revoke execute on function public.resolve_compliance_alert(uuid, text) from public, anon;
grant execute on function public.resolve_compliance_alert(uuid, text) to authenticated;
