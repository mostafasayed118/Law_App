-- ============================================================================
-- supabase/tests/25_research_rls.sql — research runs + findings battery
--
-- Pins the research slice (supabase/migrations/25_research.sql +
-- supabase/policies/research_runs.sql + research_findings.sql + the four
-- supabase/rpc/*research* functions):
--   - partner and attorney start positives with the redacted research:start
--     audit rows and the trimmed prompt summary (25.01-25.02);
--   - client / suspended / owner / anon start denials; cross-org matter
--     denial; prompt-summary validation (25.03-25.08);
--   - list scoping and newest-first ordering for runs; active-member reads
--     for findings; cross-org list denials; direct-select scoping
--     (25.09-25.11);
--   - authenticated cannot execute the service-role completion RPC (25.12);
--   - service-role completion inserts findings + updates the run + writes a
--     machine-actor research:complete audit row (25.13);
--   - completed with an empty / oversized / malformed findings array denied;
--     failed without an error code denied; invalid status denied
--     (25.14-25.17, 25.20);
--   - failed completion with an error code persists the honest state
--     (25.18);
--   - terminal runs cannot be completed twice (25.19);
--   - direct INSERT/UPDATE/DELETE denied at the privilege layer for both
--     tables (25.21);
--   - structural posture: RLS on, SELECT-only grants, one read policy each,
--     all four functions SECURITY DEFINER + pinned search_path + no
--     parameter defaults, authenticated/anon/service-role EXECUTE surface
--     (25.22);
--   - final audit/finding census with fixed redacted summaries and no prompt
--     content (25.23).
--
-- The whole battery runs in ONE transaction and ROLLS BACK. Fixture anchors
-- (00_fixtures.sql): owner …0001 (platform owner, no membership) · partner-a
-- …0002 (org-a partner, active) · client-a …0003 (org-a client, active) ·
-- partner-b …0004 (org-b partner, active) · suspended-a …0005 (org-a
-- membership suspended) · orphan …0007 (org-a client, active) · org-a
-- 20000000-…-0001 · org-b 20000000-…-0002 · matter 1 40000000-…-0001
-- (org-a, partner-a assigned) · matter 5 40000000-…-0005 (org-a, partner-b
-- assigned — cross-org anchor) · document 1 50000000-…-0001 (matter 1).
--
-- Role handling: every behavior block runs under `set role authenticated`
-- with JWT impersonation (the 01/02/03 pattern); the service-role completion
-- positive runs under `set role service_role`; verification and the seeded
-- rows run as the connection role (authenticated holds no write grant).
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 25.00 — POS (setup): a generated attorney (active, org-a) with a generated
-- matter assigned to them, plus two synthetic completed runs with findings
-- (one org-a, one org-b) at fixed 2001 timestamps. Seeds are written as the
-- connection role and roll back with the battery.
-- ############################################################################
do $$
declare
  v_attorney uuid := gen_random_uuid();
  v_matter   uuid;
  v_seed_a   uuid;
  v_seed_b   uuid;
begin
  insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, created_at, updated_at)
  values (v_attorney, 'research-attorney-' || v_attorney::text || '@org-a.test', now(),
          '{"display_name":"Research Attorney"}', now(), now());

  insert into public.memberships
    (organization_id, user_id, role, status, created_by, created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001', v_attorney, 'attorney',
     'active', v_attorney, now(), now());

  insert into public.matters
    (organization_id, title, practice_area, status, assigned_attorney_id, created_by, created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001', 'Battery research matter', 'civil', 'open',
     v_attorney, v_attorney, now(), now())
  returning id into v_matter;

  insert into public.research_runs
    (organization_id, status, model, prompt_summary, created_at, completed_at)
  values
    ('20000000-0000-4000-8000-000000000001', 'completed', 'battery-seed-model',
     'Battery seeded org-a run', '2001-01-02T00:00:00Z', '2001-01-02T00:05:00Z')
  returning id into v_seed_a;

  insert into public.research_findings
    (run_id, organization_id, headline, summary, excerpt, source_type, source_id, sort_order, created_at)
  values
    (v_seed_a, '20000000-0000-4000-8000-000000000001',
     'Battery seeded finding two', 'Battery seeded summary two', null, 'none', null,
     1, '2001-01-02T00:04:00Z'),
    (v_seed_a, '20000000-0000-4000-8000-000000000001',
     'Battery seeded finding one', 'Battery seeded summary one', 'Battery seeded excerpt',
     'matter', '40000000-0000-4000-8000-000000000001', 0, '2001-01-02T00:03:00Z');

  insert into public.research_runs
    (organization_id, status, model, prompt_summary, created_at, completed_at)
  values
    ('20000000-0000-4000-8000-000000000002', 'completed', 'battery-seed-model',
     'Battery seeded org-b run', '2001-01-01T00:00:00Z', '2001-01-01T00:05:00Z')
  returning id into v_seed_b;

  insert into public.research_findings
    (run_id, organization_id, headline, summary, excerpt, source_type, source_id, sort_order, created_at)
  values
    (v_seed_b, '20000000-0000-4000-8000-000000000002',
     'Battery seeded org-b finding', 'Battery seeded org-b summary', null, 'none', null,
     0, '2001-01-01T00:04:00Z');

  perform set_config('battery25.attorney', v_attorney::text, true);
  perform set_config('battery25.matter', v_matter::text, true);
  perform set_config('battery25.seed_a', v_seed_a::text, true);
  perform set_config('battery25.seed_b', v_seed_b::text, true);
end $$;

do $$
declare
  v_runs     bigint;
  v_findings bigint;
begin
  select count(*) into v_runs from public.research_runs;
  select count(*) into v_findings from public.research_findings;
  if v_runs <> 2 or v_findings <> 3 then
    raise exception 'POLICY-BATTERY FAIL 25.00: seeded runs/findings = %/%, want 2/3', v_runs, v_findings;
  end if;
end $$;

-- ############################################################################
-- 25.01 — POS (partner start, no matter): partner-a starts a run. The row,
-- trim, creator stamp and the redacted research:start audit row are verified.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_id := public.start_research_run(
    '20000000-0000-4000-8000-000000000001',
    null,
    '  Battery partner research question  ');
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 25.01: start_research_run returned a null id';
  end if;
  perform set_config('battery25.run_a', v_id::text, true);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery25.run_a')::uuid;
  v_row    public.research_runs;
  v_audits bigint;
  v_bad    bigint;
begin
  select * into v_row from public.research_runs where id = v_id;
  if not found then
    raise exception 'POLICY-BATTERY FAIL 25.01: started run row missing';
  end if;
  if v_row.organization_id <> '20000000-0000-4000-8000-000000000001'
     or v_row.matter_id is not null
     or v_row.requested_by is distinct from '10000000-0000-4000-8000-000000000002'
     or v_row.status <> 'running'
     or v_row.model is not null
     or v_row.prompt_summary <> 'Battery partner research question'
     or v_row.error_code is not null
     or v_row.completed_at is not null then
    raise exception 'POLICY-BATTERY FAIL 25.01: started row shape/trim drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_audits
    from public.audit_events
   where action = 'research:start'
     and outcome = 'allowed'
     and resource_type = 'research_run'
     and resource_id = v_id;
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.01: research:start audit rows = %, want 1', v_audits;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action = 'research:start'
     and resource_id = v_id
     and (organization_id is distinct from '20000000-0000-4000-8000-000000000001'
          or actor_user_id is distinct from '10000000-0000-4000-8000-000000000002'
          or redacted_summary is distinct from 'research run started'
          or redacted_summary like '%Battery%'
          or redacted_summary like '%question%');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.01: research:start audit row drift/leak (%)', v_bad;
  end if;
end $$;

-- ############################################################################
-- 25.02 — POS (attorney start, matter-linked): the generated attorney starts
-- a run on the generated matter assigned to them.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', current_setting('battery25.attorney'), false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('battery25.attorney'))::text, false);
  v_id := public.start_research_run(
    '20000000-0000-4000-8000-000000000001',
    current_setting('battery25.matter')::uuid,
    'Battery attorney research question');
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 25.02: attorney start returned a null id';
  end if;
  perform set_config('battery25.run_attorney', v_id::text, true);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery25.run_attorney')::uuid;
  v_row    public.research_runs;
  v_audits bigint;
begin
  select * into v_row from public.research_runs where id = v_id;
  if not found then
    raise exception 'POLICY-BATTERY FAIL 25.02: attorney run row missing';
  end if;
  if v_row.organization_id <> '20000000-0000-4000-8000-000000000001'
     or v_row.matter_id is distinct from current_setting('battery25.matter')::uuid
     or v_row.requested_by is distinct from current_setting('battery25.attorney')::uuid
     or v_row.status <> 'running'
     or v_row.prompt_summary <> 'Battery attorney research question' then
    raise exception 'POLICY-BATTERY FAIL 25.02: attorney row shape drift: %', row_to_json(v_row);
  end if;
  select count(*) into v_audits
    from public.audit_events where action = 'research:start' and outcome = 'allowed';
  if v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 25.02: research:start audits = %, want 2', v_audits;
  end if;
end $$;

-- ############################################################################
-- 25.03 — NEG (client start): client-a is an active org-a member but holds
-- neither research role. No run and no audit row is written.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.start_research_run(
      '20000000-0000-4000-8000-000000000001', null, 'Battery client research question');
    raise exception 'POLICY-BATTERY FAIL 25.03: client start succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 25.03: client start raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_runs   bigint;
  v_audits bigint;
begin
  select count(*) into v_runs from public.research_runs;
  select count(*) into v_audits
    from public.audit_events where action = 'research:start' and outcome = 'allowed';
  if v_runs <> 4 or v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 25.03: denied client start changed counts (runs %, audits %)', v_runs, v_audits;
  end if;
end $$;

-- ############################################################################
-- 25.04 — NEG (suspended member): suspended-a holds a SUSPENDED org-a
-- membership. Start and list both raise, and the direct select policy
-- exposes zero rows.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  begin
    perform public.start_research_run(
      '20000000-0000-4000-8000-000000000001', null, 'Battery suspended research question');
    raise exception 'POLICY-BATTERY FAIL 25.04: suspended start succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 25.04: suspended start raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.list_research_runs('20000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 25.04: suspended list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 25.04: suspended list raised "%"', sqlerrm;
    end if;
  end;

  select count(*) into v_cnt from public.research_runs;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.04: suspended caller sees % run rows, want 0', v_cnt;
  end if;
  select count(*) into v_cnt from public.research_findings;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.04: suspended caller sees % finding rows, want 0', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 25.05 — NEG (platform owner / no membership): the owner holds no org
-- membership and is denied.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.start_research_run(
      '20000000-0000-4000-8000-000000000001', null, 'Battery owner research question');
    raise exception 'POLICY-BATTERY FAIL 25.05: owner start succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 25.05: owner start raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- ############################################################################
-- 25.06 — NEG (unauthenticated): anon holds no EXECUTE grant and no table
-- grant, so the RPC calls and direct reads fail at the privilege layer.
-- ############################################################################
set role anon;
do $$
begin
  begin
    perform public.start_research_run(
      '20000000-0000-4000-8000-000000000001', null, 'Battery anon research question');
    raise exception 'POLICY-BATTERY FAIL 25.06: anon start succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform public.list_research_runs('20000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 25.06: anon list runs succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform public.complete_research_run(
      gen_random_uuid(), 'failed', null, 'provider_unavailable', null);
    raise exception 'POLICY-BATTERY FAIL 25.06: anon complete succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform count(*) from public.research_runs;
    raise exception 'POLICY-BATTERY FAIL 25.06: anon run select succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform count(*) from public.research_findings;
    raise exception 'POLICY-BATTERY FAIL 25.06: anon finding select succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

-- ############################################################################
-- 25.07 — NEG (cross-org matter): partner-b is an org-b partner and names
-- org-a matter 5 in an org-b start. The same-org clause denies it; no run
-- and no audit row is written.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    perform public.start_research_run(
      '20000000-0000-4000-8000-000000000002',
      '40000000-0000-4000-8000-000000000005',
      'Battery cross-org research question');
    raise exception 'POLICY-BATTERY FAIL 25.07: cross-org matter start succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 25.07: cross-org start raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_runs   bigint;
  v_audits bigint;
begin
  select count(*) into v_runs from public.research_runs;
  select count(*) into v_audits
    from public.audit_events where action = 'research:start' and outcome = 'allowed';
  if v_runs <> 4 or v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 25.07: denied cross-org start changed counts (runs %, audits %)', v_runs, v_audits;
  end if;
end $$;

-- ############################################################################
-- 25.08 — NEG (prompt validation): a one-character and a 501-character
-- prompt summary both raise check_violation.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.start_research_run(
      '20000000-0000-4000-8000-000000000001', null, ' A ');
    raise exception 'POLICY-BATTERY FAIL 25.08: one-character prompt succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.start_research_run(
      '20000000-0000-4000-8000-000000000001', null, repeat('x', 501));
    raise exception 'POLICY-BATTERY FAIL 25.08: 501-character prompt succeeded';
  exception when check_violation then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_runs bigint;
begin
  select count(*) into v_runs from public.research_runs;
  if v_runs <> 4 then
    raise exception 'POLICY-BATTERY FAIL 25.08: invalid prompts left % runs, want 4', v_runs;
  end if;
end $$;

-- ############################################################################
-- 25.09 — POS (run listing + scoping + ordering): partner-a, client-a and the
-- attorney read the three org-a runs; partner-b reads only the org-b seed.
-- The newest-first tail is the 2001 seed.
-- ############################################################################
set role authenticated;
do $$
declare
  v_total bigint;
  v_first uuid;
  v_last  uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);

  select count(*) into v_total
    from public.list_research_runs('20000000-0000-4000-8000-000000000001');
  if v_total <> 3 then
    raise exception 'POLICY-BATTERY FAIL 25.09: partner-a org-a list returned %, want 3', v_total;
  end if;
  select count(*) into v_total
    from public.list_research_runs('20000000-0000-4000-8000-000000000001')
   where organization_id <> '20000000-0000-4000-8000-000000000001';
  if v_total <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.09: org-a list exposed % cross-org rows', v_total;
  end if;

  select id into v_first
    from public.list_research_runs('20000000-0000-4000-8000-000000000001')
   order by created_at desc, id desc
   limit 1;
  select id into v_last
    from public.list_research_runs('20000000-0000-4000-8000-000000000001')
   order by created_at desc, id desc
   offset 2 limit 1;
  if v_first not in (current_setting('battery25.run_a')::uuid,
                     current_setting('battery25.run_attorney')::uuid)
     or v_last is distinct from current_setting('battery25.seed_a')::uuid then
    raise exception 'POLICY-BATTERY FAIL 25.09: run list is not newest-first (first % / last %)', v_first, v_last;
  end if;

  select count(*) into v_total from public.research_runs;
  if v_total <> 3 then
    raise exception 'POLICY-BATTERY FAIL 25.09: direct org-a run select returned %, want 3', v_total;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_total
    from public.list_research_runs('20000000-0000-4000-8000-000000000001');
  if v_total <> 3 then
    raise exception 'POLICY-BATTERY FAIL 25.09: client-a sees % org-a runs, want 3', v_total;
  end if;

  perform set_config('request.jwt.claim.sub', current_setting('battery25.attorney'), false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('battery25.attorney'))::text, false);
  select count(*) into v_total
    from public.list_research_runs('20000000-0000-4000-8000-000000000001');
  if v_total <> 3 then
    raise exception 'POLICY-BATTERY FAIL 25.09: attorney sees % org-a runs, want 3', v_total;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_total
    from public.list_research_runs('20000000-0000-4000-8000-000000000002');
  if v_total <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.09: partner-b sees % org-b runs, want 1', v_total;
  end if;
  select count(*) into v_total from public.research_runs;
  if v_total <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.09: direct org-b run select returned %, want 1', v_total;
  end if;
end $$;
reset role;

-- ############################################################################
-- 25.10 — NEG (cross-org list): partner-a and client-a are active org-a
-- members but hold no org-b membership — listing org-b raises.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.list_research_runs('20000000-0000-4000-8000-000000000002');
    raise exception 'POLICY-BATTERY FAIL 25.10: partner-a cross-org list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 25.10: partner-a cross-org list raised "%"', sqlerrm;
    end if;
  end;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.list_research_runs('20000000-0000-4000-8000-000000000002');
    raise exception 'POLICY-BATTERY FAIL 25.10: client-a cross-org list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 25.10: client-a cross-org list raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- ############################################################################
-- 25.11 — POS/NEG (findings read scoping): org-a members read the seeded
-- findings in sort_order; partner-b is denied the org-a run and reads its
-- own org-b finding. A missing run raises the typed not-found.
-- ############################################################################
set role authenticated;
do $$
declare
  v_total  bigint;
  v_first  uuid;
  v_second uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);

  select count(*) into v_total
    from public.list_research_findings(current_setting('battery25.seed_a')::uuid);
  if v_total <> 2 then
    raise exception 'POLICY-BATTERY FAIL 25.11: partner-a seed-a findings = %, want 2', v_total;
  end if;

  select id into v_first
    from public.list_research_findings(current_setting('battery25.seed_a')::uuid)
   order by sort_order asc, id asc
   limit 1;
  select id into v_second
    from public.list_research_findings(current_setting('battery25.seed_a')::uuid)
   order by sort_order asc, id asc
   offset 1 limit 1;
  if v_first is null or v_second is null or v_first = v_second then
    raise exception 'POLICY-BATTERY FAIL 25.11: finding ordering is not distinct';
  end if;
  if (select sort_order from public.research_findings where id = v_first) <> 0
     or (select sort_order from public.research_findings where id = v_second) <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.11: findings are not ordered by sort_order';
  end if;

  select count(*) into v_total from public.research_findings;
  if v_total <> 2 then
    raise exception 'POLICY-BATTERY FAIL 25.11: direct org-a finding select returned %, want 2', v_total;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_total
    from public.list_research_findings(current_setting('battery25.seed_a')::uuid);
  if v_total <> 2 then
    raise exception 'POLICY-BATTERY FAIL 25.11: client-a seed-a findings = %, want 2', v_total;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    perform public.list_research_findings(current_setting('battery25.seed_a')::uuid);
    raise exception 'POLICY-BATTERY FAIL 25.11: partner-b read org-a findings';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 25.11: cross-org findings read raised "%"', sqlerrm;
    end if;
  end;

  select count(*) into v_total
    from public.list_research_findings(current_setting('battery25.seed_b')::uuid);
  if v_total <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.11: partner-b seed-b findings = %, want 1', v_total;
  end if;
  select count(*) into v_total from public.research_findings;
  if v_total <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.11: direct org-b finding select returned %, want 1', v_total;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.list_research_findings(gen_random_uuid());
    raise exception 'POLICY-BATTERY FAIL 25.11: missing-run findings read succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'research run not found' then
      raise exception 'POLICY-BATTERY FAIL 25.11: missing-run read raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- ############################################################################
-- 25.12 — NEG (authenticated completion): authenticated holds no EXECUTE on
-- complete_research_run; the run stays running and no audit row appears.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.complete_research_run(
      current_setting('battery25.run_a')::uuid,
      'completed', 'battery-model', null,
      jsonb_build_array(jsonb_build_object(
        'headline', 'Battery denied finding',
        'summary', 'Battery denied summary',
        'source_type', 'none',
        'source_id', null)));
    raise exception 'POLICY-BATTERY FAIL 25.12: authenticated completion succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_status text;
  v_find   bigint;
  v_audits bigint;
begin
  select status into v_status from public.research_runs
   where id = current_setting('battery25.run_a')::uuid;
  select count(*) into v_find from public.research_findings;
  select count(*) into v_audits
    from public.audit_events where action = 'research:complete';
  if v_status <> 'running' or v_find <> 3 or v_audits <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.12: denied completion changed state (status %, findings %, audits %)',
      v_status, v_find, v_audits;
  end if;
end $$;

-- ############################################################################
-- 25.13 — POS (service-role completion): complete run_a with two findings.
-- The run flips to completed, findings copy the run's organization and keep
-- array order, and the research:complete audit row is a machine event with a
-- fixed redacted summary.
-- ############################################################################
set role service_role;
do $$
begin
  perform public.complete_research_run(
    current_setting('battery25.run_a')::uuid,
    'completed',
    'deepseek-test',
    null,
    jsonb_build_array(
      jsonb_build_object(
        'headline', '  Battery completed finding one  ',
        'summary', '  Battery completed summary one  ',
        'excerpt', 'Battery completed excerpt one',
        'source_type', 'document',
        'source_id', '50000000-0000-4000-8000-000000000001'),
      jsonb_build_object(
        'headline', 'Battery completed finding two',
        'summary', 'Battery completed summary two',
        'excerpt', null,
        'source_type', 'none',
        'source_id', null)));
end $$;
reset role;

do $$
declare
  v_id      uuid := current_setting('battery25.run_a')::uuid;
  v_row     public.research_runs;
  v_find    bigint;
  v_bad     bigint;
  v_audits  bigint;
begin
  select * into v_row from public.research_runs where id = v_id;
  if v_row.status <> 'completed'
     or v_row.model <> 'deepseek-test'
     or v_row.error_code is not null
     or v_row.completed_at is null then
    raise exception 'POLICY-BATTERY FAIL 25.13: completed run shape drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_find from public.research_findings where run_id = v_id;
  if v_find <> 2 then
    raise exception 'POLICY-BATTERY FAIL 25.13: completed run findings = %, want 2', v_find;
  end if;

  select count(*) into v_bad
    from public.research_findings
   where run_id = v_id
     and (organization_id is distinct from '20000000-0000-4000-8000-000000000001'
          or sort_order not in (0, 1)
          or headline like ' %'
          or summary like ' %');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.13: completed finding row drift (%)', v_bad;
  end if;

  if (select sort_order from public.research_findings where run_id = v_id and source_type = 'document') <> 0
     or (select source_id from public.research_findings where run_id = v_id and source_type = 'document')
        is distinct from '50000000-0000-4000-8000-000000000001'
     or (select headline from public.research_findings where run_id = v_id and source_type = 'document')
        is distinct from 'Battery completed finding one'
     or (select summary from public.research_findings where run_id = v_id and source_type = 'document')
        is distinct from 'Battery completed summary one' then
    raise exception 'POLICY-BATTERY FAIL 25.13: document finding order/source/trim drift';
  end if;
  if (select sort_order from public.research_findings where run_id = v_id and source_type = 'none') <> 1
     or (select source_id from public.research_findings where run_id = v_id and source_type = 'none')
        is not null
     or (select headline from public.research_findings where run_id = v_id and source_type = 'none')
        is distinct from 'Battery completed finding two' then
    raise exception 'POLICY-BATTERY FAIL 25.13: none finding order/source/trim drift';
  end if;

  select count(*) into v_audits
    from public.audit_events
   where action = 'research:complete' and resource_id = v_id;
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.13: research:complete audit rows = %, want 1', v_audits;
  end if;
  select count(*) into v_bad
    from public.audit_events
   where action = 'research:complete'
     and resource_id = v_id
     and (outcome <> 'allowed'
          or actor_user_id is not null
          or organization_id is distinct from '20000000-0000-4000-8000-000000000001'
          or resource_type is distinct from 'research_run'
          or redacted_summary is distinct from 'research run completed'
          or redacted_summary like '%Battery%');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.13: research:complete audit drift/leak (%)', v_bad;
  end if;
end $$;

-- ############################################################################
-- 25.14 — NEG (empty findings): a new running run cannot complete with an
-- empty array; it stays running with no findings and no completion audit.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_id := public.start_research_run(
    '20000000-0000-4000-8000-000000000001', null, 'Battery empty findings question');
  perform set_config('battery25.run_b', v_id::text, true);
end $$;
reset role;

set role service_role;
do $$
begin
  begin
    perform public.complete_research_run(
      current_setting('battery25.run_b')::uuid, 'completed', 'battery-model', null, '[]'::jsonb);
    raise exception 'POLICY-BATTERY FAIL 25.14: empty findings completion succeeded';
  exception when check_violation then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_row    public.research_runs;
  v_find   bigint;
  v_audits bigint;
begin
  select * into v_row from public.research_runs
   where id = current_setting('battery25.run_b')::uuid;
  select count(*) into v_find from public.research_findings;
  select count(*) into v_audits
    from public.audit_events where action = 'research:complete';
  if v_row.status <> 'running' or v_find <> 5 or v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.14: empty completion changed state (status %, findings %, audits %)',
      v_row.status, v_find, v_audits;
  end if;
end $$;

-- ############################################################################
-- 25.15 — NEG (too many findings): 13 findings exceed the 1..12 cap.
-- ############################################################################
set role service_role;
do $$
declare
  v_many jsonb;
begin
  select jsonb_agg(jsonb_build_object(
           'headline', 'Battery finding ' || n,
           'summary', 'Battery summary ' || n,
           'excerpt', null,
           'source_type', 'none',
           'source_id', null))
    into v_many
    from generate_series(1, 13) as n;

  begin
    perform public.complete_research_run(
      current_setting('battery25.run_b')::uuid, 'completed', 'battery-model', null, v_many);
    raise exception 'POLICY-BATTERY FAIL 25.15: 13-finding completion succeeded';
  exception when check_violation then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_status text;
  v_find   bigint;
begin
  select status into v_status from public.research_runs
   where id = current_setting('battery25.run_b')::uuid;
  select count(*) into v_find from public.research_findings;
  if v_status <> 'running' or v_find <> 5 then
    raise exception 'POLICY-BATTERY FAIL 25.15: oversized completion changed state (status %, findings %)',
      v_status, v_find;
  end if;
end $$;

-- ############################################################################
-- 25.16 — NEG (malformed finding): an empty headline and a document finding
-- without a source_id are both check_violation.
-- ############################################################################
set role service_role;
do $$
begin
  begin
    perform public.complete_research_run(
      current_setting('battery25.run_b')::uuid, 'completed', 'battery-model', null,
      jsonb_build_array(jsonb_build_object(
        'headline', '', 'summary', 'Battery summary', 'source_type', 'none', 'source_id', null)));
    raise exception 'POLICY-BATTERY FAIL 25.16: empty-headline completion succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.complete_research_run(
      current_setting('battery25.run_b')::uuid, 'completed', 'battery-model', null,
      jsonb_build_array(jsonb_build_object(
        'headline', 'Battery finding', 'summary', 'Battery summary',
        'source_type', 'document', 'source_id', null)));
    raise exception 'POLICY-BATTERY FAIL 25.16: source-less document completion succeeded';
  exception when check_violation then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_status text;
  v_find   bigint;
  v_audits bigint;
begin
  select status into v_status from public.research_runs
   where id = current_setting('battery25.run_b')::uuid;
  select count(*) into v_find from public.research_findings;
  select count(*) into v_audits
    from public.audit_events where action = 'research:complete';
  if v_status <> 'running' or v_find <> 5 or v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.16: malformed completion changed state (status %, findings %, audits %)',
      v_status, v_find, v_audits;
  end if;
end $$;

-- ############################################################################
-- 25.17 — NEG (failed without a code + invalid status): failed requires a
-- non-empty error code; 'running' is not a completion status.
-- ############################################################################
set role service_role;
do $$
begin
  begin
    perform public.complete_research_run(
      current_setting('battery25.run_b')::uuid, 'failed', 'battery-model', null, null);
    raise exception 'POLICY-BATTERY FAIL 25.17: code-less failed completion succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.complete_research_run(
      current_setting('battery25.run_b')::uuid, 'running', 'battery-model', null, null);
    raise exception 'POLICY-BATTERY FAIL 25.17: running-status completion succeeded';
  exception when check_violation then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_status text;
  v_audits bigint;
begin
  select status into v_status from public.research_runs
   where id = current_setting('battery25.run_b')::uuid;
  select count(*) into v_audits
    from public.audit_events where action = 'research:complete';
  if v_status <> 'running' or v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.17: denied completion changed state (status %, audits %)',
      v_status, v_audits;
  end if;
end $$;

-- ############################################################################
-- 25.18 — POS (failed completion): the run is persisted as failed with the
-- provider error code and a machine-actor audit row.
-- ############################################################################
set role service_role;
do $$
begin
  perform public.complete_research_run(
    current_setting('battery25.run_b')::uuid,
    'failed',
    null,
    'provider_not_configured',
    null);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery25.run_b')::uuid;
  v_row    public.research_runs;
  v_find   bigint;
  v_audits bigint;
  v_bad    bigint;
begin
  select * into v_row from public.research_runs where id = v_id;
  if v_row.status <> 'failed'
     or v_row.error_code <> 'provider_not_configured'
     or v_row.model is not null
     or v_row.completed_at is null then
    raise exception 'POLICY-BATTERY FAIL 25.18: failed run shape drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_find from public.research_findings where run_id = v_id;
  if v_find <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.18: failed run wrote % findings, want 0', v_find;
  end if;

  select count(*) into v_audits
    from public.audit_events
   where action = 'research:complete' and resource_id = v_id;
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.18: failed-run completion audits = %, want 1', v_audits;
  end if;
  select count(*) into v_bad
    from public.audit_events
   where action = 'research:complete'
     and resource_id = v_id
     and (outcome <> 'allowed'
          or actor_user_id is not null
          or redacted_summary is distinct from 'research run failed'
          or redacted_summary like '%provider_not_configured%');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.18: failed-run audit drift/leak (%)', v_bad;
  end if;
end $$;

-- ############################################################################
-- 25.19 — NEG (terminal completion): completed and failed runs cannot be
-- completed again; counts stay fixed.
-- ############################################################################
set role service_role;
do $$
begin
  begin
    perform public.complete_research_run(
      current_setting('battery25.run_a')::uuid, 'failed', null, 'provider_unavailable', null);
    raise exception 'POLICY-BATTERY FAIL 25.19: completed run re-completed';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'research run is not running' then
      raise exception 'POLICY-BATTERY FAIL 25.19: completed re-completion raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.complete_research_run(
      current_setting('battery25.run_b')::uuid, 'completed', 'battery-model', null,
      jsonb_build_array(jsonb_build_object(
        'headline', 'Battery late finding', 'summary', 'Battery late summary',
        'source_type', 'none', 'source_id', null)));
    raise exception 'POLICY-BATTERY FAIL 25.19: failed run re-completed';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'research run is not running' then
      raise exception 'POLICY-BATTERY FAIL 25.19: failed re-completion raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_find   bigint;
  v_audits bigint;
begin
  select count(*) into v_find from public.research_findings;
  select count(*) into v_audits
    from public.audit_events where action = 'research:complete';
  if v_find <> 5 or v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 25.19: terminal retries changed counts (findings %, audits %)', v_find, v_audits;
  end if;
end $$;

-- ############################################################################
-- 25.20 — NEG (invalid completion status on a running run): a fresh running
-- run cannot be completed as 'running'; it stays running and unaudited.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_id := public.start_research_run(
    '20000000-0000-4000-8000-000000000001', null, 'Battery invalid status question');
  perform set_config('battery25.run_c', v_id::text, true);
end $$;
reset role;

set role service_role;
do $$
begin
  begin
    perform public.complete_research_run(
      current_setting('battery25.run_c')::uuid, 'running', 'battery-model', null, null);
    raise exception 'POLICY-BATTERY FAIL 25.20: running-status completion succeeded';
  exception when check_violation then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_status text;
  v_audits bigint;
begin
  select status into v_status from public.research_runs
   where id = current_setting('battery25.run_c')::uuid;
  select count(*) into v_audits
    from public.audit_events where action = 'research:complete';
  if v_status <> 'running' or v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 25.20: invalid status changed state (status %, audits %)',
      v_status, v_audits;
  end if;
end $$;

-- ############################################################################
-- 25.21 — NEG (direct writes): authenticated holds SELECT only on both
-- tables — INSERT, UPDATE and DELETE are denied at the privilege layer.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);

  begin
    insert into public.research_runs (organization_id, prompt_summary)
    values ('20000000-0000-4000-8000-000000000001', 'Battery direct run insert');
    raise exception 'POLICY-BATTERY FAIL 25.21: direct run INSERT succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.research_runs
       set status = 'failed'
     where id = current_setting('battery25.run_a')::uuid;
    raise exception 'POLICY-BATTERY FAIL 25.21: direct run UPDATE succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    delete from public.research_runs
     where id = current_setting('battery25.run_a')::uuid;
    raise exception 'POLICY-BATTERY FAIL 25.21: direct run DELETE succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into public.research_findings
      (run_id, organization_id, headline, summary)
    values
      (current_setting('battery25.run_a')::uuid,
       '20000000-0000-4000-8000-000000000001',
       'Battery direct finding', 'Battery direct summary');
    raise exception 'POLICY-BATTERY FAIL 25.21: direct finding INSERT succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.research_findings
       set headline = 'Battery hijacked'
     where run_id = current_setting('battery25.run_a')::uuid;
    raise exception 'POLICY-BATTERY FAIL 25.21: direct finding UPDATE succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    delete from public.research_findings
     where run_id = current_setting('battery25.run_a')::uuid;
    raise exception 'POLICY-BATTERY FAIL 25.21: direct finding DELETE succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_status text;
  v_runs   bigint;
  v_find   bigint;
begin
  select status into v_status from public.research_runs
   where id = current_setting('battery25.run_a')::uuid;
  select count(*) into v_runs from public.research_runs;
  select count(*) into v_find from public.research_findings;
  if v_status <> 'completed' or v_runs <> 6 or v_find <> 5 then
    raise exception 'POLICY-BATTERY FAIL 25.21: direct-write denials changed state (status %, runs %, findings %)',
      v_status, v_runs, v_find;
  end if;
end $$;

-- ############################################################################
-- 25.22 — POS (table + function posture): both tables are RLS-enabled,
-- authenticated holds SELECT only, anon holds nothing, each table carries
-- exactly one read policy, and all four RPCs are SECURITY DEFINER with a
-- pinned search_path, no parameter defaults and the exact EXECUTE surface.
-- ############################################################################
do $$
declare
  r      record;
  v_oid  oid;
  v_bad  bigint;
begin
  if not (select relrowsecurity from pg_class where oid = 'public.research_runs'::regclass)
     or not (select relrowsecurity from pg_class where oid = 'public.research_findings'::regclass) then
    raise exception 'POLICY-BATTERY FAIL 25.22: RLS is not enabled on both research tables';
  end if;

  if not has_table_privilege('authenticated', 'public.research_runs', 'SELECT')
     or not has_table_privilege('authenticated', 'public.research_findings', 'SELECT') then
    raise exception 'POLICY-BATTERY FAIL 25.22: authenticated lacks SELECT on a research table';
  end if;

  if has_table_privilege('authenticated', 'public.research_runs', 'INSERT')
     or has_table_privilege('authenticated', 'public.research_runs', 'UPDATE')
     or has_table_privilege('authenticated', 'public.research_runs', 'DELETE')
     or has_table_privilege('authenticated', 'public.research_runs', 'TRUNCATE')
     or has_table_privilege('authenticated', 'public.research_findings', 'INSERT')
     or has_table_privilege('authenticated', 'public.research_findings', 'UPDATE')
     or has_table_privilege('authenticated', 'public.research_findings', 'DELETE')
     or has_table_privilege('authenticated', 'public.research_findings', 'TRUNCATE') then
    raise exception 'POLICY-BATTERY FAIL 25.22: authenticated holds a direct write privilege';
  end if;

  if has_table_privilege('anon', 'public.research_runs', 'SELECT')
     or has_table_privilege('anon', 'public.research_runs', 'INSERT')
     or has_table_privilege('anon', 'public.research_runs', 'UPDATE')
     or has_table_privilege('anon', 'public.research_runs', 'DELETE')
     or has_table_privilege('anon', 'public.research_findings', 'SELECT')
     or has_table_privilege('anon', 'public.research_findings', 'INSERT')
     or has_table_privilege('anon', 'public.research_findings', 'UPDATE')
     or has_table_privilege('anon', 'public.research_findings', 'DELETE') then
    raise exception 'POLICY-BATTERY FAIL 25.22: anon holds a research-table privilege';
  end if;

  if (select count(*) from pg_policies
       where schemaname = 'public' and tablename = 'research_runs'
         and policyname = 'research_runs_select_org') <> 1
     or (select count(*) from pg_policies
       where schemaname = 'public' and tablename = 'research_findings'
         and policyname = 'research_findings_select_org') <> 1
     or (select count(*) from pg_policies
       where schemaname = 'public' and tablename in ('research_runs', 'research_findings')) <> 2 then
    raise exception 'POLICY-BATTERY FAIL 25.22: research policy inventory drift';
  end if;

  for r in
    select * from (values
      ('start_research_run',
       'p_organization_id uuid, p_matter_id uuid, p_prompt_summary text'),
      ('complete_research_run',
       'p_run_id uuid, p_status text, p_model text, p_error_code text, p_findings jsonb'),
      ('list_research_runs', 'p_organization_id uuid'),
      ('list_research_findings', 'p_run_id uuid')
    ) as t(fn, args)
  loop
    select p.oid into v_oid
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = r.fn
       and pg_get_function_arguments(p.oid) = r.args;
    if v_oid is null then
      raise exception 'POLICY-BATTERY FAIL 25.22: function public.%(%) missing', r.fn, r.args;
    end if;
    if not (select prosecdef from pg_proc where oid = v_oid) then
      raise exception 'POLICY-BATTERY FAIL 25.22: public.% is not SECURITY DEFINER', r.fn;
    end if;
    if not (select coalesce(proconfig, '{}'::text[]) @> array['search_path=public']::text[]
              from pg_proc where oid = v_oid) then
      raise exception 'POLICY-BATTERY FAIL 25.22: public.% does not pin search_path = public', r.fn;
    end if;
    if (select pronargdefaults from pg_proc where oid = v_oid) <> 0 then
      raise exception 'POLICY-BATTERY FAIL 25.22: public.% carries a parameter default', r.fn;
    end if;
    if has_function_privilege('anon', v_oid, 'EXECUTE') then
      raise exception 'POLICY-BATTERY FAIL 25.22: anon holds EXECUTE on public.%', r.fn;
    end if;
  end loop;

  if not has_function_privilege('authenticated',
         'public.start_research_run(uuid, uuid, text)', 'EXECUTE')
     or not has_function_privilege('authenticated',
         'public.list_research_runs(uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated',
         'public.list_research_findings(uuid)', 'EXECUTE') then
    raise exception 'POLICY-BATTERY FAIL 25.22: authenticated lacks EXECUTE on a read/start RPC';
  end if;
  if has_function_privilege('authenticated',
       'public.complete_research_run(uuid, text, text, text, jsonb)', 'EXECUTE') then
    raise exception 'POLICY-BATTERY FAIL 25.22: authenticated holds EXECUTE on complete_research_run';
  end if;
  if not has_function_privilege('service_role',
       'public.complete_research_run(uuid, text, text, text, jsonb)', 'EXECUTE') then
    raise exception 'POLICY-BATTERY FAIL 25.22: service_role lacks EXECUTE on complete_research_run';
  end if;
end $$;

-- ############################################################################
-- 25.23 — POS (§8 final pin): exactly the successful writes are audited
-- (4 starts, 1 completed, 1 failed = 6 rows), every summary is fixed and
-- redacted, every audit points at a real run, and the finding census is
-- exactly the seeded + completed rows.
-- ############################################################################
do $$
declare
  v_total    bigint;
  v_starts   bigint;
  v_complete bigint;
  v_failed   bigint;
  v_bad      bigint;
begin
  select count(*) into v_total from public.audit_events where action like 'research:%';
  select count(*) into v_starts from public.audit_events where action = 'research:start';
  select count(*) into v_complete
    from public.audit_events
   where action = 'research:complete' and redacted_summary = 'research run completed';
  select count(*) into v_failed
    from public.audit_events
   where action = 'research:complete' and redacted_summary = 'research run failed';
  if v_total <> 6 or v_starts <> 4 or v_complete <> 1 or v_failed <> 1 then
    raise exception 'POLICY-BATTERY FAIL 25.23: audit mix drift (total %, start %, completed %, failed %)',
      v_total, v_starts, v_complete, v_failed;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action like 'research:%'
     and (outcome <> 'allowed'
          or resource_type <> 'research_run'
          or redacted_summary not in ('research run started',
                                      'research run completed',
                                      'research run failed')
          or redacted_summary like '%Battery%'
          or redacted_summary like '%question%'
          or not exists (
            select 1 from public.research_runs r where r.id = audit_events.resource_id));
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.23: % audit row(s) carry a non-fixed outcome/type/summary or no run', v_bad;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action = 'research:start'
     and (actor_user_id is null
          or actor_user_id not in (
            '10000000-0000-4000-8000-000000000002',
            current_setting('battery25.attorney')::uuid));
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.23: % start audit row(s) carry a foreign actor', v_bad;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action = 'research:complete'
     and actor_user_id is not null;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.23: % completion audit row(s) carry an actor', v_bad;
  end if;

  select count(*) into v_bad
    from public.research_findings
   where organization_id <> '20000000-0000-4000-8000-000000000001';
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.23: % finding row(s) carry a foreign org', v_bad;
  end if;

  select count(*) into v_total from public.research_findings;
  if v_total <> 5 then
    raise exception 'POLICY-BATTERY FAIL 25.23: findings = %, want 5', v_total;
  end if;

  select count(*) into v_bad
    from public.research_findings
   where run_id = current_setting('battery25.run_b')::uuid
      or run_id = current_setting('battery25.run_c')::uuid;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 25.23: % finding row(s) exist for a failed/running run', v_bad;
  end if;

  select count(*) into v_total from public.research_runs;
  if v_total <> 6 then
    raise exception 'POLICY-BATTERY FAIL 25.23: runs = %, want 6', v_total;
  end if;
end $$;

rollback;
