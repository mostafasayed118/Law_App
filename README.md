# LegalHub Flutter bootstrap

LegalHub implements the approved **B1–B13 foundation scope** plus the
auth/onboarding presentation scaffold and the first backend-free domain
contract (`SignUpRequest`). It is not a production legal platform and does not
connect to authentication, legal data, payments, AI, document storage, or
messaging services.

## Implemented foundation

- Pinned Flutter/Dart toolchain and committed dependency lockfile.
- GetIt dependency registration with local-only bootstrap implementations.
- Material 3 LegalHub light theme and bundled OFL fonts (no runtime font fetch).
  Dark tokens are defined and wired — approved as-is, see ADR-0002.
- Generated English, Arabic, and Turkish localization with persisted locale.
- Arabic RTL layout and Arabic-capable typography.
- `Result`, `AppError`, typed async `ViewState`, and `UseCase` boundaries.
- Cubit/Bloc state-management baseline.
- Development-only demo-session gateway that never accepts credentials.
- Auth-aware GoRouter shell and UX-only role capability hints.
- Real Supabase sign-in/sign-up behind the existing seams: when the build is
  configured with a URL + anon key (`--dart-define-from-file=.env`),
  sign-in goes through GoTrue (`AuthGateway.signIn`) and sign-up through
  `SupabaseSignUpGateway` (email verification enabled); env-less runs and
  tests keep the credential-free fakes.
- P3 organization/membership data layer behind the same flip pattern:
  `OrganizationGateway` (create org, member list, invite with one-time token,
  change role / suspend / reactivate / remove) with a PostgREST RPC adapter,
  a dev fake mirroring the server's last-active-partner and existing-member
  guards, and typed failures — screens are a follow-up slice
  ([spec](docs/p3_organization_membership_spec_2026-08-03.md)).
- Redacted error-reporting boundary with no external observability SDK.
- Auth and onboarding presentation: sign-in, sign-up, forgot-password
  (email/OTP/reset), onboarding carousel and success, home dashboard,
  settings. Sign-up is fully wired: `SignUpScreen` builds a redaction-safe
  `SignUpRequest` on submit, hands it to a feature-scoped `SignUpCubit`
  backed by a `SignUpGateway` seam, and renders loading/success/error via
  `ViewStateView`. Forgot-password email/OTP/reset steps validate and
  route, threading the email and OTP between steps via the in-memory
  `RecoveryRoutingContext` route `extra` (never the URL — email is PII and
  the OTP is a short-lived credential), so the reset screen builds a
  `PasswordRecoveryRequest` with real values; the OTP "Resend code" control
  re-sends through the gateway seam in configured builds — never a false
  assurance, because env-less runs and tests use the dev fake, which
  acknowledges without sending.
- Phase 4.1 deep-link recovery (2026-08-03, the link + PKCE variant of the
  D1-revised flow): Android `com.legalhub.app` VIEW intent filter + iOS
  `CFBundleURLTypes` scheme, `sendRecoveryOtp` now passes
  `emailRedirectTo: com.legalhub.app://auth/v1/callback`, and `AuthCubit`
  subscribes to `AuthGateway.sessionChanges` so a PKCE-recovered session
  surfaces `recoveryPending` and the router lands it on the reset step —
  never home. Verified via router/cubit/gateway tests; the dashboard
  Redirect URL remains an owner-side action (scope note
  `docs/p4_41_deeplink_recovery_scope_2026-08-03.md`).
- `SignUpRequest` pure-domain value object (features/auth/domain) with a
  redaction contract: `toRedactedMap()` is safe to embed in `AppError.context`.
  Wired into presentation via `SignUpCubit`/`SignUpGateway`; the redaction
  invariant is pinned by a failure-path `blocTest` in
  `test/features/auth/sign_up_cubit_test.dart`.
