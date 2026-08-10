# LegalHub — Paymob Integration Spec (planning only, no live payment) — DRAFT (2026-08-11)

> **Record type:** Spec-lite scope note un-blocked for **planning** by
> `docs/d11_billing_payments_decision_2026-08-08.md` §4 ("D-11 unblocks a
> **Paymob integration spec** — a separate, owner-approved slice; not
> MVP"). **Status: DRAFT — NOT approved, NOT scheduled.** This document
> plans only: **no code, no live keys, no real charges, no live-system
> effect.** The demo keeps the fake-gateway pattern ("no live payment in
> MVP"); this spec is the artifact that makes the future slice
> decision-ready. **Planning owner:** Project Owner.

---

## 1. Provenance

- D-11 (`docs/d11_billing_payments_decision_2026-08-08.md`) decided the
  provider (**Paymob** — Egyptian gateway: cards, wallets, online
  payments; sandbox available), the PCI posture (**Paymob-hosted
  tokenization**, SAQ-A-like target, **no PCI claim for the demo**), and
  tax (**out of scope, never hardcoded**). It explicitly **un-blocked
  planning** while keeping MVP implementation out.
- The §14 billing row is already partially un-deferred as **billing
  invoices read** (SHIPPED 2026-08-08, the ninth per-feature un-deferral):
  invoice metadata rows + RLS + battery + rehearsal r1 (78/0/0) + dated
  apply + matrix §4 addendum ("View an invoice (metadata)" row, **no
  payment surface**) + env-gated client swap (Invoice VO + `BillingGateway`
  + fake + supabase seam/impl/gateway + matter-invoices section, D-BI5).
- This spec extends that surface **in planning only**: the natural
  integration point is the existing invoice read surface + the
  `BillingGateway` seam — a future "pay this invoice" action would add a
  payment seam, never a change to the read contract.
- The nine shipped un-deferral slices established the per-feature pipeline
  this spec plans against: RLS-gate review → artifacts (migration + RLS)
  → battery + harness (static `--check`) → ephemeral rehearsal r1
  (genuinely executed) → dated apply-approval → apply (dev project) →
  dated matrix §4/§6 addendum → env-gated client swap.

## 2. Spec basis (verified — no new authority claimed)

| Source | What it authorizes / constrains |
|---|---|
| `docs/d11_billing_payments_decision_2026-08-08.md` §1 | Paymob provider; hosted tokenization; raw PAN/CVV never touches our servers, logs, or audit; SAQ-A-like target; no PCI claim for the demo |
| D-11 §1 MVP row | **No live payment integration** in the portfolio/demo MVP — this spec is planning only |
| D-11 §1 Tax row | No tax/VAT calculation in MVP; real tax rules deferred to a real product, **never hardcoded** (INSTRUCTIONS §1.2/§4.4) |
| D-11 §2 | Supabase stays West Europe (London); Paymob processes on its own Egyptian infrastructure; synthetic demo: no cross-border constraints; real product: law 151/2020 + transfer rules deferred |
| `docs/legalhub_specification.md` §6 billing rows | Invoice rows are metadata-only; **no payment surface** is enumerated — the pay action is a NEW surface, added only by this (future) approved slice |
| `docs/permission_matrix.md` §4 "View an invoice (metadata)" row | Read posture only; payment initiation is a new row when/if the slice runs |
| `docs/features_roadmap_2026-08-03.md` §14 | Billing row keeps its §14-deferred status as an implementation; D-11 met the un-block gate for planning |

## 3. Proposed decisions (for owner ratification, when the slice is approved)

| ID | Question | Proposed decision |
|---|---|---|
| D-P1 | Integration model | **Paymob-hosted checkout** (SDK/iframe/redirect): card data goes directly to Paymob; our servers see only the payment token/status — never PAN/CVV (D-11 PCI posture) |
| D-P2 | Currency scope | **EGP only** for v1 of the future slice (Egyptian market per D-11); multi-currency is out |
| D-P3 | Payment methods | **Cards + wallets** per D-11's provider scope; "online payments" (Paymob's bank-installment/online surface) deferred — decisions per method stay out of the demo |
| D-P4 | Sandbox posture | Sandbox keys live **only** in the env-gated dev configuration (`env.isConfigured`), never in `lib/` or committed files — same posture as the existing Supabase dev-project keys |
| D-P5 | Verification | Paymob **webhook with signature verification** is the only authoritative status source; the client never trusts its own redirect return (mirrors the server-authoritative posture of the existing RPCs) |
| D-P6 | Idempotency | Payment **initiation is idempotent** (one pending payment per invoice); retries reuse the pending token — never double-charge |
| D-P7 | Audit | Every payment outcome (initiated / succeeded / failed / expired / refunded) lands in the **audit trail** (the §8 redacted-metadata discipline already applied to every shipped slice) |

## 4. Scope (planning boundary)

**In scope of this spec:** the checkout flow design (§5), the
`BillingGateway`-adjacent payment seam shape (a future
`PaymentGateway` — `initiate`/`verifyStatus` returning synthetic VOs,
fake-gateway pattern for demo), the sandbox test plan (§6), and the
T1–T8 gate sequence (§7).

**Explicitly out (unchanged by D-11):** live Paymob keys, real charges,
any card-data collection or storage, PCI/SAQ claims, tax/VAT
calculation, refunds/chargebacks, cross-border rules (law 151/2020),
multi-currency, and any change to the shipped invoice-read surface.

## 5. Checkout flow (the future machine, planned)

1. **Initiate** — user taps "Pay invoice" on a matter-invoices row (the
   D-BI5 surface). Client calls the payment seam with the invoice id →
   `PendingPayment` (synthetic reference, idempotent per D-P6).
2. **Redirect** — client opens Paymob hosted checkout (SDK/iframe/
   redirect) with the sandbox public token; card/wallet data entry
   happens entirely on Paymob's surface (D-P1).
3. **Return** — Paymob redirects back with the payment token; the client
   treats this as **informational only** (D-P5) and shows a pending state.
4. **Verify** — the server-side webhook (signature-verified) marks the
   payment succeeded/failed/expired; the client's status poll or the
   realtime subscription (the shipped `messages` publication pattern)
   reflects it.
5. **Audit** — the terminal outcome is recorded as a redacted audit entry
   (D-P7); the invoice row shows paid/overdue metadata only.

**Demo posture:** with the fake gateway, steps 2–4 are synthetic
(no network); the flow renders identically and the same audit/status
language is used — "no live payment copy" stays the rule everywhere.

## 6. Sandbox test plan (when the slice is approved and rehearsed)

| Scenario | Expectation |
|---|---|
| Success (Paymob sandbox test card) | Webhook → paid; audit row; invoice metadata updates |
| Declined card | Webhook → failed; invoice stays open; retry allowed (new token) |
| Cancel at checkout | No webhook outcome; pending expires; idempotency guard holds |
| Timeout / no return | Status poll falls back to webhook truth; no stuck pending |
| Bad webhook signature | Rejected; no state change; logged (non-sensitive) |
| Duplicate initiate | Same pending payment returned; no second charge (D-P6) |
| Non-owner / partner attempt | Denied — the payment initiate is gated the same way as every
  owner/partner RPC (permission matrix discipline) |

Rehearsal shape mirrors the nine shipped slices: ephemeral stack →
`--apply` + battery on a scratch project → dated r1 evidence → dated
apply-approval → dev-project apply → matrix §4/§6 addenda → env-gated
client swap, every step recorded.

## 7. Gate sequence (T1–T8, the established per-feature discipline)

1. RLS-gate / mechanism review (webhook verification, idempotency,
   audit-write path) — dated review note
2. Artifacts: `supabase/migrations/NN_payments.sql` (+ `.down`) + any
   policy/webhook-surface change — rehearsal-ready
3. Policy battery + harness wiring — static `--check` green
4. Ephemeral rehearsal r1 — genuinely executed, dated evidence
5. Dated apply-approval (owner) — like every prior slice
6. Apply to the dev project — per-step output captured
7. Dated permission-matrix §4 + applied-surface §6 addenda
8. Env-gated client swap (payment seam behind `env.isConfigured`; fake
   for demo runs) + tests + full gate stack

**This spec authorizes nothing beyond planning** — steps 1–8 run only
when the owner approves the slice, on top of this ratified spec.

## 8. Open questions for the owner (decision-ready)

- **Trigger surface:** pay CTA on the matter-invoices rows (D-BI5), a
  dedicated billing screen, or both? (This spec assumes the invoice row.)
- **Status surface:** is the paid/overdue state needed on the invoice row
  in v1, or is a payment-status line enough?
- **Wallets v1:** include Paymob wallets in the first approved slice, or
  cards-only (D-P3 default: both, but owner can trim)?
- **Refunds:** explicitly out of scope, or planned as a separate future
  slice now?

## 9. Ledger

- DRAFTED 2026-08-11 (planning only — the D-11 un-block, §4); no code, no
  live-system effect, nothing committed beyond this doc. Status remains
  DRAFT until the owner ratifies §3 and schedules the slice.
