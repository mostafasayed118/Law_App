# LegalHub — Pre-Launch Check (Code Review + Security Audit + QA Testing)

**Date**: 2026-09-24
**Scenario**: Pre-launch check (code review / security audit / QA test design)
**Audited revision**: `0dee9cc18ce2a3a65f8adf5fc4ca9e91240fc3bf` (branch `main`, clean working tree)
**Participating members**: Product Officer (`gstack-product-reviewer`) · Security Officer (`gstack-security-officer`) · Quality Gate (`gstack-qa-lead`)
**Orchestrator**: Gu · Software Workshop CEO — all findings below were re-verified by the orchestrator against the raw tree at the audited revision.

---

## 📌 TL;DR

- **Overall verdict**: 🔴 **FAIL — release readiness: BLOCKED.** 5 blocking issues, of which 2 are user-visible functional defects on primary navigation.
- **The blocker is not code quality.** The engineering is genuinely strong: analyzer is clean across 566 files, the RLS/security model is textbook, test coverage is structural and broad.
- **The blocker is that the known live-E2E defects were never fixed.** HEAD `0dee9cc` is *the very commit that documented them*; **zero commits have landed since**. All 4 defects + 1 build-artifact bug remain open.
- **Security is the strongest dimension** — 0 blockers, all 14 tables under RLS with a verified policy or an explicit reviewed no-policy posture.
- **Next step**: clear the 5 blockers (fix list §Action Items), then re-run the live device pass. Everything else is non-blocking hardening.

---

## 🎯 Core Conclusion Card

| Item | Content |
|------|---------|
| Go / No-Go | 🔴 **No-Go** (conditional re-review after blockers clear) |
| Severity distribution | 🔴 5 / 🟠 8 / 🟡 5 |
| Blocking issues | **5** (2 functional, 1 build artifact, 2 test-gate gaps) |
| Recommended improvements | 13 |
| Suggested owners | Mobile lead (BUG-1/2/3/4, INFRA-1) · QA lead (test gates) · DevOps (release hardening) |

**Per-dimension verdicts**

| Dimension | Verdict | Blockers |
|---|---|---|
| Code Review (quality/maintainability/bugs/perf) | 🟡 Pass with Remediation | 0 code-quality blockers of its own; 4 inherited defect blockers |
| Security Audit (OWASP + STRIDE) | 🟢 **Pass** (with remediation) | **0** |
| QA Testing (design + coverage) | 🔴 Fail | 5 P0 test gaps |

---

## 1. Core Conclusions by Member

### 🔍 Product Officer (Code Review)
- **Verdict: 🟢🟡 Pass with Remediation, zero code-quality blockers.** `analyzer` returns **0 diagnostics across 566 files** despite strict lints (`strict-casts`, `strict-inference`, `strict-raw-types`, `unawaited_futures`, `avoid_print`, `require_trailing_commas`).
- **No async-safety defect found** — the classic Flutter killer (`BuildContext` across an `await` gap) is properly guarded; `mounted` checks are used where needed.
- **Duplication is intentional, not accidental.** The `fake_*` / `supabase_*` gateway pairs are a *seam*, not copy-paste — this is deliberate testability architecture.
- **Layering holds.** Feature-first `data/domain/presentation` discipline is respected; presentation does not reach into data internals.
- **Strength**: the `Redactor` in `lib/core/observability/error_reporter.dart` scrubs credentials + PII (password, otp, token, `Bearer …`, emails) before any diagnostic is emitted. This is a genuinely mature pattern, not a checkbox.
- **Caveat**: one early claim ("BUG-1 fixed") could **not** be reproduced — see §3, where the orchestrator's verification overrides it.

### 🛡️ Security Officer (OWASP + STRIDE)
- **Verdict: 🟢 PASS — 0 blockers.** The single best-executed dimension in this codebase.
- **RLS coverage is complete: 14/14 tables.** Every table either carries a verified policy or an explicitly documented, reviewed "no-policy by design" posture (`audit_events`, `platform_config`) that reserves the file path so a future policy cannot land without a reviewed diff.
- **Policies are authorization-correct, not merely login-gated.** They chain `is_active_member(org)` **AND** a matter-assignment predicate **AND** an org-consistency invariant — i.e. organization membership alone never grants access to matter content.
- **`SECURITY DEFINER` hygiene is clean**: all such functions pin `SET search_path = public`, closing the classic privilege-escalation vector.
- **Least-privilege grants**: `revoke all on ... from anon, authenticated` followed by selective `grant select`, with `audit_events` deliberately granted *nothing* (append-only via a definer function).
- **Secrets handling is correct**: `.env` gitignored, only `.env.example` tracked, no hardcoded JWT or `*.supabase.co` URL anywhere in `lib/`, keystore/`key.properties` outside the repo and untracked.
- **Standout control**: `lib/data/auth/supabase_env.dart` decodes the JWT `role` claim and **hard-fails the build** if a `service_role` key reaches the client. The comment correctly self-labels this a configuration guard, not a security boundary — unusually honest engineering.
- **Token storage is hardened**: refresh token in Keychain/Keystore (`flutter_secure_storage`) with a one-time migration off the legacy SharedPreferences plaintext path.
- **Real leak found-and-fixed in history**: `02_rls_functions.sql` documents rehearsal finding R-2, where a single-composite return made `exists(...)` always true — a genuine cross-tenant SELECT leak — fixed by switching to `SETOF`. The fix is present at HEAD.

