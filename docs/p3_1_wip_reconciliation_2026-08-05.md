# LegalHub — feat/p2-apply WIP Reconciliation (2026-08-05)

> **Record type:** Reconciliation of the uncommitted real-auth wiring WIP on
> the `feat/p2-apply` worktree (`C:/flutter_projects/law_app_backend`) against
> `main`, per the owner's EXPLORE brief. Purpose: state precisely what is
> already on `main`, what is genuinely missing, and the verified port scope
> for the P3.1-completion slice (Slice 3 of the approved plan).
>
> **Status: ANALYSIS COMPLETE — the WIP state is verified compilable and
> test-green (see §3); the missing delta is the typed-API refactor + localized
> recovery UX, recommended for port (D-A). The worktree itself is untouched.**
>
> **Decision (D-A, autonomy, one line):** port the verified P3.1-completion
> delta onto `main` because it completes the owner-approved P3.1 design and
> fixes a real l10n violation (hardcoded English recovery errors) on `main`.

---

## 1. What the WIP is

39 files (34 modified + 5 untracked) on `feat/p2-apply` @ `0a55945` — the
P3.1 real-auth wiring (sign-in/sign-up/password-recovery against Supabase
GoTrue behind the DTO-free seams). Untracked files carry the newest content
(mtimes 2026-08-05 00:25): the typed-result API gateways and the recovery
localizer.

| Status | Files |
|---|---|
| Modified (34) | `lib/app/service_locator.dart`; `lib/core/auth/{auth_gateway,auth_outcome}.dart`; `lib/data/auth/{fake_auth_gateway,supabase_auth_api,supabase_auth_api_impl,supabase_auth_gateway}.dart`; `lib/features/auth/data/fake_password_recovery_gateway.dart`; `lib/features/auth/domain/password_recovery_gateway.dart`; `lib/features/auth/presentation/{auth_cubit,password_recovery_cubit,sign_in_screen,sign_up_screen}.dart` + `forgot_password/{email,otp,reset}_screen.dart` + `widgets/auth_buttons.dart`; `lib/l10n/*` (8); 15 test files |
| Untracked (5) | `lib/features/auth/data/{supabase_sign_up_gateway,supabase_password_recovery_gateway}.dart`, `lib/features/auth/presentation/forgot_password/recovery_error_localizer.dart`, `test/features/auth/{supabase_sign_up_gateway,supabase_password_recovery_gateway}_test.dart` |

## 2. Port history (why `main` is behind)

- PRs **#3 / #4** (`port/p3-auth-deltas`, merged `01ad07d` + `765eef7`,
  2026-08-05) ported a **sign-up subset** of this WIP to `main`:
  `e104c11` (display_name metadata, richer failure kinds, localized sign-up
  errors, check-inbox UX) + `f901949` (emailNotConfirmed mapping pins).
- **Not ported:** the WIP's later typed-result API refactor
  (`SupabaseAuthResult`/`SupabaseSignUpResult` sealed results replacing
  exception-style `SupabaseAuthException` calls), the recovery-flow rewrite
  through `PasswordRecoveryCubit`, and `recovery_error_localizer.dart` +
  the `recoveryErrorNotice` l10n key.

## 3. WIP verification (actually run, 2026-08-05)

In the `law_app_backend` worktree (WIP state as found, `flutter pub get` then):

- `flutter analyze` → **No issues found!** (10.4s, exit 0).
- `flutter test test/features/auth test/data/auth test/service_locator_test.dart`
  → **All tests passed!** (157 tests, exit 0).

The WIP state is therefore complete and self-consistent — it is a coherent
later iteration, not abandoned mid-refactor.

## 4. Classification of the 39 files against `main`

