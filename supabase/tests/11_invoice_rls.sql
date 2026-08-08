-- ============================================================================
-- supabase/tests/11_invoice_rls.sql — billing-invoices policy battery (T3)
-- Source: docs/billing_invoices_gate_review_2026-08-08.md §4 (the deny-rows
-- contract) + docs/billing_invoices_real_data_plan_2026-08-08.md (D-BI1/D-BI2).
--
-- Proves `invoices_select_assigned` against the matrix §4 invoice row
-- (invoices are matter content — the documents row's "restricted matter or
-- its documents/messages" reading, extended to invoices; D-BI3):
--   - assigned client / assigned attorney ON THE INVOICE'S MATTER, active
--     member of the invoice's org -> the ONLY grant (positives + row-count
--     pins: client-a 2, partner-a 3, orphan 1);
--   - org role alone (member, no matter assignment) -> deny, every role;
--   - org-mismatch (D-BI2 load-bearing clause): an invoice whose
--     organization_id != its matter's org denies for every role (an invoice
--     is never readable when its matter is not) — privileged temp-row half;
--   - cross-org (assigned on an org-a matter, member of org-b only) -> deny;
--   - suspended membership -> deny (stale access);
--   - platform_owner_admin (never assigned) -> deny, always (Q4 residual);
--   - unauthenticated -> deny (no grant);
--   - amount_cents CHECK (mapping contract) -> a write path cannot insert a
--     negative amount (privileged-path half; the client has no INSERT
--     grant);
--   - status CHECK (mapping contract) -> a write path cannot insert an
--     unmapped status (D-11: deliberately minimal, no tax/lifecycle
--     machinery) — privileged-path half;
--   - matter-delete cascade -> dropping the matter removes its invoices
--     (FK on delete cascade), pinned in a rolled-back txn.
-- D-11 structural note: the battery asserts READ behavior only — the table
-- holds metadata-only columns (no card/payment columns at all), so no check
-- can ever touch payment data (the PCI constraint is enforced by schema,
-- review Q5).
--
-- Run AFTER 00_fixtures.sql, under psql -v ON_ERROR_STOP=1, by
-- scripts/verify_policy_tests.sh (which applies 10_billing_invoices.sql +
-- policies/invoices.sql to the rehearsal project first). Same impersonation
-- pattern as 01/02/03/04/05: set_config request.jwt.* for auth.uid().
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- Privileged-path half (runs as the connection role — postgres): the facts
-- no client role can observe because it holds no INSERT/DELETE grant.
-- ############################################################################

-- CHECK 11.10 — NEG (privileged half): the amount_cents CHECK is the mapping
-- contract — a negative amount is rejected even by a privileged writer, so no
-- future write path (RPC/seed) can ever insert an amount the client's
-- Invoice.amountCents cannot render.
begin;
do $$
begin
  begin
    insert into public.billing_invoices
      (id, organization_id, matter_id, invoice_number, amount_cents, currency, status, issued_at, due_at, description)
    values
      ('a0000000-0000-4000-8000-00000000ffff', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'INV-BAD-AMT', -1, 'EGP', 'issued', now(), now() + interval '30 days', 'Bad amount');
    raise exception 'POLICY-BATTERY FAIL 11.10: amount_cents CHECK accepted a negative amount';
  exception when check_violation then
    null; -- expected: CHECK rejected -1
  end;
end $$;
rollback;

-- CHECK 11.11 — NEG (privileged half): the status CHECK is the mapping
-- contract — an unmapped status is rejected even by a privileged writer, so
-- no future write path can insert a value the client's InvoiceStatus enum
-- cannot map (D-11: the status set is deliberately minimal — no tax/VAT or
-- lifecycle machinery, INSTRUCTIONS §4.4).
begin;
do $$
begin
  begin
    insert into public.billing_invoices
      (id, organization_id, matter_id, invoice_number, amount_cents, currency, status, issued_at, due_at, description)
    values
      ('a0000000-0000-4000-8000-00000000fff1', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'INV-BAD-STATUS', 1000, 'EGP', 'overdue', now(), now() + interval '30 days', 'Bad status');
    raise exception 'POLICY-BATTERY FAIL 11.11: status CHECK accepted an unmapped value';
  exception when check_violation then
    null; -- expected: CHECK rejected 'overdue'
  end;
end $$;
rollback;

-- CHECK 11.12 — POS (privileged half): matter-delete cascade — dropping the
-- matter removes its invoices (FK on delete cascade), so a matter teardown
-- can never strand orphaned invoice rows. Deletes matter-1 (which holds
-- fixture invoice-1) so the cascade is actually exercised, not vacuous.
begin;
do $$
declare
  v_cnt bigint;
begin
  delete from public.matters where id = '40000000-0000-4000-8000-000000000001';
  select count(*) into v_cnt
    from public.billing_invoices
   where matter_id = '40000000-0000-4000-8000-000000000001';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 11.12: % invoices survived the matter delete', v_cnt;
  end if;
end $$;
rollback;

