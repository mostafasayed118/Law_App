-- rpc/start_research_run.sql — audited research-run start (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §5
--                + docs/superpowers/plans/2026-10-22-research.md Task 3.
-- Backout: rpc/_down.sql / migrations/25_research.down.sql.
--
-- Gates, in order:
--   - the caller must be an ACTIVE MEMBER of p_organization_id;
--   - the caller's org role must be attorney or partner (research authority);
--   - the prompt summary is trimmed and must be 2..500 characters (mirrors
--     the table CHECK);
--   - when p_matter_id is supplied, the matter must belong to the SAME org
--     and be readable by the caller: assigned client, assigned attorney, the
--     matter's creator, or a partner of that org. An unreadable or cross-org
--     matter is a typed 'permission denied' (no existence oracle).
--
-- The insert stamps requested_by = auth.uid() and status 'running'. The audit
-- row carries a fixed redacted summary — never the question/prompt or any
-- document content.

create or replace function public.start_research_run(
  p_organization_id uuid,
  p_matter_id       uuid,
  p_prompt_summary  text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_summary text;
  v_id      uuid;
begin
  if not public.is_active_member(p_organization_id) then
    raise exception 'permission denied';
  end if;

  if not (public.has_org_role(p_organization_id, 'attorney')
          or public.has_org_role(p_organization_id, 'partner')) then
    raise exception 'permission denied';
  end if;

  v_summary := trim(p_prompt_summary);
  if v_summary is null or length(v_summary) < 2 or length(v_summary) > 500 then
    raise exception 'research prompt summary must be between 2 and 500 characters'
      using errcode = 'check_violation';
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

  insert into public.research_runs
    (organization_id, matter_id, requested_by, status, prompt_summary)
  values
    (p_organization_id, p_matter_id, auth.uid(), 'running', v_summary)
  returning id into v_id;

  perform public.write_audit(
    'research:start', 'allowed',
    p_organization_id  => p_organization_id,
    p_resource_type    => 'research_run',
    p_resource_id      => v_id,
    p_redacted_summary => 'research run started'
  );

  return v_id;
end;
$$;

revoke execute on function public.start_research_run(uuid, uuid, text) from public, anon;
grant execute on function public.start_research_run(uuid, uuid, text) to authenticated;
