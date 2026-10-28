-- ============================================================================
-- supabase/tests/20_payment_rls.sql — invoice-payment battery
--
-- Pins the payments slice (supabase/migrations/20_payments.sql +
-- supabase/rpc/initiate_invoice_payment.sql + get_invoice_payment_status.sql
-- + attach_paymob_order.sql + apply_paymob_transaction.sql +
-- record_payment_callback_rejected.sql + list_stale_pending_payments.sql):
--   - initiate positive (assignment gate) + the redacted payment:initiate
--     audit row; duplicate initiate returns the SAME pending id with ONE row
--     and ONE audit (20.01–20.03);
--   - status read projection (payment_id/status/updated_at only) and the
--     read-after-settlement behavior (the status endpoint intentionally does
--     NOT re-apply the payability gate) (20.04, 20.07);
--   - attach idempotency + different-order check_violation (20.05);
--   - apply validation denies: amount / currency / unknown order / outcome
--     allow-list (20.06);
--   - apply success settles the invoice ('paid') with ONE terminal audit
--     (machine actor, redacted summary); replay is already_processed with no
--     second audit; a conflicting terminal transition is check_violation
--     (20.07, 20.08);
--   - failed leaves the invoice 'issued', stamps failure_code, and a fresh
--     initiate creates a NEW attempt (retry path) (20.09);
--   - stale-pending sweep: threshold, projection, limit (20.10);
--   - initiate auth denials: org-role-alone / cross-org / suspended / owner /
--     unassigned member / guessed id / anon (20.11–20.17);
--   - non-payable invoices: already paid, settled to paid, zero amount,
--     non-EGP currency (20.18–20.21);
--   - service-role-only RPCs denied to authenticated (20.22–20.25);
--   - direct table DML denied, no grants, no policies (20.26);
--   - matter -> invoice -> payment cascade (20.27);
--   - callback-rejection allow-list + final audit redaction census (20.28).
--
-- The WHOLE battery runs in ONE transaction and ROLLS BACK — no committed
-- rows, so every later battery sees the exact fixture baseline. Fixture
-- anchors (00_fixtures.sql): owner …-0001 · partner-a …-0002 (org-a partner,
-- assigned matters 1–3) · client-a …-0003 (assigned matters 1, 2) ·
-- partner-b …-0004 (org-b only, assigned attorney on matter 5) · suspended-a
-- …-0005 (suspended, assigned attorney on matter 6) · orphan …-0007 (org-a
-- client, assigned matter 4) · org-a 2000…-0001 · invoices 1 (issued,
-- 2 500 000 EGP, matter 1), 2 (paid, matter 2), 3 (issued, 3 000 000 EGP,
-- matter 3), 6 (issued, matter 6).
--
-- Role handling: RPC blocks run under `set role authenticated` with JWT
-- impersonation (the 01/02/03 pattern); direct table reads/writes, the
-- service-role call surface and the audit census run as the connection role.
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 20.01 — POS: client-a (assigned client on matter 1) initiates payment on
-- issued invoice 1. The projection carries the invoice identity and the
-- pending status, and NO provider identifiers.
-- ############################################################################
set role authenticated;
do $$
declare
  v_row jsonb;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_row := public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000001');
  if (v_row ->> 'payment_id') is null then
    raise exception 'POLICY-BATTERY FAIL 20.01: initiate returned a null payment id';
  end if;
  if v_row ->> 'invoice_id' is distinct from 'a0000000-0000-4000-8000-000000000001'
     or v_row ->> 'invoice_number' is distinct from 'INV-2026-0001'
     or (v_row ->> 'amount_cents')::bigint is distinct from 2500000
     or v_row ->> 'currency' is distinct from 'EGP'
     or v_row ->> 'status' is distinct from 'pending' then
    raise exception 'POLICY-BATTERY FAIL 20.01: initiate projection drift: %', v_row;
  end if;
  if v_row ? 'provider_order_id' or v_row ? 'provider_transaction_id' then
    raise exception 'POLICY-BATTERY FAIL 20.01: provider identifiers leaked: %', v_row;
  end if;
end $$;
reset role;

-- CHECK 20.01 (privileged half) — one pending row, initiated_by = client-a,
-- and exactly one redacted payment:initiate/allowed audit row.
do $$
declare
  v_id  uuid;
  v_cnt bigint;
  v_bad bigint;
begin
  select id into v_id
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000001'
     and status = 'pending';
  select count(*) into v_cnt
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000001';
  if v_id is null or v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.01: pending rows for invoice 1 = %, want exactly 1', v_cnt;
  end if;
  select count(*) into v_bad
    from public.payments
   where id = v_id
     and (amount_cents <> 2500000
          or currency <> 'EGP'
          or provider <> 'paymob'
          or initiated_by is distinct from '10000000-0000-4000-8000-000000000003'
          or provider_order_id is not null
          or provider_transaction_id is not null);
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.01: inserted payment row drift';
  end if;
  select count(*) into v_cnt
    from public.audit_events
   where action = 'payment:initiate' and outcome = 'allowed';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.01: payment:initiate audits = %, want exactly 1', v_cnt;
  end if;
  select count(*) into v_bad
    from public.audit_events
   where action = 'payment:initiate' and outcome = 'allowed'
     and (organization_id is distinct from '20000000-0000-4000-8000-000000000001'
          or resource_type is distinct from 'payment'
          or resource_id is distinct from v_id
          or redacted_summary is distinct from 'invoice payment initiated'
          or actor_user_id is distinct from '10000000-0000-4000-8000-000000000003');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.01: payment:initiate audit row drift (%)', v_bad;
  end if;
