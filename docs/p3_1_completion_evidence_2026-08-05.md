# LegalHub — P3.1 Completion Verification & Evidence Record (2026-08-05)

> **Record type:** Slice P3.1 close-out evidence (plan
> `docs/p3_auth_org_ux_plan.md` §6 P3.1 + §10 AC-1/AC-2/AC-8, decision D-A in
> `docs/p3_1_wip_reconciliation_2026-08-05.md`) — records exactly what was
> **verified** about the real-auth completion port onto `main` (landing
> commits `5f01b12` + `2ff561a`, merge `2e18b24`) and exactly what is **still
> pending**, with no claim beyond what was actually run (INSTRUCTIONS.md §1.3
> #5).
>
> **Status: VERIFIED — port complete, merged, full gate green on `main`.**
> The row the gate-table rows below close is the P3 plan's "P3
> implementation" row (currently "⏳ not started"); the dated close decision
> itself remains owner-side (see §7).

---

## 1. What this record covers

Slice P3.1 = real auth wiring (sign-in / sign-up / password recovery) over
the DTO-free seams (`plan §6 P3.1`), delivered by porting the verified
`feat/p2-apply` WIP onto `main` (decision D-A, reconciliation
`docs/p3_1_wip_reconciliation_2026-08-05.md`). The port was **merge-style**:
the `SupabaseAuthApi` seam moved to typed sealed results
(`SupabaseAuthResult`/`SupabaseAuthFailure` incl. the `userDisabled` kind),
both gateways re-shape typed results, and password recovery was rewired
through `PasswordRecoveryCubit` + `recovery_error_localizer` +
`recoveryErrorNotice` (EN/AR/TR) — fixing the hardcoded-English recovery
messages that shipped on `main` (a §4.5 l10n violation). Phase 4.1
deep-link recovery was preserved throughout (PKCE init, `emailRedirectTo`,
`recoveredViaLink` detection, `recoveryPending`, post-recovery sign-out).

Commit trail (all local, **no push** per gate): `5f01b12` (l10n layer —
`recoveryErrorNotice` in current EN/AR/TR ARBs + `flutter gen-l10n` +
resolution pins) → `2ff561a` (atomic port: data seam + gateways + cubit +
screens + localizer + adapted tests + README) → `2e18b24` (`--no-ff` merge
into `main`).

## 2. Verified (actually run/read this session, 2026-08-05)

### 2.1 WIP source-of-truth verification (in `law_app_backend`, state as found)

- `flutter analyze` → **No issues found!** (10.4s, exit 0).
- `flutter test test/features/auth test/data/auth test/service_locator_test.dart`
  → **All tests passed!** (157 tests, exit 0).

The WIP is a complete, self-consistent later iteration — the legitimate
source for the port (reconciliation §3).

### 2.2 Port gate on `feat/p3-1-recovery-completion` (pre-merge)

| Check | Result |
|---|---|
| `dart format --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **717 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 714 in lockstep) |

### 2.3 Post-merge gate on `main` (re-run after `2e18b24`)

| Check | Result |
|---|---|
| `dart format --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **717 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 714) |

### 2.4 Change-set review (what the merge actually touched / left alone)

- **Ported:** `lib/data/auth/supabase_auth_api{,_impl,_gateway}.dart` (typed
  results), `lib/features/auth/data/supabase_{sign_up,password_recovery}_gateway.dart`
  + `fake_password_recovery_gateway.dart` (typed), `password_recovery_gateway.dart`
  seam (`sendCode`/`verifyCode`/`reset`), `password_recovery_cubit.dart`,
  `recovery_error_localizer.dart` (new), the three forgot-password screens,
  `recoveryErrorNotice` l10n key (added to **current** ARBs + regenerated —
  WIP ARBs never copied, reconciliation §4), 11 adapted test files,
  `service_locator_test.dart`, README.
