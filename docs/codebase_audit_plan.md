# LegalHub — Codebase-Audit Execution Plan

> **Record type:** Canonical execution plan for the codebase-audit work the
> repo's docs keep citing ("Batch 1 of the codebase-audit plan", "Batch 5 of
> the codebase-audit plan", "codebase-audit Batches 2–4" in
> `docs/tracked_deviations.md` and `docs/adr/0007-no-backend-until-p0-closes.md`).
> This is the home of that plan.
>
> **Status:** REVISED 2026-07-31 — incorporates the four delta rows from the
> forensic audit (CI present, Gate 3 paper-trail gap, concrete doc-drift
> targets, gitignore gaps). Step 0 is **committed** (`45b0a48`); Batch 0 is
> **completed** (`ed38fd6`–`601a2c0`, pushed); **Batch 1 committed**
> (`d8ec850`–`a508013`, +54 tests); Batches 2–5 are queued.
>
> **Governing docs:** `INSTRUCTIONS.md` §2.1/§3 (gates, delivery slices,
> approval discipline) · `docs/gate3_decision.md` +
> `docs/gate3_reconciliation.md` · `docs/p0_decision_capture.md` ·
> `docs/adr/0007` · `docs/tracked_deviations.md` ·
> `docs/legalhub_bootstrap_specification.md`.
>
> **Constraints:** Every batch is a delivery slice per `INSTRUCTIONS.md`
> §2.1 (Understanding → Discovery → Recommendation → Slice → **Gate** →
> Implementation → Verification → Learning walkthrough). **No commit or push
> without explicit owner approval.** No backend work before the P0
> decision-capture gate closes (`docs/adr/0007`).

---

## Sequencing logic

Close the governance ledger first (Step 0), then make the tree safe and push
the clean history (Batch 0), then backend-free hardening (Batches 1, 2, 4 —
parallelizable), then the gated P1 slice (Batch 3), then the earlier plan's
Batch-5 items folded in as Batch 5.

```
Step 0 (Gate 3 closeout) → Batch 0 (gitignore + pre-push + push)
   ↓
Batch 1 (test floor) ──┐
Batch 2 (P0 blockers) ─┼─ parallelizable, backend-free
Batch 4 (docs hygiene) ┘
   ↓
Batch 3 (conditional P1 — GATED on Batch 2 preconditions)
   ↓
Batch 5 (responsive hardening + token reconciliation)
```

### Batch renumbering vs. earlier citations

Earlier docs cite batch numbers from a prior version of this plan. They do
**not** map positionally onto the numbering above; the mapping is:

| Old citation | Old meaning | Now handled by |
|---|---|---|
| D-T2 "Batch 1" (sign-up half) | Land `SignUpRequest` wiring | **Resolved in code** (`0d5c66d`); ledger update in new Batch 4.3 |
| D-T2 "Batch 2" (recovery half) | Wire recovery into presentation | **Resolved in code** (`83f5bbf`); ledger update in new Batch 4.3 |
| ADR-0007 "Batches 2–4" | recovery-half of D-T2, test-floor, responsive/localization polish | New Batch 4.3 (D-T2 docs), new **Batch 1** (test floor), new **Batch 5** (responsive) |
| D-T1 "Batch 5" (responsive-hardening) | Onboarding overflow fix | New **Batch 5** — the only citation whose number survives unchanged |

---

## Step 0 — Gate 3 reconciliation closeout (**done** ✅)

**State:** The amendment is **committed** (`45b0a48`):
`docs/gate3_reconciliation.md` plus the pointer in
`docs/gate3_decision.md`, owner identity recorded in §10 and in the record's
§2.2 rows. All 20 cited hashes and every file matrix verified against
`git ls-tree f7621df` / `git ls-files`.

| # | Task | File(s) | Verification |
|---|---|---|---|
| 0.1 | **DONE** (`45b0a48`): owner identity recorded in §10 — `Project Owner (github.com/mostafasayed118)` — and in `gate3_decision.md` §2.2 (both rows) | `docs/gate3_reconciliation.md` §10, `gate3_decision.md` §2.2 | A-string present in both files |
| 0.2 | **DONE** (`45b0a48`): both docs committed as one docs-only commit | both files | `git log` shows 1 commit; no code touched |
| 0.3 | **Do not push yet** — push happens in Batch 0.6 | — | — |

