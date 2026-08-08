# Plan: Real Billing Invoices (Read-Metadata) Data Path — the §14 billing un-deferral (2026-08-08)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> §14 **billing** path — the last plannable deferred path (AI stays
> owner-blocked on D-07/D-08 + no scope), mirroring the seven read slices
> (matters / documents / message_threads / storage / audit / realtime read
> / realtime push — plans + evidence in `docs/`, all SHIPPED 2026-08-07/08)
> and the storage slice's **NEW-surface** precedent (D-STR7). **Docs-only
> planning — zero dev-project effect**: nothing here or in its TASKS
> applies anything to the dev Supabase project; every external step stays
> behind the owner's dated approval (INSTRUCTIONS.md §2.1/§5 hard gates).
>
> **Gate state (why this slice is now plannable):** the billing un-block
> gate is **MET** — owner **D-11 DECIDED 2026-08-08**
> (`docs/d11_billing_payments_decision_2026-08-08.md`): **Paymob** for any
> future real integration, **no live payment in MVP** (the **fake-gateway
> pattern** — synthetic invoices, no real charges), PCI via Paymob-hosted
> tokenization (SAQ-A-like; raw PAN/CVV never touches our servers/logs/
> audit), tax out of scope; D-04 residency confirmed. The §14 blanket
> precondition is proven by precedent (P0 RATIFIED + policy battery +
> seven full green chains). The `matters` + `documents` + `message_threads`
> tables are **applied on the dev project** and are this slice's FK targets
> + assignment source of truth. **Branch: `feat/billing-invoices-read`.**
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Move the **invoice read path** from "nothing exists" to a real,
org-scoped, **matter-scoped** metadata surface with RLS — **without any
payment/card data by construction** (D-11: the table carries invoice
metadata only; raw PAN/CVV never touches our servers). "Done" = an
active member reads exactly the **invoice metadata** for the matters they
are assigned to (client or attorney) via a `public.billing_invoices`
table through PostgREST; every other read — org-role-alone, cross-org,
unassigned, unauthenticated, `platform_owner_admin` — is denied and
policy-tested; the env-less demo and the whole test suite run on a new
dev fake generating **synthetic invoices** (no real charges). **Metadata
read-only; no write path, no payment integration, no tax calculation**
(D-11). The matrix gains a §4 "View an invoice (metadata)" row (the
documents pattern) with the `platform_owner_admin` deny always.

## 2. Gap (verified)

| Claim | Verified fact |
|---|---|
| Billing is the last plannable §14 path | matters/documents/messages/storage/audit/realtime-read/realtime-push/send-message all SHIPPED; the deferred list narrows to billing + AI (AI owner-blocked) — roadmap §13/§14 tails; reconciliation `docs/send_message_rpc_plan_2026-08-08.md` §A.1 (D-11) |
| Billing gate met at the decision level | D-11 DECIDED 2026-08-08: provider (Paymob), MVP posture (no live payment — fake gateway), PCI (hosted tokenization, no card data server-side), tax (out of scope), D-04 residency — `docs/d11_billing_payments_decision_2026-08-08.md` |
| No billing data model / RPC / matrix rows exist | repo scan: zero billing rows in `docs/permission_matrix.md`, zero billing RPCs in `supabase/rpc/`, zero billing tables; the spec's `billing_invoices` screen was "Maybe \| Defer real payment (D-09)" — now plannable |
| FK targets + assignment source are applied | `matters` (4 demo matters, org `ef43087b-…`) + `documents` + `message_threads` applied; the documents `exists`-subquery RLS pattern is the precedent |
| Harness state | 11 tables / 11 RLS / 10 public + 1 storage policies / publication exactly messages / 19 EXECUTE RPCs / batteries 01–10 (verified 2026-08-08) |

## 3. Design decisions (D-BI1…D-BI6 — ratified by autonomy 2026-08-08, one-line reasoning each; the T1 RLS-gate review answers Q1–Q6 on these)

- **D-BI1 — `public.billing_invoices` (org-scoped + matter-scoped,
  metadata-only):** `id` (uuid PK), `organization_id` (FK → `organizations`
  cascade), `matter_id` (FK → the applied `matters` cascade — the
  documents pattern), `invoice_number` (text, generic — e.g. "INV-2026-0001"),
  `amount_cents` (bigint, CHECK `>= 0`), `currency` (text default `'EGP'`),
  `status` (text CHECK `in ('issued','paid')` — no tax/lifecycle machinery),
  `issued_at` + `due_at` (timestamptz), `description` (text — generic
  demo copy, never PII). **No card/payment columns of any kind** — the
  D-11 PCI constraint made structural (raw PAN/CVV never touches our
  servers). *Reason: metadata-only read surface mirroring documents; the
  D-11 no-live-payment posture means the table must not even be able to
  hold payment data.*