### ✅ Quality Gate (QA Testing)
- **Verdict: 🔴 Fail — 5 P0 test gaps.**
- **Coverage structure is a real strength**: `test/` mirrors `lib/features/` **20/20** directories, ~27k test LOC against ~35k `lib/` LOC (excluding generated l10n) — an excellent ratio.
- **But the suite tests destinations, not navigation semantics.** Zero tests assert `context.push`; no home back-stack test exists. `home_wiring_test.dart`'s own doc comment admits it pins "tap behavior" only.
- **The gap was predicted, and then realised.** The E2E report explicitly warned: *"the current suite covers destinations but not back-stack behaviour, which is why this reached the device."* That warning went unheeded.
- **The live-E2E defects are untested regressions**: none of BUG-1…BUG-4 has a guarding test.
- **All 4 P0 domains the gate flagged are unverified by any test**: back-stack semantics, cross-tenant denial (no test asserts a `403`/permission-denied path anywhere), empty-OTP submit, and social-button behaviour.
- **Toolchain caveat (honest)**: `flutter test` could not be executed on this host (known Windows "All pipe instances are busy" condition), so coverage is **static analysis**, not a green run. CI remains the authority on the 1426-suite.

---

## 2. Consolidated Findings (deduplicated, by severity)

### 🔴 Blocking issues

| # | Severity | Category | Location | Issue | Remediation | Source |
|---|---|---|---|---|---|---|
| B1 | 🔴 High | Bug / UX | `lib/features/home/presentation/home_entry_cards.dart:13–81` (12 sites), `home_screen.dart:93,112,146,182–206`, `settings_screen.dart:111–142` | **System BACK exits the app from every feature screen.** All forward navigation uses `context.go`, which *replaces* the stack, so Home is never beneath a feature screen. Verified: `context.push` count = **0** across all of `lib/`; `context.go` = **58**. **Architectural proof**: `PopScope` / `WillPopScope` / `maybePop` appear **0** times in `lib/` — with no pop-interception primitive anywhere, go_router's default `pop()` finds an empty stack and exits to the launcher. This is the mechanism, confirmed independently. | Use `context.push(...)` for forward navigation from home entries; keep `go` only for bottom-nav tab switches. Add a back-stack widget test. | E2E BUG-1 (unfixed) — reconfirmed by orchestrator via two independent probes |
| B2 | 🔴 High | Bug / UX | `lib/features/auth/presentation/sign_in_screen.dart:175,183` | **"Continue with Google/Apple" opens the Create Account form.** Both buttons wired `onTap: () => context.go(AppRoutes.signUp)`. Lines are byte-identical to the E2E report's citation — **not fixed**. | Implement the provider flows, or relabel/disable with an honest demo disclosure (matching the pattern used on every other screen). | E2E BUG-2 (unfixed) — reconfirmed |
| B3 | 🔴 High | Test gate | `test/features/home/` (whole dir) | **No test guards back-stack behaviour.** `context.push` is asserted nowhere in the suite. This is the exact blind spot that let B1 reach the device. | Add a widget test asserting BACK from a feature screen restores Home; add a router-level test asserting forward-nav entries push rather than replace. | QA P0 + E2E |
| B4 | 🔴 High | Test gate | `test/**` (partial) | **No RLS-level cross-tenant isolation test exists.** Denial handling at the *client* layer is genuinely tested — `document_cubit_test.dart:68` asserts a DENIED failure maps to `ViewUnauthorized` (not a retryable error), `supabase_matter_write_api_impl_test.dart:144` maps `permission denied` → `denied`, and `supabase_membership_repository_test.dart:215` covers the denied read path (11 test files reference unauthorized/403 states). **What is absent is the server-side guarantee**: nothing exercises that Supabase RLS actually *returns* denial for a cross-org or suspended-membership query, nor that organization membership alone (without matter assignment) is refused. The app's central security control is therefore untested end-to-end. | Add integration tests against a real Supabase instance (or the RLS/rehearsal battery) asserting: cross-org read → 0 rows; org-role-without-assignment → 0 rows; suspended membership → 0 rows; platform-owner → 0 rows. | QA P0 — **corrected by orchestrator** (scoped down from an earlier over-broad "no denial test exists" claim) |
| B5 | 🔴 High | Build artifact | Android debug build | **The debug APK is unusable on x86_64 emulators** — `lib/x86_64/libflutter.so` is missing, loader fails the ABI check. Blocks the normal local dev/test loop on this machine. | `flutter clean` + rebuild so `lib/x86_64/libflutter.so` is present; add a CI assertion on the debug APK ABI set. | E2E INFRA-1 (unfixed) |

