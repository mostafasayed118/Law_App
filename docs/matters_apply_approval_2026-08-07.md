# LegalHub — Matters Apply Approval Decision Record (2026-08-07)

> **Record type:** The dated decision record that closes the apply-approval
> gate for the real-matters read slice (plan
> `docs/matters_real_data_plan_2026-08-07.md` T5), per the P2/P3 discipline
> (`docs/p2_apply_approval_2026-08-01.md` is the precedent shape) and
> `INSTRUCTIONS.md` §2.1 gates. This record, **once signed in §6**, is the
> owner's explicit authorization to apply the reviewed + rehearsed slice to
> the shared dev project, with the rollback pairing standing by.
>
> **Status: DRAFT — awaiting the owner's dated signature (§6).** Nothing is
> authorized by this document until the owner signs it with a date. This
> draft restates the preconditions, the exact scope, the execution
> guardrails, and the rollback pairing so the sign-off is a review, not a
> discovery.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/matters_real_data_plan_2026-08-07.md` (T5) ·
> `docs/matters_rls_gate_review_2026-08-07.md` (Q1–Q6, §6 rollback) ·
> `docs/matters_rehearsal_evidence_r1_2026-08-07.md` (r1 PASSED) ·
> `docs/rollback_plan.md` §1/§5 · `docs/permission_matrix.md` §7 ·
> `supabase/README.md` · `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| §14 un-deferral gate (P0 closes + policy tests) | `docs/p0_closure_scope_2026-08-05.md` RATIFIED + `scripts/verify_policy_tests.sh` | ✅ Met 2026-08-05 |
| RLS-gate design review | `docs/matters_rls_gate_review_2026-08-07.md` (`bf27f84`) | ✅ Passed 2026-08-07 |
| Schema artifacts (rehearsal-ready) | `supabase/migrations/04_matters.sql` + `04_matters.down.sql` (`6bf570d`, `c1d659f`) | ✅ Committed — NOT applied |
| Policy artifact | `supabase/policies/matters.sql` (`6bf570d`) | ✅ Committed — NOT applied |
| Policy battery + harness | `supabase/tests/04_matter_rls.sql`, `00_fixtures.sql`, `scripts/verify_policy_tests.sh` (`736e433`, `a08ef99`) | ✅ Committed; static `--check` PASS 24/0/0 |
| **Ephemeral rehearsal (r1)** | `docs/matters_rehearsal_evidence_r1_2026-08-07.md` (`ea3a15d`) | ✅ **Executed — PASSED 2026-08-07** (Path A, owner's Docker host; all ten 04 checks + structural pins green; `RESULT: PASS`) |
| **Apply approval (this record)** | this document | ⏳ **DRAFT — awaiting the owner's dated signature (§6)** |
| Apply execution (dev project) | `docs/matters_apply_execution_2026-08-07.md` (to be written) | ⏳ Only after §6 is signed |

## 2. Gate criteria — what the r1 rehearsal proved (evidence `ea3a15d`)

Against the ephemeral project built from the committed files, r1 verified:

| # | Criterion | r1 evidence | Verdict |
|---|---|---|---|
| 1 | `--apply` builds the slice cleanly (01, 02, 04, policies, RPCs) | §4: 04_matters + policies/matters applied cleanly | ✅ MET |
| 2 | Structural pins hold on the applied posture | §4: 7 tables / 7 RLS / 6 policies / matters SELECT grant + anon absence / documents–messages–files still absent | ✅ MET |
| 3 | 00/01/02/03 regression batteries unaffected | §4: fixtures + single-account bound + 01/02/03 all PASS | ✅ MET |
| 4 | `matters_select_assigned` enforces the matrix §4 contract | §4: client-a 2 · partner-a 3 · orphan 1 · org-role-alone 0 · cross-org 0 · suspended 0 · owner 0 · anon denied | ✅ MET |
| 5 | Mapping contract + teardown safety | §4: CHECK rejects `'tax'` · org-a delete cascades its six matters | ✅ MET |

**Verdict: all five criteria satisfied on the r1 evidence. No failing
assertion remains.** The apply-approval gate is unblocked pending the
owner's signature in §6.

## 3. Decision (scope this record authorizes — once signed)

**APPLY APPROVED (pending §6):** apply the reviewed + rehearsed matters
slice to the shared dev project (`eutmvevpskerzpqmwplv`, `eu-central-1`) in
this order:

1. `supabase/migrations/04_matters.sql` — the table, `matter_status` enum,
   indexes, RLS enable, default-deny revoke, narrow `select` grant.
2. `supabase/policies/matters.sql` — `matters_select_assigned`.
3. **Demo seed** — a small set of demo matter rows (3–4) in the dev demo
   org, referencing the **dev project's own demo-account `auth.users` ids**
   (resolved at apply time via `select id from auth.users where email in
   ('demo@…', …)` — never guessed, never the rehearsal project's synthetic
   ids; the exact rows + ids are recorded in the execution record).

plus the post-apply verification (structural subset + demo reads as
assigned roles) per §4 condition 5, and the execution evidence record
(`docs/matters_apply_execution_2026-08-07.md`).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline probe (read-only):** confirm `matters` does not yet
   exist on the dev project (`information_schema` probe via `supabase db
   query --linked` or psql) and note the current `pg_policies` count —
   the up sequence runs against the same baseline the rehearsal proved.
2. **Verify, don't guess (demo seed):** demo-account `auth.users.id`
   values come from the **dev project's own** rows; the seed never uses
   rehearsal ids, never touches non-demo accounts, never uses real PII.
3. **Rollback pairing standing by (rollback_plan §1/§5):** `04_matters.down.sql`
   (drops the table — the policy dies with its table) + a targeted delete
   of the seeded demo rows is ready before step 1; **any** trigger
   condition (a matrix negative row starts passing, cross-tenant data
   visible, a demo row lands on a real account) = immediate revert, never
   fix-forward.
4. **Per-step verification:** after each of the three steps, probe the
   applied state (table exists → policy present → seed rows scoped
   correctly) with the observed output pasted into the execution record.
5. **Post-apply smoke (dev project):** the structural subset the rehearsal
   proved — table + RLS enabled + policy present + grants; then demo reads
   with role impersonation (`set local role authenticated` +
   `request.jwt.claims` via `supabase db query --linked`, the R1 pattern):
   a demo client sees its assigned demo matters; an unassigned demo user
   sees none.
6. **No scope beyond the slice:** no other table/RPC/policy changes, no
   email, no storage/realtime, no production, no service-role key, no real
   client/legal data.

## 5. What this approval does NOT authorize

- No other schema, policy, or RPC change beyond §3; no write path to
  matters (the slice is read-only — a future write slice is a separate
  review + addendum + apply).
- No change to the Flutter client (`lib/`) — the env-gated `MatterGateway`
  swap is plan **T7**, a separate slice with its own gate.
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

- **Project Owner:** github.com/mostafasayed118 — **date:** ____________
  — **signature / approval wording:** "Apply approved — matters read slice
  (04_matters + policy + demo seed), per this record §3–§5."

> **Status flips to APPLY APPROVED (dated) once §6 is filled.** The
> execution record then captures the actual run; on success, plan T6 (dated
> matrix addendum) and T7 (client swap) follow.

## 7. Ledger

- On signature: this record's §1 row flips ⏳ → ✅ APPROVED (dated); the
  plan's T5 row updates; the execution record (`docs/matters_apply_execution_2026-08-07.md`)
  is written from the actual run.
- On apply success: roadmap §14 gains the matters per-feature flip (T8),
  the dated matrix addendum lands (T6), and the README/ledger lockstep is
  re-run on the merged tree.
