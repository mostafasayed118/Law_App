# LegalHub — Live E2E test report (2026-09-23)

Live on-device testing of the shipped release build on a real emulator, driven
through the Android device bridge (adb) because the Flutter CLI was unavailable
in this session (see "Environment constraints"). Every step below was performed
against the installed app; evidence is the app's own semantics tree
(`uiautomator`), screenshots with pixel analysis, and logcat.

## Environment

| Item | Value |
|---|---|
| Device | `emulator-5554` — AVD `Pixel_9_Pro`, Android 17, x86_64 |
| Screen | 1280 x 2856 @ 480 dpi (portrait) |
| Build under test | `app-release.apk` (61.9 MB), signed with the owner upload keystore |
| Driver | adb + `uiautomator` semantics dump (accessibility service enabled), taps by content-desc |
| Error monitor | `logcat` filtered for `FATAL EXCEPTION`, `E/flutter`, `E/AndroidRuntime` after every step |

### Environment constraints (recorded honestly)

1. **Flutter CLI unusable** — every `flutter` command dies with
   `ProcessException: All pipe instances are busy (OS error 231)` when spawning
   child processes (sandboxed and unsandboxed). Therefore `integration_test`
   could not be run and the 1426-test suite could not be re-executed here; CI
   covers those.
2. **Emulator storage 94% full** — PackageManager refused installs until the
   low-storage threshold was lowered on the device (reverted after testing).
3. The **debug APK cannot run on this emulator at all** — see INFRA-1.

## Results summary

| Area | Cases exercised | Verdict |
|---|---|---|
| Cold start / launch | cold start, offline cold start, relaunch after force-stop | **PASS** |
| Sign-in validation | empty submit, invalid email, short password, valid credentials | **PASS** |
| Demo session entry | button → authenticated home | **PASS** |
| Home + all 12 entry surfaces | 12 feature screens opened and content verified | **PASS** |
| Booking wizard | type → time → review → confirm → reference issued | **PASS** |
| Video consultation demo | join, live timer, mic toggle, camera toggle, leave | **PASS** |
| Messaging / Documents / Invoices / Alerts / Tasks / Approvals / Research | list content + demo disclosures | **PASS** |
| Discovery + Matters filters | filter chips render and select | **PASS** |
| Settings — theme | Dark and Light selected; verified by screenshot luminance (34 vs 246) | **PASS** |
| Settings — language/RTL | EN → AR; verified by Arabic labels **and** mirrored tab positions | **PASS** |
| Profile | fields render (name, account id, role, expiry) | **PASS** |
| Delete account | dialog, Cancel path, Delete path (→ session cleared) | **PASS** |
| Sign out | "End demo session" → back to sign-in | **PASS** |
| Forgot password | email → OTP (6 boxes) → reset → success message | **PASS** |
| Password reset validation | mismatch error shown | **PASS** |
| Offline behaviour | airplane mode: cold start + sign-in + feature navigation | **PASS** |
| Rotation | portrait ↔ landscape on a feature screen | **PASS** |
| Interrupted flow | force-stop mid-wizard → relaunch | **PASS** |
| System BACK navigation | BACK from feature screens | **FAIL — BUG-1** |
| Social auth buttons | Google / Apple buttons | **FAIL — BUG-2** |
| Validation error lifecycle | stale error while editing | **FAIL (minor) — BUG-3** |

No crash, ANR, or `E/flutter` line was observed in any passing scenario.

## Findings

### BUG-1 — System BACK exits the app from every feature screen (High)

**Steps.** Sign in (demo session) → open **Messages** → press the system BACK
button once.
**Expected.** Returns to Home (standard Android back semantics; the screen is a
forward navigation from Home).
**Observed.** The app exits to the launcher. Reproduced from **Messages**,
**Recover Password** and the **booking wizard**. The bottom-nav Home tab does
return home, so the app is usable — but BACK is broken everywhere.
**Cause (verified in source).** All home entries navigate with `context.go(...)`
(12 in `lib/features/home/presentation/home_entry_cards.dart`, 7 in
`home_screen.dart`; `context.push` is used **zero** times). `go` replaces the
stack, so Home is never beneath a feature screen.
**Fix.** Use `context.push(...)` for forward navigation from the home entries
(keep `go` for the bottom-nav tabs). Add a widget test asserting that BACK from
a feature screen restores Home — the current suite covers destinations but not
back-stack behaviour, which is why this reached the device.

### BUG-2 — "Continue with Google/Apple" opens the Create Account form (Medium-High)