- Tests (874 total): Result, AppError, UseCase, ViewState, AuthCubit (demo
  session + gateway-failure error path), LocaleCubit (locale persistence +
  unsupported-code rejection), Redactor (password/OTP/email/Bearer redaction
  with leak guards), DI registration graph, validators, router redirect logic
  (unauthenticated-deny + authenticated-redirect), sign-in screen (welcome copy
  + empty-form blocking + valid submit + forgot link + error snackbar),
  sign-up screen (title + 4 fields + terms-checkbox gating + invalid-form
  blocking + check-inbox success state + continue-to-sign-in route),
  forgot-password email step (empty
  blocking + gateway send + route), forgot-password OTP step (disabled-until-6-
  digits + gateway verify + real resend), `OtpFieldRow` (length, code
  concatenation, clear, completion notifier), forgot-password reset screen
  (confirm-password stale-capture regression + ViewStateView error surface +
  retry), home screen (EN + AR/RTL localized activity cards), settings screen
  (title + language dropdown + demo-session notice + sign-out + locale
  switch), onboarding carousel/success (page advance + Skip + Get Started +
  success routing), SharedPreferences locale store (round-trip + stale-code
  rejection + supported-code acceptance), SignUpRequest redaction invariants,
  PasswordRecoveryRequest redaction invariants, `SignUpCubit` emission
  sequences (loading→success/error, duplicate-submit guard, `resetToEmpty`
  retry re-enable, redaction invariant on the failure path), the Supabase
  recovery gateway (delegation + failure mapping + non-enumerating ack +
  redaction), the recovery OTP API seam (send without create-user/redirect,
  magiclink verify, wrong-code mapping, password update + session clear),
  the sign-up screen (VO construction with normalized values, terms-checkbox
  gating, invalid-form blocking, check-inbox success surface + its explicit
  sign-in action, gateway-failure `ViewStateView` error surface), and the
  end-to-end boot / locale-switch widget flow. Batch 1 of
  the codebase-audit plan added 54 tests covering `ViewStateView` all
  branches, the error reporters (runZoned print-capture), TR locale loading,
  form-field + feature widgets, the home no-session fallback pin, the router
  onboarding bypass, the reset-screen success path, the dev gateways, the
  in-memory locale store, and the onboarding-success screen. Batch 5 added
  the 800×600 onboarding no-overflow test and the EN/AR/TR localized-fallback
  assertions.
- Coverage: **874 tests** (2026-08-07); `flutter analyze` and the format gate
  clean. The coverage-gap list from the codebase audit (cubit emission
  streams, shared widgets, screen negative paths, router bypass, TR locale,
  reset success path) was closed by Batch 1 of
  [`docs/codebase_audit_plan.md`](docs/codebase_audit_plan.md) and is no
  longer listed here. The P3 organization data layer (2026-08-03) added the
  Supabase org RPC adapter (provider error mapping pinned), the org gateway
  (role-surface validation, loud unknown-role handling, typed failures) and
  the dev fake (mirrored last-partner/existing-member guards) — see
  [`docs/p3_organization_membership_spec_2026-08-03.md`](docs/p3_organization_membership_spec_2026-08-03.md).
  The real password-recovery slice (2026-08-03, D1 revised) wired the
  Supabase-backed recovery gateway behind the `PasswordRecoveryGateway` seam
  (send OTP → verify OTP → change password, no deep links needed), flipped DI
  on `env.isConfigured`, wired the email/OTP/resend screens to the gateway
  with non-enumerating acknowledgement, and pinned it with gateway, API-seam,
  screen, and DI-flip tests. **P3.1 completion (2026-08-05):** the auth data
  layer moved to typed sealed results on the `SupabaseAuthApi` seam
  (`SupabaseAuthResult`/`SupabaseSignUpResult` — GoTrue exceptions never
  cross it), both gateways re-shape typed results into `Result`, and the
  recovery flow renders **one localized, non-enumerating denial** in
  EN/AR/TR (`recoveryErrorNotice` + `recovery_error_localizer.dart`) via the
  `PasswordRecoveryCubit`-wired email/OTP/reset screens. Phase 4.1 deep-link
  recovery (PKCE init, `emailRedirectTo`, `recoveredViaLink` routing,
  post-recovery sign-out) is preserved and re-pinned across the seam,
  gateway, and cubit tests.