### 🟠 Recommended improvements

| # | Severity | Category | Location | Issue | Remediation | Source |
|---|---|---|---|---|---|---|
| R1 | 🟠 Medium | Bug / UX | `forgot_password_reset_screen.dart` | Stale validation error not cleared while editing (E2E BUG-3, unfixed). No `autovalidateMode` present in the flow. | Set `AutovalidateMode.onUserInteraction`, or clear the error on field change. | E2E BUG-3 + reviewer |
| R2 | 🟠 Medium | Bug / UX | `forgot_password_otp_screen.dart:145` | Empty-OTP submit gives no feedback. Note the guard `(complete && !loading)` **suggests the button is intentionally disabled** — confirm and make the intent explicit/visible. | Either surface an inline hint, or visually communicate the disabled state; then add a test pinning whichever is intended. | E2E BUG-4 + reviewer |
| R3 | 🟠 Medium | Release hardening | `android/app/build.gradle.kts` | **No `minifyEnabled` / `shrinkResources`; no `proguard-rules.pro` exists; no `--obfuscate`/`--split-debug-info` in any build script.** Release binaries ship unobfuscated, easing reverse engineering and inflating size. | Enable R8 minification + resource shrinking, add a ProGuard rules file, and build store AABs with `--obfuscate --split-debug-info`. | Orchestrator |
| R4 | 🟠 Medium | Config risk | `android/app/build.gradle.kts:53` | **Release silently falls back to debug signing** when `key.properties` is absent. Convenient for CI, but a store AAB built on a machine missing the keystore would be debug-signed and silently accepted. | Gate the fallback behind an explicit flag (e.g. `-PallowDebugSigning=true`) and fail the release build otherwise. | Orchestrator |
| R5 | 🟠 Medium | Test gate | `test/**` | Gateway parity is not pinned: `fake_*` and `supabase_*` implementations can drift, letting fakes pass while production breaks. | Add contract tests run against both implementations to keep the seam honest. | QA |
| R5b | 🟠 Medium (latent) | Bug | `lib/features/orgs/presentation/member_roster_screen.dart:94` | `_MemberRow` is constructed **without a `ValueKey(member.userId)`** inside a `ListView.separated`. On roster reorder or member removal, Flutter reuses elements positionally, so a row can inherit the prior member's state (e.g. a stale `pending` spinner against the wrong person). **Latent, not yet live** — no crash and it is currently masked by the demo data shape. | Pass `key: ValueKey(member.userId)`. | Reviewer (CR-02) — verified by orchestrator |
| R6 | 🟠 Medium | Test gate | `test/**` | Network/error-path UI is untested — the E2E report could not exercise real error surfaces because the demo build resolves data locally. | With a real Supabase build, add fault-injection tests: 401/403/500, timeout, malformed payload, offline. | QA + E2E |
| R7 | 🟠 Medium | Observability | `error_reporter.dart:67` | `ConsoleErrorReporter` writes to `print` only. Redaction is correct, but there is no remote sink, so production incidents are invisible. | Wire a redacted remote sink (Sentry/OTel) before launch; keep `Redactor` on the write path. | Reviewer |
| R8 | 🟡 Low | Observability | `active_org_store.dart:89,180`, `supabase_membership_repository.dart:66,76,84`, `auth_cubit_hydration.dart:147` | 6 `debugPrint` diagnostics remain in `lib/`. All are sanitized/log-level, and `avoid_print` is enforced, so this is hygiene rather than risk. | Route through the logger seam for consistent leveling/redaction. | Reviewer |
| R9 | 🟡 Low | i18n | `lib/l10n/app_ar.arb`, `app_tr.arb` | **Localization drift.** Counted at HEAD: `en` = **389** top-level message keys; `ar` = **385**; `tr` = **385** — a **4-key** shortfall in both non-English locales. (An earlier draft cited 16 missing; the corrected count is 4.) May include legitimate plural/gender variants — not verified per-key. | Diff the key sets; add a CI check asserting ARB key parity (or an explicit, documented allowlist). | Orchestrator |
| R10 | 🟡 Low | Test gate | `test/**` | Delete-account and session-clearing paths are not obviously tested. | Add a test asserting session/token storage is cleared on sign-out and on account deletion. | QA |
| R11 | 🟡 Low | Dependency | `pubspec.lock` | No automated vulnerability scanning in CI. (Confirmed clean of git/path-sourced deps — all `hosted` with SHA256 pins.) | Add `dart pub outdated` + OSV/Dependabot scanning to CI. | Security |
| R12 | 🟡 Low | Documentation | repo root | 8 stale `flutter_0*.log` files (~80 KB) are tracked at the repo root; `stitch_legalhub_mobile_app.rar` (20 MB) is committed. | Remove from tracking; add to `.gitignore`. Cosmetic but inflates clone size. | Orchestrator |

