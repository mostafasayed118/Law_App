# LegalHub — Phase 4.1 Scope Note: Deep-Link Password Recovery (2026-08-03)

> **Record type:** Spec-lite scope note required by the Phase 4.1 gate
> (`docs/features_roadmap_2026-08-03.md` §6/§7): platform config review +
> approval (touches `android/`/`ios/` + Supabase dashboard Redirect URL),
> then the gate stack. This slice completes the original D1 half — the
> link-based + PKCE recovery variant — on top of the shipped code-based
> OTP variant (`c2496df`).
> **Planning owner:** `docs/features_roadmap_2026-08-03.md` §6.
> **Status: APPROVED + IMPLEMENTED 2026-08-03 (Project Owner — session
> instruction "Approve, implement"). Implementation notes in §7.**

---

## 1. Scope

Link-based + PKCE password recovery end to end: the "forgot password" email
carries a recovery link instead of a 6-digit OTP; tapping it opens the app
via a custom scheme; supabase_flutter's built-in deep-link observer exchanges
the PKCE code; the router lands the user on the reset step. Concretely:

1. **Android intent filter** — add a `<data>` intent filter for the
   `com.legalhub.app` scheme to the existing `MainActivity` (launch-mode
   `singleTop` already correct for deep links) in
   `android/app/src/main/AndroidManifest.xml`.
2. **iOS URL scheme** — add `CFBundleURLTypes` with the `com.legalhub.app`
   scheme in `ios/Runner/Info.plist` (Android app id = `com.legalhub.app`).
3. **Provider callback handling** — supabase_flutter ^2.16 already defaults
   to `AuthFlowType.pkce` + `detectSessionInUri: true` (the deep-link
   observer that obtains a session from a detected URI is **on by default**);
   the app must send the recovery link with `emailRedirectTo:
   com.legalhub.app://auth/v1/callback` so the emailed link is a deep link.
4. **Router handling** — a recovery deep link must land on the reset step,
   not home: supabase_flutter's observer emits the session via the existing
   `onAuthStateChange` stream (already consumed by `SupabaseAuthApiImpl`),
   and the recovery half of the reset screen already tolerates a null
   `RecoveryRoutingContext` (deep-link/refresh fallback, `recovery_routing
   _context.dart`). The slice adds the routing that carries the deep link's
   `type=recovery` intent to `/forgot-password/reset` without leaking the
   code/token into the URL surface.

## 2. Platform config review (gate requirement)

| Surface | Change | Risk |
|---|---|---|
| `AndroidManifest.xml` | `<intent-filter>` with `android:scheme="com.legalhub.app"` + VIEW action on `MainActivity` | Low: declarative; launch mode already `singleTop`; no permission change |
| `ios/Runner/Info.plist` | `CFBundleURLTypes` → `CFBundleURLSchemes` = `com.legalhub.app` | Low: declarative; standard Supabase deep-link pattern |
| Supabase dashboard (dev project) | **Redirect URL** `com.legalhub.app://auth/v1/callback` under Auth → URL Configuration | Dashboard-side, **owner action** (not repo code); no key/secret exposed |
| Client | `emailRedirectTo` param on the existing `signInWithOtp` call | Provider-surface only; no new dependency (`app_links` already transitive, `pubspec.lock` line 20) |

No `pubspec.yaml` change, no server RPC, no schema/RLS/policy change, no
matrix addendum (the recovery surface is auth-flow, not org-surface).

## 7. Implementation notes (2026-08-03)

- **Session-change wiring was the hidden gap**: `AuthGateway.sessionChanges`
  had **no consumer** — a deep-link session recovered by supabase_flutter's
  observer reached the gateway but never the `AuthCubit`/router. The slice
  makes `AuthCubit` subscribe to `sessionChanges` and surface a
  `recoveryPending` flag from the `AuthChangeEvent.passwordRecovery` event
  (PKCE exchange fires it for recovery links; `signedIn` otherwise).
- **No `app_links` dependency needed**: the recovery intent is carried by
  gotrue's `passwordRecovery` auth event, so the slice adds no pubspec
  change and no direct deep-link URI consumption — the URI's `code`/token
  never enters the router surface (scope §1.4).
- **Dashboard Redirect URL remains an owner action** (scope §2 row 3): the
  repo change is inert until `com.legalhub.app://auth/v1/callback` is added
  under Auth → URL Configuration on the dev project; verification against a
  live provider is gated on it (risk R1, not silently skipped).

## 3. Assumptions & non-goals

- **supabase_flutter 2.16 default is PKCE + URI detection** (`supabase_auth
  .dart` line 128: `detectSessionInUri` starts the deep-link observer).
  No `authFlowType` change is required; the slice states it explicitly in
  `initializeSupabase` for clarity only.
- The **code-based OTP variant stays the primary** in-app flow (`c2496df`);
  the deep-link variant is the *email path*: the emailed recovery link is a
  deep link, the in-app OTP flow is unchanged.
- The **reset screen's null-extra fallback** already covers deep-link entry
  (no email/OTP threaded); the slice must not require OTP on that path —
  the PKCE session authorizes the reset.
- Non-goals: invite-email deep links (R2, §3.3), accept-invitation deep
  links (R3 — paste screen ships in Phase 2.4; deep-link variant remains
  Phase 4 follow-up if approved), email-template copy changes, web deep
  links (no web target), any server amendment.

## 4. Acceptance criteria

1. `com.legalhub.app://` opens the app on Android and iOS (intent-filter /
   URL-scheme present and documented).
2. `sendRecoveryOtp` passes `emailRedirectTo: com.legalhub.app://auth/v1/
   callback`; recovery emails therefore carry a deep link.
3. Tapping the recovery link (when the dashboard Redirect URL is set) ends
   on `/forgot-password/reset` with a recovered PKCE session, **not** on
   home, and no code/token ever appears in the app URL surface.
4. The in-app OTP recovery flow (step 1→2→3) is byte-for-byte unchanged.
5. Fakes/env-less tests keep working (no new required config); gate stack
   green (`dart format` + `flutter analyze` + `flutter test`).

## 5. Risks (recorded, not assumed)

- **R1 — dashboard Redirect URL is owner-side**: the repo change is inert
  until the owner adds the redirect URL on the dev project dashboard. The
  slice documents the exact value; verification against a live provider is
  gated on that dashboard action (recorded in the apply/verification step,
  not silently skipped).
- **R2 — deep-link session vs. recovery intent**: a PKCE session recovered
  from a *recovery* link must not boot as a normal authenticated session
  (recovery must not silently leave the app signed in — same rule as the
  OTP variant, `updatePassword` signs out after). The router handling must
  distinguish the recovery path from a plain sign-in deep link.
- **R3 — platform smoke needs devices**: intent filters cannot be exercised
  by the widget suite; verification is config-level + the gate stack, with
  a manual device smoke recorded as pending if no device is available.

## 6. Exit

`dart format --output=none --set-exit-if-changed .` + `flutter analyze` +
`flutter test` all green; platform configs reviewed (this note) and the
dashboard Redirect URL recorded as an owner action item; no commit, push, or
provider change without owner approval.