- **Untouched (main's supersets preserved):** `auth_gateway.dart`,
  `auth_outcome.dart`, `fake_auth_gateway.dart`, `auth_cubit.dart`,
  `sign_in_screen.dart`, `sign_up_screen.dart` — the shipped sign-in/sign-up
  and Phase 4.1 behavior was never regressed by the port.
- **RTL:** `DirectionalIcon` restored on all three ported recovery screens
  (the WIP's `Icon` change was rejected as an RTL regression).
- **Redaction (ADR-0003):** failure contexts are built from
  `SignUpRequest`/`PasswordRecoveryRequest` `.toRedactedMap()`; no
  password/token/email in diagnostics.

### 2.5 Code-review finding — resolved by inspection

The reviewer flagged the gateways' hardcoded English `userMessage` strings
as a potential sign-up localization regression. **No regression:** the
untouched `sign_up_screen._localizeSignUpError` maps the gateway's typed
`code` → localized copy, and the ported `_codeFor` emits the **identical**
code strings main's old gateway emitted (`emailInUse`/`rateLimited`/
`providerUnavailable`), plus the new `userDisabled` → generic localized
fallback. The English strings are diagnostics-only; the presentation layer
always localizes (same design as `recovery_error_localizer`). The port
therefore preserves the localized sign-up errors shipped by PRs #3/#4.

## 3. Pending (honestly NOT run — do not read as verified)

- **Live end-to-end auth against the dev Supabase project** (real
  sign-in / sign-up / password-recovery round-trips with the configured
  anon key) was **not** exercised in this session. All verification above is
  the typed/fake-gateway test suite plus static review. The anon-key guard
  and the env-based DI flip (`service_locator.dart`) mean a configured-build
  E2E check remains **owner-side** (requires `.env`, which stays git-ignored
  — never committed).
- **The dated close decision** for the P3.1 gate-table row (see §7) has not
  been recorded by the owner.

## 4. Acceptance-criteria status (plan §10, P3.1-relevant)

| AC | Status | Evidence |
|---|---|---|
| AC-1 sign-in: valid credentials → session + memberships hydrate; wrong credentials → typed invalid-credentials message | **VERIFIED (client half)** — typed failure-kind mapping + gateway tests green; live dev-project sign-in PENDING (owner-side E2E, §3) | §2.2/§2.3 + ported `supabase_auth_gateway` tests |
| AC-2 sign-up: email confirmation enabled → pending-verification notice, no session until confirmed | **VERIFIED** — shipped pre-port (`deb72d8`), preserved; typed `SupabaseSignUpPending` → check-inbox success path tested | ported `supabase_sign_up_gateway` tests + sign-up screen tests |
| AC-8 localization/RTL: EN/AR/TR + direction-aware layout on P3 surfaces | **VERIFIED** — `recoveryErrorNotice` resolves in EN/AR/TR (resolution pins in `app_localizations_test.dart`); `DirectionalIcon` on all recovery screens; full suite (incl. RTL widget tests) green | §2.2/§2.3 + l10n pins |
| Plan §6 P3.1 test bullets: gateway mapping (DTO→domain, token-free), sign-up pending/denied/rate-limit, sign-in failure kinds, recovery generic responses | **VERIFIED** — ported/adapted; 157 auth+data tests pass on the branch, 717 full suite on `main` | §2.2/§2.3 |
| Exit criteria (plan gate table): EN/AR/TR + RTL + expiry + denial covered by tests; capability maps stay UX hints; server denial distinct from generic errors | **VERIFIED** — suite green incl. RTL/denial widget tests; denial rendering unchanged (untouched screens) | §2.2/§2.3 |

## 5. Exact commands (as run — reproducible)

```bash
cd <law_app main worktree>
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
bash scripts/verify_ledger.sh
```

## 6. Ledger impact

README test count synced **703 → 714** in lockstep with the ledger's
declaration count (+11 port tests). `scripts/verify_ledger.sh` **PASS
115/0/0** both before and after the merge. No schema/RLS/policy change —
this slice is client code only (P3 plan "code only — no schema/RLS
changes").

## 7. Owner attention needed

- **Dated close decision:** approve closing the P3 plan gate-table
  "P3 implementation" row (⏳ not started → **SHIPPED 2026-08-05**,
  `2e18b24`, suite 717, ledger PASS 115) and the P3 status line, mirroring
  how Phases 5–12 rows were closed. One-line record is enough; the evidence
  above is the verification for it.
- **Optional live E2E:** a configured-build sign-in/sign-up/recovery smoke
  test on the dev project (owner-side, needs `.env`) to confirm the
  provider round-trip beyond the typed/fake suite.
- **Worktree cleanup (out of this slice's scope):** decide the fate of the
  `law_app_backend` worktree / `feat/p2-apply` branch — superseded by this
  merge (reconciliation §6).
