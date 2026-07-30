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
- Tests: Result, AuthCubit, LocaleCubit, Redactor, DI, validators, router
  redirect logic, sign-in screen behavior, SignUpRequest redaction invariants,
  and the end-to-end boot/locale-switch widget flow (36 tests total).

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
ADR-0003 (SignUpRequest redaction contract).
