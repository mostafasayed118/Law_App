# LegalHub — Phase 4.1 Completion Verification & Evidence Record (2026-08-07)

> **Record type:** Phase 4 slice 4.1 close-out evidence (plan
> `docs/p4_1_deeplink_recovery_plan_2026-08-07.md`) — records exactly what
> was **verified** about the accept-invitation deep link (commits
> `95c1676`..`58134f6` on `feat/p4-1-accept-deeplink`, plus the plan commit
> `322b34e` on `main`, no push) and exactly what is **still pending**, with
> no claim beyond what was actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-07 — implementation complete, full gate green
> (format clean, analyze clean, suite 850, ledger PASS 115).** The dated close
> decision for the roadmap rows is recorded in this commit (roadmap status
> line + §6 4.1 bullet + gate-table row), mirroring the P0C / P3.1–P3.5
> close. This slice consummates the D-P34.2 forward hook recorded at the
> P3.4/P3.5 closes — the invite share link is now a first-class deep link.

---

## 1. What this record covers

Phase 4.1 has **two halves**, reconciled (verified file-by-file, not
assumed) in the plan document:

- **The recovery half (original D1 half)** — link-based + PKCE password
  recovery — was already fully shipped in `1f45d9c` (+ P3.1 `2ff561a`):
  Android VIEW intent-filter (`com.legalhub.app`, `singleTop`), iOS
  `CFBundleURLTypes`, `initializeSupabase` stating `AuthFlowType.pkce` +
  `detectSessionInUri: true`, `resetPasswordForEmail` →
  `emailRedirectTo: com.legalhub.app://auth/v1/callback`, the `AuthCubit`
  session subscription + `recoveryPending` (from the `passwordRecovery`
  event / `recovery_sent_at`), and the router's recoveryPending → reset
  guard. No rework was needed or done.
- **The genuine delta (this slice)** — the **accept-invitation share link**
  (`com.legalhub.app://accept-invite?token=<one-time-token>`), the D-P34.2
  hook consummating the P3 §2 "share link" promise on top of the paste
  surface. Delivered in five gated slices with decisions ratified by
  autonomy (D-P41.1..4):

| Slice | Artifact | Commit |
|---|---|---|
| ① — parser | `AppLinkParser` (pure, dependency-free): `Uri` → sealed `AppLinkIntent` (`AcceptInviteIntent(token)` | `RecoveryIntent` | `NoAppLinkIntent`); the accept host only mints an intent with a non-empty trimmed token; the Supabase auth callback classifies as `RecoveryIntent` so the listener leaves it to supabase_flutter's observer — no PKCE double-consumption (D-P41.2) | `95c1676` |
| ② — pending store + DI | `PendingAcceptInviteStore` (app-scoped in-memory buffer, the `BookingPrefill` precedent): buffers the one-time token across cold-start/signed-out arrivals (D-P41.4), **consumed-and-cleared** (single delivery), never persisted or logged; registered in `configureDependencies`, +3 `service_locator_test` pins | `95c1676` |
| ③ — listener + boot | `AppLinkSource` boundary + `AppLinksPluginSource` adapter (**the only file importing `app_links`**, declared direct at the supabase-compatible `^7.2.1`); `AppLinkListener` bridges OS intents → parser → store → `router.go(AppRoutes.acceptInvitation)`; recovery/auth-callback URIs deliberately untouched; `main.dart` hoists the router and starts the listener `unawaited` after `runApp` (plugin holds the cold-start link until requested) | `1767a5e` |
| ④ — accept pre-fill | `AcceptInvitationScreen.initState` consume-and-clear: deep-linked token pre-fills the paste field — user still taps Accept exactly like a pasted token (**never auto-submit**); empty store = paste flow unchanged; +3 widget tests | `1767a5e` |
| ⑤ — router e2e pin | Real `AppLinkListener` (stub source) + real router + the **locator's** store: cold-start share link → `/accept-invitation` opens pre-filled and the store is consumed; signed-out pin (D-P41.4) — the auth gate bounces to `/sign-in`, token stays pending, then a later signed-in visit consumes it | `e0cca3b`, `58134f6` |

D-P41.1 (token delivery **in-memory only** — the `PendingAcceptInviteStore`
+ router `extra`, never the URL surface; the `RecoveryRoutingContext`
discipline) and D-P41.3 (`app_links` declared direct at the already-resolved
transitive version) are recorded in the plan document §3.

## 2. Verified (actually run this session, 2026-08-07)

### 2.1 Final gate on `feat/p4-1-accept-deeplink` (post-`58134f6` + Task 6 lockstep)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **850 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 847 in lockstep) |

### 2.2 Test coverage added by the slice (+23 declarations, 824 → 847; suite 827 → 850)

- `test/app/deep_link/app_link_parser_test.dart` (+8): token extraction and
  trimming; missing/blank token → no intent (a share link without its
  one-time token is never actionable); `RecoveryIntent` passthrough for the
  Supabase auth callback; foreign scheme/host → `NoAppLinkIntent`.
- `test/app/deep_link/pending_accept_invite_store_test.dart` (+4): empty
  start, consume-once (single delivery), supersede, fresh window.
- `test/app/deep_link/app_link_listener_test.dart` (+6, stub `AppLinkSource`):
  cold/warm accept links buffer + open the accept surface; **recovery URIs
  untouched**; foreign URI no-op; missing token no-op; null initial link.
- `test/features/orgs/presentation/accept_invitation_screen_test.dart` (+3):
  pre-fill + store consumed; **no auto-submit** (still user-triggered);
  empty store → paste flow unchanged.