end $$;

-- ############################################################################
-- 20.02 — POS (idempotent duplicate): the same caller twice and the assigned
-- attorney once all resolve to the SAME pending payment.
-- ############################################################################
set role authenticated;
do $$
declare
  v_a jsonb;
  v_b jsonb;
  v_c jsonb;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_a := public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000001');
  v_b := public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000001');
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_c := public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000001');
  if v_a ->> 'payment_id' is distinct from v_b ->> 'payment_id'
     or v_a ->> 'payment_id' is distinct from v_c ->> 'payment_id' then
    raise exception 'POLICY-BATTERY FAIL 20.02: duplicate initiate minted a new payment (% / % / %)',
      v_a ->> 'payment_id', v_b ->> 'payment_id', v_c ->> 'payment_id';
  end if;
  if v_a ->> 'status' is distinct from 'pending' then
    raise exception 'POLICY-BATTERY FAIL 20.02: duplicate initiate status = %', v_a ->> 'status';
  end if;
end $$;
reset role;

-- CHECK 20.02 (privileged half) — still one row, one audit, and the partial
-- unique index backing the invariant exists.
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000001';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.02: invoice 1 payments = %, want 1 after duplicates', v_cnt;
  end if;
  select count(*) into v_cnt
    from public.audit_events
   where action = 'payment:initiate' and outcome = 'allowed';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.02: payment:initiate audits = %, want 1 (no audit for reuse)', v_cnt;
  end if;
  select count(*) into v_cnt
    from pg_indexes
   where schemaname = 'public'
     and tablename = 'payments'
     and indexname = 'payments_one_pending_per_invoice';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.02: payments_one_pending_per_invoice index missing';
  end if;
end $$;

-- ############################################################################
-- 20.03 — POS (status read): the projection is exactly
-- payment_id/status/updated_at and matches the pending attempt.
-- ############################################################################
set role authenticated;
do $$
declare
  v_init   jsonb;
  v_status jsonb;
  v_keys   bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_init := public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000001');
  v_status := public.get_invoice_payment_status('a0000000-0000-4000-8000-000000000001');
  if v_status is null then
    raise exception 'POLICY-BATTERY FAIL 20.03: status read returned null for a pending payment';
  end if;
  if v_status ->> 'payment_id' is distinct from v_init ->> 'payment_id'
     or v_status ->> 'status' is distinct from 'pending'
     or (v_status ->> 'updated_at') is null then
    raise exception 'POLICY-BATTERY FAIL 20.03: status projection drift: %', v_status;
  end if;
  select count(*) into v_keys from jsonb_object_keys(v_status);
  if v_keys <> 3 then
    raise exception 'POLICY-BATTERY FAIL 20.03: status read returned % keys, want exactly 3: %', v_keys, v_status;
  end if;
end $$;
reset role;

-- ############################################################################
-- 20.04 — NEG (payment reads are RPC-only): authenticated holds NO SELECT on
-- public.payments even for an assigned invoice; the status RPC is the only
-- read surface.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform count(*) from public.payments;
    raise exception 'POLICY-BATTERY FAIL 20.04: authenticated raw SELECT on payments succeeded';
  exception when insufficient_privilege then
    null; -- expected: no table grant
  end;
end $$;
reset role;

-- ############################################################################
-- 20.05 — POS/NEG (attach): service-side attach is idempotent for the same
-- order and check_violation for a different order.
-- ############################################################################
do $$
declare
  v_pay    uuid;
  v_row    jsonb;
  v_again  jsonb;
begin
  select id into v_pay
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000001'
     and status = 'pending';
  v_row := public.attach_paymob_order(v_pay, 'po-20-0001');
  if v_row ->> 'attached' is distinct from 'true'
     or v_row ->> 'payment_status' is distinct from 'pending' then
    raise exception 'POLICY-BATTERY FAIL 20.05: first attach drift: %', v_row;
  end if;
  v_again := public.attach_paymob_order(v_pay, 'po-20-0001');
  if v_again ->> 'attached' is distinct from 'false'
     or v_again ->> 'provider_order_id' is distinct from 'po-20-0001' then
    raise exception 'POLICY-BATTERY FAIL 20.05: idempotent attach drift: %', v_again;
  end if;
  begin
    perform public.attach_paymob_order(v_pay, 'po-20-0001-other');
    raise exception 'POLICY-BATTERY FAIL 20.05: different-order attach succeeded';
  exception when check_violation then
    null; -- expected: immutable order binding
  end;
  if (select provider_order_id from public.payments where id = v_pay) is distinct from 'po-20-0001' then
    raise exception 'POLICY-BATTERY FAIL 20.05: denied attach mutated provider_order_id';
  end if;