**Acceptance:** committed ledger shows the amendment; `gate3_decision.md`
header links it — **met by `45b0a48`**.

---

## Batch 0 — Gitignore fixes + pre-push safety + push

**Source (audit):** `.freebuff/` untracked and **not ignored**
(`git check-ignore` exit 1) · `.openclaude/settings.local.json` ignored only
via *global* gitignore (machine-level global ignore file, not portable) ·
`.mcp.json` is tracked · `ci.yml` **present** (discrepancy closed: exists,
tracked, committed `1a6cc55`, unmodified since) · at audit time HEAD was 7
commits ahead of `origin/main`.

| # | Task | File(s) | Verification |
|---|---|---|---|
| 0.1 | **DONE** (`ed38fd6`): `.freebuff/` added to gitignore | `.gitignore` | `git check-ignore .freebuff/` exits 0 |
| 0.2 | **DONE** (`ed38fd6`): `.openclaude/` ignored via repo-local rule | `.gitignore` | `git check-ignore -v .openclaude/settings.local.json` shows repo rule |
| 0.3 | **DECIDED** (2026-07-31): keep `.mcp.json` tracked — contents verified benign (project-relative server declaration, already public in `origin/main`) | `.mcp.json` | decision recorded in closeout commits |
| 0.4 | **DECIDED** (2026-07-31): add the push-to-main trigger — to be applied as closeout commit 4 | `.github/workflows/ci.yml` | workflow runs green |
| 0.5 | Pre-push review of the 7 unpushed commits: `git log origin/main..HEAD`, `git diff origin/main..HEAD --stat`, secret scan (api keys, tokens, `.env.*` values, real PII) | — | scan output clean |
| 0.6 | `git push origin main` — **only on explicit approval** | — | `origin/main == HEAD`; `git log origin/main..HEAD` empty |

**Acceptance:** tree hygiene fixed; public record clean; the reconciled
history (Step 0 commit + Batch 0 commits) is pushed as one coherent set.

---

## Batch 1 — Test floor + coverage gaps (backend-free)

**Source (audit):** README "Coverage gaps" section + audit §4 (27 test files,
136/136 passing, `flutter analyze` clean; gaps below are the *remaining*
ones).

