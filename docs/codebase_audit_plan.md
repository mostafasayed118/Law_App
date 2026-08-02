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
> (`d8ec850`–`a508013`, +54 tests); **Batch 2 completed** (`94c9607`, P0
> decided, P1 approved); **Batch 4 completed** (`c6d4b69`, `1335512`,
> `70271d4`, `f909d85`, plus follow-up `be90fd0` — all eight doc-drift
> targets closed); **Batch 3.1+3.4 completed** (`1042daf`, `e98e61b` —
> contract-§5 session model, D-T4 resolved, suite 205/205); **Batch 3.2
> completed** (`b1ae361`, `88c3005` — Supabase adapter behind the seam,
> suite 220/220); **Batch 5 completed** (`6c3d274`, `a17b747`, `77c43de`,
> `75ff17b` — D-T1/D-T3 resolved, ADR-0008 supersedes ADR-0006, suite
> 222/222); **Batch 3.3 completed** (`cc917b7`, `e8c70b9` — build-time
> config + anon-key guard + DI flip, suite 235/235); **UI foundation
> merged** (`7f2bf39`, PR #2, 2026-08-02): `feat/foundation-screens`
> profile + notifications screens merged into `main` — `ProfileScreen`,
> notification-prefs domain/stores/cubit/settings screen, EN/AR/TR keys,
> +27 tests (suite 261/261, CI green on push). **Shell navigation arc
> completed** (`8092f0e`–`8aa0414`, 2026-08-02): settings-descendant
> surfaces wired and pinned — notifications (`8092f0e`) and profile
> (`3998aef`) tile-navigation tests, settings highlight on descendant
> routes (`768127b`), capability-derived shell nav index with
> `capabilitiesForRole` seam and no-bar guard for <2 destinations
> (`32803ae`), and map-level `roleCapabilities` invariants
> (at-least-one-destination `356f1b1`, capability-route alignment
> `8aa0414`); suite 275/275, CI green on push.
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
| 2.1 | **DONE** (`94c9607`): all ten blockers D-02…D-10b recorded with Owner + Decision + Decided-on (2026-07-31) | `p0_decision_capture.md` §1 | every row has owner+date |
| 2.2 | **DONE** (`94c9607`): §2 P1-readiness checklist fully satisfied — dev project provisioned (`eu-central-1`), ref kept in the local git-ignored `.env` by owner's choice, rollback plan + permission matrix in place | `p0_decision_capture.md` §2 | boxes reflect reality |
| 2.3 | **DONE** (`94c9607`): §3 slice-map approvals populated — P1 **APPROVED** by Project Owner 2026-07-31 | `p0_decision_capture.md` §3 | approvals recorded |
| 2.4 | **DONE** (`45b0a48`): §10.2/§10.5 owner identity recorded in `gate3_decision.md` §2.2 per `gate3_reconciliation.md` §6/§10 — recorded via the amendment's commit; the record's §9 mechanism wording is separately tracked as 4.8 | `gate3_decision.md` | placeholders replaced in `45b0a48` |
| 2.5 | **DONE** (`94c9607`): §4 open questions resolved (D-02 product model, D-03 jurisdiction owner, D-04 provider project, D-07 auth policy, permission matrix) | `p0_decision_capture.md` §4 | answered in §1/§2 |

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

**Status 2026-08-01:** decision-level preconditions met (`94c9607`) and
**D-T4 has landed (`1335512`) and been resolved by Batch 3.1** (`1042daf`,
`e98e61b` — see rows 3.1/3.4). **The zero-tables gate passed 2026-08-01**
(read-only REST probe: 200, `TABLE_COUNT=0`, no `definitions` block) and
**Batch 3.2 is complete** (`b1ae361`, `88c3005`): `main.dart` now awaits
`AuthCubit.restore()` at startup; the seam is tested, not dead code.
**Finding for 3.3 — RESOLVED (2026-08-01):** the `.env` key was swapped
to the anon public key (role claim verified `anon` via read-only decode)
and Batch 3.3 landed: `--dart-define-from-file` consumption +
`SupabaseEnv.ensureAnonKey` guard + DI flip (`cc917b7`, `e8c70b9`). The
guard refuses any non-anon key at configure time, so a service-role key
can never be consumed on the Flutter client.

| # | Task | File(s) | Exit criterion |
|---|---|---|---|
| 3.1 | **DONE** (`1042daf`): session model per contract §5 (`userId`, `memberships`, `expiresAt`), `AuthOutcome`/`AuthFailure`, membership summary behind the `AuthGateway` seam. **Resolved D-T4** (recorded `1335512`, resolved `1042daf`) | `lib/core/auth/*` | presentation cannot grant a role — **met**: no session-level role; UX projection via `activeMembership.primaryRole` |
| 3.2 | **DONE** (`b1ae361`, `88c3005`): provider adapter (`supabase_flutter ^2.16.0`) in the data layer — token-free `SupabaseAuthApi` seam, GoTrue-backed impl (the only file importing provider types), `SupabaseAuthGateway` (restore signed-out/expired/valid, missing expiry → reauthRequired, demo-denial, signOut), `restore()` wired at startup, INTERNET permission for release. DTOs/tokens never cross to presentation — **met**: snapshot surface pinned to `[userId, displayName, expiresAt]`. **Gate passed 2026-08-01**: REST 200 + `TABLE_COUNT=0` (zero tables verified) | `lib/data/auth/*`, `lib/main.dart`, `android/.../AndroidManifest.xml`, `pubspec.yaml` | boundary tests green (suite 220/220) |
| 3.3 | **DONE** (`cc917b7`, `e8c70b9`): `--dart-define-from-file` consumption — `SupabaseEnv` (URL + anon key via `String.fromEnvironment`; `.env.example` stays name-only), `initializeSupabase` behind the data layer (`publishableKey:` — the ^2.16 rename), DI flip with the **anon-key guard** (`ensureAnonKey` refuses any key whose role claim is not `anon`), wired in `main.dart` before `configureDependencies` | `lib/data/auth/supabase_env.dart`, `supabase_auth_api_impl.dart`, `service_locator.dart`, `main.dart` + tests | no key in VCS — **met**: `.env` git-ignored; only the anon public key is ever consumed |
| 3.4 | **DONE** (`e98e61b`): Unit/Cubit tests — restore (signed-out/authenticated/expired→reauthRequired/unavailable), startDemoSession, expiry, sign-out, membership transitions with synthetic fakes | new + updated tests | emission-sequence tests green (suite 205/205) |

**Acceptance (gate3 §5):** P1 exit = "Flutter presentation cannot grant a
role or bypass a denied result." Org-a/org-b policy tests belong to P2, not
P1.

---

## Batch 4 — Docs hygiene (concrete audit targets)

**Source (audit):** doc-drift findings, each with the invalidating commit.

| # | Task | File(s) |
|---|---|---|
| 4.1 | **DONE** (`c6d4b69`): README test count **134 → 190** (actual) | `README.md` |
| 4.2 | **DONE** (`c6d4b69`): removed the stale "AuthCubit/PasswordRecoveryCubit terminal-state-only" gap note — both are `blocTest` emission sequences since `46bcb7c` | `README.md` |
| 4.3 | **DONE** (`1335512`): `tracked_deviations.md` D-T2 — recovery half **resolved** (`83f5bbf`); "Resend" is now disabled (`onPressed: null`), not a no-op | `tracked_deviations.md` |
| 4.4 | **DONE** (`1335512`): **D-T4** (`Session {id, displayName, role}` demo shape) recorded with cross-ref to the reconciliation amendment §7. **Landed before Batch 3.1** (which resolves it) — dependency satisfied | `tracked_deviations.md` |
| 4.5 | **DONE** (`c6d4b69`): README forgot-password description reflects email/OTP threading via in-memory `extra` | `README.md` |
| 4.6 | **DONE** (`c6d4b69`): `.env.example` consumption decision recorded — names-only template; real URL/anon key consumed at build time via `--dart-define-from-file` from git-ignored `.env` (P1 3.3) | `README.md` |
| 4.7 | **DONE** (`70271d4`): bootstrap-spec §7/§9 readiness reconciled — backlog status column, DoD checkboxes, readiness conditions, approval gates annotated against the as-built repo | `docs/legalhub_bootstrap_specification.md` |
| 4.8 | **DONE** (`f909d85`): `gate3_decision.md` §9 — replaced the stale "in place (as an unstaged edit, still uncommitted)" mechanism wording with the amendment's authoritative-record framing | `gate3_decision.md` |

**Acceptance:** every audit-flagged doc↔code discrepancy closed; README
coverage map matches the actual suite. **Met 2026-07-31** — all eight rows
DONE (`c6d4b69`, `1335512`, `70271d4`, `f909d85`).

---

## Batch 5 — Responsive hardening + token reconciliation *(maps to the earlier plan's Batch 5)* — **COMPLETED (2026-08-01)**

**Source:** `tracked_deviations.md` D-T1/D-T3 · `docs/adr/0006`.

**Status 2026-08-01:** all three rows DONE — D-T1 and D-T3 resolved in
`tracked_deviations.md`, `primaryContainer` reconciled to the code value
`#1A2B3C` by ADR-0008 (supersedes ADR-0006; the spec table was updated, not
the code). Suite 222/222.

| # | Task | File(s) |
|---|---|---|
| 5.1 | **DONE** (`6c3d274`): D-T1 resolved — carousel page is now `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight)` (centers at phone heights, scrolls at compact/desktop); the 411×867 tests stay green **and** a default-surface 800×600 test asserting `takeException() == null` was added | `onboarding_screen.dart` + test |
| 5.2 | **DONE** (`a17b747`): D-T3 resolved — the no-session branch was reachable only via direct pump, so the fallback was **localized, not removed**: `l10n.homeFallbackName` (`Guest`/`ضيف`/`Misafir`) across EN/AR/TR, pinned with AR/TR assertions | `home_screen.dart` + 3 `.arb` + generated l10n + test |
| 5.3 | **DONE** (`77c43de`): ADR-0006 superseded by **ADR-0008** — candidates rendered (light-theme consumer surfaces, live WCAG contrast; spec value collapses the M3 container role, so the code value `#1A2B3C` won); spec §5.1 rows updated to `#1a2b3c`/`#8192a7`, theme test now pins both, ADR-0005/0006 open conditions annotated closed | `docs/adr/0008` (new), spec table, `legalhub_theme_test.dart`, ADR index |

---

## Forward hooks — tracked deferrals (must not silently evaporate)

> **Hook 1 — P3 display-name RPC (D-T6):** the matrix §2 addendum and the
> D-T6 ledger entry defer the partner's need for a member's display name to
> "a separate reviewed RPC decision" in P3. When P3 planning starts, revisit
> `docs/p2_schema_rls_design.md` §5.2 (`profiles` own-row-only) and decide
> whether to add a narrow display-name RPC. Any such RPC **widens** the
> approved client surface — it requires a dated matrix addendum per matrix
> §7 before it can ship, and it must be reviewed, not silently picked up.

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
