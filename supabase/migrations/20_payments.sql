-- 20_payments.sql — invoice payment attempts (NOT APPLIED — rehearsal only)
-- Source of truth: the payments slice (Paymob hosted checkout, fake-gateway
-- posture in MVP). Table only; every mutation goes through the audited RPCs
-- in supabase/rpc/ (initiate_invoice_payment, attach_paymob_order,
-- apply_paymob_transaction, record_payment_callback_rejected) and the
-- service-role sweep (list_stale_pending_payments).
--
-- D-11 PCI constraint stays STRUCTURAL: this table carries provider ORDER and
-- TRANSACTION identifiers only — no card token, no PAN, no CVV, no billing
-- address, no payer identity. The provider-hosted checkout owns all card
-- data; the server never sees it. The unique provider identifiers are the
-- idempotency keys for callbacks.
--
-- Lifecycle: one PENDING attempt per invoice (partial unique index), then a
-- single terminal transition (succeeded / failed / expired / cancelled /
-- refunded). A failed/expired/cancelled attempt does not mutate the invoice,
-- so the client may initiate a fresh pending attempt. Only 'succeeded'
-- settles the invoice (billing_invoices.status = 'paid').
--
-- RLS: enabled with NO policies and NO direct grants to anon/authenticated —
-- reads and writes are RPC-only. The RPCs are security definer and re-assert
-- the assignment gate themselves (the invoices/matters/tasks precedent).
-- Rollback: 20_payments.down.sql (same directory).

begin;

-- 20.1 payments — one row per gateway attempt on an issued invoice.
create table public.payments (
  id                      uuid primary key default gen_random_uuid(),
  invoice_id              uuid not null references public.billing_invoices (id) on delete cascade,
  initiated_by            uuid references auth.users (id) on delete set null,
  amount_cents            bigint not null
    check (amount_cents >= 0),           -- client Invoice.amountCents mapping contract (initiate requires > 0)
  currency                text not null default 'EGP'
    check (currency = 'EGP'),            -- D-11 demo posture; no FX machinery
  status                  text not null default 'pending'
    check (status in ('pending', 'succeeded', 'failed', 'expired', 'cancelled', 'refunded')),
  provider                text not null default 'paymob'
    check (provider = 'paymob'),         -- single provider in this slice; CHECK = mapping contract
  provider_order_id       text unique,   -- opaque Paymob order id; set once by attach_paymob_order
  provider_transaction_id text unique,   -- opaque Paymob transaction id; never returned to clients
  failure_code            text,          -- provider reason code only; never raw payload/PII
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  settled_at              timestamptz    -- stamped on the terminal transition, never on pending
);

-- At most ONE pending attempt per invoice: the partial unique index is the
-- concurrency backstop behind initiate_invoice_payment's invoice-row lock.
create unique index payments_one_pending_per_invoice
  on public.payments (invoice_id)
  where status = 'pending';

-- The two read shapes: latest attempt per invoice (status polling) and the
-- stale-pending sweep (status + created_at).
create index payments_invoice_created
  on public.payments (invoice_id, created_at desc);

-- RLS on (default deny: with no policy, all access is denied) + NO grants:
-- authenticated/anon hold no table privilege at all — the payment surface is
-- RPC-only, so no row-level policy can ever expose raw provider identifiers
-- or the audit-bearing lifecycle.
alter table public.payments enable row level security;

revoke all on public.payments from anon, authenticated;

commit;