end $$;

-- ############################################################################
-- 20.06 — NEG (apply validation): amount mismatch, currency mismatch,
-- unknown order, and an outcome outside the allow-list are all
-- check_violation and leave the attempt pending.
-- ############################################################################
do $$
declare
  v_pay uuid;
begin
  select id into v_pay
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000001'
     and status = 'pending';

  begin
    perform public.apply_paymob_transaction('po-20-0001', 'txn-20-0001', 'succeeded', 2500001, 'EGP');
    raise exception 'POLICY-BATTERY FAIL 20.06: amount-mismatch apply succeeded';
  exception when check_violation then
    null; -- expected: amount gate
  end;

  begin
    perform public.apply_paymob_transaction('po-20-0001', 'txn-20-0001', 'succeeded', 2500000, 'USD');
    raise exception 'POLICY-BATTERY FAIL 20.06: currency-mismatch apply succeeded';
  exception when check_violation then
    null; -- expected: currency gate
  end;

  begin
    perform public.apply_paymob_transaction('po-20-does-not-exist', 'txn-20-0001', 'succeeded', 2500000, 'EGP');
    raise exception 'POLICY-BATTERY FAIL 20.06: unknown-order apply succeeded';
  exception when check_violation then
    null; -- expected: payment lookup gate
  end;

  begin
    perform public.apply_paymob_transaction('po-20-0001', 'txn-20-0001', 'pending', 2500000, 'EGP');
    raise exception 'POLICY-BATTERY FAIL 20.06: non-terminal outcome apply succeeded';
  exception when check_violation then
    null; -- expected: outcome allow-list
  end;

  if (select status from public.payments where id = v_pay) is distinct from 'pending'
     or (select provider_transaction_id from public.payments where id = v_pay) is not null then
    raise exception 'POLICY-BATTERY FAIL 20.06: a denied apply mutated the payment';
  end if;
  if (select status from public.billing_invoices where id = 'a0000000-0000-4000-8000-000000000001')
       is distinct from 'issued' then
    raise exception 'POLICY-BATTERY FAIL 20.06: a denied apply settled the invoice';
  end if;
end $$;

-- ############################################################################
-- 20.07 — POS (success): the attempt settles to succeeded, the invoice to
-- paid, settled_at/provider_transaction_id are stamped, and exactly ONE
-- machine-actor audit row is written with a redacted summary.
-- ############################################################################
do $$
declare
  v_pay    uuid;
  v_row    jsonb;
  v_status text;
  v_cnt    bigint;
  v_bad    bigint;
begin
  select id into v_pay
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000001'
     and status = 'pending';
  v_row := public.apply_paymob_transaction(
    'po-20-0001', 'txn-20-0001', 'succeeded', 2500000, 'EGP');
  if v_row ->> 'payment_status' is distinct from 'succeeded'
     or v_row ->> 'invoice_status' is distinct from 'paid'
     or (v_row ->> 'already_processed')::boolean is distinct from false then
    raise exception 'POLICY-BATTERY FAIL 20.07: success projection drift: %', v_row;
  end if;
  select status into v_status from public.payments where id = v_pay;
  if v_status is distinct from 'succeeded' then
    raise exception 'POLICY-BATTERY FAIL 20.07: payment status = %, want succeeded', v_status;
  end if;
  if (select settled_at from public.payments where id = v_pay) is null
     or (select provider_transaction_id from public.payments where id = v_pay) is distinct from 'txn-20-0001'
     or (select failure_code from public.payments where id = v_pay) is not null then
    raise exception 'POLICY-BATTERY FAIL 20.07: terminal stamps drift';
  end if;
  select status into v_status
    from public.billing_invoices
   where id = 'a0000000-0000-4000-8000-000000000001';
  if v_status is distinct from 'paid' then
    raise exception 'POLICY-BATTERY FAIL 20.07: invoice status = %, want paid', v_status;
  end if;
  select count(*) into v_cnt
    from public.audit_events
   where action = 'payment:succeeded' and outcome = 'allowed';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.07: payment:succeeded audits = %, want exactly 1', v_cnt;
  end if;
  select count(*) into v_bad
    from public.audit_events
   where action = 'payment:succeeded' and outcome = 'allowed'
     and (actor_user_id is not null
          or organization_id is distinct from '20000000-0000-4000-8000-000000000001'
          or resource_type is distinct from 'payment'
          or resource_id is distinct from v_pay
          or redacted_summary is distinct from 'payment succeeded'
          or redacted_summary like '%txn-20%'
          or redacted_summary like '%po-20%');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.07: succeeded audit row drift (%)', v_bad;
  end if;
end $$;

-- CHECK 20.07 (status read after settlement) — the settlement flips the
-- invoice to 'paid'; the status endpoint still answers (it does not re-apply
-- the initiation payability gate).
set role authenticated;
do $$
declare
  v_row jsonb;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_row := public.get_invoice_payment_status('a0000000-0000-4000-8000-000000000001');
  if v_row is null or v_row ->> 'status' is distinct from 'succeeded' then
    raise exception 'POLICY-BATTERY FAIL 20.07: status read after settlement drift: %', v_row;
  end if;