-- CHECK 11.05 — NEG (privileged half, org-mismatch / D-BI2 load-bearing
-- clause): insert a temp org-b matter assigned to partner-a, then a temp
-- invoice whose organization_id (org-a) does NOT match its matter's org
-- (org-b). Partner-a is an org-a member AND assigned on the matter — without
-- the m.organization_id = billing_invoices.organization_id clause the exists
-- would grant; the clause must deny, proving "an invoice is never readable
-- when its matter is not". All temp rows roll back.
begin;
insert into public.matters
  (id, organization_id, title, practice_area, status, assigned_attorney_id, created_at, updated_at)
values
  ('40000000-0000-4000-8000-00000000fffa', '20000000-0000-4000-8000-000000000002', 'Mismatch matter', 'civil', 'open', '10000000-0000-4000-8000-000000000002', now(), now());
insert into public.billing_invoices
  (id, organization_id, matter_id, invoice_number, amount_cents, currency, status, issued_at, due_at, description)
values
  ('a0000000-0000-4000-8000-00000000fffe', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-00000000fffa', 'INV-MISMATCH', 1000, 'EGP', 'issued', now(), now() + interval '30 days', 'Mismatch invoice');
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.billing_invoices
   where id = 'a0000000-0000-4000-8000-00000000fffe';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 11.05: org-mismatch invoice was readable';
  end if;
end $$;
reset role;
rollback;

set role authenticated;

-- ############################################################################
-- Positives — assigned client / assigned attorney ON THE INVOICE'S MATTER,
-- active member of the invoice's org (the ONLY grant, matrix §4).
-- ############################################################################

-- CHECK 11.01 — POS: client-a (org-a, client/active) sees exactly its two
-- assigned-client matters' invoices (matters 1, 2) and no others.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt from public.billing_invoices;
  if v_cnt <> 2 then
    raise exception 'POLICY-BATTERY FAIL 11.01: assigned client saw % invoices, want 2', v_cnt;
  end if;
end $$;

-- CHECK 11.02 — POS: partner-a (org-a, partner/active) sees exactly its three
-- assigned-attorney matters' invoices (matters 1, 2, 3) — the count proves
-- no blanket org access (invoice-4, on the matter partner-a is not assigned
-- to, is NOT visible).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt from public.billing_invoices;
  if v_cnt <> 3 then
    raise exception 'POLICY-BATTERY FAIL 11.02: assigned attorney saw % invoices, want 3', v_cnt;
  end if;
end $$;

-- CHECK 11.03 — POS: orphan (org-a, client/active) sees exactly the invoice
-- of its one assigned-client matter (4) — a row is granted by matter
-- assignment, not by membership breadth.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  select count(*) into v_cnt from public.billing_invoices;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 11.03: assigned client (orphan) saw % invoices, want 1', v_cnt;
  end if;
end $$;

-- ############################################################################
-- Negatives — the matrix §4 deny rows.
-- ############################################################################

-- CHECK 11.04 — NEG (org role alone): partner-a is an ACTIVE org-a partner
-- but has NO assignment on matter-4 — its invoice (invoice-4) is denied,
-- proving "an org role alone never grants invoice access" (deny for every
-- role).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.billing_invoices
   where id = 'a0000000-0000-4000-8000-000000000004';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 11.04: org-role-alone partner read an unassigned matter''s invoice';
  end if;
end $$;

-- CHECK 11.06 — NEG (cross-org): partner-b is assigned as attorney on an
-- org-a matter (5) but is an active member of org-b ONLY — membership is
-- tested against the invoice's org (the matter's authoritative org), so the
-- assignment grants nothing. Proves the reverse direction of the matrix line
-- "a matter in org-a cannot be accessed by an otherwise-authorized member of
-- org-b" applied to its invoices.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_cnt from public.billing_invoices;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 11.06: cross-org user saw % invoices, want 0', v_cnt;
  end if;
end $$;

-- CHECK 11.07 — NEG (stale access): suspended-a is ASSIGNED as attorney on
-- matter-6 but its org-a membership is 'suspended' — is_active_member is the
-- status = 'active' rule, so the assignment grants nothing (the 02 hardening
-- guard extended to invoices).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select count(*) into v_cnt from public.billing_invoices;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 11.07: suspended member saw % invoices, want 0', v_cnt;
  end if;
end $$;

-- CHECK 11.08 — NEG (platform_owner_admin): the owner (0001) is never
-- assigned on any matter, so the matter gate denies its invoices always.
-- RESIDUAL (design review Q4, recorded): if an owner account were ever
-- assigned on a matter, this policy WOULD grant — the categorical matrix deny
-- is an operational invariant, not a policy guarantee; fixtures never create
-- that state.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt from public.billing_invoices;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 11.08: platform_owner_admin saw % invoices, want 0', v_cnt;
  end if;
end $$;

-- CHECK 11.09 — NEG (unauthenticated): anon holds NO grant on
-- billing_invoices (the 01-pattern default-deny revoke), so a raw read is
-- denied at the privilege layer — double-denied with the null-auth.uid()
-- policy.
set role anon;
do $$
begin
  begin
    perform count(*) from public.billing_invoices;
    raise exception 'POLICY-BATTERY FAIL 11.09: anon raw SELECT on billing_invoices succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
end $$;
set role authenticated;