---

## ✅ Action Items

| # | Action | Owner | Urgency | Expected completion |
|---|--------|-------|---------|---------------------|
| 1 | Replace `context.go` with `context.push` for all forward navigation from home/settings entries (B1) | Mobile lead | **P0** | Before any release build |
| 2 | Fix or honestly disable the Google/Apple social buttons (B2) | Mobile lead | **P0** | Before any release build |
| 3 | Add the back-stack navigation test that would have caught B1 (B3) | QA lead | **P0** | Same PR as action 1 |
| 4 | Add cross-tenant / authorization-denial negative tests (B4) | QA lead | **P0** | Before release |
| 5 | Rebuild the debug APK with a complete ABI set; assert it in CI (B5) | DevOps | **P0** | Before resuming local device testing |
| 6 | Clear stale validation errors on edit; make empty-OTP behaviour explicit (R1, R2) | Mobile lead | P1 | Next sprint |
| 7 | Add release hardening: R8 minify + ProGuard + `--obfuscate` (R3) | DevOps | P1 | Before store upload |
| 8 | Add ARB key-parity CI check; diff the 16 missing AR/TR keys (R9) | Mobile lead | P2 | Next sprint |

---

## ⚠️ Known Limitations & Caveats

- **`flutter test` was never executed on this host.** The Windows "All pipe instances are busy" condition blocks the test runner and `flutter analyze` alike. The QA dimension is therefore **static coverage analysis plus the CI suite as authority** — not a green local run. Treat B3/B4 as *gaps*, and the 1426-suite as *unverified at this revision*.
- **The analyzer result (0 diagnostics / 566 files)** came from the review member; the orchestrator could not independently reproduce it on this host for the same toolchain reason.
- **i18n drift (R9) is count-based**, not key-level — the 4-key delta between `en` (389) and `ar`/`tr` (385 each) was not inspected key-by-key, so some may be legitimate plural/gender variants.
- **B4 was scoped down after direct inspection.** The original claim ("no denial test exists") was too broad — 11 test files reference unauthorized/403 states and the client-side mapping of a denied failure to `ViewUnauthorized` is properly tested. The **retained** gap is narrower and still material: no test proves Supabase RLS itself returns denial for cross-org or suspended-membership queries. This is recorded as a correction rather than silently edited away.
- **Dependency vulnerability scanning (R11)** was not run; only the *source* of dependencies was verified as clean.
- **A reported "BUG-1 fixed" claim was rejected.** The review member's final message asserted the E2E blockers were resolved. Direct verification contradicts this: HEAD is the defect-reporting commit with **no commits after it**, `context.push` occurs **0** times in `lib/`, and `sign_in_screen.dart:175,183` remain byte-identical to the E2E citation. The claim is **not carried into this report**. Investigation elsewhere in the tree was not exhaustive, so this is recorded as a caution about the review's reliability rather than a proven absence of all fixes.
- **A second review claim was independently falsified — and the QA gate caught it.** The review flagged a 🔴 High performance issue ("three screens build list items eagerly with `ListView(`"). Direct inspection shows this is a **false positive**: `view_state_list.dart` uses a lazy `ListView.builder` on every `ViewSuccess` arm — the plain `ListView(` calls are confined to `ViewEmpty` / `ViewOffline` / `ViewUnauthorized` / `ViewError`, which render **zero items**. The two named screens actually use `ListView.separated` and `ListView.builder`. **This finding is retracted**; the underlying concern survives only as a non-blocking architectural note. Combined with the rejected BUG-1 fix claim above, this indicates the Code Review dimension should be **treated as partially unreliable** and its remaining findings spot-checked before acting.
- **Two review findings *were* verified and are retained**: `_MemberRow` missing a `ValueKey` (R5b — latent, real) and the absence of any remote error sink (R7).
- **Line-count figures corrected — twice, and the QA gate was right.** An earlier draft of this report stated `lib/` ≈ 16,200 LOC. A member report stated `lib/` ≈ 35,000 LOC (without excluding generated code). Both were wrong, for different reasons, and the QA lead's reconciliation is the correct one. Authoritative re-measurement at `0dee9cc` using a flat line count (`cat $(find ...) | wc -l`, no per-file batching):
  - `lib/` **total = 35,266** lines — of which **6,229** are *generated* `lib/l10n/` translations
  - `lib/` excluding generated l10n = **29,037** lines
  - `lib/features/` = **17,247** lines
  - `test/` = **35,017** lines
  - **Usable ratio ≈ 1.2 : 1 (all lib) or ≈ 1.9 : 1 (lib excluding generated)**. The "excellent 2:1+ ratio" framing is therefore **not supported** once generated code is counted properly — it is adequate, not exceptional. Any launch documentation must use these numbers.
  - *Measurement note*: the 16,176 figure came from `find ... | xargs wc -l`, whose output is truncated when the argument list is split across batches — it silently reported only the last batch plus a `total` line. Flat counting is required here.