- **D-BI2 — RLS `invoices_select_assigned` (the documents gate):**
  `is_active_member(organization_id)` AND `exists` on the matter row with
  the **org-mismatch clause** `m.organization_id = invoices.organization_id`
  AND assigned client/attorney = `auth.uid()`. *Reason: the documents
  pattern is the proven, battery-tested assignment gate; invoices are
  matter-scoped documents.*
- **D-BI3 — matrix §4 row (dated addendum, T6):** "View an invoice
  (metadata)" — client/attorney **SHIP** behind `invoices_select_assigned`;
  partner / `compliance_officer` "deny unless separately assigned" stay
  **ungranted**; `platform_owner_admin` **deny always**. *Reason: the
  documents row's exact cell split, extended to invoices.*
- **D-BI4 — fake-gateway pattern (D-11):** env-less runs + the whole test
  suite use a new `FakeBillingGateway` generating **synthetic invoices**
  (deterministic, no real charges); the env-gated `SupabaseBillingGateway`
  reads the applied table. No write path. *Reason: D-11 "no live payment
  in MVP" — the fake is the product posture, not a stopgap.*
- **D-BI5 — client surface (NEW, the storage D-STR7 precedent):** an
  `Invoice` VO (metadata-only: id, matterRef, invoiceNumber, amountCents,
  currency, status, issuedAt, dueAt) + `BillingGateway.fetchInvoices()`
  (all assigned; the matter section filters client-side — the documents
  pattern) + fake + a **matter-invoices section** on the matter details
  screen (mirroring `matter_documents_section` / the storage
  `matter_files_section`) + l10n ×3 (EN/AR/TR). *Reason: the smallest
  delta that gives the invoice read a home; the matter-scoped section
  matches how documents/files already surface.*
- **D-BI6 — harness + battery:** `11_invoice_rls.sql` (fixtures: 4–6
  invoice rows referencing the six fixture matters in `00_fixtures.sql`;
  positives client-a/partner-a + the non-vacuous org-mismatch row + the
  CHECK rows + the matter-delete cascade) + `verify_policy_tests.sh`
  edits (file list, run loop, `--apply` order gaining `10_billing_invoices.sql`,
  pins **tables 11→12 / RLS 11→12 / public policies 10→11**, UUID + FAIL
  scans, header comments, selftest glob). *Reason: the same lockstep
  discipline every slice proved.*
- **Demo seed (T5):** 4 invoice rows referencing the **applied demo
  matter ids** (`a6715e17-…`, `d155dc92-…`, `4f4a935f-…`, `575391b6-…`,
  org `ef43087b-…`) with generic numbers/copy; the partner reads the 3 it
  is assigned; the family invoice stays client-only (0 for the partner —
  the assignment gate firing live).

## 4. Layers touched

- **Server (rehearsal → dated apply):** `supabase/migrations/10_billing_invoices.sql`
  + `.down.sql` · `supabase/policies/invoices.sql` · `supabase/tests/11_invoice_rls.sql`
  · `supabase/tests/00_fixtures.sql` · `scripts/verify_policy_tests.sh` ·
  `supabase/README.md`.
- **Domain:** `lib/features/billing/domain/invoice.dart` (NEW VO) +
  `invoice_gateway.dart` (NEW) — mirror the storage feature's shape.
- **Data:** `lib/data/billing/supabase_billing_api.dart` + `_impl.dart` +
  `supabase_billing_gateway.dart` (NEW, the documents seam pattern —
  table SELECT + typed failure kinds) + `lib/features/billing/data/fake_billing_gateway.dart`
  (NEW).
- **Presentation:** a matter-invoices section (mirror the storage
  `matter_files_section`) + cubit/state if the section needs one (the
  documents section pattern) + l10n ×3.
- **DI:** `lib/app/service_locator.dart` — `BillingGateway` registration +
  the env-gated flip behind `env.isConfigured` + `service_locator_test`
  pins.

## 5. New/changed files