- `test/app/router_test.dart` (+2 e2e pins): cold-start accept link drives
  the real router to `/accept-invitation` pre-filled + consumed (signed-in);
  signed-out bounce buffers the token, then a later signed-in visit
  consumes it (D-P41.4 fully pinned).
- `test/service_locator_test.dart` (+3): `PendingAcceptInviteStore`
  registration graph + stable lazy-singleton instance.
- `pubspec.yaml`: `app_links: ^7.2.1` declared **direct** (resolved
  supabase-compatible version; was transitive) — no dependency drift.

## 3. Pending (honestly NOT run — do not read as verified)

- **Live device deep-link smoke (plan R3):** no physical device/emulator
  exercise of a real `com.legalhub.app://accept-invite?token=…` link — the
  listener/parser/store/navigation is verified through the typed + stub
  source suite only; the `app_links` platform channels are exercised by
  neither the widget tests nor `flutter analyze`.
- **Dashboard Redirect URL allowlist (plan R1, owner-side):** the Supabase
  dashboard must list the custom scheme callback for the **recovery** email
  link to resolve (per the Supabase docs researched in the plan); the
  accept-invite deep link needs no dashboard entry (no PKCE). Owner-side,
  needs the owner's Supabase dashboard — not run.
- **Warm-start device observation (plan R4):** the subscribe-first ordering
  (`6d85eb3`) matches the app_links-documented pattern, but a real warm
  intent delivery on a device is an owner-side smoke, not a widget-test
  claim.
- **No server change was made or needed** — this slice is client code only
  (plan §1 "no schema/RLS changes"); it consumes the shipped accept screen
  and the P3.4 invitation RPCs as-is.

## 4. Acceptance-criteria status

| Criterion (plan §3 / scope note 4.1) | Status | Evidence |
|---|---|---|
| Parse the accept-invite share link host into a one-time token | **VERIFIED** — `AppLinkParser` minted only from `accept-invite` + non-empty trimmed token | parser tests, §2.1 |
| Buffer the token across cold-start / signed-out races without persisting or logging it | **VERIFIED** — in-memory `PendingAcceptInviteStore`, consume-and-clear single delivery; signed-out bounce retains then a later signed-in visit consumes | store + router e2e tests, §2.1 |
| Deliver the token to the accept surface without auto-submitting | **VERIFIED** — `router.go(acceptInvitation)` + `initState` pre-fill; Accept stays user-triggered | screen + router tests, §2.1 |
| Leave recovery/auth-callback URIs to supabase_flutter's `detectSessionInUri` observer (no PKCE double-consumption, D-P41.2) | **VERIFIED** — `RecoveryIntent` classified and untouched by the listener | listener tests, §2.1 |
| Recovery half (platform filters, PKCE init, `emailRedirectTo`, `recoveryPending` guard) shipped and intact | **VERIFIED (existing)** — reconciled file-by-file in the plan; no rework | plan §2 + `1f45d9c`/`2ff561a` |
| `app_links` declared direct at the supabase-compatible resolution | **VERIFIED** — `^7.2.1`, no dependency drift (lockfile unchanged in version) | pubspec, §2.2 |
| Exit criteria (plan §6): full gate green incl. the new suite; README + ledger in lockstep | **VERIFIED** — format/analyze/test/ledger green; README 824 → **847** | §2.1 |

## 5. Exact commands (as run — reproducible)

```bash
cd <law_app worktree on feat/p4-1-accept-deeplink>
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
bash scripts/verify_ledger.sh <canonical docs + touched files>
```

## 6. Ledger impact

README test count synced **824 → 847** in lockstep with the ledger's
declaration count across the slice (+23). Final state
`scripts/verify_ledger.sh` **PASS 115/0/0** with README 847. No
schema/RLS/policy change — this slice is client code only (`app_links`
declared direct is the only pubspec change, at the already-resolved
transitive version).

## 7. Review findings — resolved (not papered over)

- **Subscribe-first race (Task 3–4 review):** `start()` awaited
  `getInitialLink()` **before** subscribing to the warm-link stream — a
  URI arriving in that microtask window was dropped (broadcast, no replay),
  and a throwing initial-link fetch would have left the listener
  **permanently deaf**. Reordered to subscribe-first (the app_links
  documented order); the two channels never overlap, so no double
  processing (`6d85eb3`).
- **Signed-out pin honesty (Task 5 review):** the first signed-out pin
  *claimed* the token was buffered "for the signed-in visit" but only
  asserted retention. The test now consummates the promise — after the
  bounce, a signed-in visit opens the accept surface pre-filled and the
  store is consumed (`58134f6`). Reviewer confirmed the remaining honesty
  checks: single locator-store instance shared by listener and screen,
  unambiguous `find.byType(TextField)` after go-router replaces the shell
  child, no timer/subscription leaks.

## 8. Owner attention needed

- **R1 (dashboard):** add `com.legalhub.app://auth/v1/callback` to the
  Supabase dashboard **Redirect URLs** so the recovery email link opens the
  app (the one external config the recovery half needs; the accept-invite
  deep link needs none).
- **R3/R4 (device smoke):** on a real device/emulator with a configured
  build, open `com.legalhub.app://accept-invite?token=<one-time-token>`
  cold and warm — expect the accept screen pre-filled, Accept still manual,
  and the token consumed; also exercise a recovery email link end-to-end
  (PKCE exchange → `passwordRecovery` → reset screen).
- **Remaining roadmap:** Phase 4 is now complete at the client level (4.2
  SHIPPED 2026-08-03, 4.1 recovery + accept deep link SHIPPED); the next
  natural roadmap work after the owner-side smokes is the auth/org live E2E
  (D-45.1 Phase 2 checklist in `docs/p3_plan_complete_2026-08-05.md`).
