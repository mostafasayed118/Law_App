-- rpc/complete_research_run.sql — service-role completion of a research run
-- (NOT APPLIED — rehearsal only).
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §5
--                + docs/superpowers/plans/2026-10-22-research.md Task 3.
-- Backout: rpc/_down.sql / migrations/25_research.down.sql.
--
-- SERVICE-ROLE ONLY: the research-analyze Edge Function validates the River
-- output under the caller's JWT, then persists the result here with its
-- service-role client. No client grant exists.
--
-- Rules:
--   - the run must exist and still be 'running' (terminal runs are final);
--   - p_status is exactly 'completed' or 'failed';
--   - a failed run requires a non-empty error code and writes no findings;
--   - a completed run requires a JSON array of 1..12 findings; every finding
--     must carry a non-empty headline/summary, a valid source_type, and a
--     source_id consistent with that type;
--   - findings copy organization_id from the run and are ordered by their
--     array position; the run is updated with status/model/error/completed_at.
--
-- The completion audit row is a machine event (null actor) with a fixed
-- redacted summary — never the question, headline, summary, or excerpt.

create or replace function public.complete_research_run(
  p_run_id     uuid,
  p_status     text,
  p_model      text,
  p_error_code text,
  p_findings   jsonb
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_run             public.research_runs%rowtype;
  v_model           text;
  v_error           text;
  v_count           integer;
  v_index           integer;
  v_item            jsonb;
  v_headline        text;
  v_summary         text;
  v_excerpt         text;
  v_source_type     text;
  v_source_id_text  text;
begin
  select * into v_run
    from public.research_runs
   where id = p_run_id
     for update;

  if not found then
    raise exception 'research run not found';
  end if;

  if v_run.status <> 'running' then
    raise exception 'research run is not running';
  end if;

  if p_status is null or p_status not in ('completed', 'failed') then
    raise exception 'invalid research run status' using errcode = 'check_violation';
  end if;

  v_model := nullif(trim(p_model), '');
  v_error := nullif(trim(p_error_code), '');

  if p_status = 'failed' then
    if v_error is null then
      raise exception 'failed research run requires an error code'
        using errcode = 'check_violation';
    end if;
    if length(v_error) > 100 then
      raise exception 'research run error code is too long'
        using errcode = 'check_violation';
    end if;
  else
    if p_findings is null or jsonb_typeof(p_findings) <> 'array' then
      raise exception 'completed research run requires a findings array'
        using errcode = 'check_violation';
    end if;

    v_count := jsonb_array_length(p_findings);
    if v_count < 1 or v_count > 12 then
      raise exception 'completed research run requires between 1 and 12 findings'
        using errcode = 'check_violation';
    end if;

    for v_index in 0 .. v_count - 1 loop
      v_item := p_findings -> v_index;

      if v_item is null or jsonb_typeof(v_item) <> 'object' then
        raise exception 'research finding % is not an object', v_index + 1
          using errcode = 'check_violation';
      end if;

      if jsonb_typeof(v_item -> 'headline') is distinct from 'string' then
        raise exception 'research finding % requires a headline', v_index + 1
          using errcode = 'check_violation';
      end if;
      v_headline := trim(v_item ->> 'headline');
      if v_headline is null or length(v_headline) < 2 or length(v_headline) > 200 then
        raise exception 'research finding % headline must be between 2 and 200 characters', v_index + 1
          using errcode = 'check_violation';
      end if;

      if jsonb_typeof(v_item -> 'summary') is distinct from 'string' then
        raise exception 'research finding % requires a summary', v_index + 1
          using errcode = 'check_violation';
      end if;
      v_summary := trim(v_item ->> 'summary');
      if v_summary is null or length(v_summary) < 2 or length(v_summary) > 4000 then
        raise exception 'research finding % summary must be between 2 and 4000 characters', v_index + 1
          using errcode = 'check_violation';
      end if;

      if v_item ? 'excerpt'
         and jsonb_typeof(v_item -> 'excerpt') not in ('string', 'null') then
        raise exception 'research finding % excerpt must be a string or null', v_index + 1
          using errcode = 'check_violation';
      end if;
      v_excerpt := v_item ->> 'excerpt';
      if v_excerpt is not null and length(v_excerpt) > 2000 then
        raise exception 'research finding % excerpt is too long', v_index + 1
          using errcode = 'check_violation';
      end if;

      if v_item ? 'source_type'
         and jsonb_typeof(v_item -> 'source_type') not in ('string', 'null') then
        raise exception 'research finding % source_type must be a string or null', v_index + 1
          using errcode = 'check_violation';
      end if;
      v_source_type := coalesce(nullif(trim(v_item ->> 'source_type'), ''), 'none');
      if v_source_type not in ('document', 'matter', 'none') then
        raise exception 'invalid research finding source_type' using errcode = 'check_violation';
      end if;

      if v_item ? 'source_id'
         and jsonb_typeof(v_item -> 'source_id') not in ('string', 'null') then
        raise exception 'research finding % source_id must be a string or null', v_index + 1
          using errcode = 'check_violation';
      end if;
      v_source_id_text := nullif(trim(v_item ->> 'source_id'), '');
      if v_source_id_text is not null
         and v_source_id_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        raise exception 'research finding % source_id is not a uuid', v_index + 1
          using errcode = 'check_violation';
      end if;
      if v_source_type = 'none' and v_source_id_text is not null then
        raise exception 'research finding % cites an id with source_type none', v_index + 1
          using errcode = 'check_violation';
      end if;
      if v_source_type in ('document', 'matter') and v_source_id_text is null then
        raise exception 'research finding % requires a source_id', v_index + 1
          using errcode = 'check_violation';
      end if;
    end loop;

    for v_index in 0 .. v_count - 1 loop
      v_item := p_findings -> v_index;
      insert into public.research_findings
        (run_id, organization_id, headline, summary, excerpt,
         source_type, source_id, sort_order)
      values (
        p_run_id,
        v_run.organization_id,
        trim(v_item ->> 'headline'),
        trim(v_item ->> 'summary'),
        v_item ->> 'excerpt',
        coalesce(nullif(trim(v_item ->> 'source_type'), ''), 'none'),
        case
          when nullif(trim(v_item ->> 'source_id'), '') is null then null
          else (v_item ->> 'source_id')::uuid
        end,
        v_index
      );
    end loop;
  end if;

  update public.research_runs
     set status       = p_status,
         model        = v_model,
         error_code   = v_error,
         completed_at = now()
   where id = p_run_id;

  perform public.write_audit(
    'research:complete', 'allowed',
    p_organization_id  => v_run.organization_id,
    p_resource_type    => 'research_run',
    p_resource_id      => p_run_id,
    p_redacted_summary => case
                            when p_status = 'completed' then 'research run completed'
                            else 'research run failed'
                          end,
    p_actor            => null
  );
end;
$$;

revoke execute on function public.complete_research_run(uuid, text, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.complete_research_run(uuid, text, text, text, jsonb)
  to service_role;
