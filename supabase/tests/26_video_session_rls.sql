-- ============================================================================
-- supabase/tests/26_video_session_rls.sql — video sessions battery
--
-- Pins the video slice (supabase/migrations/26_video_sessions.sql +
-- supabase/policies/video_sessions.sql + the five supabase/rpc/*video*
-- functions):
--   - partner create with the generated room shape and the redacted
--     video_session:create audit row (26.01);
--   - attorney create on a readable matter (26.02);
--   - client / cross-org matter / suspended / anon create denials
--     (26.03-26.05);
--   - booking-linked create positive and a cross-org booking denial
--     (26.06-26.07);
--   - participant-scoped list/get (partner sees the org, the creator/matter
--     reader reads its own session, the booking client reads theirs, an
--     unrelated active member reads none), cross-org list denial
--     (26.08-26.10);
--   - booking-client mark-live positive + audit, terminal/live mark-live
--     denials (26.11-26.12);
--   - end by creator positive, end by partner positive, unrelated-client
--     denial (26.13-26.15);
--   - direct INSERT/UPDATE/DELETE denied at the privilege layer (26.16);
--   - room-name shape + uniqueness + the CHECK (26.17);
--   - structural posture: RLS on, SELECT-only grant, one read policy, all
--     five functions SECURITY DEFINER + pinned search_path + no parameter
--     defaults + the exact EXECUTE surface (26.18);
--   - final audit/session census with fixed redacted summaries (26.19).
--
-- The whole battery runs in ONE transaction and ROLLS BACK. Fixture anchors
-- (00_fixtures.sql): owner …0001 (platform owner, no membership) · partner-a
-- …0002 (org-a partner, active) · client-a …0003 (org-a client, active) ·
-- partner-b …0004 (org-b partner, active) · suspended-a …0005 (org-a
-- membership suspended) · org-a 20000000-…-0001 · org-b 20000000-…-0002 ·
-- matter 5 40000000-…-0005 (org-a, created by partner-b — cross-org anchor) ·
-- consultation e0000000-…-0001 (client-a, org-a) · slot
-- d0000000-…-0002 (available).
--
-- Role handling: every behavior block runs under `set role authenticated`
-- with JWT impersonation (the 01/02/03 pattern); seeded rows and verification
-- run as the connection role (authenticated holds no write grant).
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 26.00 — POS (setup): a generated org-a attorney with a generated matter
-- assigned to them, three seeded sessions (org-a scheduled, org-b scheduled,
-- org-a ended) at fixed 2001 timestamps, and one generated org-b booking
-- (partner-b is an org-b member) for the cross-org booking denial. Seeds are
-- written as the connection role and roll back with the battery.
-- ############################################################################
do $$
declare
  v_attorney uuid := gen_random_uuid();
  v_matter   uuid;
  v_seed_a   uuid;
  v_seed_b   uuid;
  v_ended    uuid;
  v_booking  uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, created_at, updated_at)
  values (v_attorney, 'video-attorney-' || v_attorney::text || '@org-a.test', now(),
          '{"display_name":"Video Attorney"}', now(), now());

  insert into public.memberships
    (organization_id, user_id, role, status, created_by, created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001', v_attorney, 'attorney',
     'active', v_attorney, now(), now());

  insert into public.matters
    (organization_id, title, practice_area, status, assigned_attorney_id, created_by, created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001', 'Battery video matter', 'civil', 'open',
     v_attorney, v_attorney, now(), now())
  returning id into v_matter;

  insert into public.video_sessions
    (organization_id, matter_id, booking_id, room_name, provider, status,
     scheduled_at, started_at, ended_at, created_by, created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001', null, null,
     'room_0123456789abcdef0123456789abcdef', 'livekit', 'scheduled',
     '2001-01-02T00:00:00Z', null, null,
     '10000000-0000-4000-8000-000000000002',
     '2001-01-02T00:00:00Z', '2001-01-02T00:00:00Z')
  returning id into v_seed_a;

  insert into public.video_sessions
    (organization_id, matter_id, booking_id, room_name, provider, status,
     scheduled_at, started_at, ended_at, created_by, created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000002', null, null,
     'room_fedcba9876543210fedcba9876543210', 'livekit', 'scheduled',
     '2001-01-01T00:00:00Z', null, null,
     '10000000-0000-4000-8000-000000000004',
     '2001-01-01T00:00:00Z', '2001-01-01T00:00:00Z')
  returning id into v_seed_b;

  insert into public.video_sessions
    (organization_id, matter_id, booking_id, room_name, provider, status,
     scheduled_at, started_at, ended_at, created_by, created_at, updated_at)
  values
    ('20000000-0000-4000-8000-000000000001', null, null,
     'room_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'livekit', 'ended',
     '2001-01-03T00:00:00Z', '2001-01-03T00:05:00Z', '2001-01-03T00:30:00Z',
     '10000000-0000-4000-8000-000000000002',
     '2001-01-03T00:00:00Z', '2001-01-03T00:30:00Z')
  returning id into v_ended;

  insert into public.consultations
    (id, client_user_id, slot_id, category, topic, attorney_ref, status,
     reference_id, created_at, updated_at, cancelled_at)
  values
    (v_booking, '10000000-0000-4000-8000-000000000004',
     'd0000000-0000-4000-8000-000000000002', 'general', null, null, 'booked',
     'LH-BATTERY26', now(), now(), null);

  perform set_config('battery26.attorney', v_attorney::text, true);
  perform set_config('battery26.matter', v_matter::text, true);
  perform set_config('battery26.seed_a', v_seed_a::text, true);
  perform set_config('battery26.seed_b', v_seed_b::text, true);
  perform set_config('battery26.seed_ended', v_ended::text, true);
  perform set_config('battery26.booking_cross', v_booking::text, true);
end $$;

do $$
declare
  v_sessions bigint;
begin
  select count(*) into v_sessions from public.video_sessions;
  if v_sessions <> 3 then
    raise exception 'POLICY-BATTERY FAIL 26.00: seeded sessions = %, want 3', v_sessions;
  end if;
end $$;

-- ############################################################################
-- 26.01 — POS (partner create, no matter): partner-a creates an org-a
-- session. The scheduled row, generated room shape, creator stamp, null
-- links and the redacted video_session:create audit row are verified.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_id := public.create_video_session(
    '20000000-0000-4000-8000-000000000001',
    null,
    null,
    '2030-01-02T10:00:00Z');
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 26.01: create_video_session returned a null id';
  end if;
  perform set_config('battery26.session_partner', v_id::text, true);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery26.session_partner')::uuid;
  v_row    public.video_sessions;
  v_audits bigint;
  v_bad    bigint;
begin
  select * into v_row from public.video_sessions where id = v_id;
  if not found then
    raise exception 'POLICY-BATTERY FAIL 26.01: created session row missing';
  end if;
  if v_row.organization_id <> '20000000-0000-4000-8000-000000000001'
     or v_row.matter_id is not null
     or v_row.booking_id is not null
     or v_row.provider <> 'livekit'
     or v_row.status <> 'scheduled'
     or v_row.started_at is not null
     or v_row.ended_at is not null
     or v_row.created_by is distinct from '10000000-0000-4000-8000-000000000002'
     or v_row.scheduled_at is distinct from '2030-01-02T10:00:00Z'::timestamptz
     or v_row.room_name !~ '^room_[a-z0-9]{16,40}$' then
    raise exception 'POLICY-BATTERY FAIL 26.01: created row shape drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_audits
    from public.audit_events
   where action = 'video_session:create'
     and outcome = 'allowed'
     and resource_type = 'video_session'
     and resource_id = v_id;
  if v_audits <> 1 then
    raise exception 'POLICY-BATTERY FAIL 26.01: video_session:create audit rows = %, want 1', v_audits;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action = 'video_session:create'
     and resource_id = v_id
     and (organization_id is distinct from '20000000-0000-4000-8000-000000000001'
          or actor_user_id is distinct from '10000000-0000-4000-8000-000000000002'
          or redacted_summary is distinct from 'video session created'
          or redacted_summary like '%room_%');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 26.01: create audit row drift/leak (%)', v_bad;
  end if;
end $$;

-- ############################################################################
-- 26.02 — POS (attorney create on a readable matter): the generated attorney
-- creates a session on the generated matter assigned to them; a matter-less
-- attorney create is denied by the plan's global constraint.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', current_setting('battery26.attorney'), false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('battery26.attorney'))::text, false);

  begin
    perform public.create_video_session(
      '20000000-0000-4000-8000-000000000001', null, null, null);
    raise exception 'POLICY-BATTERY FAIL 26.02: attorney matter-less create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 26.02: attorney matter-less create raised "%"', sqlerrm;
    end if;
  end;

  v_id := public.create_video_session(
    '20000000-0000-4000-8000-000000000001',
    current_setting('battery26.matter')::uuid,
    null,
    null);
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 26.02: attorney create returned a null id';
  end if;
  perform set_config('battery26.session_attorney', v_id::text, true);
end $$;
reset role;

do $$
declare
  v_id     uuid := current_setting('battery26.session_attorney')::uuid;
  v_row    public.video_sessions;
  v_audits bigint;
begin
  select * into v_row from public.video_sessions where id = v_id;
  if not found then
    raise exception 'POLICY-BATTERY FAIL 26.02: attorney session row missing';
  end if;
  if v_row.organization_id <> '20000000-0000-4000-8000-000000000001'
     or v_row.matter_id is distinct from current_setting('battery26.matter')::uuid
     or v_row.created_by is distinct from current_setting('battery26.attorney')::uuid
     or v_row.status <> 'scheduled' then
    raise exception 'POLICY-BATTERY FAIL 26.02: attorney row shape drift: %', row_to_json(v_row);
  end if;
  select count(*) into v_audits
    from public.audit_events where action = 'video_session:create' and outcome = 'allowed';
  if v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 26.02: video_session:create audits = %, want 2', v_audits;
  end if;
end $$;

-- ############################################################################
-- 26.03 — NEG (client create): client-a is an active org-a member but holds
-- neither session role. No session and no audit row is written.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.create_video_session(
      '20000000-0000-4000-8000-000000000001', null, null, null);
    raise exception 'POLICY-BATTERY FAIL 26.03: client create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 26.03: client create raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_sessions bigint;
  v_audits   bigint;
begin
  select count(*) into v_sessions from public.video_sessions;
  select count(*) into v_audits
    from public.audit_events where action = 'video_session:create' and outcome = 'allowed';
  if v_sessions <> 5 or v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 26.03: denied client create changed counts (sessions %, audits %)',
      v_sessions, v_audits;
  end if;
end $$;

-- ############################################################################
-- 26.04 — NEG (cross-org matter): partner-b is an org-b partner and names
-- org-a matter 5 in an org-b create. The same-org clause denies it; no
-- session and no audit row is written.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    perform public.create_video_session(
      '20000000-0000-4000-8000-000000000002',
      '40000000-0000-4000-8000-000000000005',
      null,
      null);
    raise exception 'POLICY-BATTERY FAIL 26.04: cross-org matter create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 26.04: cross-org matter create raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_sessions bigint;
  v_audits   bigint;
begin
  select count(*) into v_sessions from public.video_sessions;
  select count(*) into v_audits
    from public.audit_events where action = 'video_session:create' and outcome = 'allowed';
  if v_sessions <> 5 or v_audits <> 2 then
    raise exception 'POLICY-BATTERY FAIL 26.04: denied cross-org create changed counts (sessions %, audits %)',
      v_sessions, v_audits;
  end if;
end $$;

-- ############################################################################
-- 26.05 — NEG (suspended + anon): suspended-a cannot create or list and the
-- read policy exposes zero rows; anon holds no EXECUTE and no table grant.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  begin
    perform public.create_video_session(
      '20000000-0000-4000-8000-000000000001', null, null, null);
    raise exception 'POLICY-BATTERY FAIL 26.05: suspended create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 26.05: suspended create raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.list_video_sessions('20000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 26.05: suspended list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 26.05: suspended list raised "%"', sqlerrm;
    end if;
  end;

  select count(*) into v_cnt from public.video_sessions;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 26.05: suspended caller sees % session rows, want 0', v_cnt;
  end if;
end $$;
reset role;

set role anon;
do $$
begin
  begin
    perform public.create_video_session(
      '20000000-0000-4000-8000-000000000001', null, null, null);
    raise exception 'POLICY-BATTERY FAIL 26.05: anon create succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform public.list_video_sessions('20000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 26.05: anon list succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform count(*) from public.video_sessions;
    raise exception 'POLICY-BATTERY FAIL 26.05: anon select succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

-- ############################################################################
-- 26.06 — POS (booking-linked create): partner-a links the org-a booking
-- owned by client-a. The booking is accepted because its client is an active
-- org-a member.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_id := public.create_video_session(
    '20000000-0000-4000-8000-000000000001',
    null,
    'e0000000-0000-4000-8000-000000000001',
    null);
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 26.06: booking-linked create returned a null id';
  end if;
  perform set_config('battery26.session_booking', v_id::text, true);
end $$;
reset role;

do $$
declare
  v_id  uuid := current_setting('battery26.session_booking')::uuid;
  v_row public.video_sessions;
  v_aud bigint;
begin
  select * into v_row from public.video_sessions where id = v_id;
  if not found then
    raise exception 'POLICY-BATTERY FAIL 26.06: booking-linked row missing';
  end if;
  if v_row.booking_id is distinct from 'e0000000-0000-4000-8000-000000000001'
     or v_row.matter_id is not null
     or v_row.status <> 'scheduled' then
    raise exception 'POLICY-BATTERY FAIL 26.06: booking-linked row drift: %', row_to_json(v_row);
  end if;
  select count(*) into v_aud
    from public.audit_events where action = 'video_session:create' and outcome = 'allowed';
  if v_aud <> 3 then
    raise exception 'POLICY-BATTERY FAIL 26.06: video_session:create audits = %, want 3', v_aud;
  end if;
end $$;

-- ############################################################################
-- 26.07 — NEG (cross-org booking): the generated booking is owned by
-- partner-b, an org-b member only, so an org-a create is denied.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_video_session(
      '20000000-0000-4000-8000-000000000001',
      null,
      current_setting('battery26.booking_cross')::uuid,
      null);
    raise exception 'POLICY-BATTERY FAIL 26.07: cross-org booking create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 26.07: cross-org booking create raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_sessions bigint;
  v_audits   bigint;
begin
  select count(*) into v_sessions from public.video_sessions;
  select count(*) into v_audits
    from public.audit_events where action = 'video_session:create' and outcome = 'allowed';
  if v_sessions <> 6 or v_audits <> 3 then
    raise exception 'POLICY-BATTERY FAIL 26.07: denied cross-org booking changed counts (sessions %, audits %)',
      v_sessions, v_audits;
  end if;
end $$;

-- ############################################################################
-- 26.08 — POS/NEG (participant-scoped list): partner-a reads the five org-a
-- sessions (partner); client-a reads only the booking-linked session;
-- the generated attorney reads only the session they created on their
-- matter; orphan (active org-a member, assigned only on matter 4) reads
-- none; partner-b reads only org-b's one. Direct selects exercise the same
-- policy.
-- ############################################################################
set role authenticated;
do $$
declare
  v_partner  bigint;
  v_client   bigint;
  v_attorney bigint;
  v_orphan   bigint;
  v_cross    bigint;
  v_direct   bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_partner
    from public.list_video_sessions('20000000-0000-4000-8000-000000000001');
  select count(*) into v_direct from public.video_sessions;
  if v_partner <> 5 or v_direct <> 5 then
    raise exception 'POLICY-BATTERY FAIL 26.08: partner-a sees % rpc / % direct, want 5/5', v_partner, v_direct;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_client
    from public.list_video_sessions('20000000-0000-4000-8000-000000000001');
  select count(*) into v_direct from public.video_sessions;
  if v_client <> 1 or v_direct <> 1 then
    raise exception 'POLICY-BATTERY FAIL 26.08: client-a sees % rpc / % direct, want 1/1', v_client, v_direct;
  end if;

  perform set_config('request.jwt.claim.sub', current_setting('battery26.attorney'), false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('battery26.attorney'))::text, false);
  select count(*) into v_attorney
    from public.list_video_sessions('20000000-0000-4000-8000-000000000001');
  select count(*) into v_direct from public.video_sessions;
  if v_attorney <> 1 or v_direct <> 1 then
    raise exception 'POLICY-BATTERY FAIL 26.08: attorney sees % rpc / % direct, want 1/1', v_attorney, v_direct;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  select count(*) into v_orphan
    from public.list_video_sessions('20000000-0000-4000-8000-000000000001');
  select count(*) into v_direct from public.video_sessions;
  if v_orphan <> 0 or v_direct <> 0 then
    raise exception 'POLICY-BATTERY FAIL 26.08: unrelated active member sees % rpc / % direct, want 0/0', v_orphan, v_direct;
  end if;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_cross
    from public.list_video_sessions('20000000-0000-4000-8000-000000000002');
  select count(*) into v_direct from public.video_sessions;
  if v_cross <> 1 or v_direct <> 1 then
    raise exception 'POLICY-BATTERY FAIL 26.08: partner-b sees % rpc / % direct, want 1/1', v_cross, v_direct;
  end if;
end $$;
reset role;

-- ############################################################################
-- 26.09 — NEG (cross-org list): partner-a and client-a hold no org-b
-- membership — listing org-b raises.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.list_video_sessions('20000000-0000-4000-8000-000000000002');
    raise exception 'POLICY-BATTERY FAIL 26.09: partner-a cross-org list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 26.09: partner-a cross-org list raised "%"', sqlerrm;
    end if;
  end;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.list_video_sessions('20000000-0000-4000-8000-000000000002');
    raise exception 'POLICY-BATTERY FAIL 26.09: client-a cross-org list succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 26.09: client-a cross-org list raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

-- ############################################################################
-- 26.10 — POS/NEG (participant-scoped get): partner-a reads the org-a seed;
-- client-a is denied that seed (unrelated active member) but reads the
-- booking-linked session; partner-a is denied the org-b seed; a random id
-- raises the typed not-found.
-- ############################################################################
set role authenticated;
do $$
declare
  v_row public.video_sessions;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_row := public.get_video_session(current_setting('battery26.seed_a')::uuid);
  if v_row.id is distinct from current_setting('battery26.seed_a')::uuid
     or v_row.organization_id <> '20000000-0000-4000-8000-000000000001' then
    raise exception 'POLICY-BATTERY FAIL 26.10: partner-a get drift: %', row_to_json(v_row);
  end if;

  begin
    perform public.get_video_session(current_setting('battery26.seed_b')::uuid);
    raise exception 'POLICY-BATTERY FAIL 26.10: partner-a cross-org get succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 26.10: cross-org get raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.get_video_session(gen_random_uuid());
    raise exception 'POLICY-BATTERY FAIL 26.10: missing get succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'video session not found' then
      raise exception 'POLICY-BATTERY FAIL 26.10: missing get raised "%"', sqlerrm;
    end if;
  end;

  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.get_video_session(current_setting('battery26.seed_a')::uuid);
    raise exception 'POLICY-BATTERY FAIL 26.10: unrelated client-a get succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 26.10: unrelated get raised "%"', sqlerrm;
    end if;
  end;

  v_row := public.get_video_session(current_setting('battery26.session_booking')::uuid);
  if v_row.id is distinct from current_setting('battery26.session_booking')::uuid
     or v_row.booking_id is distinct from 'e0000000-0000-4000-8000-000000000001' then
    raise exception 'POLICY-BATTERY FAIL 26.10: booking-client get drift: %', row_to_json(v_row);
  end if;
end $$;
reset role;

-- ############################################################################
-- 26.11 — POS (booking-client mark-live + audit): client-a is the client on
-- the session's linked booking and starts that scheduled session.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  perform public.mark_video_session_live(
    current_setting('battery26.session_booking')::uuid);
end $$;
reset role;

do $$
declare
  v_id  uuid := current_setting('battery26.session_booking')::uuid;
  v_row public.video_sessions;
  v_aud bigint;
  v_bad bigint;
begin
  select * into v_row from public.video_sessions where id = v_id;
  if v_row.status <> 'live'
     or v_row.started_at is null
     or v_row.ended_at is not null
     or v_row.updated_at < v_row.created_at then
    raise exception 'POLICY-BATTERY FAIL 26.11: mark-live row drift: %', row_to_json(v_row);
  end if;

  select count(*) into v_aud
    from public.audit_events
   where action = 'video_session:live'
     and outcome = 'allowed'
     and resource_id = v_id;
  if v_aud <> 1 then
    raise exception 'POLICY-BATTERY FAIL 26.11: video_session:live audits = %, want 1', v_aud;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action = 'video_session:live'
     and resource_id = v_id
     and (organization_id is distinct from '20000000-0000-4000-8000-000000000001'
          or actor_user_id is distinct from '10000000-0000-4000-8000-000000000003'
          or redacted_summary is distinct from 'video session started'
          or redacted_summary like '%room_%');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 26.11: live audit row drift/leak (%)', v_bad;
  end if;
end $$;

-- ############################################################################
-- 26.12 — NEG (mark-live terminals): the seeded ended session raises
-- 'video session has already ended'; the now-live session raises 'video
-- session is not scheduled'. No extra audit row appears.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.mark_video_session_live(current_setting('battery26.seed_ended')::uuid);
    raise exception 'POLICY-BATTERY FAIL 26.12: mark-live on ended succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'video session has already ended' then
      raise exception 'POLICY-BATTERY FAIL 26.12: mark-live on ended raised "%"', sqlerrm;
    end if;
  end;

  begin
    perform public.mark_video_session_live(current_setting('battery26.session_booking')::uuid);
    raise exception 'POLICY-BATTERY FAIL 26.12: mark-live on live succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'video session is not scheduled' then
      raise exception 'POLICY-BATTERY FAIL 26.12: mark-live on live raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_aud bigint;
begin
  select count(*) into v_aud
    from public.audit_events where action = 'video_session:live' and outcome = 'allowed';
  if v_aud <> 1 then
    raise exception 'POLICY-BATTERY FAIL 26.12: denied mark-live changed audits (%), want 1', v_aud;
  end if;
end $$;

-- ############################################################################
-- 26.13 — POS (end by creator): partner-a ends the live booking-linked
-- session they created.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.end_video_session(current_setting('battery26.session_booking')::uuid);
end $$;
reset role;

do $$
declare
  v_id  uuid := current_setting('battery26.session_booking')::uuid;
  v_row public.video_sessions;
  v_aud bigint;
begin
  select * into v_row from public.video_sessions where id = v_id;
  if v_row.status <> 'ended'
     or v_row.ended_at is null
     or v_row.updated_at < v_row.created_at then
    raise exception 'POLICY-BATTERY FAIL 26.13: creator end row drift: %', row_to_json(v_row);
  end if;
  select count(*) into v_aud
    from public.audit_events
   where action = 'video_session:end' and outcome = 'allowed' and resource_id = v_id;
  if v_aud <> 1 then
    raise exception 'POLICY-BATTERY FAIL 26.13: video_session:end audits = %, want 1', v_aud;
  end if;
end $$;

-- ############################################################################
-- 26.14 — POS (end by partner, not creator): partner-a ends the session the
-- generated attorney created.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.end_video_session(current_setting('battery26.session_attorney')::uuid);
end $$;
reset role;

do $$
declare
  v_id  uuid := current_setting('battery26.session_attorney')::uuid;
  v_row public.video_sessions;
  v_aud bigint;
begin
  select * into v_row from public.video_sessions where id = v_id;
  if v_row.status <> 'ended' or v_row.ended_at is null then
    raise exception 'POLICY-BATTERY FAIL 26.14: partner end row drift: %', row_to_json(v_row);
  end if;
  select count(*) into v_aud
    from public.audit_events where action = 'video_session:end' and outcome = 'allowed';
  if v_aud <> 2 then
    raise exception 'POLICY-BATTERY FAIL 26.14: video_session:end audits = %, want 2', v_aud;
  end if;
end $$;

-- ############################################################################
-- 26.15 — NEG (unrelated client end): client-a is an active member but is
-- neither the creator nor a partner — and holds no participant access to
-- this session — so the scheduled session stays scheduled and no audit row
-- is written.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.end_video_session(current_setting('battery26.session_partner')::uuid);
    raise exception 'POLICY-BATTERY FAIL 26.15: unrelated client end succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    if sqlerrm <> 'permission denied' then
      raise exception 'POLICY-BATTERY FAIL 26.15: unrelated end raised "%"', sqlerrm;
    end if;
  end;
end $$;
reset role;

do $$
declare
  v_row public.video_sessions;
  v_aud bigint;
begin
  select * into v_row from public.video_sessions
   where id = current_setting('battery26.session_partner')::uuid;
  if v_row.status <> 'scheduled' or v_row.ended_at is not null
     or v_row.started_at is not null then
    raise exception 'POLICY-BATTERY FAIL 26.15: denied end changed state: %', row_to_json(v_row);
  end if;
  select count(*) into v_aud
    from public.audit_events where action = 'video_session:end' and outcome = 'allowed';
  if v_aud <> 2 then
    raise exception 'POLICY-BATTERY FAIL 26.15: denied end changed audits (%), want 2', v_aud;
  end if;
end $$;

-- ############################################################################
-- 26.16 — NEG (direct writes): authenticated holds SELECT only — INSERT,
-- UPDATE and DELETE are denied at the privilege layer.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);

  begin
    insert into public.video_sessions (organization_id, room_name)
    values ('20000000-0000-4000-8000-000000000001', 'room_directinsert0000000000000000');
    raise exception 'POLICY-BATTERY FAIL 26.16: direct INSERT succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.video_sessions
       set status = 'ended'
     where id = current_setting('battery26.session_partner')::uuid;
    raise exception 'POLICY-BATTERY FAIL 26.16: direct UPDATE succeeded';
  exception when insufficient_privilege then
    null;
  end;

  begin
    delete from public.video_sessions
     where id = current_setting('battery26.session_partner')::uuid;
    raise exception 'POLICY-BATTERY FAIL 26.16: direct DELETE succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

do $$
declare
  v_row public.video_sessions;
  v_cnt bigint;
begin
  select * into v_row from public.video_sessions
   where id = current_setting('battery26.session_partner')::uuid;
  select count(*) into v_cnt from public.video_sessions;
  if v_row.status <> 'scheduled' or v_cnt <> 6 then
    raise exception 'POLICY-BATTERY FAIL 26.16: direct-write denials changed state (status %, sessions %)',
      v_row.status, v_cnt;
  end if;
end $$;

-- ############################################################################
-- 26.17 — POS (room-name shape): every stored room matches the pinned shape,
-- names are unique, the provider is livekit, and the CHECK rejects a bad
-- name at the table layer.
-- ############################################################################
do $$
declare
  v_bad bigint;
  v_dup bigint;
begin
  select count(*) into v_bad
    from public.video_sessions
   where room_name !~ '^room_[a-z0-9]{16,40}$'
      or provider <> 'livekit';
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 26.17: % room(s) violate the pinned shape/provider', v_bad;
  end if;

  select count(*) into v_dup
    from (select room_name from public.video_sessions group by room_name having count(*) > 1) d;
  if v_dup <> 0 then
    raise exception 'POLICY-BATTERY FAIL 26.17: % duplicate room name(s)', v_dup;
  end if;

  begin
    insert into public.video_sessions (organization_id, room_name)
    values ('20000000-0000-4000-8000-000000000001', 'room_BAD');
    raise exception 'POLICY-BATTERY FAIL 26.17: invalid room name INSERT succeeded';
  exception when check_violation then
    null;
  end;
end $$;

-- ############################################################################
-- 26.18 — POS (table + function posture): RLS enabled, authenticated holds
-- SELECT only, anon holds nothing, exactly one read policy, and all five
-- RPCs are SECURITY DEFINER with a pinned search_path, no parameter
-- defaults and the exact EXECUTE surface.
-- ############################################################################
do $$
declare
  r     record;
  v_oid oid;
begin
  if not (select relrowsecurity from pg_class where oid = 'public.video_sessions'::regclass) then
    raise exception 'POLICY-BATTERY FAIL 26.18: RLS is not enabled on video_sessions';
  end if;

  if not has_table_privilege('authenticated', 'public.video_sessions', 'SELECT') then
    raise exception 'POLICY-BATTERY FAIL 26.18: authenticated lacks SELECT on video_sessions';
  end if;

  if has_table_privilege('authenticated', 'public.video_sessions', 'INSERT')
     or has_table_privilege('authenticated', 'public.video_sessions', 'UPDATE')
     or has_table_privilege('authenticated', 'public.video_sessions', 'DELETE')
     or has_table_privilege('authenticated', 'public.video_sessions', 'TRUNCATE') then
    raise exception 'POLICY-BATTERY FAIL 26.18: authenticated holds a direct write privilege';
  end if;

  if has_table_privilege('anon', 'public.video_sessions', 'SELECT')
     or has_table_privilege('anon', 'public.video_sessions', 'INSERT')
     or has_table_privilege('anon', 'public.video_sessions', 'UPDATE')
     or has_table_privilege('anon', 'public.video_sessions', 'DELETE') then
    raise exception 'POLICY-BATTERY FAIL 26.18: anon holds a video_sessions privilege';
  end if;

  if (select count(*) from pg_policies
       where schemaname = 'public' and tablename = 'video_sessions'
         and policyname = 'video_sessions_select_org') <> 1
     or (select count(*) from pg_policies
       where schemaname = 'public' and tablename = 'video_sessions') <> 1 then
    raise exception 'POLICY-BATTERY FAIL 26.18: video_sessions policy inventory drift';
  end if;

  for r in
    select * from (values
      ('create_video_session',
       'p_organization_id uuid, p_matter_id uuid, p_booking_id uuid, p_scheduled_at timestamp with time zone'),
      ('list_video_sessions', 'p_organization_id uuid'),
      ('get_video_session', 'p_id uuid'),
      ('mark_video_session_live', 'p_id uuid'),
      ('end_video_session', 'p_id uuid')
    ) as t(fn, args)
  loop
    select p.oid into v_oid
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = r.fn
       and pg_get_function_arguments(p.oid) = r.args;
    if v_oid is null then
      raise exception 'POLICY-BATTERY FAIL 26.18: function public.%(%) missing', r.fn, r.args;
    end if;
    if not (select prosecdef from pg_proc where oid = v_oid) then
      raise exception 'POLICY-BATTERY FAIL 26.18: public.% is not SECURITY DEFINER', r.fn;
    end if;
    if not (select coalesce(proconfig, '{}'::text[]) @> array['search_path=public']::text[]
              from pg_proc where oid = v_oid) then
      raise exception 'POLICY-BATTERY FAIL 26.18: public.% does not pin search_path = public', r.fn;
    end if;
    if (select pronargdefaults from pg_proc where oid = v_oid) <> 0 then
      raise exception 'POLICY-BATTERY FAIL 26.18: public.% carries a parameter default', r.fn;
    end if;
    if has_function_privilege('anon', v_oid, 'EXECUTE') then
      raise exception 'POLICY-BATTERY FAIL 26.18: anon holds EXECUTE on public.%', r.fn;
    end if;
  end loop;

  if not has_function_privilege('authenticated',
         'public.create_video_session(uuid, uuid, uuid, timestamptz)', 'EXECUTE')
     or not has_function_privilege('authenticated',
         'public.list_video_sessions(uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated',
         'public.get_video_session(uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated',
         'public.mark_video_session_live(uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated',
         'public.end_video_session(uuid)', 'EXECUTE') then
    raise exception 'POLICY-BATTERY FAIL 26.18: authenticated lacks EXECUTE on a video RPC';
  end if;
end $$;

-- ############################################################################
-- 26.19 — POS (§8 final pin): exactly the successful writes are audited
-- (3 creates, 1 live, 2 ends = 6 rows), every summary is fixed and redacted,
-- every audit points at a real session, and the session census is exact.
-- ############################################################################
do $$
declare
  v_total    bigint;
  v_create   bigint;
  v_live     bigint;
  v_end      bigint;
  v_bad      bigint;
  v_sessions bigint;
  v_scheduled bigint;
  v_ended    bigint;
  v_org_a    bigint;
  v_org_b    bigint;
begin
  select count(*) into v_total from public.audit_events where action like 'video_session:%';
  select count(*) into v_create from public.audit_events where action = 'video_session:create';
  select count(*) into v_live from public.audit_events where action = 'video_session:live';
  select count(*) into v_end from public.audit_events where action = 'video_session:end';
  if v_total <> 6 or v_create <> 3 or v_live <> 1 or v_end <> 2 then
    raise exception 'POLICY-BATTERY FAIL 26.19: audit mix drift (total %, create %, live %, end %)',
      v_total, v_create, v_live, v_end;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action like 'video_session:%'
     and (outcome <> 'allowed'
          or resource_type <> 'video_session'
          or redacted_summary not in ('video session created',
                                      'video session started',
                                      'video session ended')
          or redacted_summary like '%room_%'
          or actor_user_id is null
          or not exists (
            select 1 from public.video_sessions s where s.id = audit_events.resource_id));
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 26.19: % audit row(s) carry a non-fixed outcome/type/summary/actor or no session', v_bad;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action = 'video_session:create'
     and actor_user_id not in (
       '10000000-0000-4000-8000-000000000002',
       current_setting('battery26.attorney')::uuid);
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 26.19: % create audit row(s) carry a foreign actor', v_bad;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action = 'video_session:live'
     and actor_user_id is distinct from '10000000-0000-4000-8000-000000000003';
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 26.19: % live audit row(s) carry a foreign actor', v_bad;
  end if;

  select count(*) into v_sessions from public.video_sessions;
  select count(*) into v_scheduled from public.video_sessions where status = 'scheduled';
  select count(*) into v_ended from public.video_sessions where status = 'ended';
  select count(*) into v_org_a
    from public.video_sessions where organization_id = '20000000-0000-4000-8000-000000000001';
  select count(*) into v_org_b
    from public.video_sessions where organization_id = '20000000-0000-4000-8000-000000000002';
  if v_sessions <> 6 or v_scheduled <> 3 or v_ended <> 3 or v_org_a <> 5 or v_org_b <> 1 then
    raise exception 'POLICY-BATTERY FAIL 26.19: session census drift (total %, scheduled %, ended %, org-a %, org-b %)',
      v_sessions, v_scheduled, v_ended, v_org_a, v_org_b;
  end if;

  if not exists (
    select 1 from public.video_sessions
     where id = current_setting('battery26.session_partner')::uuid
       and status = 'scheduled'
       and started_at is null
       and ended_at is null
  ) then
    raise exception 'POLICY-BATTERY FAIL 26.19: session_partner is not the expected scheduled session';
  end if;

  if not exists (
    select 1 from public.video_sessions
     where id = current_setting('battery26.session_booking')::uuid
       and booking_id = 'e0000000-0000-4000-8000-000000000001'
       and status = 'ended'
  ) then
    raise exception 'POLICY-BATTERY FAIL 26.19: booking link/status was not persisted';
  end if;
end $$;

rollback;
