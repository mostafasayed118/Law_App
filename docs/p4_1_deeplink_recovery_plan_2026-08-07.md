# Plan: Phase 4.1 completion — deep-link recovery (reconciliation) + accept-invitation deep link (D-P34.2)

> **Record type:** SPEC_KIT PLAN (Template 2) + TASKS (Template 3) for the
> Phase 4.1 slice, per `SPEC_KIT.md` and the scope note
> `docs/p4_41_deeplink_recovery_scope_2026-08-03.md` (APPROVED + IMPLEMENTED
> for the recovery half). **Status: PLAN — not yet implemented** (this
> document is the research + design deliverable). No schema/RLS/policy
> change — the plan is client code + one declared dependency + recorded
> owner-side actions (INSTRUCTIONS.md §1.3 #5: nothing here is verified
> until the gate runs).

---

## 0. Reconciliation — what Phase 4.1 already shipped (verified, not assumed)

The scope note's **link-based + PKCE recovery half is fully implemented**
(commits `1f45d9c` "deep-link password recovery (Phase 4.1)" + P3.1
completion `2ff561a`). Verified file-by-file this session:

| Scope item | Shipped state (verified) |
|---|---|
| Android intent filter | ✅ `android/app/src/main/AndroidManifest.xml` — VIEW intent-filter with `android:scheme="com.legalhub.app"` on `MainActivity` (launchMode `singleTop`); scheme-only (catches both recovery and any future auth links) |
| iOS URL scheme | ✅ `ios/Runner/Info.plist` — `CFBundleURLTypes` → `com.legalhub.app` |
| PKCE + URI detection | ✅ `initializeSupabase` (`lib/data/auth/supabase_auth_api_impl.dart`) — `AuthFlowType.pkce` + `detectSessionInUri: true` stated explicitly |
| `emailRedirectTo` | ✅ `resetPasswordForEmail` → `emailRedirectTo: com.legalhub.app://auth/v1/callback` (the dashboard Magic Link template also renders `{{ .Token }}`, so the in-app OTP flow is unchanged) |
| Session-change wiring | ✅ `AuthCubit` subscribes to `AuthGateway.sessionChanges` (a PKCE-exchanged deep-link session reaches the app state); `recoveryPending` derived from the `passwordRecovery` event or the `recovery_sent_at` claim (cold restore) |
| Router routing | ✅ redirect guard: `recoveryPending` → `/forgot-password/reset`, never home; cleared on sign-out |
| Reset-screen deep-link entry | ✅ `RecoveryRoutingContext.empty` null-extra fallback (reachable without OTP; the PKCE session authorizes the reset) |
| Dependency | ✅ none added — gotrue's `passwordRecovery` auth event carries the intent (scope note §7) |

Research (Supabase docs, 2026-08-07) confirms the shipped mechanics exactly:
custom-scheme intent filters + `CFBundleURLTypes`; `detectSessionInUri`
exchanges the PKCE code and fires `AuthChangeEvent.passwordRecovery` for
recovery links; `emailRedirectTo` must be allowlisted as a **dashboard
Redirect URL** or the auth server rejects it (R1 — owner action).

## 1. Gap analysis — the genuine remaining work

1. **D-P34.2 hook — accept-invitation deep link** (scope note R3 follow-up,
   "Phase 4 follow-up if approved"; named in this request): the paste-token
   accept screen gains the **share-link variant** — the P3 §2 promise
   "invite tokens ... delivered out-of-band (copy/paste or **share link**)".
   The share link (`com.legalhub.app://accept-invite?token=<one-time-token>`)
   opens the app and pre-fills the accept screen; paste remains the primary
   surface. This is the only new client work.
2. **Owner-side actions (recorded, not repo code):** dashboard Redirect URL
   `com.legalhub.app://auth/v1/callback` (R1 — the recovery link is inert
   until it is allowlisted under Auth → URL Configuration) and the device
   smoke of the intent filters (R3 — the widget suite cannot exercise OS
   intents).

## 2. Layers touched

- **Presentation:** `lib/features/orgs/presentation/accept_invitation_screen.dart`
  (pre-fill the existing `_token` TextEditingController — a one-liner) +
  new `accept_invite_routing_context.dart` (in-memory token payload,
  mirrors `RecoveryRoutingContext`).
