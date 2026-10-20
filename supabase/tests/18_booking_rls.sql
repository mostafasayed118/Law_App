-- ============================================================================
-- supabase/tests/18_booking_rls.sql — consultation booking battery
--
-- Pins the booking slice (supabase/migrations/18_booking.sql +
-- supabase/policies/consultation_slots.sql + consultations.sql +
-- supabase/rpc/book_consultation.sql):
--   - the available-slot read (any authenticated caller sees only active,
--     unclaimed slots; booked/inactive slots disappear);
--   - the audited booking RPC positive: reference regex ^LH-[0-9A-F]{8}$,
--     status booked, slot claim, owner-row read, non-PII projection
--     (no topic / client_user_id keys), and exactly one §8 audit row with a
--     NULL organization_id;
--   - own-row scoping: the owner reads the booking, a second user does not;
--   - the privilege-layer denies: anon SELECT on both tables, anon RPC
--     EXECUTE, and direct INSERT/UPDATE/DELETE on both tables;
--   - the in-function validation denies: invalid category, oversized topic,
--     and double-book (unique_violation);
--   - the §8 negative: denied writes write no audit row.
--
-- The whole battery runs in ONE transaction and ROLLS BACK — it has no
-- side effects on the rehearsal baseline. Fixture anchors (00_fixtures.sql):
-- client-a 10000000-…-0003 · orphan …-0007 · partner-b …-0004 · slots
-- d0000000-…-0001/0002 available, …-0003 booked, …-0004 inactive ·
-- consultations e0000000-…-0001 (client-a) / …-0002 (orphan, cancelled).
--
-- Role handling: RPC blocks run under `set role authenticated` with JWT
-- impersonation (the 01/02/03 pattern); privilege and audit reads run as the
-- connection role.
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 18.01 — POS (available-slot read): client-a sees exactly the two available
-- slots; the booked (…-0003) and inactive (…-0004) slots are invisible.
-- ############################################################################
set role authenticated;
do $$
declare
  v_all bigint; v_available bigint; v_hidden bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_all from public.consultation_slots;
  select count(*) into v_available from public.consultation_slots
   where id in ('d0000000-0000-4000-8000-000000000001',
                'd0000000-0000-4000-8000-000000000002');
  select count(*) into v_hidden from public.consultation_slots
   where id in ('d0000000-0000-4000-8000-000000000003',
                'd0000000-0000-4000-8000-000000000004');
  if v_all <> 2 or v_available <> 2 or v_hidden <> 0 then
    raise exception 'POLICY-BATTERY FAIL 18.01: available-slot read drift (all %, available %, hidden %)',
      v_all, v_available, v_hidden;
  end if;
end $$;
reset role;

-- ############################################################################
-- 18.02 — POS (booking): client-a books available slot …-0001. The RPC
-- returns the persisted non-PII projection; the slot disappears from the
-- available read and the row is readable by its owner.
-- ############################################################################
set role authenticated;
do $$
declare
  v_row  jsonb;
  v_id   uuid;
  v_cnt  bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_row := public.book_consultation(
    'd0000000-0000-4000-8000-000000000001', 'general',
    '  Lease renewal question  ', '  Attorney A  ');
  v_id := (v_row ->> 'id')::uuid;
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 18.02: book_consultation returned a null id';
  end if;
  if v_row ->> 'reference_id' is null
     or (v_row ->> 'reference_id') !~ '^LH-[0-9A-F]{8}$' then
    raise exception 'POLICY-BATTERY FAIL 18.02: reference_id shape drift: %', v_row ->> 'reference_id';
  end if;
  if v_row ->> 'status' is distinct from 'booked'
     or v_row ->> 'category' is distinct from 'general'
     or v_row ->> 'slot_id' is distinct from 'd0000000-0000-4000-8000-000000000001'
     or v_row ->> 'attorney_ref' is distinct from 'Attorney A'
     or v_row ->> 'starts_at' is null
     or v_row ->> 'duration_minutes' is distinct from '45' then
    raise exception 'POLICY-BATTERY FAIL 18.02: booking projection drift: %', v_row;
  end if;
  if jsonb_exists(v_row, 'topic') or jsonb_exists(v_row, 'client_user_id') then
    raise exception 'POLICY-BATTERY FAIL 18.02: booking projection leaked PII keys: %', v_row;
  end if;
  select count(*) into v_cnt from public.consultation_slots
   where id = 'd0000000-0000-4000-8000-000000000001';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 18.02: booked slot still visible in the available read';
  end if;
  select count(*) into v_cnt from public.consultations
   where id = v_id and client_user_id = auth.uid();
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 18.02: booking not readable by its owner (want 1 row, got %)', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 18.03 — POS (§8 audit + claim): exactly one consultation:book/allowed row
-- for the new booking, with a NULL organization_id and the redacted summary;
-- the slot carries its booked_at claim.
-- ############################################################################
do $$
declare
  v_id     uuid;
  v_cnt    bigint;
  v_booked bigint;