end $$;
reset role;

-- ############################################################################
-- 20.08 — NEG (terminal immutability): an identical replay is
-- already_processed with no second audit; a conflicting outcome is
-- check_violation; re-attaching a terminal attempt is refused.
-- ############################################################################
do $$
declare
  v_pay uuid;
  v_row jsonb;
  v_cnt bigint;
begin
  select id into v_pay
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000001'
     and status = 'succeeded';

  v_row := public.apply_paymob_transaction(
    'po-20-0001', 'txn-20-0001', 'succeeded', 2500000, 'EGP');
  if (v_row ->> 'already_processed')::boolean is distinct from true
     or v_row ->> 'payment_status' is distinct from 'succeeded'
     or v_row ->> 'invoice_status' is distinct from 'paid' then
    raise exception 'POLICY-BATTERY FAIL 20.08: replay projection drift: %', v_row;
  end if;

  select count(*) into v_cnt
    from public.audit_events where action = 'payment:succeeded';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.08: replay wrote a second audit (rows = %)', v_cnt;
  end if;

  begin
    perform public.apply_paymob_transaction(
      'po-20-0001', 'txn-20-0001-conflict', 'failed', 2500000, 'EGP');
    raise exception 'POLICY-BATTERY FAIL 20.08: conflicting terminal outcome succeeded';
  exception when check_violation then
    null; -- expected: terminal immutability
  end;

  begin
    perform public.attach_paymob_order(v_pay, 'po-20-0001-late');
    raise exception 'POLICY-BATTERY FAIL 20.08: attach on a terminal payment succeeded';
  exception when check_violation then
    null; -- expected: pending-only attach
  end;

  if (select status from public.payments where id = v_pay) is distinct from 'succeeded' then
    raise exception 'POLICY-BATTERY FAIL 20.08: a denied transition mutated the payment';
  end if;
end $$;

-- ############################################################################
-- 20.09 — POS/NEG (failure + retry): a failed attempt leaves the invoice
-- issued, stamps the failure code, and a fresh initiate creates a NEW
-- attempt (the retry path).
-- ############################################################################
set role authenticated;
do $$
declare
  v_row jsonb;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_row := public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000003');
  if v_row ->> 'status' is distinct from 'pending'
     or (v_row ->> 'amount_cents')::bigint is distinct from 3000000 then
    raise exception 'POLICY-BATTERY FAIL 20.09: invoice-3 initiate drift: %', v_row;
  end if;
end $$;
reset role;

do $$
declare
  v_pay   uuid;
  v_row   jsonb;
  v_cnt   bigint;
  v_bad   bigint;
begin
  select id into v_pay
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000003'
     and status = 'pending';
  perform public.attach_paymob_order(v_pay, 'po-20-0003');
  v_row := public.apply_paymob_transaction(
    'po-20-0003', 'txn-20-0003-f', 'failed', 3000000, 'EGP', 'declined');
  if v_row ->> 'payment_status' is distinct from 'failed'
     or v_row ->> 'invoice_status' is distinct from 'issued'
     or (v_row ->> 'already_processed')::boolean is distinct from false then
    raise exception 'POLICY-BATTERY FAIL 20.09: failure projection drift: %', v_row;
  end if;
  if (select status from public.billing_invoices where id = 'a0000000-0000-4000-8000-000000000003')
       is distinct from 'issued' then
    raise exception 'POLICY-BATTERY FAIL 20.09: failed attempt settled the invoice';
  end if;
  if (select failure_code from public.payments where id = v_pay) is distinct from 'declined'
     or (select settled_at from public.payments where id = v_pay) is null then
    raise exception 'POLICY-BATTERY FAIL 20.09: failure stamps drift';
  end if;
  select count(*) into v_cnt
    from public.audit_events where action = 'payment:failed' and outcome = 'allowed';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.09: payment:failed audits = %, want exactly 1', v_cnt;
  end if;
  select count(*) into v_bad
    from public.audit_events
   where action = 'payment:failed' and outcome = 'allowed'
     and (actor_user_id is not null
          or redacted_summary is distinct from 'payment failed'
          or redacted_summary like '%declined%'
          or redacted_summary like '%txn-20%');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.09: failed audit row drift (%)', v_bad;
  end if;

  -- A failed attempt is terminal: succeeding it later is a contradiction.
  begin
    perform public.apply_paymob_transaction(
      'po-20-0003', 'txn-20-0003-s', 'succeeded', 3000000, 'EGP');
    raise exception 'POLICY-BATTERY FAIL 20.09: failed->succeeded transition succeeded';
  exception when check_violation then
    null; -- expected: terminal immutability
  end;
  if (select status from public.payments where id = v_pay) is distinct from 'failed' then
    raise exception 'POLICY-BATTERY FAIL 20.09: conflicting transition mutated the failed payment';
  end if;
end $$;

-- Retry: the invoice is still issued, so partner-a gets a NEW pending attempt.
set role authenticated;
do $$
declare
  v_row jsonb;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_row := public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000003');
  if v_row ->> 'status' is distinct from 'pending' then
    raise exception 'POLICY-BATTERY FAIL 20.09: retry initiate status = %', v_row ->> 'status';
  end if;