- **App (deep-link plumbing):** new `lib/app/deep_link/` — `app_link_parser.dart`
  (pure `Uri` → sealed `AppLinkIntent`), `app_link_listener.dart`
  (`app_links` stream → parser → store/router), `pending_accept_invite_store.dart`
  (app-scoped in-memory holder, mirrors the `BookingPrefill` precedent);
  `lib/main.dart` boot wiring.
- **Domain / data:** none — reuses `OrganizationGateway.acceptInvitation` and
  the shipped P3.4 accept flow (re-hydrate + org switch).
- **Dependency:** `app_links` declared **direct** in `pubspec.yaml` (already
  the resolved transitive version — `pubspec.lock` line 20, via
  `supabase_flutter: ^2.16.0`).

| New/changed file | Layer | Responsibility |
|---|---|---|
| `lib/app/deep_link/app_link_parser.dart` | app | Pure `Uri` → `AppLinkIntent` (accept-invite token | recovery | none) |
| `lib/app/deep_link/app_link_listener.dart` | app | `app_links` initial-link + stream → parser → pending store / router `extra` |
| `lib/app/deep_link/pending_accept_invite_store.dart` | app | In-memory one-time token holder (cold-start + signed-out buffering); consumed + cleared |
| `lib/features/orgs/presentation/accept_invite_routing_context.dart` | presentation | Equatable in-memory token payload (mirrors `RecoveryRoutingContext`) |
| `lib/features/orgs/presentation/accept_invitation_screen.dart` | presentation | Pre-fill `_token` from the pending store/`extra`; no auto-submit |
| `lib/main.dart` | app | Wire the listener after `runApp`/router creation (getInitialLink buffers via the store) |
| `pubspec.yaml` | deps | `app_links: ^6.x` (the resolved transitive version) |

## 3. State shape

No new Cubit. `AppLinkParser` returns a sealed classification:

```dart
sealed class AppLinkIntent { const AppLinkIntent(); }
final class AcceptInviteIntent extends AppLinkIntent { final String token; }
final class RecoveryIntent extends AppLinkIntent {} // owned by supabase_flutter — ignored here
final class NoAppLinkIntent extends AppLinkIntent {}
```

`PendingAcceptInviteStore` is a plain app-scoped holder (not a Cubit):
`String? takePendingToken()` consumes-and-clears; `setPendingToken` buffers.
Never persisted, never logged; the token is transient in-memory only
(contract §8).

## 4. Data flow

Share-link tap → OS intent → `app_links` (`getInitialLink` at cold start /
`onUri` while running) → `AppLinkParser`:
- `accept-invite` host → `AcceptInviteIntent(token)` → **pending store** (if
  no authenticated accept screen is mounted yet) or **router `extra`** → the
  accept screen pre-fills `_token` and clears the store → user taps
  **Accept** → the shipped P3.4 flow (`acceptInvitation` → re-hydrate →
  org switch).
- `auth/v1/callback` (recovery) → `RecoveryIntent` → **ignored by this
  listener** — supabase_flutter's `detectSessionInUri` observer owns it
  (prevents double-consumption of the PKCE code).
- Anything else → `NoAppLinkIntent` → no-op.

The one-time token travels **only** in memory (OS intent → store/`extra`);
it never enters the GoRouter URL surface, browser history, or diagnostics
(the `RecoveryRoutingContext` discipline).

## 5. Dependencies

`app_links` becomes a direct dependency. **Why now:** supabase_flutter's
`detectSessionInUri` consumes **auth callbacks only**; an invite URI is a
non-auth link its observer ignores, so the app must read raw URIs itself.
**Alternatives:** `uni_links` (same class of plugin, no reason to prefer);
a GoRouter path-param route `/accept-invite/:token` (rejected — the token
would appear in the URL surface, violating the token privacy discipline);
deferral (impossible — this is the hook). The version is already resolved in
`pubspec.lock` (transitive via `supabase_flutter`), so declaring it direct
adds no resolution churn.

## 6. Testing strategy

- **Unit — `AppLinkParser`:** accept-invite token extracted; recovery URI →
  `RecoveryIntent`; foreign scheme/host → `None`; missing/empty token →
  `None` (never an empty token into the store).
- **Unit — `PendingAcceptInviteStore`:** `takePendingToken` consumes-and-
  clears; a second take is null; survives a screen re-entry.
