# LegalHub — Billing Invoices (Read-Metadata) Completion Verification & Evidence Record (2026-08-08)

> **Record type:** Slice T8 close-out evidence (plan
> `docs/billing_invoices_real_data_plan_2026-08-08.md`) — the **ninth §14
> per-feature un-deferral** (matters → documents → message_threads →
> storage → audit surfacing → individual messages/bodies → live delivery →
> the audited send path → **billing invoices read-metadata**), records
> exactly what was **verified** about the `billing_invoices` read path
> (server-side T1–T4 rehearsed, T5 apply **owner-approved and EXECUTED
> 2026-08-08** (`docs/billing_invoices_apply_execution_2026-08-08.md`);
> dated matrix §4 addendum T6; client swap `f116966`; all on
> `feat/billing-invoices-read`, no push) and exactly what is **still
> pending**, with no claim beyond what was actually run (INSTRUCTIONS.md
> §1.3 #5).
>
> **Status: SHIPPED 2026-08-08 — the full gate green on the committed
> branch state (format clean, analyze clean, suite 1080 runtime / README
> 1077 declaration, ledger PASS 115), and the T5 apply EXECUTED the same
> day (owner's dated §6 sign-off → tables/RLS 11→12, public policies
> 10→11, 4 demo invoices on the applied demo matters, smoke green).** The
> D-11 billing decision (Paymob for any real integration, **no live
> payment in MVP**) is honored structurally: the table is metadata-only by
> construction and the client surface carries no payment capability. The
> dated close decision is recorded in §9, mirroring the P0C / P3.1–P3.5 /
> matters / documents / messages / storage / audit / realtime read /
> realtime push / send-message close format.

---

## 1. What this record covers

The billing-invoices **read-metadata** path — the `billing_invoices`
table (D-BI1) + the `invoices_select_assigned` RLS policy (D-BI2) + the
policy battery (D-BI6) + the dated apply + the dated matrix §4 addendum +
the env-gated client swap (D-BI5) — delivered as plan T1–T8:

| Stage | Artifact | Commit |
|---|---|---|
| T1 — RLS-gate design review | `docs/billing_invoices_gate_review_2026-08-08.md` (Q1–Q6: single-layer PostgREST SELECT — pure metadata, no bytes → no storage layer; D-BI1 metadata-only table with the D-11 PCI constraint **structural**; D-BI2 = the documents exists-subquery gate verbatim with the load-bearing org-mismatch clause; no owner carve-out; select-only grant; read-only — no `write_audit` call sites) | `7d0ab93` |
| T2 — rehearsal-ready artifacts (NOT applied) | `supabase/migrations/10_billing_invoices.sql` + `.down.sql` + `supabase/policies/invoices.sql` — the metadata-only table (org + matter FK pair, `amount_cents >= 0` + `status in ('issued','paid')` CHECKs, **no card/payment columns of any kind**) + `invoices_select_assigned` (documents gate verbatim) | `844a00e` |
| T3 — battery + harness | NEW `supabase/tests/11_invoice_rls.sql` (12 named checks: the 2/3/1 positives, org-role-alone / **non-vacuous org-mismatch** / cross-org / suspended / owner / anon denies, `amount_cents` + `status` CHECKs, matter-delete cascade) + `00_fixtures.sql` invoice fixtures (six rows referencing the six fixture matter ids) + harness re-scope (file list, `--apply` order gaining `10_billing_invoices.sql`, pins 1a tables/RLS 11→12, 1e public policies 10→11, 1f ninth-un-deferral pin); static `--check` **339/0/0**, selftest 6/6 | `9a1310b` |
| T4 — rehearsal r1 | **Genuinely executed** battery on the Docker-backed scratch stack (fresh-schema reset first): **`== summary: 78 passed, 0 warnings, 0 failures ==` / `RESULT: PASS`**, pins 12 tables / 12 RLS / **11 public policies** / storage unchanged / publication exactly messages; evidence `docs/billing_invoices_rehearsal_evidence_r1_2026-08-08.md` **PASSED** | `da4fa97` |
| T5 — dated apply gate + execution | `docs/billing_invoices_apply_approval_2026-08-08.md` → **APPLY APPROVED 2026-08-08** (§6 dated sign-off) + `docs/billing_invoices_apply_execution_2026-08-08.md` **APPLIED**: baseline probed (billing_invoices absent, the four demo matter ids resolve under org `ef43087b-…`, 11 tables/11 RLS, 10 public policies, 1 storage policy, publication exactly messages) → `10_billing_invoices` + `policies/invoices` (tables/RLS 11→12, public policies 10→11) → 4 demo invoices on the applied demo matters (org = the matter's org on all four, generic numbers/amounts/copy) → smoke green (partner 3 / clients 0/0 / anon denied) | `fc7ed1b` |
| T6 — dated matrix addendum | `docs/permission_matrix.md` §4 — **new "View an invoice (metadata)" row**: client/attorney SHIP behind `invoices_select_assigned`; the six deny rows with battery checks (incl. the **non-vacuous org-mismatch** 11.02-vs-11.05); partner/`compliance_officer` "deny unless separately assigned" stay ungranted; **no payment surface** (D-11 — metadata-only by construction); `platform_owner_admin` deny always; in effect since the apply execution | `4dbfc35` |
| T7 — env-gated client swap | NEW surface (D-BI5): `Invoice` VO + `BillingGateway` seam + deterministic non-PII fake (D-BI4) + `supabase_billing_api`/impl/gateway behind `env.isConfigured` + `matter_invoices_section` (gated by the existing `canViewDocuments` nav hint — the plan carries no `user_role.dart` change) + l10n ×5 + DI pins + mapping/matterRef-fallback/failure-mapping/impl/fake/cubit/section tests | `f116966` |
| T8 — lockstep + evidence + close | README count lockstep (1077 — see §7), roadmap §14 ninth flip + §13 gate-table row + §14 deferred-list narrowing + forward-hook rows, this record, dated close decision | this commit |

## 2. Verified (actually run, 2026-08-08)

### 2.1 Final gate on the committed T7 state (`f116966`; T8 is docs-only and re-swept the ledger)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` (whole repo, CI-exact) | **PASS — 0 changed** (314 files) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **1080 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 1077 in lockstep) |
| `scripts/verify_policy_tests.sh --check` (static battery) | **PASS 339/0/0** (the 11 battery + harness re-scope landed at T3) |
| Live battery (rehearsal, genuinely executed) | **`== summary: 78 passed, 0 warnings, 0 failures ==` / `RESULT: PASS`** (T4, evidence `da4fa97`; selftest 6/6; pins 12/12/11/1) |

### 2.2 Server-side verification (rehearsal stack + dev project apply)

- **Battery genuinely executed (T4, `da4fa97`):** the scratch `public`
  schema was reset first, then the rehearsal ran from the committed
  files: `--apply` **42 passed / 0 failures** (including
  `10_billing_invoices.sql` + `policies/invoices.sql`), battery **78/0/0**,
  pins probed independently (12 tables / 12 RLS / 11 public policies /
  storage unchanged / publication exactly messages), all eleven battery
  files green incl. `11_invoice_rls.sql` (2/3/1 positives, non-vacuous
  org-mismatch, amount/status CHECKs, cascade).
- **The T5 apply executed the same day** (owner's dated §6 sign-off →
  APPLY APPROVED → `docs/billing_invoices_apply_execution_2026-08-08.md`
  **APPLIED**): `10_billing_invoices` (metadata-only table, RLS on) +
  `policies/invoices` live on the dev project — tables/RLS 11→12, public
  policies 10→11, storage policies unchanged, publication exactly
  messages — plus 4 demo invoices (`INV-2026-0001..0004`) on the applied
  demo matters (`org_matches_matter = true` on all four). Smoke
  (role-impersonated): partner `8fa94af0` reads exactly its 3 assigned
  matters' invoices (the client-only family invoice **absent**), demo
  clients read **0/0** (the D-BI2 membership guard firing live, recorded
  as the honest expectation — no dev membership rows), anon denied at the
  privilege layer (no grant).

### 2.3 Test coverage added by the client swap (+33 declarations, suite 1047 → 1080 runtime; README 1044 → 1077 declaration)

- `supabase_billing_api_impl_test` (+5): the SELECT-call pin (table +
  the D-BI1 VO column list incl. the `matters(title)` embed), table
  denial → denied kind, RLS-denial text → denied kind, unknown preserved
  with the message, non-Postgrest → providerUnavailable (raw throw from
  the injected caller).
- `supabase_billing_gateway_test` (+15): the full row→VO mapping with the
  embedded matter title, the paid-status mapping, matterRef
  embed-resolution + both fallbacks (absent embed / empty title), empty
  success, loud-drift rows (non-int `amount_cents`, unmapped `status` —
  the D-11 minimal CHECK set honored loudly, missing
  invoice_number/matter_id/issued_at/id), and the failure-kind mapping
  (denied / unavailable / unknown, no row content in errors).
- `billing_gateway_test` (fake, +5): deterministic per call, the D-BI1
  non-PII metadata shape, known-synthetic-matter-titles pin (every matter
  has an invoice), statuses within the issued/paid CHECK set, and the
  **no-payment-surface pin** (no card/pay shape anywhere).
- `billing_cubit_test` (+6): starts loading, load → success, empty →
  ViewEmpty, failure → ViewError, in-flight duplicate ignored, retry
  after error.
- `service_locator_test` (+2): fake in env-less, flip to
  `SupabaseBillingGateway` behind the anon key.
- `matter_details_screen_test` (+0 declarations, extended): the workspace
  sections test now pins the Invoices header + `INV-2026-0001` +
  `INV-2026-0002` absent (per-matter filter), and the empty-subset test
  pins the invoices empty copy.
- `app_localizations_test` (+0 declarations, extended): the invoices
  title/empty/status keys resolve in EN/AR/TR + the D-11 no-pay/charge
  framing rail on the empty copy.

  Per-file sums: 5 + 15 + 5 + 6 + 2 = **33 declarations** — matching the
  ledger lockstep 1044 → 1077 (suite 1047 → 1080 runtime; the +3 spread
  is the `blocTest<>` expansion convention).

## 3. Pending (honestly NOT run — do not read as verified)

- **No live configured-build read round-trip on a device/emulator** — all
  client verification is the typed/fake test suite + DI pins (the D-45.1
  Phase 2 convention; needs `.env`, git-ignored). The real RLS-scoped
  SELECT on the dev project is only observable after a configured build.
- **No payment integration of any kind** (D-11 — Paymob is a separate,
  future, owner-approved integration spec; no live payment in MVP; no tax
  machinery). The fake is the product posture (D-BI4), not a stopgap.
- **No write path** — invoices are read-only in this slice; any invoice
  creation surface is a future slice behind its own gate.
- **No push** — `feat/billing-invoices-read` is ahead of `origin`; push
  awaits owner approval.

## 4. Acceptance-criteria status (plan §7/T8 done-when)

| Criterion | Status | Evidence |
|---|---|---|
| RLS-gate review answers Q1–Q6 (metadata-only, D-BI2 gate, no owner carve-out, read-only, no new events) | **VERIFIED** | `7d0ab93` |
| Rehearsal-ready artifacts match D-BI1/D-BI2 (metadata-only table — no card/payment columns; documents gate verbatim) | **VERIFIED** | `844a00e` |
| Battery pins the grant + denies + CHECKs + cascade; harness re-scoped (12/12/11-public) | **VERIFIED** | `9a1310b`: 11 battery (12 checks); static `--check` 339/0/0; selftest 6/6 |
| Rehearsal r1 genuinely executed green with the pins verified | **VERIFIED** | `da4fa97`: 78/0/0, RESULT: PASS, pins 12/12/11/1 |
| Dated apply-approval → apply executed (baseline, migration + policy, demo seed, smoke), rollback pairing standing by | **VERIFIED** | `fc7ed1b`: APPLIED — tables/RLS 11→12, public policies 10→11, 4 demo invoices, smoke green; no trigger fired |
| Dated matrix §4 addendum precedes the client surface | **VERIFIED** | `4dbfc35` (T6) < `f116966` (T7) |
| Env-gated client swap (Invoice VO + seam/fake + supabase impl + DI flip + matter-invoices section, metadata-only) | **VERIFIED** | `f116966`: mapping / matterRef-fallback / failure-mapping / impl / fake / cubit / DI / section tests; suite green |
| README count lockstep; roadmap §14 ninth flip + §13 row; ledger PASS on the committed state | **VERIFIED** | §2.1; README 1077; §6; this commit |
| Full gate on the client slice; ledger PASS | **VERIFIED** | §2.1; PASS 115 |

## 5. Exact commands (as run — reproducible)

```bash
# T4 — rehearsal (fresh-schema reset, then the genuine cycle; Docker stack)
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_policy_tests.sh --apply        # -> 42/0/0
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_policy_tests.sh                # -> 78/0/0, RESULT: PASS
# T5 — apply on the dev project (owner §6 sign-off; §4 guardrails)
supabase db query --linked --file supabase/migrations/10_billing_invoices.sql
supabase db query --linked --file supabase/policies/invoices.sql
#   + the 4-row demo seed + role-impersonated smoke (see the execution record)
# T7 — client gate
dart format --output=none --set-exit-if-changed .    # whole-repo, CI-exact
flutter analyze                                      # No issues found
flutter test                                         # 1080 passed
bash scripts/verify_ledger.sh                        # PASS 115
```

## 6. Ledger impact

README test count **1044 → 1077** across the slice in lockstep with the
ledger's declaration count (suite 1047 → 1080 runtime). The ledger's
README-count check (both the `Tests (N total)` marker and the `**N
tests**` marker) caught the drift on the uncommitted T7 state before the
commit — the count was updated in the same commit (`f116966`) so the gate
claim is true of what ships. Final state `scripts/verify_ledger.sh`
**PASS 115/0/0**. The docs all sweep green with the resolved commit refs.

## 7. Review findings — resolved (not papered over)

- **T3 battery shape followed the documents precedent with the D-11
  mapping contract pinned:** the `status` CHECK row (11.11) rejects an
  unmapped value (`'overdue'`) — the deliberately minimal `issued`/`paid`
  set — so the client's `InvoiceStatus` enum mapping is a two-way
  contract, not an assumption (`9a1310b`).
- **T4 rehearsal watch-items resolved live:** the metadata-only migration
  applied cleanly on the scratch stack (column set + both CHECKs
  accepted) and the re-scoped pins (12 tables / 12 RLS / 11 public
  policies) reported exactly as designed — no column-set surprise on the
  hosted side (`da4fa97`).
- **T5 baseline-count honesty:** the approval record's baseline
  ("10 public policies") matched the actual pre-apply state (the storage
  apply took 9→10; this apply took 10→11) — the record documents the
  delta rather than assuming the earlier figures (`fc7ed1b`).
- **T5 smoke honest expectation:** the demo clients are assigned on the
  demo matters but hold **no dev membership rows** — `is_active_member`
  is false, so they read 0. This is the D-BI2 membership guard firing
  live (the matters/documents/messages/storage smoke precedent), recorded
  as the honest expectation, never a defect.
- **T7 ledger catch (count accuracy):** the final ledger sweep on the
  uncommitted T7 state caught the README count at 1044 while the ledger's
  git-grep declaration count on the tree was 1077 — the README was
  updated **in the same commit** (`f116966`) so the committed bytes match
  the gate claim (the realtime-push T7 lesson applied: run the ledger on
  the exact bytes that get committed).

## 8. Owner attention needed

- **Push approval:** `feat/billing-invoices-read` is ahead of `origin`;
  the slice's commits (`7d0ab93` T1, `844a00e` T2, `9a1310b` T3,
  `da4fa97` T4, `fc7ed1b` T5, `4dbfc35` T6, `f116966` T7, this T8) await
  your push approval.
- **Configured-build verification (D-BI5):** the real RLS-scoped SELECT
  on the dev project (reading the 4 applied demo invoices under the same
  gates) needs a configured build (`.env`, git-ignored) — the D-45.1
  convention.
- **Remaining §14 deferred paths:** **AI** (no scope, D-07/D-08
  owner-blocked) is the only path left — billing is now the **ninth**
  un-deferral SHIPPED, and the roadmap's §14 list narrows to AI. Any
  future billing write/payment surface (Paymob integration, invoice
  creation) is a separate slice behind its own gate per D-11.

## 9. Dated close decision

**Billing invoices (read-metadata) slice — CLOSED 2026-08-08.** T1–T8 met
their gates: the RLS-gate review answered Q1–Q6 (metadata-only table with
the D-11 PCI constraint **structural** — no card/payment column can even
exist; the documents exists-subquery gate verbatim with the load-bearing
org-mismatch clause; no owner carve-out; select-only grant; no audit
events); the rehearsal-ready artifacts matched D-BI1/D-BI2 and the
battery + harness pinned the grant, the six deny rows (incl. the
**non-vacuous org-mismatch**), the CHECK rows, and the cascade (static
`--check` 339/0/0, selftest 6/6); the **rehearsal battery was genuinely
executed green** (78/0/0, pins 12/12/11/1); the dated apply-approval was
signed and the apply **executed on the dev project** (tables/RLS 11→12,
public policies 10→11, 4 demo invoices on the applied demo matters, smoke
green — partner 3 / clients 0/0 / anon denied); the dated matrix §4
addendum moved the new "View an invoice (metadata)" row to SHIP before
the client surface; and the env-gated swap shipped — `Invoice` VO +
`BillingGateway` + deterministic non-PII fake + supabase seam/impl/
gateway behind `env.isConfigured` + the matter-invoices section (gated by
the existing `canViewDocuments` nav hint) + l10n ×5, **metadata-only with
no payment capability of any kind** — with the full gate green on the
committed state (format PASS · analyze clean · suite 1080 runtime / README
1077 declaration · ledger PASS 115, the README 1044→1077 drift caught by
the final sweep and fixed in the same commit). **The roadmap §14 billing
row flips to per-feature SHIPPED (ninth un-deferral); AI is the only
remaining deferred path.** **Nothing pushed**; billing and AI stay
deferred as *future slices* — billing's payment/write surface is a
separate owner-approved integration spec (D-11), and AI waits on
D-07/D-08 + scope.