begin
  select id into v_id
    from public.consultations
   where slot_id = 'd0000000-0000-4000-8000-000000000001'
     and client_user_id = '10000000-0000-4000-8000-000000000003';
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 18.03: 18.02 booking missing (non-vacuity broken)';
  end if;
  select count(*) into v_cnt
    from public.audit_events
   where action = 'consultation:book'
     and outcome = 'allowed'
     and resource_id = v_id
     and organization_id is null
     and redacted_summary = 'consultation booked';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 18.03: consultation:book audit rows = % for the booking, want exactly 1', v_cnt;
  end if;
  select count(*) into v_booked
    from public.consultation_slots
   where id = 'd0000000-0000-4000-8000-000000000001'
     and booked_at is not null;
  if v_booked <> 1 then
    raise exception 'POLICY-BATTERY FAIL 18.03: slot booked_at claim missing';
  end if;
end $$;

-- ############################################################################
-- 18.04 — POS (own-row read): client-a sees its fixture booking + the new
-- booking (2 rows); orphan sees only its own fixture booking (1 row).
-- ############################################################################
set role authenticated;
do $$
declare
  v_client bigint; v_orphan bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_client from public.consultations;
  if v_client <> 2 then
    raise exception 'POLICY-BATTERY FAIL 18.04: client-a sees % consultations, want 2 (fixture + new)', v_client;
  end if;
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  select count(*) into v_orphan from public.consultations;
  if v_orphan <> 1 then
    raise exception 'POLICY-BATTERY FAIL 18.04: orphan sees % consultations, want 1 (own fixture only)', v_orphan;
  end if;
end $$;
reset role;

-- ############################################################################
-- 18.05 — NEG (second user): orphan and partner-b cannot read client-a's
-- new booking by id; partner-b sees zero consultations at all.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id uuid;
  v_orphan bigint; v_cross bigint;
begin
  select id into v_id
    from public.consultations
   where slot_id = 'd0000000-0000-4000-8000-000000000001'
     and client_user_id = '10000000-0000-4000-8000-000000000003';
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 18.05: 18.02 booking missing (non-vacuity broken)';
  end if;
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  select count(*) into v_orphan from public.consultations where id = v_id;
  if v_orphan <> 0 then
    raise exception 'POLICY-BATTERY FAIL 18.05: orphan read another client''s consultation';
  end if;
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_cross from public.consultations;
  if v_cross <> 0 then
    raise exception 'POLICY-BATTERY FAIL 18.05: partner-b sees % consultations, want 0', v_cross;
  end if;
end $$;
reset role;

-- ############################################################################
-- 18.06 — NEG (privilege layer): anon holds no SELECT grant on either table.
-- ############################################################################
set role anon;
do $$
begin
  begin
    perform count(*) from public.consultation_slots;
    raise exception 'POLICY-BATTERY FAIL 18.06: anon slot SELECT succeeded';
  exception when insufficient_privilege then
    null; -- expected: no SELECT grant
  end;
  begin
    perform count(*) from public.consultations;
    raise exception 'POLICY-BATTERY FAIL 18.06: anon consultation SELECT succeeded';
  exception when insufficient_privilege then
    null; -- expected: no SELECT grant
  end;
end $$;
reset role;

-- ############################################################################
-- 18.07 — NEG (privilege layer): anon holds no EXECUTE grant on the booking
-- RPC (the file grants authenticated only).
-- ############################################################################
set role anon;
do $$
begin
  begin
    perform public.book_consultation(
      'd0000000-0000-4000-8000-000000000001', 'general');
    raise exception 'POLICY-BATTERY FAIL 18.07: anon booking succeeded';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