- **Widget — accept screen:** pre-fills from the pending store and clears it;
  **never auto-submits** (the user taps Accept — same control as paste);
  an empty store leaves the paste UI unchanged.
- **Router e2e:** an authenticated `AcceptInviteIntent` delivered via the
  listener lands on `/accept-invitation` with the token pre-filled.
- **Platform intent filters:** config-level only (already shipped, §0); the
  OS-level tap is **not** widget-testable (R3 — device smoke, owner-side).

## 7. Risks / open questions

- **R2 — recovery vs invite intent confusion:** the parser matches only the
  `accept-invite` host; any `auth/v1/callback` URI falls through to
  supabase_flutter's observer. A shared app_links listener must not touch
  recovery URIs (double-consumption of the PKCE code would break recovery).
- **Token-in-URI privacy:** the token rides the OS intent and is forwarded
  in-memory only; the listener must never echo the raw URI into a log or the
  URL surface.
- **Cold-start race:** `getInitialLink` can resolve before the router
  exists → the pending store buffers; the accept screen consumes on build.
- **Signed-out arrival:** the token stays pending in the store; the router's
  existing auth redirect handles the flow (no new auto-redirect — minimal);
  a signed-out invitee signs in and the accept tile/pending store surfaces
  the pre-fill.

## 8. Decisions (D-P41.x — ratified by autonomy, recorded here)

- **D-P41.1:** the accept-invitation **share link is the D-P34.2 surface** —
  paste stays the primary entry; the link is the out-of-band share variant
  the P3 §2 promise already names.
- **D-P41.2:** the one-time token is delivered **in-memory only** (pending
  store / router `extra`) — never the URL surface; the screen **pre-fills,
  never auto-submits**.
- **D-P41.3:** `app_links` becomes a **direct dependency** (already the
  resolved transitive version; honest since the app now consumes non-auth
  URIs supabase_flutter's observer ignores).
- **D-P41.4:** the app-scoped `PendingAcceptInviteStore` handles the
  cold-start and signed-out arrival races (the `BookingPrefill` precedent —
  app-scoped transient holder, consumed and cleared).

## 9. Tasks (SPEC_KIT Template 3 — committable slices)

Branch: `feat/p4-1-accept-deeplink` (merge onto `main`, no push).

- [ ] **1. `AppLinkParser` + sealed `AppLinkIntent`** — touches:
  `lib/app/deep_link/app_link_parser.dart`, `app_link_parser_test.dart` —
  done when: unit tests pass (accept/recovery/none/foreign/missing-token)
  and `flutter analyze` clean; no deps.
- [ ] **2. `PendingAcceptInviteStore` + DI** — touches: the store,
  `service_locator.dart` + pin in `service_locator_test.dart` — done when:
  consume-and-clear + re-entry tests pass.
- [ ] **3. `app_links` direct dep + `AppLinkListener` + boot wiring** —
  touches: `pubspec.yaml` (+ `flutter pub get`), the listener,
  `main.dart` — done when: the listener classifies and forwards an initial
  link into the store; analyzer clean.
- [ ] **4. Accept-screen pre-fill** — touches: `accept_invite_routing_context.dart`,
  `accept_invitation_screen.dart`, screen tests — done when: pre-fill +
  clear + never-auto-submit widget tests pass; paste flow byte-for-byte
  unchanged.
- [ ] **5. Router e2e pin** — touches: `router_test.dart` — done when: an
  authenticated accept intent lands on `/accept-invitation` pre-filled.
- [ ] **6. Docs + full gate + close** — touches: this plan (→ status),
  `docs/p4_41_deeplink_recovery_scope_2026-08-03.md` (D-P34.2 consummated
  note), roadmap row 4 follow-up line, README lockstep — done when:
  `dart format --output=none --set-exit-if-changed lib test` + `flutter
  analyze` + `flutter test` + `scripts/verify_ledger.sh` all green; the
  owner-side dashboard Redirect URL (R1) recorded as the remaining action.

## 10. Owner-side actions (not repo code — recorded, not run)

1. **Dashboard Redirect URL** — add `com.legalhub.app://auth/v1/callback`
   under Authentication → URL Configuration on the dev project (R1; the
   recovery link is inert until allowlisted).
2. **Device smoke** — tap a recovery link and an accept-invite share link on
   a device/simulator once the Redirect URL is set (R3); record observations
   in the evidence format.
