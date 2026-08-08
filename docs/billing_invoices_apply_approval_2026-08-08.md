# LegalHub — Billing Invoices Apply Approval Decision Record (2026-08-08)

> **Record type:** The dated decision record that closes the apply-approval
> gate for the billing-invoices read-metadata slice (plan
> `docs/billing_invoices_real_data_plan_2026-08-08.md` T5), per the P2/P3
> discipline (`docs/storage_apply_approval_2026-08-08.md` is the immediate
> precedent shape; `docs/documents_apply_approval_2026-08-07.md` and
> `docs/matters_apply_approval_2026-08-07.md` are the originals). This
> record, **once signed in §6**, is the owner's explicit authorization to
> apply the reviewed + rehearsed slice to the shared dev project, with the
> rollback pairing standing by.
>
> **Status: DRAFT — READY FOR THE OWNER'S DATED SIGN-OFF (2026-08-08).**
> All decision-level preconditions are MET: D-11 DECIDED (billing
> un-blocked), the RLS-gate review passed, the artifacts are
> rehearsal-ready and committed, the battery is static-green (339/0/0),
> and — unlike the storage record at its draft time — **the r1 rehearsal
> is genuinely PASSED and its evidence is in the repo**
> (`docs/billing_invoices_rehearsal_evidence_r1_2026-08-08.md`, **78/0/0
> RESULT: PASS**, executed on the Docker scratch stack). The single
> remaining gate is the owner's dated signature in §6; the §4 execution
> conditions + §5 exclusions bind the apply once signed. **Nothing has
> been applied to the dev project; no push.**
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/billing_invoices_real_data_plan_2026-08-08.md`
> (T5) · `docs/billing_invoices_gate_review_2026-08-08.md` (Q1–Q6, §6
> rollback) · `docs/billing_invoices_rehearsal_evidence_r1_2026-08-08.md`
> (**r1 PASSED — 78/0/0**) · `docs/d11_billing_payments_decision_2026-08-08.md`
> (D-11 — Paymob provider, **no live payment in MVP**, PCI via hosted
> tokenization, tax out of scope) · `docs/matters_apply_execution_2026-08-07.md`
> (the applied demo matter ids + demo accounts this seed references) ·
> `docs/storage_apply_execution_2026-08-08.md` (the current dev-project
> baseline this apply extends) · `docs/rollback_plan.md` §1/§5 ·
> `docs/permission_matrix.md` §4/§7 · `supabase/README.md` ·
> `INSTRUCTIONS.md` §2.1/§3/§4.4/§5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| §14 un-deferral gate (P0 closes + policy tests) | `docs/p0_closure_scope_2026-08-05.md` RATIFIED + `scripts/verify_policy_tests.sh` + the **seven read-slice precedents SHIPPED + applied** (the FK targets + assignment source) | ✅ Met — P0 RATIFIED 2026-08-05 · seven precedents SHIPPED + applied 2026-08-07/08 |
| **D-11 billing decision** (the previous un-block blocker) | `docs/d11_billing_payments_decision_2026-08-08.md` (`461cf51`) | ✅ **DECIDED 2026-08-08** — Paymob for any future real integration · **no live payment in MVP** (fake-gateway pattern) · PCI via Paymob-hosted tokenization · tax out of scope · D-04 residency confirmed |
| RLS-gate design review | `docs/billing_invoices_gate_review_2026-08-08.md` (`7d0ab93`) | ✅ Passed 2026-08-08 (Q1–Q6: metadata-only table — D-11 PCI structural; the documents exists-subquery gate verbatim + org-mismatch invariant; CHECK rows; rollback pairing; harness re-scope) |
| Schema artifacts (rehearsal-ready) | `supabase/migrations/10_billing_invoices.sql` + `10_billing_invoices.down.sql` (`844a00e`) | ✅ Committed — NOT applied |
| Policy artifact | `supabase/policies/invoices.sql` (`844a00e`) | ✅ Committed — NOT applied |
| Policy battery + harness | `supabase/tests/11_invoice_rls.sql`, `00_fixtures.sql`, `scripts/verify_policy_tests.sh` (`9a1310b`) | ✅ Committed; static `--check` PASS **339/0/0** |
| **Ephemeral rehearsal (r1)** | `docs/billing_invoices_rehearsal_evidence_r1_2026-08-08.md` (`da4fa97`) | ✅ **PASSED 2026-08-08 — genuinely executed** on the Docker scratch stack: `--apply` **42/0/0** (incl. `10_billing_invoices` + `policies/invoices`) · battery **78/0/0 — RESULT: PASS** · all eleven battery files green incl. `11_invoice_rls.sql` · selftest 6/6 |
| **Apply approval (this record)** | this document | ⏳ **DRAFT — ready for the owner's dated sign-off (§6)**; nothing applied until signed |
| Apply execution (dev project) | `docs/billing_invoices_apply_execution_2026-08-08.md` | ⏳ Held — pending the §6 signature; the read-only baseline probe runs at execution time |

## 2. Gate criteria — what the r1 rehearsal proved

Against the ephemeral project built from the committed files (r1, **run
and PASSED — evidence `docs/billing_invoices_rehearsal_evidence_r1_2026-08-08.md`**):

| # | Criterion | r1 evidence (captured) | Verdict |
|---|---|---|---|
| 1 | `--apply` builds the slice cleanly (01, 02, 04, 05, 06, 07, 08, 09, **10**, policies, RPCs) — `10_billing_invoices.sql` + `policies/invoices.sql` applied on top of the already-applied `matters` + `documents` + `message_threads` + `files` + `messages` tables | rehearsal §4: **`--apply` 42 passed / 0 failures** | ✅ PASSED |
| 2 | Structural pins hold on the applied posture | rehearsal §4: **1a twelve tables / twelve RLS** · **1e exactly eleven public policies** (12 minus the D-SM3 drop) · 1f **`billing_invoices` present (ninth un-deferral) 1** · billing SELECT grant + anon absence · 1g storage unchanged (bucket 1, storage policy 1) | ✅ PASSED |
| 3 | 00/01/02/03/04/05/06/07/08/09/10 regression batteries unaffected | rehearsal §4: fixtures (6 invoices) + single-account bound + all ten prior batteries `— all checks passed` | ✅ PASSED |
| 4 | `invoices_select_assigned` enforces the matrix §4 invoice contract | rehearsal §4: client-a 2 · partner-a 3 · orphan 1 · org-role-alone 0 · **org-mismatch 0 (non-vacuous — D-BI2)** · cross-org 0 · suspended 0 (the `is_active_member` arm) · owner 0 · anon denied (no grant) | ✅ PASSED |
| 5 | Mapping contract + teardown safety | rehearsal §4: `amount_cents` CHECK rejects a negative amount · `status` CHECK rejects an unmapped status (D-11 minimal set) · matter-delete cascades its invoice rows (FK on delete cascade) | ✅ PASSED |

**Verdict: PASSED 2026-08-08** — all five criteria are evidenced by the
genuinely-executed run (78/0/0), so the apply gate is open at the
decision level; only the owner's §6 signature remains.

## 3. Decision (scope this record authorizes — once signed)

**APPLY APPROVED (on signature):** apply the reviewed + rehearsed billing
slice to the shared dev project (`eutmvevpskerzpqmwplv`, `eu-central-1`) in
this order:

1. `supabase/migrations/10_billing_invoices.sql` — the `public.billing_invoices`
   **metadata-only** table (D-BI1 — **no card/payment columns of any
   kind**, the D-11 PCI constraint structural: raw PAN/CVV can never touch
   our servers, logs, or audit): `id` uuid PK · `organization_id` FK →
   `organizations` cascade · `matter_id` FK → the **applied** `matters`
   cascade · `invoice_number` (generic — never PII by convention) ·
   `amount_cents` with the client-`Invoice.amountCents` CHECK (`>= 0`) ·
   `currency default 'EGP'` · `status` with the CHECK
   (`in ('issued','paid')` — deliberately minimal, D-11: no tax/lifecycle
   machinery, INSTRUCTIONS §4.4) · `issued_at` + `due_at` + `description`
   (generic demo copy) · org + matter indexes · RLS enable · default-deny
   revoke · narrow `select` grant to `authenticated` only (Q5).
2. `supabase/policies/invoices.sql` — `invoices_select_assigned`
   (`is_active_member(organization_id)` AND exists on the matter row with
   the **org-mismatch clause** `m.organization_id =
   billing_invoices.organization_id` AND assigned client/attorney =
   `auth.uid()` — the documents gate verbatim, D-BI2).
3. **Demo seed** — a small set of demo invoice rows (4) referencing the
   **applied demo matter ids** on the dev project (resolved at apply time
   from the dev project's own `matters` rows — never guessed, never the
   rehearsal project's synthetic `40000000-…`/`a0000000-…` ids; the four
   applied demo matter ids recorded in
   `docs/matters_apply_execution_2026-08-07.md` §2.2 are `a6715e17-…`,
   `d155dc92-…`, `4f4a935f-…`, `575391b6-…`, org
   `ef43087b-adf4-4480-9bb2-28c26f46ec71`). Each seeded row carries the
   **matter's own org**, **generic invoice numbers/amounts/descriptions
   only** (D-11 — synthetic amounts, no real charges; never real
   client/legal copy, no PII, no card data), and the **D-11 no-payment
   posture holds at seed time** (no payment columns exist to fill). The
   exact rows + ids are recorded in the execution record.

plus the post-apply verification (structural subset + demo reads as
assigned roles) per §4 condition 6, and the execution evidence record
(`docs/billing_invoices_apply_execution_2026-08-08.md`).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline probe (read-only):** confirm `public.billing_invoices`
   does not yet exist on the dev project, `matters` **does** exist with its
   four applied demo rows, the current `pg_policies` count is **10 public**
   (→ **11** after apply — the storage + realtime + send-message applies
   moved the baseline from the earlier records' figures; the probe reads
   the actual current state, verify-don't-guess), tables/RLS **11** (→
   **12**), storage policies **1** (unchanged — this slice adds no storage
   surface), publication exactly `public.messages` (unchanged), and the
   four demo matter ids resolve from the dev project's own rows — the up
   sequence runs against the same baseline the rehearsal proved.
2. **Verify, don't guess (demo seed):** matter ids come from the **dev
   project's own applied `matters` rows**; the seed never uses rehearsal
   synthetic ids, never touches non-demo matters, never uses real PII,
   real account identities, or any card/payment data (generic demo
   numbers/amounts/copy only, D-11), and every seeded row's
   `organization_id` equals its matter's org (the D-BI2 invariant applied
   at seed time).
3. **Rollback pairing standing by (rollback_plan §1/§5):**
   `10_billing_invoices.down.sql` (`drop table public.billing_invoices`)
   + a targeted delete of the seeded demo rows (+ `git revert` of the
   policy commit per the RLS-gate review §6 convention) is ready before
   step 1; **any** trigger condition (a matrix negative row starts
   passing, cross-tenant data visible, a demo row lands on a real
   matter/account, a non-generic invoice number/amount/description
   appears) = immediate revert, never fix-forward.
4. **Per-step verification:** after each of the three steps, probe the
   applied state (table exists → policy present → seed rows scoped
   correctly: right org, right matter, generic values) with the observed
   output pasted verbatim into the execution record.
5. **Post-apply smoke (dev project):** the structural subset the rehearsal
   proved — **12 tables / 12 RLS / 11 public policies** + the billing
   grant; then demo reads with role impersonation (`set local role
   authenticated` + `request.jwt.claims` via `supabase db query --linked`,
   the R1 pattern): the partner/attorney demo account (the **only** dev
   member, per the matters execution baseline) reads the invoices on its
   assigned demo matters (**3** of the 4 — the family matter is
   client-only); the assigned demo clients read **0** because they hold no
   dev membership rows — the assignment gate firing live, recorded as an
   honest expectation (the matters/documents/messages/storage smoke
   precedent), never as a defect.
6. **No scope beyond the slice:** no other table/RPC/policy change, no
   write path, **no payment integration of any kind** (Paymob is a
   separate, future, owner-approved integration spec — D-11), no tax
   calculation, no realtime, no production, no service-role key, no real
   client/legal/payment data.

## 5. What this approval does NOT authorize

- No other schema, policy, or RPC change beyond §3; **no write path** to
  billing invoices (the slice is read-only; any invoice creation surface
  is a future slice behind its own gate).
- **No payment integration** (no Paymob SDK/iframe/redirect, no charge
  capability — D-11 "no live payment in MVP"; the fake-gateway pattern is
  the product posture).
- No tax/VAT calculation or lifecycle machinery (D-11, INSTRUCTIONS §4.4).
- No change to the Flutter client (`lib/`) — the env-gated
  `SupabaseBillingGateway` swap + the new invoice surface is plan **T7**,
  a separate slice with its own gate.
- No battery run against the dev project (the harness hard-refuses the dev
  ref; the battery is ephemeral-only by design).
- No push, no production deployment, no service-role credentials, no real
  data beyond the demo seed of §3.
- The actual apply **execution** is a separate execution slice with its own
  evidence record; this record authorizes the apply decision only.

## 6. Owner sign-off

By signing below, the Project Owner authorizes the §3 apply against the
shared dev project (`eutmvevpskerzpqmwplv`), subject to the §4 execution
conditions and the §5 exclusions, with the rollback pairing standing by.
**Signature is valid now that the r1 rehearsal reports PASSED** (plan T4 —
`docs/billing_invoices_rehearsal_evidence_r1_2026-08-08.md` is **PASSED
2026-08-08**, 78/0/0, genuinely executed).

- **Project Owner:** github.com/mostafasayed118 — **date:** __________
  — **approval wording (the documents/messages/storage precedent):**
  "Apply approved — billing-invoices read slice (10_billing_invoices +
  policies/invoices + demo invoices referencing the applied demo matter
  ids), per this record §3–§5, with the §4 guardrails and rollback
  pairing."

> **Awaiting the owner's dated signature.** Once signed, the execution
> record (`docs/billing_invoices_apply_execution_2026-08-08.md`) captures
> the actual run per the §4 guardrails; on success, plan T6 (dated matrix
> §4 addendum) and T7 (client swap) follow.

## 7. Ledger

- This session: docs-only — **no `lib/`/`test/` change, no README-count
  change, no dev-project change**; `verify_ledger.sh` PASS 115; nothing
  pushed; branch `feat/billing-invoices-read` @ `da4fa97` (+ this commit).
- The record's status is ⏳ **DRAFT** until the §6 signature lands; the
  plan's T5 row stays `[ ]` owner-gated. The r1 gate (§2) is PASSED and
  evidenced — the apply is **ready for the owner's dated sign-off**.
