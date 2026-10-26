-- ============================================================================
-- supabase/tests/24_compliance_alert_rls.sql — compliance alerts battery
--
-- Pins the compliance slice (supabase/migrations/24_compliance_alerts.sql +
-- supabase/policies/compliance_alerts.sql + compliance_alert_events.sql + the
-- four supabase/rpc/*compliance_alert* functions):
--   - create: partner (no matter) and compliance-officer (matter-linked)
--     positives with the created event and the redacted audit row; a client,
--     a cross-org matter, a suspended member and anon are denied; invalid
--     kind/severity and title/description bounds raise check_violation
--     (24.01-24.07);
--   - list: participant-scoped reads (partner/officer see the org queue, a
--     matter assignee sees its alert, an unrelated active member sees none),
--     cross-org denial, newest-first ordering, the exact status and severity
--     filters, and both read policies exercised directly (24.08-24.09,
--     24.19);
--   - acknowledge: any active member positive with event + audit; a resolved
--     alert and an already-acknowledged alert are refused (24.10-24.12);
--   - resolve: partner and compliance-officer positives with event + audit;
--     a client is denied, a resolved alert is refused, a missing id raises
--     the typed not-found without an audit row (24.13-24.17);
--   - direct INSERT/UPDATE is denied at the privilege layer for both tables
--     (24.18);
--   - structural posture: all four functions are SECURITY DEFINER with a
--     pinned search_path, no parameter default, authenticated EXECUTE and
--     anon none; both tables are RLS-enabled with SELECT-only grants and
--     exactly one policy each (24.20-24.21);
--   - §8 final pin: exactly the successful writes are audited with fixed
--     redacted summaries, and the event trail matches the state changes
--     (24.22).
--
-- The whole battery runs in ONE transaction and ROLLS BACK. The compliance
-- officer is created inside the transaction with a GENERATED id (the static
-- fixture cross-ref scan only accepts fixture UUIDs; a new literal would red
-- --check). Two synthetic ordering anchors with fixed 2001 timestamps are
-- inserted as the connection role at the top (no events/audit) so
-- newest-first ordering and the resolved-terminal path are provable —
-- RPC-created rows all share the transaction's now().
--
-- Fixture anchors (00_fixtures.sql): owner …0001 (platform owner, no
-- membership) · partner-a …0002 (org-a partner, active) · client-a …0003
-- (org-a client, active) · partner-b …0004 (org-b partner, active) ·
-- suspended-a …0005 (org-a membership suspended) · demo …0006 (no
-- membership) · orphan …0007 (org-a client, active) · org-a
-- 20000000-…-0001 · org-b 20000000-…-0002 · matter 2 40000000-…-0002
-- (org-a) · matter 5 40000000-…-0005 (org-a, partner-b assigned — cross-org
-- anchor).
--
-- Role handling: every behavior block runs under `set role authenticated`
-- with JWT impersonation (the 01/02/03 pattern); verification and the
-- fixtures run as the connection role (authenticated holds NO
-- INSERT/UPDATE/DELETE grant on either table).
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 24.00 — POS (setup): a generated compliance officer (active, org-a) plus
-- two synthetic anchors with fixed 2001 timestamps. No events/audit are
-- written for seeds; they roll back with the battery.
-- ############################################################################
do $$
declare
  v_officer uuid := gen_random_uuid();
  v_open    uuid;
  v_closed  uuid;
begin
  insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, created_at, updated_at)
  values (v_officer, 'officer-' || v_officer::text || '@org-a.test', now(),
          '{"display_name":"Compliance Officer"}', now(), now());

  insert into public.memberships
    (organization_id, user_id, role, status, created_by, created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001', v_officer, 'compliance_officer',
     'active', v_officer, now(), now());

  insert into public.compliance_alerts
    (organization_id, matter_id, kind, severity, title, status,
     created_by, created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001', null, 'other', 'low',
     'Battery seeded open alert', 'open',
     '10000000-0000-4000-8000-000000000002',
     '2001-01-02T00:00:00Z', '2001-01-02T00:00:00Z')
  returning id into v_open;

  insert into public.compliance_alerts
    (organization_id, matter_id, kind, severity, title, status,
     acknowledged_by, acknowledged_at, resolved_by, resolved_at,
     created_by, created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001', null, 'retention', 'critical',
     'Battery seeded resolved alert', 'resolved',
     '10000000-0000-4000-8000-000000000002', '2000-12-31T00:00:00Z',
     '10000000-0000-4000-8000-000000000002', '2001-01-01T00:00:00Z',
     '10000000-0000-4000-8000-000000000002',
     '2001-01-01T00:00:00Z', '2001-01-01T00:00:00Z')
  returning id into v_closed;

  if v_open is null or v_closed is null then
    raise exception 'POLICY-BATTERY FAIL 24.00: ordering anchors were not inserted';
  end if;
  perform set_config('battery24.officer', v_officer::text, true);
  perform set_config('battery24.seed_open', v_open::text, true);
  perform set_config('battery24.seed_resolved', v_closed::text, true);
end $$;

do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from public.memberships
   where organization_id = '20000000-0000-4000-8000-000000000001'
     and role = 'compliance_officer'
     and status = 'active';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.00: compliance-officer fixture rows = %, want 1', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 24.01 — POS (partner create, no matter): partner-a creates a deadline
-- alert. Row shape, trim, creator stamp, the 'created' event and the redacted
-- create audit row are verified.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_id := public.create_compliance_alert(
    '20000000-0000-4000-8000-000000000001',
    null,
    'deadline',
    'high',
    '  Battery partner alert  ',
    'Battery partner alert description.',
    '2030-01-01T00:00:00Z');
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 24.01: create_compliance_alert returned a null id';
  end if;
  perform set_config('battery24.a', v_id::text, true);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery24.a')::uuid;
  v_row    public.compliance_alerts;
  v_events bigint;
  v_audits bigint;
  v_sum    text;
begin
  select * into v_row from public.compliance_alerts where id = v_id;
  if not found then
    raise exception 'POLICY-BATTERY FAIL 24.01: created alert row missing';
  end if;
  if v_row.organization_id <> '20000000-0000-4000-8000-000000000001'
     or v_row.matter_id is not null
     or v_row.kind <> 'deadline'
     or v_row.severity <> 'high'
     or v_row.title <> 'Battery partner alert'
     or v_row.description is distinct from 'Battery partner alert description.'
     or v_row.status <> 'open'
     or v_row.due_at is distinct from '2030-01-01T00:00:00Z'::timestamptz
     or v_row.created_by is distinct from '10000000-0000-4000-8000-000000000002'
     or v_row.acknowledged_by is not null
     or v_row.acknowledged_at is not null
     or v_row.resolved_by is not null
     or v_row.resolved_at is not null then
    raise exception 'POLICY-BATTERY FAIL 24.01: created row shape/trim drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_events
    from public.compliance_alert_events
   where alert_id = v_id
     and action = 'created'
     and actor_id = '10000000-0000-4000-8000-000000000002'
     and note is null;
  if v_events <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.01: created event rows = %, want 1', v_events;
  end if;

  select count(*), max(redacted_summary) into v_audits, v_sum
    from public.audit_events
   where action = 'compliance_alert:create'
     and outcome = 'allowed'
     and resource_type = 'compliance_alert'
     and resource_id = v_id;
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.01: create audit rows = %, want 1', v_audits;
  end if;
  if v_sum is distinct from 'compliance alert created' then
    raise exception 'POLICY-BATTERY FAIL 24.01: create audit summary drift: %', v_sum;
  end if;
  if v_sum like '%Battery%' or v_sum like '%deadline%' then
    raise exception 'POLICY-BATTERY FAIL 24.01: create audit summary leaked alert content: %', v_sum;
  end if;
end $$;

-- ############################################################################
-- 24.02 — POS (compliance-officer create, matter-linked): the generated
-- officer creates a conflict alert on org-a matter 2.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', current_setting('battery24.officer'), false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('battery24.officer'))::text, false);
  v_id := public.create_compliance_alert(
    '20000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000002',
    'conflict',
    'medium',
    'Battery officer alert',
    null,
    null);
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 24.02: officer create returned a null id';
  end if;
  perform set_config('battery24.b', v_id::text, true);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery24.b')::uuid;
  v_row    public.compliance_alerts;
  v_events bigint;
  v_audits bigint;
begin
  select * into v_row from public.compliance_alerts where id = v_id;
  if not found then
    raise exception 'POLICY-BATTERY FAIL 24.02: officer alert row missing';
  end if;
  if v_row.organization_id <> '20000000-0000-4000-8000-000000000001'
     or v_row.matter_id <> '40000000-0000-4000-8000-000000000002'
     or v_row.kind <> 'conflict'
     or v_row.severity <> 'medium'
     or v_row.title <> 'Battery officer alert'
     or v_row.description is not null
     or v_row.status <> 'open'
     or v_row.due_at is not null
     or v_row.created_by is distinct from current_setting('battery24.officer')::uuid then
    raise exception 'POLICY-BATTERY FAIL 24.02: officer row shape drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_events
    from public.compliance_alert_events
   where alert_id = v_id and action = 'created'
     and actor_id = current_setting('battery24.officer')::uuid;
  if v_events <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.02: officer create events = %, want 1', v_events;
  end if;

  select count(*) into v_audits
    from public.audit_events where action = 'compliance_alert:create';
  if v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 24.02: create audit rows = %, want 2', v_audits;
  end if;
end $$;

-- ############################################################################
-- 24.03 — NEG (client create): client-a is an active org-a member but holds
-- neither create role. No row and no audit row is written.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.create_compliance_alert(
      '20000000-0000-4000-8000-000000000001', null, 'filing', 'low',
      'Battery client create', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.03: client create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 24.03: client create raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_rows   bigint;
  v_audits bigint;
begin
  select count(*) into v_rows from public.compliance_alerts;
  if v_rows <> 4 then
    raise exception 'POLICY-BATTERY FAIL 24.03: denied client create left % rows, want 4', v_rows;
  end if;
  select count(*) into v_audits
    from public.audit_events where action = 'compliance_alert:create';
  if v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 24.03: denied client create wrote an audit row (% total), want 2', v_audits;
  end if;
end $$;

-- ############################################################################
-- 24.04 — NEG (cross-org matter): partner-b is an org-b partner and names
-- org-a matter 5 in an org-b create. The same-org clause denies it; no row
-- and no audit row is written.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    perform public.create_compliance_alert(
      '20000000-0000-4000-8000-000000000002',
      '40000000-0000-4000-8000-000000000005',
      'filing', 'low', 'Battery cross-org matter', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.04: cross-org matter create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 24.04: cross-org matter raised "%" instead of permission denied', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_rows bigint;
begin
  select count(*) into v_rows from public.compliance_alerts;
  if v_rows <> 4 then
    raise exception 'POLICY-BATTERY FAIL 24.04: denied cross-org create left % rows, want 4', v_rows;
  end if;
end $$;

-- ############################################################################
-- 24.05 — NEG (validation): unmapped/null kind, unmapped/null severity, a
-- one-character title, a 161-character title and a 4001-character
-- description all raise check_violation.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_compliance_alert(
      '20000000-0000-4000-8000-000000000001', null, 'bribe', 'low',
      'Battery invalid kind', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.05: unmapped kind create succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.create_compliance_alert(
      '20000000-0000-4000-8000-000000000001', null, null, 'low',
      'Battery null kind', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.05: null kind create succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.create_compliance_alert(
      '20000000-0000-4000-8000-000000000001', null, 'other', 'urgent',
      'Battery invalid severity', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.05: unmapped severity create succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.create_compliance_alert(
      '20000000-0000-4000-8000-000000000001', null, 'other', null,
      'Battery null severity', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.05: null severity create succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.create_compliance_alert(
      '20000000-0000-4000-8000-000000000001', null, 'other', 'low',
      ' A ', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.05: one-character title create succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.create_compliance_alert(
      '20000000-0000-4000-8000-000000000001', null, 'other', 'low',
      repeat('x', 161), null, null);
    raise exception 'POLICY-BATTERY FAIL 24.05: 161-character title create succeeded';
  exception when check_violation then
    null;
  end;

  begin
    perform public.create_compliance_alert(
      '20000000-0000-4000-8000-000000000001', null, 'other', 'low',
      'Battery long description', repeat('y', 4001), null);
    raise exception 'POLICY-BATTERY FAIL 24.05: 4001-character description create succeeded';
  exception when check_violation then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_rows bigint;
begin
  select count(*) into v_rows from public.compliance_alerts;
  if v_rows <> 4 then
    raise exception 'POLICY-BATTERY FAIL 24.05: invalid creates left % rows, want 4', v_rows;
  end if;
end $$;

-- ############################################################################
-- 24.06 — NEG (suspended member): suspended-a holds a SUSPENDED org-a
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
    perform public.create_compliance_alert(
      '20000000-0000-4000-8000-000000000001', null, 'other', 'low',
      'Battery suspended create', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.06: suspended create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 24.06: suspended create raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.list_compliance_alerts(
      '20000000-0000-4000-8000-000000000001', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.06: suspended list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 24.06: suspended list raised "%"', sqlerrm;
    end if;
  end;

  select count(*) into v_cnt from public.compliance_alerts;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.06: suspended caller sees % alert rows, want 0', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 24.07 — NEG (unauthenticated): anon holds no EXECUTE grant and no table
-- grant, so the RPC calls and the direct reads fail at the privilege layer.
-- ############################################################################
set role anon;
do $$
begin
  begin
    perform public.create_compliance_alert(
      '20000000-0000-4000-8000-000000000001', null, 'other', 'low',
      'Battery anon create', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.07: anon create succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform public.list_compliance_alerts(
      '20000000-0000-4000-8000-000000000001', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.07: anon list succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform count(*) from public.compliance_alerts;
    raise exception 'POLICY-BATTERY FAIL 24.07: anon alert select succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform count(*) from public.compliance_alert_events;
    raise exception 'POLICY-BATTERY FAIL 24.07: anon event select succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

-- ############################################################################
-- 24.08 — POS/NEG (participant-scoped list): partner-a and the officer read
-- the four org-a rows; client-a (assigned on matter 2) reads only the
-- matter-2 alert; orphan (active org-a member, assigned only on matter 4)
-- reads none; partner-b reads zero org-b rows. Direct selects and the event
-- read policy are exercised too.
-- ############################################################################
set role authenticated;
do $$
declare
  v_total  bigint;
  v_events bigint;
  v_only   uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);

  select count(*) into v_total
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, null);
  if v_total <> 4 then
    raise exception 'POLICY-BATTERY FAIL 24.08: org-a list returned % rows, want 4', v_total;
  end if;

  select count(*) into v_total
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, null)
   where organization_id <> '20000000-0000-4000-8000-000000000001';
  if v_total <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.08: org-a list exposed % cross-org rows', v_total;
  end if;

  select count(*) into v_total from public.compliance_alerts;
  select count(*) into v_events from public.compliance_alert_events;
  if v_total <> 4 then
    raise exception 'POLICY-BATTERY FAIL 24.08: direct alert select returned % rows, want 4', v_total;
  end if;
  if v_events <> 2 then
    raise exception 'POLICY-BATTERY FAIL 24.08: direct event select returned % rows, want 2', v_events;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_total
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, null);
  if v_total <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.08: client-a sees % org-a rows, want 1', v_total;
  end if;
  select id into v_only
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, null);
  if v_only is distinct from current_setting('battery24.b')::uuid then
    raise exception 'POLICY-BATTERY FAIL 24.08: client-a sees % instead of its matter-linked alert', v_only;
  end if;
  select count(*) into v_total from public.compliance_alerts;
  select count(*) into v_events from public.compliance_alert_events;
  if v_total <> 1 or v_events <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.08: client-a direct select drift (alerts %, events %)', v_total, v_events;
  end if;

  perform set_config('request.jwt.claim.sub', current_setting('battery24.officer'), false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('battery24.officer'))::text, false);
  select count(*) into v_total
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, null);
  if v_total <> 4 then
    raise exception 'POLICY-BATTERY FAIL 24.08: officer sees % org-a rows, want 4', v_total;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  select count(*) into v_total
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, null);
  select count(*) into v_events from public.compliance_alerts;
  if v_total <> 0 or v_events <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.08: unrelated active member sees rows (rpc %, direct %)', v_total, v_events;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_total
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000002', null, null);
  select count(*) into v_events from public.compliance_alerts;
  if v_total <> 0 or v_events <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.08: org-b caller sees foreign rows (rpc %, direct %)', v_total, v_events;
  end if;
end $$;
reset role;

-- ############################################################################
-- 24.09 — NEG (cross-org list): partner-a and client-a are active org-a
-- members but hold no org-b membership — listing org-b raises.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.list_compliance_alerts('20000000-0000-4000-8000-000000000002', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.09: partner-a cross-org list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 24.09: partner-a cross-org list raised "%"', sqlerrm;
    end if;
  end;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.list_compliance_alerts('20000000-0000-4000-8000-000000000002', null, null);
    raise exception 'POLICY-BATTERY FAIL 24.09: client-a cross-org list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 24.09: client-a cross-org list raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- ############################################################################
-- 24.10 — POS (member acknowledge): client-a acknowledges the open 24.01
-- alert. Status, stamps, the 'acknowledged' event and the audit row are
-- verified.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  perform public.acknowledge_compliance_alert(current_setting('battery24.a')::uuid);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery24.a')::uuid;
  v_row    public.compliance_alerts;
  v_events bigint;
  v_actor  uuid;
  v_audits bigint;
  v_sum    text;
begin
  select * into v_row from public.compliance_alerts where id = v_id;
  if v_row.status <> 'acknowledged'
     or v_row.acknowledged_by is distinct from '10000000-0000-4000-8000-000000000003'
     or v_row.acknowledged_at is null
     or v_row.resolved_by is not null
     or v_row.resolved_at is not null
     or v_row.updated_at < v_row.created_at then
    raise exception 'POLICY-BATTERY FAIL 24.10: acknowledged row shape drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_events
    from public.compliance_alert_events
   where alert_id = v_id and action = 'acknowledged' and note is null;
  if v_events <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.10: acknowledged event rows = %, want 1', v_events;
  end if;
  select actor_id into v_actor
    from public.compliance_alert_events
   where alert_id = v_id and action = 'acknowledged';
  if v_actor is distinct from '10000000-0000-4000-8000-000000000003' then
    raise exception 'POLICY-BATTERY FAIL 24.10: acknowledged event actor drift: %', v_actor;
  end if;

  select count(*), max(redacted_summary) into v_audits, v_sum
    from public.audit_events
   where action = 'compliance_alert:acknowledge'
     and outcome = 'allowed'
     and resource_type = 'compliance_alert'
     and resource_id = v_id;
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.10: acknowledge audit rows = %, want 1', v_audits;
  end if;
  if v_sum is distinct from 'compliance alert acknowledged' then
    raise exception 'POLICY-BATTERY FAIL 24.10: acknowledge audit summary drift: %', v_sum;
  end if;
end $$;

-- ############################################################################
-- 24.11 — NEG (acknowledge on resolved): the seeded resolved alert raises
-- 'compliance alert is already resolved' and writes no event or audit row.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.acknowledge_compliance_alert(current_setting('battery24.seed_resolved')::uuid);
    raise exception 'POLICY-BATTERY FAIL 24.11: acknowledge on a resolved alert succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'compliance alert is already resolved' then
      raise exception 'POLICY-BATTERY FAIL 24.11: resolved acknowledge raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_id      uuid := current_setting('battery24.seed_resolved')::uuid;
  v_events  bigint;
  v_audits  bigint;
begin
  select count(*) into v_events
    from public.compliance_alert_events where alert_id = v_id;
  select count(*) into v_audits
    from public.audit_events where resource_id = v_id;
  if v_events <> 0 or v_audits <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.11: denied acknowledge wrote % event(s) / % audit row(s)', v_events, v_audits;
  end if;
end $$;

-- ############################################################################
-- 24.12 — NEG (double acknowledge): the 24.01 alert is already acknowledged;
-- a second acknowledgement raises the typed error and leaves the row and
-- audit trail untouched.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.acknowledge_compliance_alert(current_setting('battery24.a')::uuid);
    raise exception 'POLICY-BATTERY FAIL 24.12: double acknowledge succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'compliance alert is already acknowledged' then
      raise exception 'POLICY-BATTERY FAIL 24.12: double acknowledge raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_events  bigint;
  v_audits  bigint;
begin
  select count(*) into v_events
    from public.compliance_alert_events
   where alert_id = current_setting('battery24.a')::uuid and action = 'acknowledged';
  select count(*) into v_audits
    from public.audit_events
   where action = 'compliance_alert:acknowledge'
     and resource_id = current_setting('battery24.a')::uuid;
  if v_events <> 1 or v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.12: double acknowledge changed counts (events %, audits %)', v_events, v_audits;
  end if;
end $$;

-- ############################################################################
-- 24.13 — NEG (client resolve): client-a is an active member and may
-- acknowledge, but resolve requires partner/compliance_officer. The alert
-- stays acknowledged with no resolve event or audit row.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.resolve_compliance_alert(
      current_setting('battery24.a')::uuid, 'Battery client resolve');
    raise exception 'POLICY-BATTERY FAIL 24.13: client resolve succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 24.13: client resolve raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_row    public.compliance_alerts;
  v_events bigint;
  v_audits bigint;
begin
  select * into v_row
    from public.compliance_alerts where id = current_setting('battery24.a')::uuid;
  select count(*) into v_events
    from public.compliance_alert_events
   where alert_id = current_setting('battery24.a')::uuid and action = 'resolved';
  select count(*) into v_audits
    from public.audit_events
   where action = 'compliance_alert:resolve'
     and resource_id = current_setting('battery24.a')::uuid;
  if v_row.status <> 'acknowledged' or v_row.resolved_by is not null
     or v_events <> 0 or v_audits <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.13: denied client resolve changed state (status %, events %, audits %)',
      v_row.status, v_events, v_audits;
  end if;
end $$;

-- ############################################################################
-- 24.14 — POS (officer resolve): the compliance officer resolves the
-- acknowledged alert with a padded note. The stored note is trimmed; the
-- event carries it; the audit summary is fixed.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', current_setting('battery24.officer'), false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('battery24.officer'))::text, false);
  perform public.resolve_compliance_alert(
    current_setting('battery24.a')::uuid, '  Reviewed and closed.  ');
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery24.a')::uuid;
  v_row    public.compliance_alerts;
  v_events bigint;
  v_note   text;
  v_actor  uuid;
  v_audits bigint;
  v_sum    text;
begin
  select * into v_row from public.compliance_alerts where id = v_id;
  if v_row.status <> 'resolved'
     or v_row.resolved_by is distinct from current_setting('battery24.officer')::uuid
     or v_row.resolved_at is null
     or v_row.acknowledged_by is distinct from '10000000-0000-4000-8000-000000000003' then
    raise exception 'POLICY-BATTERY FAIL 24.14: resolved row shape drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_events
    from public.compliance_alert_events
   where alert_id = v_id and action = 'resolved';
  if v_events <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.14: resolved event rows = %, want 1', v_events;
  end if;
  select note, actor_id into v_note, v_actor
    from public.compliance_alert_events
   where alert_id = v_id and action = 'resolved';
  if v_note is distinct from 'Reviewed and closed.'
     or v_actor is distinct from current_setting('battery24.officer')::uuid then
    raise exception 'POLICY-BATTERY FAIL 24.14: resolved event drift (note %, actor %)', v_note, v_actor;
  end if;

  select count(*), max(redacted_summary) into v_audits, v_sum
    from public.audit_events
   where action = 'compliance_alert:resolve'
     and outcome = 'allowed'
     and resource_id = v_id;
  if v_audits <> 1 or v_sum is distinct from 'compliance alert resolved' then
    raise exception 'POLICY-BATTERY FAIL 24.14: resolve audit drift (rows %, summary %)', v_audits, v_sum;
  end if;
end $$;

-- ############################################################################
-- 24.15 — POS (partner resolve): partner-a resolves the officer-created
-- alert with no note; the event note is null and the audit row is written.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.resolve_compliance_alert(current_setting('battery24.b')::uuid, null);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery24.b')::uuid;
  v_row    public.compliance_alerts;
  v_events bigint;
  v_audits bigint;
begin
  select * into v_row from public.compliance_alerts where id = v_id;
  if v_row.status <> 'resolved'
     or v_row.resolved_by is distinct from '10000000-0000-4000-8000-000000000002'
     or v_row.resolved_at is null
     or v_row.acknowledged_by is not null then
    raise exception 'POLICY-BATTERY FAIL 24.15: partner resolve row drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_events
    from public.compliance_alert_events
   where alert_id = v_id and action = 'resolved' and note is null;
  select count(*) into v_audits
    from public.audit_events where action = 'compliance_alert:resolve';
  if v_events <> 1 or v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 24.15: partner resolve counts (events %, audits %)', v_events, v_audits;
  end if;
end $$;

-- ############################################################################
-- 24.16 — NEG (resolve on resolved): re-resolving 24.01 raises
-- 'compliance alert is already resolved' and writes nothing.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.resolve_compliance_alert(
      current_setting('battery24.a')::uuid, 'again');
    raise exception 'POLICY-BATTERY FAIL 24.16: re-resolve succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'compliance alert is already resolved' then
      raise exception 'POLICY-BATTERY FAIL 24.16: re-resolve raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_events bigint;
  v_audits bigint;
begin
  select count(*) into v_events
    from public.compliance_alert_events
   where alert_id = current_setting('battery24.a')::uuid and action = 'resolved';
  select count(*) into v_audits
    from public.audit_events where action = 'compliance_alert:resolve';
  if v_events <> 1 or v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 24.16: denied re-resolve changed counts (events %, audits %)', v_events, v_audits;
  end if;
end $$;

-- ############################################################################
-- 24.17 — NEG (missing id): acknowledge/resolve on a random uuid raise
-- 'compliance alert not found' and write no audit row.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.acknowledge_compliance_alert(gen_random_uuid());
    raise exception 'POLICY-BATTERY FAIL 24.17: acknowledge on a missing id succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'compliance alert not found' then
      raise exception 'POLICY-BATTERY FAIL 24.17: missing-id acknowledge raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.resolve_compliance_alert(gen_random_uuid(), null);
    raise exception 'POLICY-BATTERY FAIL 24.17: resolve on a missing id succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'compliance alert not found' then
      raise exception 'POLICY-BATTERY FAIL 24.17: missing-id resolve raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_audits bigint;
begin
  select count(*) into v_audits
    from public.audit_events where action like 'compliance_alert:%';
  if v_audits <> 5 then
    raise exception 'POLICY-BATTERY FAIL 24.17: compliance_alert:* audit rows = %, want 5 after missing-id probes', v_audits;
  end if;
end $$;

-- ############################################################################
-- 24.18 — NEG (direct writes): authenticated holds SELECT only on both
-- tables — INSERT and UPDATE are denied at the privilege layer.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);

  begin
    insert into public.compliance_alerts
      (organization_id, kind, severity, title)
    values
      ('20000000-0000-4000-8000-000000000001', 'other', 'low', 'Battery direct insert');
    raise exception 'POLICY-BATTERY FAIL 24.18: direct alert INSERT succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.compliance_alerts
       set title = 'Battery hijacked'
     where id = current_setting('battery24.a')::uuid;
    raise exception 'POLICY-BATTERY FAIL 24.18: direct alert UPDATE succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into public.compliance_alert_events
      (alert_id, organization_id, action)
    values
      (current_setting('battery24.a')::uuid,
       '20000000-0000-4000-8000-000000000001', 'resolved');
    raise exception 'POLICY-BATTERY FAIL 24.18: direct event INSERT succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.compliance_alert_events
       set action = 'acknowledged'
     where alert_id = current_setting('battery24.a')::uuid;
    raise exception 'POLICY-BATTERY FAIL 24.18: direct event UPDATE succeeded';
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
    from public.compliance_alerts where id = current_setting('battery24.a')::uuid;
  if v_title <> 'Battery partner alert' then
    raise exception 'POLICY-BATTERY FAIL 24.18: direct-write attempts changed the title: %', v_title;
  end if;
  select count(*) into v_rows from public.compliance_alerts;
  select count(*) into v_events from public.compliance_alert_events;
  if v_rows <> 4 then
    raise exception 'POLICY-BATTERY FAIL 24.18: alert rows = %, want 4 after direct-write denials', v_rows;
  end if;
  if v_events <> 5 then
    raise exception 'POLICY-BATTERY FAIL 24.18: event rows = %, want 5 after direct-write denials', v_events;
  end if;
end $$;

-- ############################################################################
-- 24.19 — POS (filters + ordering): exact status and severity filters,
-- the combined filter, and the newest-first tail (the two 2001 anchors).
-- ############################################################################
set role authenticated;
do $$
declare
  v_open    bigint;
  v_ack     bigint;
  v_res     bigint;
  v_low     bigint;
  v_medium  bigint;
  v_high    bigint;
  v_crit    bigint;
  v_combo   bigint;
  v_third   uuid;
  v_fourth  uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);

  select count(*) into v_open
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', 'open', null);
  select count(*) into v_ack
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', 'acknowledged', null);
  select count(*) into v_res
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', 'resolved', null);
  if v_open <> 1 or v_ack <> 0 or v_res <> 3 then
    raise exception 'POLICY-BATTERY FAIL 24.19: status filter drift (open %, acknowledged %, resolved %)',
      v_open, v_ack, v_res;
  end if;

  select count(*) into v_low
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, 'low');
  select count(*) into v_medium
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, 'medium');
  select count(*) into v_high
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, 'high');
  select count(*) into v_crit
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, 'critical');
  if v_low <> 1 or v_medium <> 1 or v_high <> 1 or v_crit <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.19: severity filter drift (low %, medium %, high %, critical %)',
      v_low, v_medium, v_high, v_crit;
  end if;

  select count(*) into v_combo
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', 'resolved', 'high');
  if v_combo <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.19: combined filter returned %, want 1', v_combo;
  end if;

  select id into v_third
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, null)
   order by created_at desc
   offset 2 limit 1;
  select id into v_fourth
    from public.list_compliance_alerts('20000000-0000-4000-8000-000000000001', null, null)
   order by created_at desc
   offset 3 limit 1;
  if v_third is distinct from current_setting('battery24.seed_open')::uuid
     or v_fourth is distinct from current_setting('battery24.seed_resolved')::uuid then
    raise exception 'POLICY-BATTERY FAIL 24.19: list is not newest-first (tail % / %)', v_third, v_fourth;
  end if;
end $$;
reset role;

-- ############################################################################
-- 24.20 — POS (function posture): all four RPCs are SECURITY DEFINER, pin
-- search_path = public, carry no parameter default, grant EXECUTE to
-- authenticated and not to anon.
-- ############################################################################
do $$
declare
  r     record;
  v_oid oid;
  v_bad bigint;
begin
  for r in
    select * from (values
      ('create_compliance_alert',
       'p_organization_id uuid, p_matter_id uuid, p_kind text, p_severity text, p_title text, p_description text, p_due_at timestamp with time zone'),
      ('acknowledge_compliance_alert', 'p_id uuid'),
      ('resolve_compliance_alert', 'p_id uuid, p_note text'),
      ('list_compliance_alerts',
       'p_organization_id uuid, p_status text, p_severity text')
    ) as t(fn, args)
  loop
    select p.oid into v_oid
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = r.fn
       and pg_get_function_arguments(p.oid) = r.args;
    if v_oid is null then
      raise exception 'POLICY-BATTERY FAIL 24.20: function %.%(%) missing', 'public', r.fn, r.args;
    end if;
    if not (select prosecdef from pg_proc where oid = v_oid) then
      raise exception 'POLICY-BATTERY FAIL 24.20: %.% is not SECURITY DEFINER', 'public', r.fn;
    end if;
    if not (select coalesce(proconfig, '{}'::text[]) @> array['search_path=public']::text[] from pg_proc where oid = v_oid) then
      raise exception 'POLICY-BATTERY FAIL 24.20: %.% does not pin search_path = public', 'public', r.fn;
    end if;
    if has_function_privilege('anon', v_oid, 'EXECUTE') then
      raise exception 'POLICY-BATTERY FAIL 24.20: anon holds EXECUTE on %', r.fn;
    end if;
    if not has_function_privilege('authenticated', v_oid, 'EXECUTE') then
      raise exception 'POLICY-BATTERY FAIL 24.20: authenticated lacks EXECUTE on %', r.fn;
    end if;
  end loop;

  select count(*) into v_bad
    from information_schema.parameters p
    join information_schema.routines r
      on r.specific_schema = p.specific_schema
     and r.specific_name = p.specific_name
   where r.routine_schema = 'public'
     and r.routine_name in ('create_compliance_alert', 'acknowledge_compliance_alert',
                            'resolve_compliance_alert', 'list_compliance_alerts')
     and p.parameter_default is not null;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.20: % parameter default(s) present (PostgREST incident rule)', v_bad;
  end if;
end $$;

-- ############################################################################
-- 24.21 — POS (table posture): both tables are RLS-enabled, authenticated
-- holds SELECT only (no INSERT/UPDATE/DELETE/TRUNCATE), anon holds nothing,
-- and each table carries exactly one policy.
-- ############################################################################
do $$
begin
  if not (select relrowsecurity from pg_class where oid = 'public.compliance_alerts'::regclass)
     or not (select relrowsecurity from pg_class where oid = 'public.compliance_alert_events'::regclass) then
    raise exception 'POLICY-BATTERY FAIL 24.21: RLS is not enabled on both compliance tables';
  end if;

  if not has_table_privilege('authenticated', 'public.compliance_alerts', 'SELECT')
     or not has_table_privilege('authenticated', 'public.compliance_alert_events', 'SELECT') then
    raise exception 'POLICY-BATTERY FAIL 24.21: authenticated lacks SELECT on a compliance table';
  end if;

  if has_table_privilege('authenticated', 'public.compliance_alerts', 'INSERT')
     or has_table_privilege('authenticated', 'public.compliance_alerts', 'UPDATE')
     or has_table_privilege('authenticated', 'public.compliance_alerts', 'DELETE')
     or has_table_privilege('authenticated', 'public.compliance_alerts', 'TRUNCATE')
     or has_table_privilege('authenticated', 'public.compliance_alert_events', 'INSERT')
     or has_table_privilege('authenticated', 'public.compliance_alert_events', 'UPDATE')
     or has_table_privilege('authenticated', 'public.compliance_alert_events', 'DELETE')
     or has_table_privilege('authenticated', 'public.compliance_alert_events', 'TRUNCATE') then
    raise exception 'POLICY-BATTERY FAIL 24.21: authenticated holds a direct write privilege';
  end if;

  if has_table_privilege('anon', 'public.compliance_alerts', 'SELECT')
     or has_table_privilege('anon', 'public.compliance_alerts', 'INSERT')
     or has_table_privilege('anon', 'public.compliance_alerts', 'UPDATE')
     or has_table_privilege('anon', 'public.compliance_alerts', 'DELETE')
     or has_table_privilege('anon', 'public.compliance_alert_events', 'SELECT')
     or has_table_privilege('anon', 'public.compliance_alert_events', 'INSERT')
     or has_table_privilege('anon', 'public.compliance_alert_events', 'UPDATE')
     or has_table_privilege('anon', 'public.compliance_alert_events', 'DELETE') then
    raise exception 'POLICY-BATTERY FAIL 24.21: anon holds a compliance-table privilege';
  end if;

  if (select count(*) from pg_policies
       where schemaname = 'public' and tablename = 'compliance_alerts') <> 1
     or (select count(*) from pg_policies
       where schemaname = 'public' and tablename = 'compliance_alert_events') <> 1 then
    raise exception 'POLICY-BATTERY FAIL 24.21: each compliance table must carry exactly one policy';
  end if;
end $$;

-- ############################################################################
-- 24.22 — POS (§8 final pin): exactly the successful writes are audited
-- (2 creates, 1 acknowledgement, 2 resolutions = 5 rows), every outcome is
-- 'allowed', every summary is one of the fixed strings with no alert content,
-- every event actor is present and agrees with its alert's org, and the two
-- synthetic seeds carry no event or audit row.
-- ############################################################################
do $$
declare
  v_total   bigint;
  v_created bigint;
  v_acked   bigint;
  v_resolved bigint;
  v_bad     bigint;
  v_events  bigint;
  v_ev_created bigint;
  v_ev_acked bigint;
  v_ev_resolved bigint;
begin
  select count(*) into v_total
    from public.audit_events where action like 'compliance_alert:%';
  if v_total <> 5 then
    raise exception 'POLICY-BATTERY FAIL 24.22: compliance_alert:* audit rows = %, want exactly 5', v_total;
  end if;

  select count(*) into v_created from public.audit_events where action = 'compliance_alert:create';
  select count(*) into v_acked from public.audit_events where action = 'compliance_alert:acknowledge';
  select count(*) into v_resolved from public.audit_events where action = 'compliance_alert:resolve';
  if v_created <> 2 or v_acked <> 1 or v_resolved <> 2 then
    raise exception 'POLICY-BATTERY FAIL 24.22: audit mix drift (create %, acknowledge %, resolve %)',
      v_created, v_acked, v_resolved;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action like 'compliance_alert:%'
     and (outcome <> 'allowed'
          or resource_type <> 'compliance_alert'
          or redacted_summary not in ('compliance alert created',
                                      'compliance alert acknowledged',
                                      'compliance alert resolved'));
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.22: % audit row(s) carry a non-fixed outcome/type/summary', v_bad;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action like 'compliance_alert:%'
     and (redacted_summary like '%Battery%'
          or redacted_summary like '%partner%'
          or redacted_summary like '%officer%'
          or redacted_summary like '%Reviewed%'
          or redacted_summary like '%deadline%'
          or redacted_summary like '%conflict%'
          or redacted_summary like '%retention%');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.22: % audit summary(ies) leaked alert content', v_bad;
  end if;

  select count(*) into v_bad
    from public.audit_events a
   where a.action like 'compliance_alert:%'
     and not exists (
       select 1 from public.compliance_alerts c where c.id = a.resource_id
     );
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.22: % audit row(s) point at no alert', v_bad;
  end if;

  select count(*) into v_events from public.compliance_alert_events;
  select count(*) into v_ev_created from public.compliance_alert_events where action = 'created';
  select count(*) into v_ev_acked from public.compliance_alert_events where action = 'acknowledged';
  select count(*) into v_ev_resolved from public.compliance_alert_events where action = 'resolved';
  if v_events <> 5 or v_ev_created <> 2 or v_ev_acked <> 1 or v_ev_resolved <> 2 then
    raise exception 'POLICY-BATTERY FAIL 24.22: event mix drift (total %, created %, acknowledged %, resolved %)',
      v_events, v_ev_created, v_ev_acked, v_ev_resolved;
  end if;

  select count(*) into v_bad from public.compliance_alert_events where actor_id is null;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.22: % event row(s) carry a null actor', v_bad;
  end if;

  select count(*) into v_bad
    from public.compliance_alert_events e
    join public.compliance_alerts a on a.id = e.alert_id
   where e.organization_id <> a.organization_id;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.22: % event row(s) disagree with their alert org', v_bad;
  end if;

  select count(*) into v_bad
    from public.compliance_alert_events
   where alert_id in (current_setting('battery24.seed_open')::uuid,
                      current_setting('battery24.seed_resolved')::uuid);
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.22: % event row(s) exist for the synthetic seeds', v_bad;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action like 'compliance_alert:%'
     and resource_id in (current_setting('battery24.seed_open')::uuid,
                         current_setting('battery24.seed_resolved')::uuid);
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 24.22: % audit row(s) exist for the synthetic seeds', v_bad;
  end if;
end $$;

rollback;