| # | Task | File(s) | Verification |
|---|---|---|---|
| 1.1 | `ViewStateView` widget tests for **all** branches — currently only the error branch is exercised (via reset-screen test) | new `test/shared/widgets/view_state_view_test.dart` | suite green |
| 1.2 | Dedicated widget tests: `PasswordField` obscure-toggle + validator, `LegalHubTextField`, `LabelledField` (indirect-only today) | new form-field tests | suite green |
| 1.3 | Dedicated tests: `home_cards`, `auth_buttons` (indirect-only today) | new feature-widget tests | suite green |
| 1.4 | Home no-session `'Jonathan'` fallback: decide reachable-vs-unreachable (cross-ref D-T3), then test or remove | `home_screen.dart`, `home_screen_test.dart` | branch covered or removed |
| 1.5 | Router bypass: onboarding/onboarding-success are reachable unauthenticated — **pin with a test** (README flags no test asserts this) | `router_test.dart` | bypass behavior asserted |
| 1.6 | **TR locale**: load `app_tr.arb` in a test (only EN/AR are asserted today) | new locale test | TR renders |
| 1.7 | Reset-screen **success** path (snackbar + navigate to sign-in) — only error path is tested | `forgot_password_reset_screen_test.dart` | success asserted |
| 1.8 | Refresh email/OTP step tests to `83f5bbf` reality (threading + disabled "Resend") — current step tests predate the screen change (`57e60d4`) | `forgot_password_steps_test.dart` | no stale assertions |
| 1.9 | Direct unit tests: `fake_sign_up_gateway`, `fake_password_recovery_gateway`, `in_memory_locale_store`, `onboarding_success_screen`, `ConsoleErrorReporter`/`InMemoryErrorReporter` (Redactor is covered; reporters aren't) | new test files | suite green |
| 1.10 | **DONE** (`a508013`): normalized test layout — `test/auth/` → `test/features/auth/` (both stragglers relocated; ADR-0001 + D-T2 path refs updated) | relocated files + doc refs | suite green (190/190) |

**Acceptance:** the README coverage-gap list shrinks to zero or becomes an
explicit, dated deferral list. **Verification:** `flutter test` +
`flutter analyze` + `dart format --output=none --set-exit-if-changed lib test`.

---

## Batch 2 — P0 blockers + decision capture

**Source (audit):** `docs/p0_decision_capture.md` — all blockers `OPEN`, §2
checklist unchecked, §3 approvals table **empty**; `gate3_decision.md` §2.2
placeholders **replaced** (`45b0a48`).

| # | Task | File(s) | Verification |
|---|---|---|---|
| 2.1 | For each blocker **D-02…D-10b**: record Owner + Decision + Decided-on, **or** a dated deferral with owner + risk note. No decision is a decision without owner+date | `p0_decision_capture.md` §1 | every row has owner+date |
| 2.2 | Fill the §2 P1-readiness checklist (6 boxes) as items close; record the Supabase project ref/region when available | `p0_decision_capture.md` §2 | boxes reflect reality |
| 2.3 | Populate the §3 slice-map approvals table as approvals are granted (empty today) | `p0_decision_capture.md` §3 | approvals recorded |
| 2.4 | **DONE** (`45b0a48`): §10.2/§10.5 owner identity recorded in `gate3_decision.md` §2.2 per `gate3_reconciliation.md` §6/§10 — recorded via the amendment's commit; the record's §9 mechanism wording is separately tracked as 4.8 | `gate3_decision.md` | placeholders replaced in `45b0a48` |
| 2.5 | Highest-leverage answers to drive first (§4 open questions): D-02 product model, D-03 jurisdiction owner, D-04 provider project, D-07 auth policy, permission matrix | — | answered in §1/§2 |

**Acceptance:** the P0 ledger is either decided or explicitly deferred with
owners — no silent `OPEN`. **Docs-only, no code.**

---

## Batch 3 — Conditional P1 (provider adapter) — **GATED**

**Source:** contract §11 P1, `gate3_decision.md` §5, `p0_decision_capture.md`
§2, ADR-0007.

**Hard preconditions (all required before any task):** P1-blocking blockers
decided (D-02, D-03, D-04, D-07, D-08, D-09) · non-production Supabase
project inspected (ref/region recorded) · signed **positive + negative**
permission matrix · retention/audit documented · rollback plan · no production
credentials · **explicit implementation approval recorded in §3**. If any
precondition is unmet, this batch does not start.

| # | Task | File(s) | Exit criterion |
|---|---|---|---|
| 3.1 | Domain: session model per contract §5 (`userId`, `memberships`, `expiresAt`), `AuthOutcome`/`AuthFailure`, membership summary behind the `AuthGateway` seam. Resolves the D-T4 demo-session shape — **D-T4 must be recorded in the ledger (Batch 4.4) before this lands** | `lib/core/auth/*`, `lib/features/auth/domain/*` | presentation cannot grant a role |
| 3.2 | Data: provider adapter (`supabase_flutter`) in the data layer; DTOs/tokens never cross to presentation | `lib/data/auth/*` | boundary tests |
| 3.3 | Config: `--dart-define-from-file` with URL/anon key only; **no service-role key** | build config, `.env.example` stays name-only | no key in VCS |
| 3.4 | Unit/Cubit tests: restore, sign-in, reset, expiry, sign-out, membership transitions with synthetic fakes | new tests | emission-sequence tests green |

**Acceptance (gate3 §5):** P1 exit = "Flutter presentation cannot grant a
role or bypass a denied result." Org-a/org-b policy tests belong to P2, not
P1.

---

## Batch 4 — Docs hygiene (concrete audit targets)

**Source (audit):** doc-drift findings, each with the invalidating commit.

| # | Task | File(s) |
|---|---|---|
| 4.1 | README test count: **134 → 136** (actual) | `README.md` |
| 4.2 | Remove the stale "AuthCubit/PasswordRecoveryCubit terminal-state-only" gap note — both are `blocTest` emission sequences since `46bcb7c` | `README.md` |
| 4.3 | `tracked_deviations.md` D-T2: recovery half **resolved** (`83f5bbf`); "Resend" is now disabled (`onPressed: null`), not a no-op | `tracked_deviations.md` |
| 4.4 | Add **D-T4** (`Session {id, displayName, role}` demo shape) with cross-ref to the reconciliation amendment §7. **Must land before Batch 3.1** (which resolves it) — see the dependency table | `tracked_deviations.md` |
| 4.5 | Update README forgot-password description to reflect email/OTP threading via in-memory `extra` | `README.md` |
| 4.6 | `.env.example` is still unconsumed (0 `String.fromEnvironment` uses) — document as aspirational or record a consumption decision | `README.md` / decision note |
| 4.7 | Reconcile bootstrap-spec §7/§9 readiness checkboxes with reality (repo now a git repo, CI present, fonts + licenses committed) | `docs/legalhub_bootstrap_specification.md` |
| 4.8 | `gate3_decision.md` §9 says the record will be updated "in place (as an unstaged edit, still uncommitted)" — stale since the record was committed at `1a99df0`; reconcile the §9 mechanism wording with the amendment's authoritative-record framing | `gate3_decision.md` |

**Acceptance:** every audit-flagged doc↔code discrepancy closed; README
coverage map matches the actual suite.

---

## Batch 5 — Responsive hardening + token reconciliation *(maps to the earlier plan's Batch 5)*

**Source:** `tracked_deviations.md` D-T1/D-T3 · `docs/adr/0006`.

| # | Task | File(s) |
|---|---|---|
| 5.1 | D-T1: OnboardingScreen overflow at compact/desktop (800×600, ~139px) — `SingleChildScrollView`/`Flexible`; keep the 411×867 test green **and** add the 800×600 test | `onboarding_screen.dart` + test |
| 5.2 | D-T3: `'Jonathan'` fallback — localize neutrally or remove (decision cross-refs Batch 1.4) | `home_screen.dart` |
| 5.3 | ADR-0006: render `primaryContainer` candidates (`#1A2B3C` vs spec `#0b1d2e`) EN/AR/RTL + light/dark; decide code-vs-spec; update the loser and supersede ADR-0006 | `legalhub_theme.dart`, spec table, new ADR |

---

## Sequencing & governance

| Order | Batch | Depends on | Branch shape | Gate |
|---|---|---|---|---|
| 1 | Step 0 reconciliation | — | `docs/…` | owner identity + approval ✅ (2026-07-31) |
| 2 | Batch 0 | Step 0 | `chore/…` | approval before push |
| 3 | Batch 1 | — (can start anytime) | `test:…` | standard review |
| 4 | Batch 2 | — (parallel with 1) | `docs/…` | owner answers required |
| 5 | Batch 4 | Step 0 (needs amendment committed first) | `docs/…` | standard |
| 6 | Batch 3 | **Batch 2 preconditions + Batch 4.4 (D-T4 recorded)** | `feat:…` | **§3 approval recorded** |
| 7 | Batch 5 | — | `fix/…`/`docs/…` | design review (5.3) |

> The diagram above and this table agree: Batches 1/2/4 run backend-free in
> parallel before Batch 3, and **Batch 4.4 (D-T4) must land before Batch
> 3.1**, which is what the 4.4 note's "see the dependency table" points to.

---

## Definition of done (applies to every batch)

- [ ] Scope, assumptions, non-goals, and role/permission impact documented.
- [ ] Required discovery/design/specification approval gates passed.
- [ ] `git status`/`git diff` reviewed for secrets, real data, generated junk,
      and unrelated edits.
- [ ] Verification commands actually run and outcomes reported honestly.
- [ ] No commit, push, deployment, or external consequential action occurred
      without explicit approval.