| File | Layer | Responsibility |
|---|---|---|
| `supabase/migrations/10_billing_invoices.sql` + `.down.sql` | server | `billing_invoices` table (D-BI1) + grants; clean inverse |
| `supabase/policies/invoices.sql` | server | `invoices_select_assigned` (D-BI2) |
| `supabase/tests/11_invoice_rls.sql` + `00_fixtures.sql` | server | the battery + invoice fixtures (D-BI6) |
| `scripts/verify_policy_tests.sh` + `supabase/README.md` | harness | 11 wired; pins 12/12/11-public; apply order |
| `lib/features/billing/domain/invoice.dart` + `invoice_gateway.dart` | domain | the `Invoice` VO + `BillingGateway` (D-BI5) |
| `lib/features/billing/data/fake_billing_gateway.dart` | domain | synthetic invoices, deterministic (D-BI4) |
| `lib/data/billing/supabase_billing_api.dart` + `_impl.dart` + `supabase_billing_gateway.dart` | data | env-gated real read + failure mapping (the documents seam) |
| `lib/features/billing/presentation/…` (section + cubit/state) | presentation | the matter-invoices surface + l10n ×3 |
| `lib/app/service_locator.dart` + `test/service_locator_test.dart` | DI | `BillingGateway` registration + flip pins |
| `docs/billing_invoices_gate_review_2026-08-08.md` (T1) + `docs/billing_invoices_rehearsal_evidence_r1_2026-08-08.md` (T4) + `docs/billing_invoices_apply_approval_2026-08-08.md` (T5) + `docs/billing_invoices_apply_execution_2026-08-08.md` (T5) + `docs/billing_invoices_real_data_completion_evidence_2026-08-08.md` (T8) | docs | the per-feature gate chain |
| `docs/permission_matrix.md` | docs | §4 addendum (T6) |

## 6. State shape / data flow

- **State (mirror the documents section):** `InvoiceListState` with
  `ViewLoading` / `ViewSuccess<List<Invoice>>` / `ViewEmpty` / `ViewError`
  — loaded once per matter-details open, filtered by the matter id
  client-side (the documents section pattern).
- **Data flow:** matter-details opens → the invoices section's cubit
  `load()` → `BillingGateway.fetchInvoices()` → (env-less) the fake's
  synthetic rows | (configured) `SupabaseBillingGateway` → the impl's
  PostgREST SELECT (RLS-scoped by `invoices_select_assigned`) → raw map
  rows → the `Invoice` VO (`matterRef` from the embedded `matters(title)`
  select, the D-MSR4 pattern, raw-id fallback) → `ViewSuccess`. Failure
  kinds map to `AppError` codes (`invoice_read_denied` / `_unavailable` /
  `_failed`) — the documents gateway convention. No write path anywhere.

## 7. Dependencies

**None.** No new package (PostgREST via the existing `supabase_flutter`;
the l10n ×3 arbs are generated). Paymob is **not** integrated in this
slice (D-11 — a separate, future, owner-approved integration spec).

## 8. Testing strategy

- **Battery (`11_invoice_rls.sql`):** fixtures + positives (client-a,
  partner-a), the non-vacuous **org-mismatch** deny (an assigned reader
  demonstrably reads org-a invoices in a prior check), org-role-alone /
  cross-org / suspended / owner / anon deny rows, the `amount_cents >= 0`
  + `status` CHECK rows, the matter-delete cascade — the P0C battery
  pattern.
- **Unit:** impl SELECT-call pin + failure mapping (denied/unavailable/
  unknown) · gateway row→VO mapping + matterRef fallback + malformed-row
  loud failure · fake determinism (synthetic invoices, no real charges).
- **Widget:** the matter-invoices section (empty / loaded / error) +
  l10n pins.
- **DI:** `service_locator_test` — fake in env-less, flip to
  `SupabaseBillingGateway` behind the anon key (the documents/storage pin
  pattern).
- **Skipped (recorded):** no live Paymob round-trip (D-11 — no payment
  integration), no configured-build device round-trip until a `.env`
  build exists (D-45.1 convention).

## 9. Acceptance criteria

| # | Criterion | Evidence |
|---|---|---|
| 1 | `billing_invoices` table + `invoices_select_assigned` rehearsed (battery green on the committed files) + applied on the dev project with rollback pairing | T2/T4/T5 records |
| 2 | Matrix §4 "View an invoice (metadata)" addendum precedes the client surface | T6 < T7 |
| 3 | Env-gated `SupabaseBillingGateway` swap; fake synthetic + untouched VO/presentation conventions; all tests on the fake | T7 tests + DI pins |
| 4 | Read-only: no write path, no payment integration, no tax calculation (D-11) | T7 surface + §5 exclusions |
| 5 | README count lockstep + roadmap §14 billing flip (SHIPPED, last un-deferral) + ledger PASS on the committed state | T8 |
| 6 | Full gate on the client slice: format · analyze · suite · ledger | T7/T8 |

## 10. Risks / open questions

