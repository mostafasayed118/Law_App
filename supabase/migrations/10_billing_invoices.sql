-- 10_billing_invoices.sql — billing invoices read-path migration (REHEARSAL-READY — NOT applied, 2026-08-08)
-- Source of truth: docs/billing_invoices_real_data_plan_2026-08-08.md (D-BI1)
--                + docs/billing_invoices_gate_review_2026-08-08.md (Q1-Q6).
-- Rollback: 10_billing_invoices.down.sql (same directory).
--
-- The ninth roadmap §14 un-deferral: a real, org-scoped, MATTER-scoped
-- invoice METADATA table (read path only). D-11 is STRUCTURAL here: the
-- table carries invoice metadata only — NO card/payment columns of any
-- kind (no card_token, no payment_method, no billing_address, no
-- payer-identity beyond the assigned matter) — raw PAN/CVV can never
-- touch our servers, logs, or audit (PCI via Paymob-hosted tokenization
-- is a future, separate, owner-approved integration spec; no live payment
-- in MVP, fake-gateway pattern). RLS grants a row iff the reader is an
-- active member of the invoice's organization AND is assigned (client or
-- attorney) on the invoice's matter (matrix §4 — invoices are matter
-- content, the documents row's "restricted matter or its
-- documents/messages" reading extended to invoices; an org role alone
-- never grants invoice access). Requires the APPLIED matters table
-- (04_matters.sql) as its FK target + assignment source of truth (the
-- documents 05 pattern). No INSERT/UPDATE/DELETE grant (Q5): there is no
-- write path — invoices are created by a future, owner-approved billing
-- slice; D-11 tax rules are never hardcoded (INSTRUCTIONS §4.4 — the
-- status CHECK is deliberately minimal).

begin;

-- 10.1 billing_invoices — org-scoped, matter-scoped, metadata-only (D-BI1)
create table public.billing_invoices (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  matter_id       uuid not null references public.matters (id) on delete cascade,
  invoice_number  text not null,       -- generic — "INV-2026-0001" style; never PII by convention
  amount_cents    bigint not null default 0
    check (amount_cents >= 0),         -- client Invoice.amountCents (D-BI5); CHECK = mapping contract
  currency        text not null default 'EGP',  -- D-11 demo posture; no FX machinery
  status          text not null default 'issued'
    check (status in ('issued', 'paid')),       -- deliberately minimal (D-11: no tax/lifecycle machinery)
  issued_at       timestamptz not null default now(),
  due_at          timestamptz not null,
  description     text not null default ''      -- generic demo copy; never PII by convention
);

-- The two read shapes: the org-scoped list read + the per-matter lookup
-- (the FK join and the invoices battery both use matter_id).
create index billing_invoices_org on public.billing_invoices (organization_id);
create index billing_invoices_matter on public.billing_invoices (matter_id);

-- RLS on (default deny: with no policy, all access is denied).
alter table public.billing_invoices enable row level security;

-- Default-deny baseline: strip the hosting default grants (the 01 pattern).
revoke all on public.billing_invoices from anon, authenticated;

-- Narrow direct SELECT grant per Q5 (row-scoped reads only; there is no
-- write path in this slice). Grants alone do nothing without policies;
-- the policy follows in policies/invoices.sql.
grant select on public.billing_invoices to authenticated;

commit;
