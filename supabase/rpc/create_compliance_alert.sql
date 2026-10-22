-- rpc/create_compliance_alert.sql — audited compliance-alert create (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §4
--                + docs/superpowers/plans/2026-10-22-compliance.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- Gates, in order:
--   - the caller must be an ACTIVE MEMBER of p_organization_id
--     (is_active_member) — the org id is a routing hint, membership is
--     re-derived server-side;
--   - the caller must be a PARTNER or a COMPLIANCE OFFICER of that org
--     (there is no 'admin' org role);
--   - kind must be one of the five mapped values and severity one of the four
--     mapped values; title is trimmed and must be 2..160 characters (mirrors
--     the table CHECK, raised with check_violation so client classifiers treat
--     all validation denies identically); description is bounded at 4000;
--   - when p_matter_id is supplied, the matter must exist in the SAME org. A
--     cross-org or unknown matter is a typed 'permission denied' (no
--     existence oracle).
--
-- The insert stamps created_by = auth.uid(), never an argument. The create
-- event and the redacted audit row are written in the same transaction as
-- the insert, so any failure rolls the whole alert back.

create or replace function public.create_compliance_alert(
  p_organization_id uuid,
  p_matter_id       uuid,
  p_kind            text,
  p_severity        text,
  p_title           text,
  p_description     text,
  p_due_at          timestamptz
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_title text;
  v_id    uuid;
begin
  if not public.is_active_member(p_organization_id) then
    raise exception 'permission denied';
  end if;

  if not (public.has_org_role(p_organization_id, 'partner')
          or public.has_org_role(p_organization_id, 'compliance_officer')) then
    raise exception 'permission denied';
  end if;

  if p_kind is null
     or p_kind not in ('deadline', 'conflict', 'retention', 'filing', 'other') then
    raise exception 'invalid compliance alert kind' using errcode = 'check_violation';
  end if;

  if p_severity is null
     or p_severity not in ('low', 'medium', 'high', 'critical') then
    raise exception 'invalid compliance alert severity' using errcode = 'check_violation';
  end if;

  v_title := trim(p_title);
  if v_title is null or length(v_title) < 2 or length(v_title) > 160 then
    raise exception 'compliance alert title must be between 2 and 160 characters'
      using errcode = 'check_violation';
  end if;

  if p_description is not null and length(p_description) > 4000 then
    raise exception 'compliance alert description is too long' using errcode = 'check_violation';
  end if;

  if p_matter_id is not null then
    if not exists (
      select 1
        from public.matters m
       where m.id = p_matter_id
         and m.organization_id = p_organization_id
    ) then
      raise exception 'permission denied';
    end if;
  end if;

  insert into public.compliance_alerts
    (organization_id, matter_id, kind, severity, title, description, due_at, created_by)
  values
    (p_organization_id, p_matter_id, p_kind, p_severity, v_title, p_description,
     p_due_at, auth.uid())
  returning id into v_id;

  insert into public.compliance_alert_events
    (alert_id, organization_id, action, actor_id)
  values
    (v_id, p_organization_id, 'created', auth.uid());

  -- §8 audit (contract): redacted summary only — never the title.
  perform public.write_audit(
    'compliance_alert:create', 'allowed',
    p_organization_id  => p_organization_id,
    p_resource_type    => 'compliance_alert',
    p_resource_id      => v_id,
    p_redacted_summary => 'compliance alert created'
  );

  return v_id;
end;
$$;

revoke execute on function public.create_compliance_alert(uuid, uuid, text, text, text, text, timestamptz) from public, anon;
grant execute on function public.create_compliance_alert(uuid, uuid, text, text, text, text, timestamptz) to authenticated;