- **The invoice row's `matterRef` needs the matter title** — the embedded
  `matters(title)` join (the D-MSR4 pattern) is used; the policy
  guarantees the reader passes the matter gate so the embed resolves;
  raw-id fallback recorded. (Precedent-proven, low risk.)
- **Status semantics** ("issued"/"paid") are deliberately minimal — no
  tax/VAT/lifecycle machinery (D-11); a real product adds them behind a
  new decision.
- **The partner/compliance "deny unless separately assigned" cells stay
  ungranted** (the documents precedent) — a firm-wide invoices view for
  partners is a recorded follow-up, not this slice.
- **AI stays deferred** (D-07/D-08 + no scope) — with this slice, billing
  becomes the **ninth** un-deferral and AI the only remaining §14 path.

---

# Tasks: Real Billing Invoices (Read-Metadata) Data Path

Branch: `feat/billing-invoices-read`

- [ ] **1. RLS-gate design review (Q1–Q6)** — touches:
  `docs/billing_invoices_gate_review_2026-08-08.md` — the D-BI1 table
  shape (metadata-only, no card columns — the D-11 PCI constraint made
  structural), the D-BI2 `invoices_select_assigned` gate (the documents
  `exists`-subquery + org-mismatch invariant), the CHECK rows, the
  rollback pairing, the harness re-scope (pins 12/12/11-public) — done
  when: Q1–Q6 answered, D-BI1..D-BI6 ratified, gated and committed as
  docs(billing).
- [ ] **2. Rehearsal-ready artifacts (NOT applied)** — touches:
  `supabase/migrations/10_billing_invoices.sql` + `.down.sql` +
  `supabase/policies/invoices.sql` — done when: clean apply unit +
  inverse, column list consistent with D-BI1, gated and committed.
- [ ] **3. Battery + harness** — touches: `supabase/tests/11_invoice_rls.sql`
  (fixtures referencing the six fixture matter ids in `00_fixtures.sql` +
  the non-vacuous org-mismatch row + CHECK rows + cascade row) +
  `scripts/verify_policy_tests.sh` (file list, run loop, `--apply` order
  gaining 10, pins tables 11→12 / RLS 11→12 / public policies 10→11, UUID
  + FAIL scans, header comments) — done when: static `--check` green,
  selftest 6/6, committed.
- [x] **4. Ephemeral rehearsal (r1)** — touches:
  `docs/billing_invoices_rehearsal_evidence_r1_2026-08-08.md` — done
  when: the genuine cycle (`--apply` + battery on the Docker scratch
  stack) runs green and the record flips to PASSED, committed as
  docs(billing). **DONE 2026-08-08** — genuinely executed on the Docker
  scratch stack: `--apply` **42/0/0** (incl. `10_billing_invoices` +
  `policies/invoices`), battery **78/0/0 — RESULT: PASS** (1a 12 tables /
  12 RLS, 1e 11 policies, 1f `billing_invoices` ninth-un-deferral pin 1),
  all eleven battery files green incl. `11_invoice_rls.sql`, selftest
  6/6. Record flipped to PASSED; nothing applied.
- [ ] **5. Dated apply-approval → apply** — touches: dev project +
  `docs/billing_invoices_apply_approval_2026-08-08.md` + execution record
  — done when: the owner's dated sign-off, apply executed (baseline probe,
  `10_billing_invoices` + policy + demo seed referencing the applied demo
  matter ids, rollback pairing), execution evidence APPLIED. **Owner-gated.**
- [ ] **6. Dated matrix addendum** — touches: `docs/permission_matrix.md`
  §4 "View an invoice (metadata)" row (client/attorney SHIP behind
  `invoices_select_assigned`; partner/compliance ungranted;
  `platform_owner_admin` deny always) — done when: committed **before**
  the client surface (T7), ledger green.
- [ ] **7. Client swap (env-gated, NEW surface)** — touches:
  `Invoice` VO + `BillingGateway` + fake + `supabase_billing_api`/impl/
  gateway + the matter-invoices section + l10n ×3 + service_locator flip
  + tests (mapping / matterRef-fallback / failure-mapping / DI pins / fake
  determinism) — done when: format clean · analyze clean · suite green ·
  ledger PASS.
- [ ] **8. Lockstep + evidence + close** — touches: README test count,
  roadmap §14 billing flip (**ninth** per-feature un-deferral) + §13
  gate-table row + plan task rows, completion evidence
  `docs/billing_invoices_real_data_completion_evidence_2026-08-08.md`,
  dated close decision — done when: all docs sweep green, full gate
  re-run, close decision recorded, committed as docs(billing).