**Steps.** On Sign In, tap **Google** (and **Apple**).
**Expected.** Starts the respective social sign-in flow (or is clearly disabled
in a demo build).
**Observed.** Both buttons open the **Create Account** screen.
**Cause (verified in source).** `lib/features/auth/presentation/sign_in_screen.dart:173,181`
— both `SocialButton`s are wired `onTap: () => context.go(AppRoutes.signUp)`.
**Fix.** Either implement the provider flows, or relabel/disable the buttons with
an honest demo note, matching the disclosure pattern used on every other screen.

### BUG-3 — Stale validation error is not cleared while editing (Low)

**Steps.** On Reset Password, enter mismatching passwords → submit (error
"Passwords do not match." appears) → correct both fields so they match.
**Expected.** The error clears as soon as the input becomes valid.
**Observed.** The error remains on screen until the next submit (it then clears
and the reset succeeds). Cosmetic, but it tells the user they are still wrong
after they have fixed the problem.

### BUG-4 — Empty OTP submit gives no feedback (Low, needs a look)

**Steps.** On Verify Email, tap **Verify & Continue** with all six code boxes
empty.
**Observed.** Nothing happens — no inline error, no navigation, no snackbar.
**Caveat.** The button may simply be disabled while the code is incomplete, in
which case this is acceptable; worth confirming which of the two it is.

### INFRA-1 — The debug APK is unusable on x86_64 devices (High, build artifact)

**Steps.** Install `app-debug.apk` on the x86_64 emulator and launch.
**Observed.** `FATAL EXCEPTION: main` →
`UnsatisfiedLinkError: dlopen failed: "/data/data/com.legalhub.app/app_lib/libflutter.so"
is for EM_AARCH64 (183) instead of EM_X86_64 (62)`. Reproduced after a clean
uninstall/reinstall (so it is not stale app data).
**Cause (verified by inspecting the APKs).** The debug APK's `lib/x86_64/`
contains only `libdartjni.so` and `libdatastore_shared_counter.so` — **it is
missing `libflutter.so`**, so the loader falls back to ReLinker, which extracts
the arm64 copy and fails the ABI check. The release APK is complete (x86_64 has
`libflutter.so`, `libapp.so`, and the plugin libs) and runs correctly — which is
why this report was produced on the release build.
**Impact.** Debug builds cannot be run on x86_64 emulators, which blocks the
normal development/test loop on this machine.
**Fix.** Rebuild the debug APK with a complete ABI set (`flutter clean` +
`flutter build apk --debug`, or `flutter run`), verifying `lib/x86_64/libflutter.so`
is present. The local Flutter CLI is currently unusable (constraint 1), so this
needs a working toolchain first.

### Observations (not defects)

- **Demo session is not persisted — by design.** After the app exits, relaunch
  returns to Sign In. `service_locator.dart:122` registers the credential-free
  `FakeAuthGateway` for env-less builds, and the fake keeps the session in
  memory only; secure persistence exists on the real Supabase path
  (`lib/data/auth/secure_session_storage.dart`).
- **Sign-out is below the fold.** "End demo session" is on the Settings tab and
  requires a scroll; it works correctly once reached.
- **Role changed across sessions.** Profile showed `Partner` initially and
  `Client` after the demo account was deleted and recreated — expected for a
  synthetic demo identity, but worth confirming it is intentional.
- **Every data screen carries its honesty disclosure** (messages, invoices,
  documents, alerts, tasks, approvals, research, video, booking, discovery,
  matters). This is consistent and is a genuine strength of the build.

## What this run could not cover

- **Real network failure surfaces** — the demo build resolves data locally
  through fakes, so there is no server call to fail. Airplane mode therefore
  proves offline resilience, not error-state UI. Testing the real error paths
  needs a configured Supabase build plus fault injection.
- **Real media** in the video consultation (by design: "No real audio or video").
- **Payments, push notifications, iOS** — out of scope for this demo build.
- **The 1426-test suite and `integration_test`** — blocked by the Flutter CLI
  constraint; CI runs them on the next push.

## Prioritised fix list

1. **BUG-1** — `context.go` → `context.push` on the home entries (+ a back-stack test).
2. **INFRA-1** — rebuild the debug APK so x86_64 emulators can run it.
3. **BUG-2** — wire or honestly disable the Google/Apple buttons.
4. **BUG-3** — clear validation errors on edit.
5. **BUG-4** — confirm the intended empty-OTP behaviour and make it explicit.