end $$;
reset role;

do $$
declare
  v_failed  uuid;
  v_pending uuid;
  v_cnt     bigint;
begin
  select id into v_failed
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000003'
     and status = 'failed';
  select id into v_pending
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000003'
     and status = 'pending';
  if v_failed is null or v_pending is null or v_failed = v_pending then
    raise exception 'POLICY-BATTERY FAIL 20.09: retry did not create a distinct pending attempt (% / %)',
      v_failed, v_pending;
  end if;
  select count(*) into v_cnt
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000003';
  if v_cnt <> 2 then
    raise exception 'POLICY-BATTERY FAIL 20.09: invoice 3 payments = %, want 2 (failed + retry)', v_cnt;
  end if;
  select count(*) into v_cnt
    from public.audit_events where action = 'payment:initiate' and outcome = 'allowed';
  if v_cnt <> 3 then
    raise exception 'POLICY-BATTERY FAIL 20.09: payment:initiate audits = %, want 3', v_cnt;
  end if;
  -- Bind the retry attempt to an order for the stale sweep.
  perform public.attach_paymob_order(v_pending, 'po-20-0003b');
end $$;

-- ############################################################################
-- 20.10 — POS (stale sweep): threshold filtering, projection and limit.
-- The retry attempt is backdated; one temp fresh and one temp stale pending
-- attempt are seeded directly (rolled back with the battery).
-- ############################################################################
do $$
declare
  v_p3b   uuid;
  v_fresh uuid;
  v_stale uuid;
  v_cnt   bigint;
  v_item  jsonb;
  v_keys  bigint;
begin
  select id into v_p3b
    from public.payments
   where invoice_id = 'a0000000-0000-4000-8000-000000000003'
     and status = 'pending';
  update public.payments
     set created_at = now() - interval '1 hour'
   where id = v_p3b;

  insert into public.billing_invoices
    (id, organization_id, matter_id, invoice_number, amount_cents, currency, status, issued_at, due_at, description)
  values
    ('a0000000-0000-4000-8000-0000000020f1', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'INV-20-FRESH', 1100, 'EGP', 'issued', now(), now() + interval '30 days', 'Temp fresh invoice'),
    ('a0000000-0000-4000-8000-0000000020f2', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'INV-20-STALE', 1200, 'EGP', 'issued', now(), now() + interval '30 days', 'Temp stale invoice');

  insert into public.payments (invoice_id, amount_cents, currency, status, created_at)
  values ('a0000000-0000-4000-8000-0000000020f1', 1100, 'EGP', 'pending', now())
  returning id into v_fresh;

  insert into public.payments (invoice_id, amount_cents, currency, status, created_at)
  values ('a0000000-0000-4000-8000-0000000020f2', 1200, 'EGP', 'pending', now() - interval '2 hours')
  returning id into v_stale;

  select count(*) into v_cnt
    from public.list_stale_pending_payments() as s(item);
  if v_cnt <> 2 then
    raise exception 'POLICY-BATTERY FAIL 20.10: stale sweep returned %, want 2 (fresh excluded)', v_cnt;
  end if;

  select count(*) into v_cnt
    from public.list_stale_pending_payments() as s(item)
   where item ->> 'id' = v_p3b::text;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.10: backdated retry attempt missing from the stale sweep';
  end if;

  select count(*) into v_cnt
    from public.list_stale_pending_payments() as s(item)
   where item ->> 'id' = v_fresh::text;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.10: fresh pending attempt leaked into the stale sweep';
  end if;

  select item into v_item
    from public.list_stale_pending_payments() as s(item)
   where item ->> 'id' = v_p3b::text;
  select count(*) into v_keys from jsonb_object_keys(v_item);
  if v_keys <> 5
     or v_item ->> 'provider_order_id' is distinct from 'po-20-0003b'
     or (v_item ->> 'amount_cents')::bigint is distinct from 3000000
     or v_item ->> 'currency' is distinct from 'EGP'
     or (v_item ->> 'created_at') is null then
    raise exception 'POLICY-BATTERY FAIL 20.10: stale projection drift: %', v_item;
  end if;

  select count(*) into v_cnt
    from public.list_stale_pending_payments('15 minutes', 1) as s(item);
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.10: p_limit=1 returned % rows', v_cnt;
  end if;

  select count(*) into v_cnt
    from public.list_stale_pending_payments(null, null) as s(item);
  if v_cnt <> 2 then
    raise exception 'POLICY-BATTERY FAIL 20.10: null-argument defaults returned % rows, want 2', v_cnt;
  end if;
end $$;

-- ############################################################################
-- AUTH DENIALS — the in-function assignment gate. Each denial raises before
-- anything is written.
-- ############################################################################

-- CHECK 20.11 — NEG (org role alone): partner-a is an active org-a partner
-- but is NOT assigned on matter 4 — invoice 4 is denied.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000004');
    raise exception 'POLICY-BATTERY FAIL 20.11: org-role-alone initiate succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: permission denied
  end;
end $$;
reset role;