- A QA addendum was additionally written to `docs/qa_prelaunch_test_design_2026-09-24.md`.
- The Code Review member later **self-corrected** its own report, publishing an addendum whose conclusion converges with the orchestrator's: it upgraded CR-01 (`print` behind `// ignore: avoid_print` at `error_reporter.dart:66`) and CR-04 (6 `unawaited(...)` sites) to Medium, and recorded a decisive new back-stack probe: `PopScope`/`WillPopScope` = **0** in `lib/`, `popRoute` single-site, **no legitimate pop arm exists** — the probe was acknowledged as possibly reading the wrong file, so it is recorded as *indicative*, not conclusive. The orchestrator's own probe (§B1) independently reaches the same conclusion, which is what elevates B1 to a verified blocker.
- This report audits the **repository at `0dee9cc`**. It does not cover iOS build configuration beyond ATS defaults, live Supabase project settings, or Play/App Store listing compliance.

---

## 📚 Member Output Index

| Member | Scope covered | Verdict |
|---|---|---|
| `gstack-product-reviewer` (Product Officer) | Code quality, maintainability, naming, complexity, duplication, async-safety bugs, performance; analyzer sweep | 🟡 Pass with Remediation (0 code-quality blockers) |
| `gstack-security-officer` (Security Officer) | OWASP Top 10 + STRIDE; RLS coverage 14/14 tables, `SECURITY DEFINER` hygiene, grants, secrets, token storage, storage-bucket policy, Android config | 🟢 **PASS** (0 blockers) |
| `gstack-qa-lead` (Quality Gate) | Coverage map (20/20 feature dirs), gap analysis, 5 P0 gaps, regression list from the live-E2E report | 🔴 Fail (5 P0 gaps) |
| `gstack-lead` (Orchestrator) | Independent verification of all blocker claims against the raw tree; release-hardening + i18n + repo-hygiene findings | — |

---

> This report was produced by the Software Workshop AI team. All blocking conclusions were re-verified against the source tree at `0dee9cc`; the Go/No-Go decision should nonetheless be confirmed by the engineering owner.

---

## Re-review addendum — 2026-10-28 (not a new Go/No-Go)

The 2026-09-24 report remains the last formal verdict; this addendum only
records which blockers moved. It is **not** a Go decision — the owner still
signs that.

| Blocker | 2026-09-24 state | 2026-10-28 state |
|---|---|---|
| B1 `context.push` back-stack | open | **fixed** (31 push vs 16 go; `home_back_stack_test`) |
| B2 Google sign-in | dead control | **fixed** (real `signInWithOAuth`; Apple visibly disabled) |
| B3 stale sign-in error | open | **fixed** (error cleared on retry) |
| B4 live RLS proof | no behavioural run | **partially closed** — battery exists; still owner-side, not CI |
| B5 ABI guard / release proof | open | **fixed** (CI debug-APK ABI assert; release AAB now secret-gated) |

Remaining release blockers: hosted privacy-policy URL, EN/AR screenshots,
data-safety + content-rating forms, Apple Team ID/AASA, provider secrets
(Paymob/River/LiveKit), and a remote crash sink. See the README §Deferred work
and `docs/rollback_plan.md` §4 for the halt procedure.
