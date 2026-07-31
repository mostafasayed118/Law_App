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
- Redacted error-reporting boundary with no external observability SDK.
- Auth and onboarding presentation: sign-in, sign-up, forgot-password
  (email/OTP/reset), onboarding carousel and success, home dashboard,
  settings. SignUp/forgot-password validate and navigate only — no Cubit yet.
- `SignUpRequest` pure-domain value object (features/auth/domain) with a
  redaction contract: `toRedactedMap()` is safe to embed in `AppError.context`.
- Tests (118 total): Result, AppError, UseCase, ViewState, AuthCubit (demo
  session + gateway-failure error path), LocaleCubit (locale persistence +
  unsupported-code rejection), Redactor (password/OTP/email/Bearer redaction
  with leak guards), DI registration graph, validators, router redirect logic
  (unauthenticated-deny + authenticated-redirect), sign-in screen (welcome copy
  + empty-form blocking + valid submit + forgot link + error snackbar),
  sign-up screen (title + 4 fields + terms-checkbox gating + invalid-form
  blocking + stub-submit snackbar/route), forgot-password email step (empty
  blocking + valid-email route), forgot-password OTP step (disabled-until-6-
  digits + route), `OtpFieldRow` (length, code concatenation, clear,
  completion notifier), forgot-password reset screen (confirm-password
  stale-capture regression + ViewStateView error surface + retry), home screen
  (EN + AR/RTL localized activity cards), settings screen (title + language
  dropdown + demo-session notice + sign-out + locale switch), onboarding
  carousel/success (page advance + Skip + Get Started + success routing),
  SharedPreferences locale store (round-trip + stale-code rejection +
  supported-code acceptance), SignUpRequest redaction invariants,
  PasswordRecoveryRequest redaction invariants, and the end-to-end boot /
  locale-switch widget flow.
- Coverage gaps (tracked for later batches):
  - **Cubit emission streams** — `AuthCubit`, `PasswordRecoveryCubit`, and
    `LocaleCubit` transitions are asserted via terminal state only, not
    `blocTest` emission sequences. Loading→success/error transitions are
    proven only at the destination, not as a stream.
  - **Shared widgets** — `ViewStateView` is exercised only on its error
    branch (via the reset screen test); loading/empty/success/offline/
    unauthorized branches are untested. `PasswordField` (obscure toggle),
    `LegalHubTextField`, `LabelledField`, `home_cards`, and `auth_buttons`
    have no dedicated tests (indirect coverage via their consuming screens
    only).
  - **Screen negative paths** — `settings`, `home`, and `onboarding` screens
    are happy-path-only. The `home_screen` no-session `'Jonathan'` fallback
    branch is not exercised.
  - **Router bypass** — the onboarding/onboarding-success routes are reachable
    while unauthenticated (`router.dart` redirect bypass), but no test asserts
    this; only the deny and authenticated-redirect paths are covered.
  - **TR locale** — only EN and AR are asserted in any test; TR translations
    are never loaded/exercised.
  - **Reset-screen success path** — only the error path is tested; the
    success/snackbar/navigation path is not.
- Tracked deviations: OnboardingScreen desktop overflow (D-T1), domain VOs
  built but not wired into presentation (D-T2), and the hardcoded `'Jonathan'`
  fallback (D-T3) are recorded in [`docs/tracked_deviations.md`](docs/tracked_deviations.md).
  The `primaryContainer` token deviation (`#1A2B3C` vs spec `#0b1d2e`) is
  recorded as ADR-0006 in [`docs/adr/`](docs/adr/). These are the standing
  references; this README does not duplicate their detail.

## Brand

The product brand is **LegalHub** (decision D-01; see ADR-0001). The wordmark is
localized via `AppLocalizations.appTitle`; no hardcoded "Lexis"/"Lex Juris"
labels remain in user-facing strings.

## Deliberate product boundary

The demo session, route redirects, and role capability map are **not security
controls**. Any future organization, matter, document, billing, conflict,
approval, or AI capability must enforce authorization in the server/data
boundary and ship with corresponding policy tests before it is exposed here.

No Supabase client, Sentry SDK, service-role key, credential form, production
auth flow, or real legal/client data is included.

### Secret and environment posture

- `.env.example` is **names-only**: `SUPABASE_URL=` and `SUPABASE_ANON_KEY=` with
  no values. It documents the variables the app will one day consume; it does
  not contain secrets.
- `.gitignore` excludes every env variant (`.env`, `.env.*`, `*.env`,
  `*.env.*`) except `.env.example` itself, so a local `.env` is never
  committed.
- A **service-role key is never permitted on the Flutter client.** Only the
  approved public Supabase URL/anon configuration belongs in a client build,
  injected at build time via `--dart-define(-from-file)`. Service-role keys
  and privileged credentials belong only in controlled server/edge-function
  environments.
- No backend SDK is imported anywhere in `lib/` — a codebase audit confirmed
  zero references to `supabase`, `firebase`, `paymob`, `http`, `dio`, `sqflite`,
  or `hive`. The only `Supabase` mention in code is a comment in
  `core/observability/error_reporter.dart` stating it is a future integration
  that must not be wired into the client now.

## Run and verify

```bash
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run
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
ADR-0006 (primaryContainer remains #1A2B3C as a tracked deviation).
Known deviations that are not architecture decisions (a deferred render bug,
unwired-but-tested domain contracts, a hardcoded fixture string) live in
[`docs/tracked_deviations.md`](docs/tracked_deviations.md).