| Bucket | Files | Notes |
|---|---|---|
| **Already ported (functionally on `main`)** | `service_locator.dart` (auth registrations), `auth_outcome.dart` failure kinds (`emailNotConfirmed`/`emailInUse`/`rateLimited` present), sign-up check-inbox keys/UX, `auth_buttons.dart` (present), the two gateway tests (present on `main` at `test/features/auth/data/`, older API style) | `main` = ported sign-up half |
| **Missing on `main` (the port delta)** | `supabase_auth_api.dart`, `supabase_auth_api_impl.dart`, `supabase_auth_gateway.dart` (typed results; `main` has exception style `sendRecoveryOtp`/`verifyRecoveryOtp`/`updatePassword`), `supabase_sign_up_gateway.dart` + `supabase_password_recovery_gateway.dart` (typed variants), `password_recovery_gateway.dart` seam (`sendCode`/`verifyCode`/`reset`), `password_recovery_cubit.dart`, `recovery_error_localizer.dart` (**0 matches on `main`**), `recoveryErrorNotice` l10n key (**0 matches on `main`**), `forgot_password_{email,otp,reset}_screen.dart` (cubit-wired, localized denial), `fake_auth_gateway.dart`/`fake_password_recovery_gateway.dart` (typed), `auth_cubit.dart`, `sign_in_screen.dart`, `sign_up_screen.dart`, and the 15 WIP test files | **Main's `SupabasePasswordRecoveryGateway` ships hardcoded English user messages — a §4.5 l10n violation the WIP fixes.** |
| **Superseded / not portable as-is** | WIP `lib/l10n/*` ARBs + generated localizations (old tree predates Phases 5–12 — hundreds of keys absent), WIP README/docs | Port must add keys to **current** ARBs and regenerate via `flutter gen-l10n`, never copy these files wholesale |

## 5. Port scope for Slice 3 (P3.1-completion, conditional on this record)

1. Data: `SupabaseAuthApi` typed results (`resetPasswordForEmail`/`verifyOtp`/
   `updateUserPassword` + typed sealed results), `SupabaseAuthApiImpl`
   GoTrue mapping, `SupabaseAuthGateway` session/`signIn` paths.
2. Domain: `PasswordRecoveryGateway` seam → `sendCode`/`verifyCode`/`reset`;
   both gateway impls (typed).
3. Presentation: `PasswordRecoveryCubit` step states (shared `ViewState`),
   three forgot-password screens via the cubit, `recovery_error_localizer`
   (one generic localized denial; code preserved for diagnostics, ADR-0003),
   `auth_buttons` delta, sign-in/sign-up/auth-cubit adjustments.
4. l10n: add `recoveryErrorNotice` to the **current** EN/AR/TR ARBs +
   `flutter gen-l10n` (generated files regenerated, never hand-edited).
5. Tests: port the WIP's gateway/cubit/screen tests adapted to `main`'s
   suite; `service_locator_test` registration pins; EN/AR/TR resolution pins.
6. Verification: `dart format` → `flutter analyze` → `flutter test` →
   `scripts/verify_ledger.sh`; README count in lockstep; commit per layer or
   as one reviewed slice; **no push** (8 unpushed commits stay local).

## 6. Worktree safety

The `law_app_backend` worktree was only read and used for the verification
runs above. **No commit, stash, or discard was made there**; it remains
exactly as found (owner may later decide to delete/stash the stale branch —
outside this record's scope).

## 7. Self-check questions (Slice 2)

1. Why is `main`'s password-recovery gateway an l10n violation while the
   sign-up flow is clean? (Answer: the port brought sign-up's localized
   errors; recovery's hardcoded English messages predate it and were never
   re-wired through the localization layer.)
2. Why must the WIP's ARB files never be copied onto `main`? (They were
   generated on an old tree missing Phases 5–12 keys; copying would delete
   shipped strings. The port adds keys to the current ARBs and regenerates.)
3. What does "verified compilable and test-green" entitle us to claim — and
   not claim? (It proves the WIP is complete and self-consistent; it does not
   prove the port is green on `main`, which requires the full gate in §5.)