-- CHECK 20.12 — NEG (cross-org): partner-b is assigned attorney on org-a
-- matter 5 but an ACTIVE member of org-b only — invoice 1 is denied.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    perform public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 20.12: cross-org initiate succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: permission denied
  end;
end $$;
reset role;

-- CHECK 20.13 — NEG (stale access): suspended-a IS the assigned attorney on
-- matter 6 (invoice 6) but its membership is 'suspended' — denied.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  begin
    perform public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000006');
    raise exception 'POLICY-BATTERY FAIL 20.13: suspended initiate succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: permission denied
  end;
end $$;
reset role;

-- CHECK 20.14 — NEG (platform_owner_admin): the owner is never assigned —
-- no carve-out.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 20.14: owner initiate succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: permission denied
  end;
end $$;
reset role;

-- CHECK 20.15 — NEG (unassigned member): orphan is an active org-a client
-- but assigned on matter 4 only — invoice 1 is denied.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  begin
    perform public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 20.15: unassigned-member initiate succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: permission denied
  end;
end $$;
reset role;

-- CHECK 20.16 — NEG (guessed id): a nonexistent invoice id is the same typed
-- denial (no existence oracle).
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.initiate_invoice_payment('a0000000-0000-4000-8000-00000000ffff');
    raise exception 'POLICY-BATTERY FAIL 20.16: guessed-id initiate succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: permission denied
  end;
end $$;
reset role;

