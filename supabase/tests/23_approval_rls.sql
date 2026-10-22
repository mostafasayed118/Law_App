-- ============================================================================
-- supabase/tests/23_approval_rls.sql — approvals battery
--
-- Pins the approvals slice (supabase/migrations/23_approvals.sql +
-- supabase/policies/approval_requests.sql + approval_events.sql + the four
-- supabase/rpc/*approval* functions):
--   - create: partner (no matter) and client (readable matter) positives; a
--     cross-org matter, a non-member, a suspended member and anon are all
--     denied; invalid kind and title bounds raise check_violation; every
--     successful create writes exactly one 'created' event and one redacted
--     audit row (23.01-23.08);
--   - list: active-member scoping, newest-first ordering, the status filter,
--     and cross-org denial; both read policies are exercised directly
--     (23.09-23.10);
--   - decide: partner approve/reject positives with event + audit; the
--     requester cannot self-decide, a client cannot decide, invalid
--     decisions and a note-less rejection are refused, and a non-pending
--     request cannot be decided twice (23.11-23.17);
--   - cancel: the requester and a partner can cancel; another client and a
--     non-member cannot; a non-pending request cannot be cancelled again
--     (23.18-23.20);
--   - not-found ids raise the typed error without an audit row (23.21);
--   - direct INSERT/UPDATE is denied at the privilege layer for both tables
--     (23.22);
--   - structural posture: all four functions are SECURITY DEFINER with a
--     pinned search_path, no parameter default, authenticated EXECUTE,
--     anon none (23.23); both tables are RLS-enabled with SELECT-only
--     grants and exactly one policy each (23.24);
--   - §8 final pin: exactly the successful writes are audited with fixed
--     redacted summaries, and the event trail matches the state changes
--     (23.25).
--
-- The whole battery runs in ONE transaction and ROLLS BACK. Two synthetic
-- ordering anchors are inserted as the connection role at the top (fixed
-- 2001 timestamps, no events/audit) so newest-first ordering is provable —
-- RPC-created rows all share the transaction's now().
--
-- Fixture anchors (00_fixtures.sql): owner …0001 (platform owner, no
-- membership) · partner-a …0002 (org-a partner, active) · client-a …0003
-- (org-a client, assigned on matters 1,2) · partner-b …0004 (org-b partner,
-- active) · suspended-a …0005 (org-a membership suspended) · demo …0006 (no
-- membership) · orphan …0007 (org-a client, assigned on matter 4) · org-a
-- 20000000-…-0001 · org-b 20000000-…-0002 · matter 1 40000000-…-0001
-- (client-a + partner-a) · matter 2 40000000-…-0002 (client-a + partner-a) ·
-- matter 5 40000000-…-0005 (partner-b assigned, org-a — cross-org anchor).
--
-- Role handling: every behavior block runs under `set role authenticated`
-- with JWT impersonation (the 01/02/03 pattern); verification and the two
-- ordering anchors run as the connection role (authenticated holds NO
-- INSERT/UPDATE/DELETE grant on either table).
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 23.00 — POS (ordering anchors): two synthetic requests with fixed 2001
-- timestamps (one pending, one cancelled) so the list order and the status
-- filter have a deterministic tail. No events/audit are written for seeds;
-- they are inserted as the connection role and roll back with the battery.
-- ############################################################################
do $$
declare
  v_new uuid;
  v_old uuid;
begin
  insert into public.approval_requests
    (organization_id, matter_id, title, kind, status, requested_by,
     created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001', null,
     'Battery seeded pending request', 'other', 'pending',
     '10000000-0000-4000-8000-000000000002',
     '2001-01-02T00:00:00Z', '2001-01-02T00:00:00Z')
  returning id into v_new;

  insert into public.approval_requests
    (organization_id, matter_id, title, kind, status, requested_by,
     created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001', null,
     'Battery seeded cancelled request', 'other', 'cancelled',
     '10000000-0000-4000-8000-000000000002',
     '2001-01-01T00:00:00Z', '2001-01-01T00:00:00Z')
  returning id into v_old;

  if v_new is null or v_old is null then
    raise exception 'POLICY-BATTERY FAIL 23.00: ordering anchors were not inserted';
  end if;
  perform set_config('battery23.seed_new', v_new::text, true);
  perform set_config('battery23.seed_old', v_old::text, true);
end $$;

-- ############################################################################
-- 23.01 — POS (partner create, no matter): partner-a creates a conflict
-- request. Row shape, requester stamp, the 'created' event and the redacted
-- create audit row are verified.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_id := public.create_approval_request(
    '20000000-0000-4000-8000-000000000001',
    null,
    'conflict',
    '  Battery conflict check  ',
    'Description of the conflict check.');
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 23.01: create_approval_request returned a null id';
  end if;
  perform set_config('battery23.a', v_id::text, true);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery23.a')::uuid;
  v_row    public.approval_requests;
  v_events bigint;
  v_audits bigint;
  v_sum    text;
begin
  select * into v_row from public.approval_requests where id = v_id;
  if not found then
    raise exception 'POLICY-BATTERY FAIL 23.01: created request row missing';
  end if;
  if v_row.organization_id <> '20000000-0000-4000-8000-000000000001'
     or v_row.matter_id is not null
     or v_row.title <> 'Battery conflict check'
     or v_row.description is distinct from 'Description of the conflict check.'
     or v_row.kind <> 'conflict'
     or v_row.status <> 'pending'
     or v_row.requested_by is distinct from '10000000-0000-4000-8000-000000000002'
     or v_row.decided_by is not null
     or v_row.decided_at is not null
     or v_row.decision_note is not null then
    raise exception 'POLICY-BATTERY FAIL 23.01: created row shape/trim drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_events
    from public.approval_events
   where request_id = v_id
     and action = 'created'
     and actor_id = '10000000-0000-4000-8000-000000000002'
     and note is null;
  if v_events <> 1 then
    raise exception 'POLICY-BATTERY FAIL 23.01: created event rows = %, want 1', v_events;
  end if;

  select count(*), max(redacted_summary) into v_audits, v_sum
    from public.audit_events
   where action = 'approval:create'
     and outcome = 'allowed'
     and resource_type = 'approval_request'
     and resource_id = v_id;
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 23.01: create audit rows = %, want 1', v_audits;
  end if;
  if v_sum is distinct from 'approval request created' then
    raise exception 'POLICY-BATTERY FAIL 23.01: create audit summary drift: %', v_sum;
  end if;
  if v_sum like '%Battery%' or v_sum like '%conflict%' then
    raise exception 'POLICY-BATTERY FAIL 23.01: create audit summary leaked request content: %', v_sum;
  end if;
end $$;

-- ############################################################################
-- 23.02 — POS (client create on a readable matter): client-a is assigned on
-- matter 1 and creates an expense request linked to it.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_id := public.create_approval_request(
    '20000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    'expense',
    'Battery expense approval',
    null);
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 23.02: matter-linked create returned a null id';
  end if;
  perform set_config('battery23.b', v_id::text, true);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery23.b')::uuid;
  v_row    public.approval_requests;
  v_events bigint;
  v_audits bigint;
begin
  select * into v_row from public.approval_requests where id = v_id;
  if not found then
    raise exception 'POLICY-BATTERY FAIL 23.02: matter-linked request row missing';
  end if;
  if v_row.organization_id <> '20000000-0000-4000-8000-000000000001'
     or v_row.matter_id <> '40000000-0000-4000-8000-000000000001'
     or v_row.title <> 'Battery expense approval'
     or v_row.kind <> 'expense'
     or v_row.status <> 'pending'
     or v_row.requested_by is distinct from '10000000-0000-4000-8000-000000000003'
     or v_row.description is not null then
    raise exception 'POLICY-BATTERY FAIL 23.02: matter-linked row shape drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_events
    from public.approval_events
   where request_id = v_id and action = 'created'
     and actor_id = '10000000-0000-4000-8000-000000000003';
  if v_events <> 1 then
    raise exception 'POLICY-BATTERY FAIL 23.02: matter-linked create events = %, want 1', v_events;
  end if;

  select count(*) into v_audits
    from public.audit_events where action = 'approval:create';
  if v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 23.02: approval:create audit rows = %, want 2', v_audits;
  end if;
end $$;

-- ############################################################################
-- 23.03 — NEG (cross-org matter): partner-b is an org-b partner and is
-- assigned attorney on matter 5, but matter 5 belongs to org-a. A create in
-- org-b naming matter 5 is denied by the same-org clause; no row and no
-- audit row is written.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    perform public.create_approval_request(
      '20000000-0000-4000-8000-000000000002',
      '40000000-0000-4000-8000-000000000005',
      'filing',
      'Battery cross-org matter',
      null);
    raise exception 'POLICY-BATTERY FAIL 23.03: cross-org matter create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 23.03: cross-org matter raised "%" instead of permission denied', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_rows   bigint;
  v_audits bigint;
begin
  select count(*) into v_rows from public.approval_requests;
  if v_rows <> 2 then
    raise exception 'POLICY-BATTERY FAIL 23.03: denied cross-org create left % rows, want 2', v_rows;
  end if;
  select count(*) into v_audits
    from public.audit_events where action = 'approval:create';
  if v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 23.03: denied cross-org create wrote an audit row (% total), want 2', v_audits;
  end if;
end $$;

-- ############################################################################
-- 23.04 — NEG (non-member create): partner-b holds no org-a membership, so a
-- create routed to org-a is denied before any matter logic.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    perform public.create_approval_request(
      '20000000-0000-4000-8000-000000000001',
      null,
      'other',
      'Battery foreign org create',
      null);
    raise exception 'POLICY-BATTERY FAIL 23.04: non-member create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 23.04: non-member create raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_rows bigint;
begin
  select count(*) into v_rows from public.approval_requests;
  if v_rows <> 2 then
    raise exception 'POLICY-BATTERY FAIL 23.04: denied non-member create left % rows, want 2', v_rows;
  end if;
end $$;

-- ############################################################################
-- 23.05 — NEG (suspended member): suspended-a holds a SUSPENDED org-a
-- membership (role partner). Create and list both raise, and the direct
-- select policy exposes zero rows.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  begin
    perform public.create_approval_request(
      '20000000-0000-4000-8000-000000000001',
      null,
      'other',
      'Battery suspended create',
      null);
    raise exception 'POLICY-BATTERY FAIL 23.05: suspended create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 23.05: suspended create raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.list_approval_requests(
      '20000000-0000-4000-8000-000000000001', null);
    raise exception 'POLICY-BATTERY FAIL 23.05: suspended list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 23.05: suspended list raised "%"', sqlerrm;
    end if;
  end;

  select count(*) into v_cnt from public.approval_requests;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.05: suspended caller sees % request rows, want 0', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 23.06 — NEG (unauthenticated): anon holds no EXECUTE grant and no table
-- grant, so the RPC call and the direct reads fail at the privilege layer.
-- ############################################################################
set role anon;
do $$
begin
  begin
    perform public.create_approval_request(
      '20000000-0000-4000-8000-000000000001',
      null,
      'other',
      'Battery anon create',
      null);
    raise exception 'POLICY-BATTERY FAIL 23.06: anon create succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform count(*) from public.approval_requests;
    raise exception 'POLICY-BATTERY FAIL 23.06: anon request select succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform count(*) from public.approval_events;
    raise exception 'POLICY-BATTERY FAIL 23.06: anon event select succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

-- ############################################################################
-- 23.07 — NEG (kind validation): a value outside the five mapped kinds and a
-- null kind both raise check_violation, leaving the row count untouched.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_approval_request(
      '20000000-0000-4000-8000-000000000001', null, 'bribe',
      'Battery invalid kind', null);
    raise exception 'POLICY-BATTERY FAIL 23.07: unmapped kind create succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.create_approval_request(
      '20000000-0000-4000-8000-000000000001', null, null,
      'Battery null kind', null);
    raise exception 'POLICY-BATTERY FAIL 23.07: null kind create succeeded';
  exception when check_violation then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_rows bigint;
begin
  select count(*) into v_rows from public.approval_requests;
  if v_rows <> 2 then
    raise exception 'POLICY-BATTERY FAIL 23.07: invalid-kind attempts left % rows, want 2', v_rows;
  end if;
end $$;

-- ############################################################################
-- 23.08 — NEG (title bounds): a title that trims to one character, a
-- 161-character title and a null title all raise check_violation.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_approval_request(
      '20000000-0000-4000-8000-000000000001', null, 'other', ' A ', null);
    raise exception 'POLICY-BATTERY FAIL 23.08: one-character title create succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.create_approval_request(
      '20000000-0000-4000-8000-000000000001', null, 'other',
      repeat('x', 161), null);
    raise exception 'POLICY-BATTERY FAIL 23.08: 161-character title create succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.create_approval_request(
      '20000000-0000-4000-8000-000000000001', null, 'other', null, null);
    raise exception 'POLICY-BATTERY FAIL 23.08: null title create succeeded';
  exception when check_violation then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_rows bigint;
begin
  select count(*) into v_rows from public.approval_requests;
  if v_rows <> 2 then
    raise exception 'POLICY-BATTERY FAIL 23.08: invalid-title attempts left % rows, want 2', v_rows;
  end if;
end $$;

-- ############################################################################
-- 23.09 — POS (list scoping, ordering, filter): partner-a and client-a both
-- read the four org-a rows (two anchors + 23.01/23.02) newest first; the
-- pending/cancelled filters narrow correctly; partner-b reads zero org-b
-- rows and both read policies expose nothing cross-org.
-- ############################################################################
set role authenticated;
do $$
declare
  v_total  bigint;
  v_pend   bigint;
  v_canc   bigint;
  v_rej    bigint;
  v_third  uuid;
  v_fourth uuid;
  v_events bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);

  select count(*) into v_total
    from public.list_approval_requests('20000000-0000-4000-8000-000000000001', null);
  if v_total <> 4 then
    raise exception 'POLICY-BATTERY FAIL 23.09: org-a list returned % rows, want 4', v_total;
  end if;

  select count(*) into v_total
    from public.list_approval_requests('20000000-0000-4000-8000-000000000001', null)
   where organization_id <> '20000000-0000-4000-8000-000000000001';
  if v_total <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.09: org-a list exposed % cross-org rows', v_total;
  end if;

  select count(*) into v_pend
    from public.list_approval_requests('20000000-0000-4000-8000-000000000001', 'pending');
  select count(*) into v_canc
    from public.list_approval_requests('20000000-0000-4000-8000-000000000001', 'cancelled');
  select count(*) into v_rej
    from public.list_approval_requests('20000000-0000-4000-8000-000000000001', 'rejected');
  if v_pend <> 3 or v_canc <> 1 or v_rej <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.09: status filter drift (pending %, cancelled %, rejected %)', v_pend, v_canc, v_rej;
  end if;

  select id into v_third
    from public.list_approval_requests('20000000-0000-4000-8000-000000000001', null)
   order by created_at desc
   offset 2 limit 1;
  select id into v_fourth
    from public.list_approval_requests('20000000-0000-4000-8000-000000000001', null)
   order by created_at desc
   offset 3 limit 1;
  if v_third is distinct from current_setting('battery23.seed_new')::uuid
     or v_fourth is distinct from current_setting('battery23.seed_old')::uuid then
    raise exception 'POLICY-BATTERY FAIL 23.09: list is not newest-first (tail % / %)', v_third, v_fourth;
  end if;

  select count(*) into v_total from public.approval_requests;
  select count(*) into v_events from public.approval_events;
  if v_total <> 4 then
    raise exception 'POLICY-BATTERY FAIL 23.09: direct request select returned % rows, want 4', v_total;
  end if;
  if v_events <> 2 then
    raise exception 'POLICY-BATTERY FAIL 23.09: direct event select returned % rows, want 2', v_events;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_total from public.list_approval_requests('20000000-0000-4000-8000-000000000001', null);
  if v_total <> 4 then
    raise exception 'POLICY-BATTERY FAIL 23.09: client-a sees % org-a rows, want 4', v_total;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_total from public.list_approval_requests('20000000-0000-4000-8000-000000000002', null);
  select count(*) into v_pend from public.approval_requests;
  select count(*) into v_events from public.approval_events;
  if v_total <> 0 or v_pend <> 0 or v_events <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.09: org-b caller sees foreign rows (rpc %, requests %, events %)', v_total, v_pend, v_events;
  end if;
end $$;
reset role;

-- ############################################################################
-- 23.10 — NEG (cross-org list): partner-a and client-a are active org-a
-- members but hold no org-b membership — listing org-b raises.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.list_approval_requests('20000000-0000-4000-8000-000000000002', null);
    raise exception 'POLICY-BATTERY FAIL 23.10: partner-a cross-org list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 23.10: partner-a cross-org list raised "%"', sqlerrm;
    end if;
  end;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.list_approval_requests('20000000-0000-4000-8000-000000000002', null);
    raise exception 'POLICY-BATTERY FAIL 23.10: client-a cross-org list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 23.10: client-a cross-org list raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- ############################################################################
-- 23.11 — POS (partner approve): client-a creates a waiver request on
-- matter 2; partner-a approves it with a note. Row, event and audit are
-- verified.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_id := public.create_approval_request(
    '20000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000002',
    'waiver',
    'Battery waiver approval',
    null);
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 23.11: waiver create returned a null id';
  end if;
  perform set_config('battery23.c', v_id::text, true);
end $$;
reset role;

set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.decide_approval_request(
    current_setting('battery23.c')::uuid, 'approved', 'Looks good');
end $$;
reset role;

do $$
declare
  v_id      uuid := current_setting('battery23.c')::uuid;
  v_row     public.approval_requests;
  v_events  bigint;
  v_audits  bigint;
  v_note    text;
  v_outcome text;
  v_sum     text;
begin
  select * into v_row from public.approval_requests where id = v_id;
  if v_row.status <> 'approved'
     or v_row.decided_by is distinct from '10000000-0000-4000-8000-000000000002'
     or v_row.decided_at is null
     or v_row.decision_note is distinct from 'Looks good'
     or v_row.updated_at < v_row.created_at then
    raise exception 'POLICY-BATTERY FAIL 23.11: approved row shape drift: %', row_to_json(v_row);
  end if;

  select count(*), max(note) into v_events, v_note
    from public.approval_events
   where request_id = v_id
     and action = 'approved'
     and actor_id = '10000000-0000-4000-8000-000000000002';
  if v_events <> 1 then
    raise exception 'POLICY-BATTERY FAIL 23.11: approved event rows = %, want 1', v_events;
  end if;
  if v_note is distinct from 'Looks good' then
    raise exception 'POLICY-BATTERY FAIL 23.11: approved event note drift: %', v_note;
  end if;

  select count(*), max(outcome), max(redacted_summary)
    into v_audits, v_outcome, v_sum
    from public.audit_events
   where action = 'approval:decide'
     and resource_type = 'approval_request'
     and resource_id = v_id;
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 23.11: decide audit rows = %, want 1', v_audits;
  end if;
  if v_outcome is distinct from 'approved'
     or v_sum is distinct from 'approval request decided' then
    raise exception 'POLICY-BATTERY FAIL 23.11: decide audit drift (outcome %, summary %)', v_outcome, v_sum;
  end if;
end $$;

-- ############################################################################
-- 23.12 — NEG (self-decision): partner-a creates a request and cannot decide
-- it, even as a partner. The request stays pending with no decide audit.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_id := public.create_approval_request(
    '20000000-0000-4000-8000-000000000001',
    null,
    'filing',
    'Battery self decision',
    null);
  perform set_config('battery23.d', v_id::text, true);

  begin
    perform public.decide_approval_request(v_id, 'approved', null);
    raise exception 'POLICY-BATTERY FAIL 23.12: requester self-decision succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 23.12: self-decision raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery23.d')::uuid;
  v_row    public.approval_requests;
  v_audits bigint;
  v_events bigint;
begin
  select * into v_row from public.approval_requests where id = v_id;
  if v_row.status <> 'pending' or v_row.decided_by is not null or v_row.decision_note is not null then
    raise exception 'POLICY-BATTERY FAIL 23.12: denied self-decision changed the row: %', row_to_json(v_row);
  end if;
  select count(*) into v_audits
    from public.audit_events where action = 'approval:decide' and resource_id = v_id;
  if v_audits <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.12: denied self-decision wrote % decide audit row(s)', v_audits;
  end if;
  select count(*) into v_events
    from public.approval_events where request_id = v_id and action in ('approved', 'rejected');
  if v_events <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.12: denied self-decision wrote % decision event(s)', v_events;
  end if;
end $$;

-- ############################################################################
-- 23.13 — NEG (client decide): client-a and orphan are org-a clients, not
-- partners — neither can decide client-a's own request.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_id := public.create_approval_request(
    '20000000-0000-4000-8000-000000000001',
    null,
    'other',
    'Battery client decision',
    null);
  perform set_config('battery23.e', v_id::text, true);

  begin
    perform public.decide_approval_request(v_id, 'approved', null);
    raise exception 'POLICY-BATTERY FAIL 23.13: client self-decision succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 23.13: client decision raised "%"', sqlerrm;
    end if;
  end;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  begin
    perform public.decide_approval_request(v_id, 'approved', null);
    raise exception 'POLICY-BATTERY FAIL 23.13: orphan client decision succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 23.13: orphan client decision raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_row public.approval_requests;
begin
  select * into v_row from public.approval_requests
   where id = current_setting('battery23.e')::uuid;
  if v_row.status <> 'pending' or v_row.decided_by is not null then
    raise exception 'POLICY-BATTERY FAIL 23.13: denied client decisions changed the row: %', row_to_json(v_row);
  end if;
end $$;

-- ############################################################################
-- 23.14 — NEG (invalid decision): partner-a tries an unmapped decision and a
-- null decision; both raise check_violation and leave the request pending.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid := current_setting('battery23.e')::uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.decide_approval_request(v_id, 'maybe', null);
    raise exception 'POLICY-BATTERY FAIL 23.14: unmapped decision succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.decide_approval_request(v_id, null, null);
    raise exception 'POLICY-BATTERY FAIL 23.14: null decision succeeded';
  exception when check_violation then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_row public.approval_requests;
begin
  select * into v_row from public.approval_requests
   where id = current_setting('battery23.e')::uuid;
  if v_row.status <> 'pending' then
    raise exception 'POLICY-BATTERY FAIL 23.14: invalid decisions changed the row: %', row_to_json(v_row);
  end if;
end $$;

-- ############################################################################
-- 23.15 — NEG (rejection note): a null note, a blank note and a one-character
-- note are all refused with 'a rejection note is required'.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid := current_setting('battery23.e')::uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.decide_approval_request(v_id, 'rejected', null);
    raise exception 'POLICY-BATTERY FAIL 23.15: null-note rejection succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'a rejection note is required' then
      raise exception 'POLICY-BATTERY FAIL 23.15: null-note rejection raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.decide_approval_request(v_id, 'rejected', '   ');
    raise exception 'POLICY-BATTERY FAIL 23.15: blank-note rejection succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'a rejection note is required' then
      raise exception 'POLICY-BATTERY FAIL 23.15: blank-note rejection raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.decide_approval_request(v_id, 'rejected', 'x');
    raise exception 'POLICY-BATTERY FAIL 23.15: one-character-note rejection succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'a rejection note is required' then
      raise exception 'POLICY-BATTERY FAIL 23.15: one-character-note rejection raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_row public.approval_requests;
begin
  select * into v_row from public.approval_requests
   where id = current_setting('battery23.e')::uuid;
  if v_row.status <> 'pending' or v_row.decision_note is not null then
    raise exception 'POLICY-BATTERY FAIL 23.15: note-less rejections changed the row: %', row_to_json(v_row);
  end if;
end $$;

-- ############################################################################
-- 23.16 — POS (partner reject): partner-a rejects the request with a padded
-- two-plus-character note. The stored note is trimmed; the event and audit
-- carry the rejection outcome.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.decide_approval_request(
    current_setting('battery23.e')::uuid, 'rejected', '  Not valid.  ');
end $$;
reset role;

do $$
declare
  v_id      uuid := current_setting('battery23.e')::uuid;
  v_row     public.approval_requests;
  v_events  bigint;
  v_note    text;
  v_audits  bigint;
  v_outcome text;
begin
  select * into v_row from public.approval_requests where id = v_id;
  if v_row.status <> 'rejected'
     or v_row.decided_by is distinct from '10000000-0000-4000-8000-000000000002'
     or v_row.decided_at is null
     or v_row.decision_note is distinct from 'Not valid.' then
    raise exception 'POLICY-BATTERY FAIL 23.16: rejected row shape drift: %', row_to_json(v_row);
  end if;

  select count(*), max(note) into v_events, v_note
    from public.approval_events
   where request_id = v_id and action = 'rejected';
  if v_events <> 1 or v_note is distinct from 'Not valid.' then
    raise exception 'POLICY-BATTERY FAIL 23.16: rejected event drift (rows %, note %)', v_events, v_note;
  end if;

  select count(*), max(outcome) into v_audits, v_outcome
    from public.audit_events
   where action = 'approval:decide' and resource_id = v_id;
  if v_audits <> 1 or v_outcome is distinct from 'rejected' then
    raise exception 'POLICY-BATTERY FAIL 23.16: rejected audit drift (rows %, outcome %)', v_audits, v_outcome;
  end if;
end $$;

-- ############################################################################
-- 23.17 — NEG (non-pending decide): the rejected request and the approved
-- 23.11 request cannot be decided again.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.decide_approval_request(
      current_setting('battery23.e')::uuid, 'approved', 'ok');
    raise exception 'POLICY-BATTERY FAIL 23.17: re-deciding a rejected request succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'approval request is not pending' then
      raise exception 'POLICY-BATTERY FAIL 23.17: rejected re-decide raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.decide_approval_request(
      current_setting('battery23.c')::uuid, 'rejected', 'ok');
    raise exception 'POLICY-BATTERY FAIL 23.17: re-deciding an approved request succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'approval request is not pending' then
      raise exception 'POLICY-BATTERY FAIL 23.17: approved re-decide raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- ############################################################################
-- 23.18 — POS (requester cancel): client-a creates and cancels its own
-- request; a second cancel hits the pending gate.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_id := public.create_approval_request(
    '20000000-0000-4000-8000-000000000001',
    null,
    'expense',
    'Battery requester cancel',
    null);
  perform set_config('battery23.f', v_id::text, true);

  perform public.cancel_approval_request(v_id);

  begin
    perform public.cancel_approval_request(v_id);
    raise exception 'POLICY-BATTERY FAIL 23.18: double cancel succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'approval request is not pending' then
      raise exception 'POLICY-BATTERY FAIL 23.18: double cancel raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery23.f')::uuid;
  v_row    public.approval_requests;
  v_events bigint;
  v_audits bigint;
begin
  select * into v_row from public.approval_requests where id = v_id;
  if v_row.status <> 'cancelled'
     or v_row.decided_by is not null
     or v_row.decided_at is not null
     or v_row.decision_note is not null then
    raise exception 'POLICY-BATTERY FAIL 23.18: cancelled row shape drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_events
    from public.approval_events
   where request_id = v_id
     and action = 'cancelled'
     and actor_id = '10000000-0000-4000-8000-000000000003'
     and note is null;
  if v_events <> 1 then
    raise exception 'POLICY-BATTERY FAIL 23.18: cancel event rows = %, want 1', v_events;
  end if;

  select count(*) into v_audits
    from public.audit_events
   where action = 'approval:cancel' and resource_id = v_id
     and outcome = 'allowed'
     and redacted_summary = 'approval request cancelled';
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 23.18: cancel audit rows = %, want 1', v_audits;
  end if;
end $$;

-- ############################################################################
-- 23.19 — NEG (other-client cancel): client-a creates; orphan (another
-- org-a client) and demo (no membership) cannot cancel it.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_id := public.create_approval_request(
    '20000000-0000-4000-8000-000000000001',
    null,
    'conflict',
    'Battery other client cancel',
    null);
  perform set_config('battery23.g', v_id::text, true);

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  begin
    perform public.cancel_approval_request(v_id);
    raise exception 'POLICY-BATTERY FAIL 23.19: another client cancel succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 23.19: other-client cancel raised "%"', sqlerrm;
    end if;
  end;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000006', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000006"}', false);
  begin
    perform public.cancel_approval_request(v_id);
    raise exception 'POLICY-BATTERY FAIL 23.19: non-member cancel succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 23.19: non-member cancel raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_row    public.approval_requests;
  v_audits bigint;
begin
  select * into v_row from public.approval_requests
   where id = current_setting('battery23.g')::uuid;
  if v_row.status <> 'pending' then
    raise exception 'POLICY-BATTERY FAIL 23.19: denied cancels changed the row: %', row_to_json(v_row);
  end if;
  select count(*) into v_audits
    from public.audit_events
   where action = 'approval:cancel' and resource_id = v_row.id;
  if v_audits <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.19: denied cancels wrote % audit row(s)', v_audits;
  end if;
end $$;

-- ############################################################################
-- 23.20 — POS (partner cancel): partner-a cancels client-a's request.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.cancel_approval_request(current_setting('battery23.g')::uuid);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery23.g')::uuid;
  v_row    public.approval_requests;
  v_events bigint;
  v_actor  uuid;
begin
  select * into v_row from public.approval_requests where id = v_id;
  if v_row.status <> 'cancelled' then
    raise exception 'POLICY-BATTERY FAIL 23.20: partner cancel left status %, want cancelled', v_row.status;
  end if;
  select count(*), max(actor_id) into v_events, v_actor
    from public.approval_events
   where request_id = v_id and action = 'cancelled';
  if v_events <> 1 or v_actor is distinct from '10000000-0000-4000-8000-000000000002' then
    raise exception 'POLICY-BATTERY FAIL 23.20: partner cancel event drift (rows %, actor %)', v_events, v_actor;
  end if;
end $$;

-- ############################################################################
-- 23.21 — NEG (missing id): decide/cancel on a random uuid raise
-- 'approval request not found' and write no audit row.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.decide_approval_request(gen_random_uuid(), 'approved', null);
    raise exception 'POLICY-BATTERY FAIL 23.21: decide on a missing id succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'approval request not found' then
      raise exception 'POLICY-BATTERY FAIL 23.21: missing-id decide raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.cancel_approval_request(gen_random_uuid());
    raise exception 'POLICY-BATTERY FAIL 23.21: cancel on a missing id succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'approval request not found' then
      raise exception 'POLICY-BATTERY FAIL 23.21: missing-id cancel raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_audits bigint;
begin
  select count(*) into v_audits
    from public.audit_events where action like 'approval:%';
  if v_audits <> 11 then
    raise exception 'POLICY-BATTERY FAIL 23.21: approval:* audit rows = %, want 11 after missing-id probes', v_audits;
  end if;
end $$;

-- ############################################################################
-- 23.22 — NEG (direct writes): authenticated holds SELECT only on both
-- tables — INSERT and UPDATE are denied at the privilege layer.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);

  begin
    insert into public.approval_requests
      (organization_id, title, kind)
    values
      ('20000000-0000-4000-8000-000000000001', 'Battery direct insert', 'other');
    raise exception 'POLICY-BATTERY FAIL 23.22: direct request INSERT succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.approval_requests
       set title = 'Battery hijacked'
     where id = current_setting('battery23.a')::uuid;
    raise exception 'POLICY-BATTERY FAIL 23.22: direct request UPDATE succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into public.approval_events
      (request_id, organization_id, action)
    values
      (current_setting('battery23.a')::uuid,
       '20000000-0000-4000-8000-000000000001', 'approved');
    raise exception 'POLICY-BATTERY FAIL 23.22: direct event INSERT succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.approval_events
       set action = 'rejected'
     where request_id = current_setting('battery23.a')::uuid;
    raise exception 'POLICY-BATTERY FAIL 23.22: direct event UPDATE succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_title  text;
  v_rows   bigint;
  v_events bigint;
begin
  select title into v_title
    from public.approval_requests where id = current_setting('battery23.a')::uuid;
  if v_title <> 'Battery conflict check' then
    raise exception 'POLICY-BATTERY FAIL 23.22: direct-write attempts changed the title: %', v_title;
  end if;
  select count(*) into v_rows from public.approval_requests;
  select count(*) into v_events from public.approval_events;
  if v_rows <> 9 then
    raise exception 'POLICY-BATTERY FAIL 23.22: request rows = %, want 9 after direct-write denials', v_rows;
  end if;
  if v_events <> 11 then
    raise exception 'POLICY-BATTERY FAIL 23.22: event rows = %, want 11 after direct-write denials', v_events;
  end if;
end $$;

-- ############################################################################
-- 23.23 — POS (function posture): all four RPCs are SECURITY DEFINER, pin
-- search_path = public, carry no parameter default, grant EXECUTE to
-- authenticated and not to anon.
-- ############################################################################
do $$
declare
  r     record;
  v_oid oid;
  v_cnt bigint;
  v_bad bigint;
begin
  for r in
    select * from (values
      ('create_approval_request', 'p_organization_id uuid, p_matter_id uuid, p_kind text, p_title text, p_description text'),
      ('decide_approval_request', 'p_id uuid, p_decision text, p_note text'),
      ('cancel_approval_request', 'p_id uuid'),
      ('list_approval_requests',  'p_organization_id uuid, p_status text')
    ) as t(fn, args)
  loop
    select p.oid into v_oid
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = r.fn
       and pg_get_function_arguments(p.oid) = r.args;
    if v_oid is null then
      raise exception 'POLICY-BATTERY FAIL 23.23: function %.%(%) missing', 'public', r.fn, r.args;
    end if;
    if not (select prosecdef from pg_proc where oid = v_oid) then
      raise exception 'POLICY-BATTERY FAIL 23.23: %.% is not SECURITY DEFINER', 'public', r.fn;
    end if;
    if not (select coalesce(proconfig, '{}'::text[]) @> array['search_path=public']::text[] from pg_proc where oid = v_oid) then
      raise exception 'POLICY-BATTERY FAIL 23.23: %.% does not pin search_path = public', 'public', r.fn;
    end if;
    if has_function_privilege('anon', v_oid, 'EXECUTE') then
      raise exception 'POLICY-BATTERY FAIL 23.23: anon holds EXECUTE on %', r.fn;
    end if;
    if not has_function_privilege('authenticated', v_oid, 'EXECUTE') then
      raise exception 'POLICY-BATTERY FAIL 23.23: authenticated lacks EXECUTE on %', r.fn;
    end if;
  end loop;

  select count(*) into v_cnt
    from information_schema.parameters p
    join information_schema.routines r
      on r.specific_schema = p.specific_schema
     and r.specific_name = p.specific_name
   where r.routine_schema = 'public'
     and r.routine_name in ('create_approval_request', 'decide_approval_request',
                            'cancel_approval_request', 'list_approval_requests');
  if v_cnt = 0 then
    raise exception 'POLICY-BATTERY FAIL 23.23: no parameters found for the four functions';
  end if;

  select count(*) into v_bad
    from information_schema.parameters p
    join information_schema.routines r
      on r.specific_schema = p.specific_schema
     and r.specific_name = p.specific_name
   where r.routine_schema = 'public'
     and r.routine_name in ('create_approval_request', 'decide_approval_request',
                            'cancel_approval_request', 'list_approval_requests')
     and p.parameter_default is not null;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.23: % parameter default(s) present (PostgREST incident rule)', v_bad;
  end if;
end $$;

-- ############################################################################
-- 23.24 — POS (table posture): both tables are RLS-enabled, authenticated
-- holds SELECT only (no INSERT/UPDATE/DELETE/TRUNCATE), anon holds nothing,
-- and each table carries exactly one policy.
-- ############################################################################
do $$
begin
  if not (select relrowsecurity from pg_class where oid = 'public.approval_requests'::regclass)
     or not (select relrowsecurity from pg_class where oid = 'public.approval_events'::regclass) then
    raise exception 'POLICY-BATTERY FAIL 23.24: RLS is not enabled on both approval tables';
  end if;

  if not has_table_privilege('authenticated', 'public.approval_requests', 'SELECT')
     or not has_table_privilege('authenticated', 'public.approval_events', 'SELECT') then
    raise exception 'POLICY-BATTERY FAIL 23.24: authenticated lacks SELECT on an approval table';
  end if;

  if has_table_privilege('authenticated', 'public.approval_requests', 'INSERT')
     or has_table_privilege('authenticated', 'public.approval_requests', 'UPDATE')
     or has_table_privilege('authenticated', 'public.approval_requests', 'DELETE')
     or has_table_privilege('authenticated', 'public.approval_requests', 'TRUNCATE')
     or has_table_privilege('authenticated', 'public.approval_events', 'INSERT')
     or has_table_privilege('authenticated', 'public.approval_events', 'UPDATE')
     or has_table_privilege('authenticated', 'public.approval_events', 'DELETE')
     or has_table_privilege('authenticated', 'public.approval_events', 'TRUNCATE') then
    raise exception 'POLICY-BATTERY FAIL 23.24: authenticated holds a direct write privilege';
  end if;

  if has_table_privilege('anon', 'public.approval_requests', 'SELECT')
     or has_table_privilege('anon', 'public.approval_requests', 'INSERT')
     or has_table_privilege('anon', 'public.approval_requests', 'UPDATE')
     or has_table_privilege('anon', 'public.approval_requests', 'DELETE')
     or has_table_privilege('anon', 'public.approval_events', 'SELECT')
     or has_table_privilege('anon', 'public.approval_events', 'INSERT')
     or has_table_privilege('anon', 'public.approval_events', 'UPDATE')
     or has_table_privilege('anon', 'public.approval_events', 'DELETE') then
    raise exception 'POLICY-BATTERY FAIL 23.24: anon holds an approval-table privilege';
  end if;

  if (select count(*) from pg_policies
       where schemaname = 'public' and tablename = 'approval_requests') <> 1
     or (select count(*) from pg_policies
       where schemaname = 'public' and tablename = 'approval_events') <> 1 then
    raise exception 'POLICY-BATTERY FAIL 23.24: each approval table must carry exactly one policy';
  end if;
end $$;

-- ############################################################################
-- 23.25 — POS (§8 final pin): exactly the successful writes are audited
-- (7 creates, 2 decisions, 2 cancels = 11 rows), every outcome is 'allowed',
-- every summary is one of the three fixed strings with no request content,
-- and the event trail matches the same 11 transitions.
-- ############################################################################
do $$
declare
  v_total   bigint;
  v_created bigint;
  v_decided bigint;
  v_cancel  bigint;
  v_bad     bigint;
  v_events  bigint;
  v_pending bigint;
  v_approved bigint;
  v_rejected bigint;
  v_cancelled bigint;
begin
  select count(*) into v_total
    from public.audit_events where action like 'approval:%';
  if v_total <> 11 then
    raise exception 'POLICY-BATTERY FAIL 23.25: approval:* audit rows = %, want exactly 11', v_total;
  end if;

  select count(*) into v_created from public.audit_events where action = 'approval:create';
  select count(*) into v_decided from public.audit_events where action = 'approval:decide';
  select count(*) into v_cancel  from public.audit_events where action = 'approval:cancel';
  if v_created <> 7 or v_decided <> 2 or v_cancel <> 2 then
    raise exception 'POLICY-BATTERY FAIL 23.25: audit mix drift (create %, decide %, cancel %)', v_created, v_decided, v_cancel;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action like 'approval:%'
     and (outcome <> 'allowed'
          or redacted_summary not in ('approval request created',
                                      'approval request decided',
                                      'approval request cancelled'));
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.25: % audit row(s) carry a non-fixed outcome/summary', v_bad;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action like 'approval:%'
     and (redacted_summary like '%Battery%'
          or redacted_summary like '%conflict%'
          or redacted_summary like '%waiver%'
          or redacted_summary like '%expense%'
          or redacted_summary like '%Not valid%'
          or redacted_summary like '%Looks good%');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.25: % audit summary(ies) leaked request content', v_bad;
  end if;

  select count(*) into v_events from public.approval_events;
  select count(*) into v_pending from public.approval_events where action = 'created';
  select count(*) into v_approved from public.approval_events where action = 'approved';
  select count(*) into v_rejected from public.approval_events where action = 'rejected';
  select count(*) into v_cancelled from public.approval_events where action = 'cancelled';
  if v_events <> 11 or v_pending <> 7 or v_approved <> 1
     or v_rejected <> 1 or v_cancelled <> 2 then
    raise exception 'POLICY-BATTERY FAIL 23.25: event mix drift (total %, created %, approved %, rejected %, cancelled %)',
      v_events, v_pending, v_approved, v_rejected, v_cancelled;
  end if;

  select count(*) into v_bad
    from public.approval_events
   where actor_id is null;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.25: % event row(s) carry a null actor', v_bad;
  end if;

  select count(*) into v_bad
    from public.approval_events e
    join public.approval_requests r on r.id = e.request_id
   where e.organization_id <> r.organization_id;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 23.25: % event row(s) disagree with their request org', v_bad;
  end if;
end $$;

rollback;