- Tracked deviations: D-T1 (OnboardingScreen desktop overflow) and D-T3 (the
  hardcoded `'Jonathan'` fallback) were **resolved by Batch 5** — the carousel
  page now scrolls at compact heights and the no-session greeting fallback is
  a localized `homeFallbackName` key (`Guest`/`ضيف`/`Misafir`). D-T2 (domain
  VOs) was resolved earlier. All are recorded in
  [`docs/tracked_deviations.md`](docs/tracked_deviations.md). The
  `primaryContainer` token was **reconciled to the code value `#1A2B3C` by
  ADR-0008** (supersedes ADR-0006); the spec table now matches the code.
  These are the standing references; this README does not duplicate their
  detail.

## Brand

The product brand is **LegalHub** (decision D-01; see ADR-0001). The wordmark is
localized via `AppLocalizations.appTitle`; no hardcoded "Lexis"/"Lex Juris"
labels remain in user-facing strings.

## Deliberate product boundary

The demo session, route redirects, and role capability map are **not security
controls**. Any future organization, matter, document, billing, conflict,
approval, or AI capability must enforce authorization in the server/data
boundary and ship with corresponding policy tests before it is exposed here.

No Sentry SDK, service-role key, credential form, production auth flow, or real
legal/client data is included. The Supabase client exists **only** inside the
data-layer adapter behind the `AuthGateway` seam (Batch 3.2/3.3); DTOs and
tokens never cross to presentation (contract §2.6).

### Secret and environment posture

- `.env.example` is **names-only**: `SUPABASE_URL=` and `SUPABASE_ANON_KEY=` with
  no values. It documents the variables the app will one day consume; it does
  not contain secrets. **Consumption decision (2026-07-31):** the URL + anon
  key are consumed at build time via `--dart-define-from-file` — **landed in
  Batch 3.3**: `SupabaseEnv.fromEnvironment()` reads both via
  `String.fromEnvironment`, and the DI flip refuses any key whose JWT `role`
  claim is not `anon` (a service-role key fails fast at configure time).
- `.gitignore` excludes every env variant (`.env`, `.env.*`, `*.env`,
  `*.env.*`) except `.env.example` itself, so a local `.env` is never
  committed.
- A **service-role key is never permitted on the Flutter client.** Only the
  approved public Supabase URL/anon configuration belongs in a client build,
  injected at build time via `--dart-define(-from-file)`. Service-role keys
  and privileged credentials belong only in controlled server/edge-function
  environments.
- The only backend SDK imported anywhere in `lib/` is `supabase_flutter`, and
  it is confined to two adapter files: `lib/data/auth/supabase_auth_api_impl.dart`
  (the GoTrue-backed auth adapter) and `lib/data/orgs/supabase_org_api_impl.dart`
  (the org RPC adapter). Every layer above consumes the provider-neutral
  `SupabaseAuthApi`/`AuthGateway` + `SupabaseOrgApi`/`OrganizationGateway` seams —
  DTOs and tokens are stripped at the adapter boundary. No `firebase`,
  `paymob`, `http`, `dio`, `sqflite`, or `hive` appears in `lib/`.

## Run and verify

```bash
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
# With real Supabase config (Batch 3.3): the anon public key + URL come from
# the git-ignored .env file at build time. Omitting the flag runs the fake
# gateway (env-less local runs and tests keep working).
flutter run --dart-define-from-file=.env
```

## Fonts and licenses

Bundled font files live in `assets/fonts/`. Their SIL Open Font License texts
are committed under `assets/licenses/`.

## Deferred work

Product capabilities beyond B13 remain blocked until their prerequisites are
approved: real authentication/authorization policy, tenant model and RLS,
privacy and retention controls, legal review of claims and consent, secure
storage, observability policy, and feature-specific acceptance tests.

## Decision log

Architecture and product decisions that are expensive to reverse or that
deviate from the approved spec are recorded as ADRs in [`docs/adr/`](docs/adr/).
Notable entries: ADR-0001 (brand = LegalHub), ADR-0002 (dark theme approved),
ADR-0003 (SignUpRequest redaction contract), ADR-0004 (enforce the shared/
second-use rule; retain ViewStateView), ADR-0005 (canonical primary = #0b1d2e),
ADR-0008 (primaryContainer = #1A2B3C, supersedes ADR-0006).
Known deviations that are not architecture decisions (a deferred render bug,
unwired-but-tested domain contracts, a hardcoded fixture string) live in
[`docs/tracked_deviations.md`](docs/tracked_deviations.md).