-- CHECK 20.17 — NEG (unauthenticated): anon holds no EXECUTE grant on the
-- payment RPCs (initiate/status grant authenticated only).
set role anon;
do $$
begin
  begin
    perform public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 20.17: anon initiate succeeded';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
  begin
    perform public.get_invoice_payment_status('a0000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 20.17: anon status read succeeded';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
end $$;
reset role;

-- CHECK 20.17 (privileged half) — the deny rows wrote no payment row and no
-- audit row: 5 attempts total, 3 initiate audits.
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt from public.payments;
  if v_cnt <> 5 then
    raise exception 'POLICY-BATTERY FAIL 20.17: payments = % after denies, want 5', v_cnt;
  end if;
  select count(*) into v_cnt
    from public.audit_events where action = 'payment:initiate' and outcome = 'allowed';
  if v_cnt <> 3 then
    raise exception 'POLICY-BATTERY FAIL 20.17: payment:initiate audits = % after denies, want 3', v_cnt;
  end if;
end $$;

-- ############################################################################
-- NON-PAYABLE INVOICES — the invoice-domain gates.
-- ############################################################################

-- CHECK 20.18 — NEG (already paid): fixture invoice 2 is 'paid' — initiating
-- is check_violation (client-a is assigned on matter 2).
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000002');
    raise exception 'POLICY-BATTERY FAIL 20.18: already-paid invoice initiate succeeded';
  exception when check_violation then
    null; -- expected: payability gate
  end;
end $$;
reset role;

-- CHECK 20.19 — NEG (settled to paid): invoice 1 became 'paid' in 20.07 —
-- a second initiate is refused (no double charge).
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.initiate_invoice_payment('a0000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 20.19: settled invoice initiate succeeded';
  exception when check_violation then
    null; -- expected: payability gate
  end;
end $$;
reset role;

-- Seed the two non-payable temp invoices (rolled back with the battery).
do $$
begin
  insert into public.billing_invoices
    (id, organization_id, matter_id, invoice_number, amount_cents, currency, status, issued_at, due_at, description)
  values
    ('a0000000-0000-4000-8000-0000000020f3', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'INV-20-ZERO', 0, 'EGP', 'issued', now(), now() + interval '30 days', 'Temp zero invoice'),
    ('a0000000-0000-4000-8000-0000000020f4', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'INV-20-USD', 1000, 'USD', 'issued', now(), now() + interval '30 days', 'Temp non-EGP invoice');
end $$;

-- CHECK 20.20 — NEG (zero amount): the invoice amount gate is check_violation
-- and writes nothing.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.initiate_invoice_payment('a0000000-0000-4000-8000-0000000020f3');
    raise exception 'POLICY-BATTERY FAIL 20.20: zero-amount invoice initiate succeeded';
  exception when check_violation then
    null; -- expected: amount gate
  end;
end $$;
reset role;

-- CHECK 20.21 — NEG (non-EGP): the invoice currency gate is check_violation.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.initiate_invoice_payment('a0000000-0000-4000-8000-0000000020f4');
    raise exception 'POLICY-BATTERY FAIL 20.21: non-EGP invoice initiate succeeded';
  exception when check_violation then
    null; -- expected: currency gate
  end;
end $$;
reset role;

do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from public.payments
   where invoice_id in (
     'a0000000-0000-4000-8000-0000000020f3',
     'a0000000-0000-4000-8000-0000000020f4');
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.21: non-payable invoice denials wrote % payment rows', v_cnt;
  end if;
  select count(*) into v_cnt from public.payments;
  if v_cnt <> 5 then
    raise exception 'POLICY-BATTERY FAIL 20.21: payments = % after non-payable denies, want 5', v_cnt;
  end if;
end $$;

-- ############################################################################
-- SERVICE-ROLE-ONLY SURFACE — authenticated must be denied at the privilege
-- layer for every backend RPC.
-- ############################################################################

-- CHECK 20.22 — NEG: attach_paymob_order is service-role only.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.attach_paymob_order('a0000000-0000-4000-8000-00000000ffff', 'po-x');
    raise exception 'POLICY-BATTERY FAIL 20.22: authenticated attach succeeded';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
end $$;
reset role;

-- CHECK 20.23 — NEG: apply_paymob_transaction is service-role only.
set role authenticated;
do $$
begin
  begin
    perform public.apply_paymob_transaction('po-20-0003b', 'txn-x', 'succeeded', 3000000, 'EGP');
    raise exception 'POLICY-BATTERY FAIL 20.23: authenticated apply succeeded';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
end $$;
reset role;

-- CHECK 20.24 — NEG: record_payment_callback_rejected is service-role only.
set role authenticated;
do $$
begin
  begin
    perform public.record_payment_callback_rejected('signature_mismatch');
    raise exception 'POLICY-BATTERY FAIL 20.24: authenticated callback-rejection write succeeded';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
end $$;
reset role;

-- CHECK 20.25 — NEG: list_stale_pending_payments is service-role only.
set role authenticated;
do $$
begin
  begin
    perform count(*) from public.list_stale_pending_payments();
    raise exception 'POLICY-BATTERY FAIL 20.25: authenticated stale sweep succeeded';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
end $$;
reset role;

-- ############################################################################
-- DIRECT TABLE POSTURE — no grants, no policies, no direct DML.
-- ############################################################################

-- CHECK 20.26 — NEG: authenticated/anon hold no table privilege, there are
-- no policies on public.payments, and a raw INSERT is denied.
do $$
declare
  v_pol bigint;
begin
  if has_table_privilege('authenticated', 'public.payments', 'SELECT')
     or has_table_privilege('authenticated', 'public.payments', 'INSERT')
     or has_table_privilege('authenticated', 'public.payments', 'UPDATE')
     or has_table_privilege('authenticated', 'public.payments', 'DELETE') then
    raise exception 'POLICY-BATTERY FAIL 20.26: authenticated holds a direct privilege on payments';
  end if;
  if has_table_privilege('anon', 'public.payments', 'SELECT')
     or has_table_privilege('anon', 'public.payments', 'INSERT')
     or has_table_privilege('anon', 'public.payments', 'UPDATE')
     or has_table_privilege('anon', 'public.payments', 'DELETE') then
    raise exception 'POLICY-BATTERY FAIL 20.26: anon holds a direct privilege on payments';
  end if;
  select count(*) into v_pol
    from pg_policies
   where schemaname = 'public' and tablename = 'payments';
  if v_pol <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.26: payments carries % policies, want 0', v_pol;
  end if;
end $$;

set role authenticated;
do $$
begin
  begin
    insert into public.payments (invoice_id, amount_cents, currency, status)
    values ('a0000000-0000-4000-8000-000000000006', 1200000, 'EGP', 'pending');
    raise exception 'POLICY-BATTERY FAIL 20.26: authenticated raw INSERT succeeded';
  exception when insufficient_privilege then
    null; -- expected: no INSERT grant
  end;
end $$;
reset role;

-- ############################################################################
-- 20.27 — NEG (cascade): deleting the matter removes its invoices and their
-- payments (matter -> invoice -> payment FK chain). Temp rows, rolled back.
-- ############################################################################
do $$
declare
  v_inv   uuid := 'a0000000-0000-4000-8000-0000000020f5';
  v_pay   uuid;
  v_cnt   bigint;
begin
  insert into public.matters
    (id, organization_id, title, practice_area, status, assigned_client_id, created_at, updated_at)
  values
    ('40000000-0000-4000-8000-0000000020f1', '20000000-0000-4000-8000-000000000001', 'Cascade matter', 'civil', 'open', '10000000-0000-4000-8000-000000000003', now(), now());
  insert into public.billing_invoices
    (id, organization_id, matter_id, invoice_number, amount_cents, currency, status, issued_at, due_at, description)
  values
    (v_inv, '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-0000000020f1', 'INV-20-CASCADE', 500, 'EGP', 'issued', now(), now() + interval '30 days', 'Temp cascade invoice');
  insert into public.payments (invoice_id, amount_cents, currency, status)
  values (v_inv, 500, 'EGP', 'pending')
  returning id into v_pay;

  delete from public.matters where id = '40000000-0000-4000-8000-0000000020f1';

  select count(*) into v_cnt from public.billing_invoices where id = v_inv;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.27: invoice survived the matter delete';
  end if;
  select count(*) into v_cnt from public.payments where id = v_pay;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.27: payment survived the matter cascade';
  end if;
end $$;

-- ############################################################################
-- 20.28 — POS/NEG (callback rejection + audit census): the reason allow-list
-- normalizes anything else, and the final payment audit set is exactly the
-- successful transitions — no provider identifiers, no raw failure text.
-- ############################################################################
do $$
declare
  v_cnt bigint;
  v_bad bigint;
begin
  perform public.record_payment_callback_rejected('signature_mismatch');
  perform public.record_payment_callback_rejected('raw body with txn-20-0001 and po-20-0001');

  select count(*) into v_cnt
    from public.audit_events
   where action = 'payment:callback_rejected' and outcome = 'denied';
  if v_cnt <> 2 then
    raise exception 'POLICY-BATTERY FAIL 20.28: callback_rejected audits = %, want 2', v_cnt;
  end if;

  select count(*) into v_bad
    from public.audit_events
   where action = 'payment:callback_rejected'
     and (actor_user_id is not null
          or organization_id is not null
          or resource_type is distinct from 'payment'
          or resource_id is not null);
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.28: callback_rejected audit row drift (%)', v_bad;
  end if;

  select count(*) into v_cnt
    from public.audit_events
   where action = 'payment:callback_rejected'
     and redacted_summary = 'payment callback rejected: signature_mismatch';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.28: allow-listed reason was not recorded verbatim';
  end if;

  select count(*) into v_cnt
    from public.audit_events
   where action = 'payment:callback_rejected'
     and redacted_summary = 'payment callback rejected: unclassified';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.28: non-allow-listed reason was not normalized to unclassified';
  end if;

  -- Final census: initiate 3, succeeded 1, failed 1, rejected 2 = 7.
  select count(*) into v_cnt
    from public.audit_events where action like 'payment:%';
  if v_cnt <> 7 then
    raise exception 'POLICY-BATTERY FAIL 20.28: total payment audit rows = %, want 7', v_cnt;
  end if;
  select count(*) into v_cnt
    from public.audit_events
   where action = 'payment:initiate' and outcome = 'allowed';
  if v_cnt <> 3 then
    raise exception 'POLICY-BATTERY FAIL 20.28: payment:initiate audits = %, want 3', v_cnt;
  end if;
  select count(*) into v_cnt
    from public.audit_events
   where action = 'payment:succeeded' and outcome = 'allowed';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.28: payment:succeeded audits = %, want 1', v_cnt;
  end if;
  select count(*) into v_cnt
    from public.audit_events
   where action = 'payment:failed' and outcome = 'allowed';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 20.28: payment:failed audits = %, want 1', v_cnt;
  end if;

  -- Redaction: no summary carries a provider order/transaction id, a raw
  -- failure payload, or a card-shaped token.
  select count(*) into v_bad
    from public.audit_events
   where action like 'payment:%'
     and (redacted_summary like '%txn-20%'
          or redacted_summary like '%po-20%'
          or redacted_summary like '%declined%'
          or redacted_summary like '%card%'
          or redacted_summary like '%cvv%');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.28: % payment audit summaries leak provider/payment detail', v_bad;
  end if;

  -- Terminal audits are machine events; initiate audits carry the caller.
  select count(*) into v_bad
    from public.audit_events
   where action in ('payment:succeeded', 'payment:failed')
     and actor_user_id is not null;
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.28: terminal payment audit carries an actor (%)', v_bad;
  end if;
  select count(*) into v_bad
    from public.audit_events
   where action = 'payment:initiate'
     and (actor_user_id is null
          or actor_user_id not in (
            '10000000-0000-4000-8000-000000000002',
            '10000000-0000-4000-8000-000000000003'));
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 20.28: initiate audit actor drift (%)', v_bad;
  end if;
end $$;

-- ############################################################################
-- 20.29 — POS (late success after expiry): the provider checkout key is valid
-- longer than the stale sweep. A signed success that arrives after the sweep
-- expired the attempt must settle the payment and the still-issued invoice;
-- a later conflicting outcome stays check_violation (audit H1).
-- ############################################################################
do $$
declare
  v_pay    uuid;
  v_row    jsonb;
  v_status text;
begin
  insert into public.payments
    (invoice_id, amount_cents, currency, status, provider_order_id)
  values
    ('a0000000-0000-4000-8000-000000000004', 800000, 'EGP', 'pending', 'po-20-late')
  returning id into v_pay;

  perform public.apply_paymob_transaction(
    'po-20-late', 'txn-20-late-exp', 'expired', 800000, 'EGP', 'sweep');

  v_row := public.apply_paymob_transaction(
    'po-20-late', 'txn-20-late-ok', 'succeeded', 800000, 'EGP');
  if v_row ->> 'payment_status' is distinct from 'succeeded'
     or (v_row ->> 'already_processed')::boolean then
    raise exception 'POLICY-BATTERY FAIL 20.29: late success projection drift: %', v_row;
  end if;

  select status into v_status
    from public.billing_invoices
   where id = 'a0000000-0000-4000-8000-000000000004';
  if v_status is distinct from 'paid' then
    raise exception 'POLICY-BATTERY FAIL 20.29: late success left the invoice %', v_status;
  end if;

  begin
    perform public.apply_paymob_transaction(
      'po-20-late', 'txn-20-late-bad', 'failed', 800000, 'EGP');
    raise exception 'POLICY-BATTERY FAIL 20.29: succeeded -> failed was allowed';
  exception when check_violation then
    null; -- expected: only expired -> succeeded is exempt
  end;
end $$;

rollback;