end $$;
reset role;

-- ############################################################################
-- 18.08 — NEG (no direct write grant): authenticated INSERT on consultations
-- is denied at the privilege layer (RPC-only writes).
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    insert into public.consultations
      (client_user_id, slot_id, category, status, reference_id)
    values
      ('10000000-0000-4000-8000-000000000003',
       'd0000000-0000-4000-8000-000000000002',
       'general', 'booked', 'LH-DIRECT01');
    raise exception 'POLICY-BATTERY FAIL 18.08: direct consultation INSERT succeeded';
  exception when insufficient_privilege then
    null; -- expected: no INSERT grant
  end;
end $$;
reset role;

-- ############################################################################
-- 18.09 — NEG (no direct write grant): authenticated UPDATE on slots is
-- denied at the privilege layer.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    update public.consultation_slots
       set is_active = false
     where id = 'd0000000-0000-4000-8000-000000000002';
    raise exception 'POLICY-BATTERY FAIL 18.09: direct slot UPDATE succeeded';
  exception when insufficient_privilege then
    null; -- expected: no UPDATE grant
  end;
end $$;
reset role;

-- ############################################################################
-- 18.10 — NEG (no direct write grant): authenticated DELETE on consultations
-- is denied at the privilege layer.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    delete from public.consultations
     where id = 'e0000000-0000-4000-8000-000000000002';
    raise exception 'POLICY-BATTERY FAIL 18.10: direct consultation DELETE succeeded';
  exception when insufficient_privilege then
    null; -- expected: no DELETE grant
  end;
end $$;
reset role;

-- ############################################################################
-- 18.11 — NEG (validation): an unmapped category is refused with
-- check_violation and leaves the slot available.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.book_consultation(
      'd0000000-0000-4000-8000-000000000002', 'legal');
    raise exception 'POLICY-BATTERY FAIL 18.11: invalid-category booking succeeded';
  exception when check_violation then
    null; -- expected: category allow-list
  end;
  select count(*) into v_cnt from public.consultation_slots
   where id = 'd0000000-0000-4000-8000-000000000002';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 18.11: invalid-category booking claimed the slot';
  end if;
end $$;
reset role;

-- ############################################################################
-- 18.12 — NEG (validation): a topic over 2000 characters is refused with
-- check_violation and leaves the slot available.
-- ############################################################################
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.book_consultation(
      'd0000000-0000-4000-8000-000000000002', 'general', repeat('x', 2001));
    raise exception 'POLICY-BATTERY FAIL 18.12: oversized-topic booking succeeded';
  exception when check_violation then
    null; -- expected: 2000-char cap
  end;
  select count(*) into v_cnt from public.consultation_slots
   where id = 'd0000000-0000-4000-8000-000000000002';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 18.12: oversized-topic booking claimed the slot';
  end if;
end $$;
reset role;

-- ############################################################################
-- 18.13 — NEG (double-book): orphan cannot book the slot client-a already
-- claimed in 18.02; the claim raises unique_violation (slot unavailable).
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  begin
    perform public.book_consultation(
      'd0000000-0000-4000-8000-000000000001', 'general');
    raise exception 'POLICY-BATTERY FAIL 18.13: double-book succeeded';
  exception when unique_violation then
    null; -- expected: atomic slot claim
  end;
end $$;
reset role;

-- ############################################################################
-- 18.14 — NEG (§8 negative): after every deny row, exactly the one 18.02
-- booking audit row exists; no denied consultation write wrote an audit row.
-- ############################################################################
do $$
declare
  v_allowed bigint; v_denied bigint;
begin
  select count(*) into v_allowed
    from public.audit_events
   where action = 'consultation:book' and outcome = 'allowed';
  select count(*) into v_denied
    from public.audit_events
   where action like 'consultation:%' and outcome <> 'allowed';
  if v_allowed <> 1 or v_denied <> 0 then
    raise exception 'POLICY-BATTERY FAIL 18.14: audit rows after denies (allowed %, denied %) — want 1/0', v_allowed, v_denied;
  end if;
end $$;

rollback;
