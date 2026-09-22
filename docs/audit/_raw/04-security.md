# LegalHub — Security Dimension Audit (raw, uncapped)

> **Auditor stance:** static reading + scoped grep only. Every claim below was
> opened in the file cited. No `flutter test` / `flutter analyze` was run.
> **Posture judged:** DEMO-READY (non-production), dev Supabase project,
> synthetic data only (`docs/p4_release_readiness_2026-08-09.md`).
> **Prior work built on, not re-reported:** `docs/p4_threat_model_2026-08-09.md`,
> `docs/security_review_gate_record_2026-08-09.md`,
> `docs/p4_findings_register_2026-08-09.md`,
> `docs/auth_tenant_authorization_contract.md`, `docs/permission_matrix.md`,
> `docs/p2_schema_rls_design.md`, `docs/tracked_deviations.md`,
> `docs/adr/0003`, `docs/adr/0007`.
> **Date:** 2026-09-21. **Working tree:** 15 modified + 1 new (`lib/data/list_query_guards.dart`)
> uncommitted files — inspected, all in-flight perf/UI work, no security delta.

---

## 0. Headline

**No CRITICAL finding.** No exposed secret, no client-reachable authorization
bypass, and no injection sink with a live data path was found. The
server-side authorization design (RLS + `SECURITY DEFINER` RPCs that re-derive
membership from `auth.uid()`) is the strongest part of this codebase and is
backed by a genuine positive+negative policy battery. The weakest part is
**client-side secret-at-rest hygiene**: the Supabase session (access +
refresh token) is persisted in plaintext `SharedPreferences` and is eligible
for Android Auto Backup. That is a real production blocker, and it is
reported as the top item — but it is not a demo-scope compromise.

---

## 1. Findings

### MEDIUM — Supabase session (access + refresh token) is persisted in plaintext `SharedPreferences`, and app data is eligible for Android Auto Backup

**Location**: `lib/data/auth/supabase_auth_api_impl.dart:26-33`;
`android/app/src/main/AndroidManifest.xml:5-8`;
`~/AppData/Local/Pub/Cache/hosted/pub.dev/supabase_flutter-2.16.0/lib/src/supabase.dart:126-132`

**Issue**: `initializeSupabase` passes
`FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce, detectSessionInUri: true)`
and **no `localStorage`**. `supabase_flutter` 2.16.0 then defaults the
persistence backend to `SharedPreferencesLocalStorage` with key
`sb-<project-ref>-auth-token` (`supabase.dart:126-132`), and writes the whole
serialized `Session` — `access_token`, `refresh_token`, `provider_token`,
`expires_at`, user object — into plaintext `SharedPreferences`
(`supabase_auth.dart:189`, `local_storage.dart` `persistSession`). Nothing in
`lib/` overrides this with `flutter_secure_storage` or `EmptyLocalStorage`;
`grep -rn "localStorage" lib/` returns exactly one hit (the `authOptions`
constructor above). Separately, `AndroidManifest.xml` declares `<application>`
with no `android:allowBackup`, no `android:fullBackupContent` and no
`android:dataExtractionRules`, so the platform default (`allowBackup=true`)
applies and the `shared_prefs` XML holding the refresh token is in scope for
Auto Backup / device-to-device transfer. `ios/Runner/Info.plist` has no
backup exclusion either (iOS `NSUserDefaults` is included in iCloud/iTunes
backups unless the app opts out).

**Impact**: A long-lived refresh token is recoverable from a device by any
actor who can read app-private storage: root/jailbreak, an ADB backup on a
debug build, a forensic image, or — with `allowBackup` left on — an
Auto Backup extraction. With the token, an attacker mints fresh access tokens
and reads whatever the victim's RLS grants them. Preconditions: physical or
logical access to the unlocked device's storage. On a stock non-rooted device
this is not remotely exploitable, which is why this is MEDIUM and not
CRITICAL. **At production cutover this is a blocker** — legal matter content
under a stolen refresh token is exactly the M9 failure the threat model's
asset table calls "sensitive matter content".

**Fix**: two independent arms, both small.
1. Route session persistence through an encrypted store — pass
   `AuthClientOptions(localStorage: ...)` backed by `flutter_secure_storage`
   (Keystore/Keychain), or accept the shorter-lived posture by persisting only
   the access token and requiring re-auth.
2. Close the backup path:
   `android:allowBackup="false"` plus
   `android:dataExtractionRules="@xml/data_extraction_rules"` /
   `android:fullBackupContent="@xml/backup_rules"` excluding `shared_prefs`;
   and on iOS set the `NSURLIsExcludedFromBackupKey` on the prefs store or
   adopt the encrypted store from arm 1 (which removes the plaintext artifact
   entirely).
   The app's *own* stores are already clean (`lib/data/local/*`,
   `lib/features/notifications/data/shared_preferences_notification_prefs_store.dart`
   persist only locale / theme / active-org id / notification prefs — no PII,
   no tokens), so this fix touches only the provider-owned key.

---

### LOW — The anon-key guard is a runtime check: a service-role key pasted into `.env` is still compiled into the binary before the guard fires

**Location**: `lib/data/auth/supabase_env.dart:63-74`;
`lib/app/service_locator.dart:146-157`

**Issue**: `SupabaseEnv.ensureAnonKey` correctly refuses any key whose JWT
`role` claim is not `anon` — the implementation was read and it does what the
docstring claims (decodes segment 2, requires `role == 'anon'`, throws
`StateError` otherwise; `test/data/auth/supabase_env_test.dart:62-67` pins it).
But the value reaches the app through `String.fromEnvironment`
(`supabase_env.dart:15-18`), which is a **compile-time constant**, and the
guard runs at `configureDependencies` time (`service_locator.dart:150`). So a
service-role key placed in `.env` is baked into the release binary *before*
the guard rejects it. The guard prevents *use*; it does not prevent
*embedding* — and an APK/AAB is trivially decompilable to its string table.
The docstring itself is honest about this ("a configuration guard, not a
security boundary"), so this is a defence-in-depth gap rather than a
misrepresentation.

**Impact**: Only reachable if an operator pastes a privileged key into `.env`
and builds. In that case the app refuses to start (fail-fast, good) but a
service-role key — which bypasses all RLS — ships inside the artifact.
Preconditions: operator error + distribution of the artifact. No demo-scope
impact today (`.env` is git-ignored, `.env.example` is names-only, and no
service-role string exists in tree or history — see §3).

**Fix**: add a build-time/CI assertion so the key never reaches a build:
`grep -E 'eyJ[A-Za-z0-9_-]{10,}' .env` decoded and checked for `role=anon` in
the release pipeline (or a `dart run` pre-build script), and document "never
put a service-role key in `.env`" in the release checklist. Keep the runtime
guard as the second layer.

---

### LOW — Inconsistent defensive parsing of PostgREST rows across the data gateways

**Location**: `lib/data/orgs/supabase_membership_repository.dart:62,73`;
`lib/data/orgs/supabase_organization_gateway.dart:238-266`;
`lib/data/admin/supabase_platform_admin_gateway.dart:146-184`;
`lib/data/matters/supabase_matter_gateway.dart:129-139`
(contrast the correct pattern at `lib/data/storage/supabase_storage_gateway.dart:55-94`)

**Issue**: `SupabaseStorageGateway._fileFromRow` guards every field with
`is! String` / `is! int` checks and raises a typed `FormatException` that the
gateway maps to a redaction-safe `AppError` — the right shape. Most sibling
gateways instead do bare casts: `row['role'] as String?`,
`row['organization_id'] as String`,
`DateTime.parse(row['created_at'] as String).toLocal()`. If a column arrives
with an unexpected type (or `created_at` is null), Dart throws an
`_TypeError` / `FormatException` that is **not** in the gateway's `on ...`
catch list, so it escapes the `Result`/`ViewState` boundary and surfaces as an
unhandled error rather than a typed failure. Enum and date parsing *are*
defensive where it matters most — `userRoleFromServerName`
(`lib/core/organizations/organization_models.dart:20-27`) and
`membershipStatusFromServerName` return `null` on unknown values and the
repository drops the row loudly
(`supabase_membership_repository.dart:63-84`) — so the gap is narrow.

**Impact**: Very low. The rows come from the app's own schema-typed Postgres
tables behind RLS; there is no client-controlled path to a malformed payload,
so this is provider-drift robustness, not an injection or bypass. It is listed
because the prompt asked specifically about unsafe deserialization, and
because a future backend migration could turn it into a user-visible crash.

**Fix**: adopt the `supabase_storage_gateway.dart` guarded-read pattern (or a
small `String? asString(row, key)` helper) in the remaining gateways, and add
the thrown type to each `on` clause.

---

### LOW — The "Continue as demo" affordance is rendered on a configured build, where it always fails

**Location**: `lib/features/auth/presentation/sign_in_screen.dart:110-140`;
`lib/data/auth/supabase_auth_gateway.dart:119-128`

**Issue**: The demo-session button is built unconditionally on the sign-in
screen (it is not gated on `SupabaseEnv.isConfigured`). On a configured build
the tap routes to `SupabaseAuthGateway.startDemoSession`, which **hard-denies**
— `AuthFailure(kind: membershipDenied, message: 'Demo sessions are not
available with a real provider.')`. This is a genuine negative (verified: the
demo path **cannot** grant real access; the only implementation that mints a
session is `FakeAuthGateway.startDemoSession`,
`lib/data/auth/fake_auth_gateway.dart:87-97`, which is registered only when
`env.isConfigured == false` and touches no backend). The residual issue is the
inverse of a bypass: a visible control that always errors, i.e. the project's
own "no false assurance" contract (§4.4 of the threat model) inverted.

**Impact**: None to confidentiality or integrity. A configured-build user
tapping it gets an authentication error snackbar and cannot sign in that way.
Cosmetic/UX plus a small demo-credibility cost.

**Fix**: gate the button on the same env flip that selects the gateway
(`env.isConfigured`), or hide it when a real provider is wired.

---

### LOW — One-time invitation tokens are copied to the system clipboard

**Location**: `lib/features/orgs/presentation/invite_member_sheet.dart:222,240`;
`lib/features/orgs/presentation/member_roster_screen.dart:292`

**Issue**: The partner "copy invite token / copy invite link" actions place a
credential-adjacent value on the OS clipboard
(`Clipboard.setData(ClipboardData(text: token))`). The clipboard is readable
by other apps on Android < 13 (and by clipboard-history / cloud-keyboard
features on both platforms), so the one-time token can outlive the app's
in-memory handling. This is the same class as F-06 (token in a deep-link URL,
`docs/p4_findings_register_2026-08-09.md` F-06) but a *different* channel —
F-06 covers the URL, not the clipboard.

**Impact**: Low. The token is single-use, sha-256-hashed at rest, 7-day
expiry, and requires the invitee's GoTrue `email` claim to match
(`supabase/rpc/accept_invitation.sql:36-44`), so a clipboard leak has a narrow
window and a bound blast radius. Preconditions: another app on the device
reads the clipboard before it is cleared, or the user pastes it somewhere
durable.

**Fix**: after copy, show the token in a non-persistent sheet instead of the
clipboard, or clear the clipboard on a short timer
(`Clipboard.setData(ClipboardData(text: ''))`) and state the exposure in the
accept-deeplink scope note alongside F-06. Long term, the F-06 fix
(server-issued short-lived code) removes both channels at once.

---

### LOW — CI actions are tag-pinned, not SHA-pinned

**Location**: `.github/workflows/ci.yml:42,72`;
`.github/workflows/ledger-selftest.yml:41`

**Issue**: `actions/checkout@v5` and `subosito/flutter-action@v2` are pinned
to mutable tags rather than commit SHAs. A compromised or retargeted tag
would execute in CI. Mitigating context that keeps this LOW: both workflows
declare `permissions: contents: read` (`ci.yml:27-28`,
`ledger-selftest.yml:30-31`), reference **no secrets**, and contain **no
build/deploy/publish/sign/release step** (`ci.yml:14`, `ledger-selftest.yml:14`
say so explicitly), so the worst case is a poisoned build in a read-only job.

**Impact**: Supply-chain risk with a read-only blast radius and no credential
to steal. Preconditions: GitHub Actions tag compromise or upstream account
takeover.

**Fix**: pin to full commit SHAs with a `# vX.Y.Z` comment and let Dependabot
bump them. While here: `pubspec.yaml`'s Flutter constraint was loosened from
an exact `3.44.4` pin to `>=3.44.4 <4.0.0` in the working tree while CI still
pins `flutter-version: '3.44.4'` — a reproducibility drift worth a decision,
though `pubspec.lock` is committed (good) and the Dart SDK constraint is still
narrow.

---

### INFO — Malformed storage path segments raise a Postgres cast error rather than evaluating false

**Location**: `supabase/policies/storage_objects.sql:34`

**Issue**: `public.is_active_member((storage.foldername(name))[1]::uuid)` casts
a path segment to `uuid`. If the first segment is not a UUID, Postgres raises
`invalid input syntax for type uuid`, which aborts the statement instead of
the policy evaluating to `false`. The policy comment claims malformed paths are
"denied for every role", and functionally they are (the request fails), but
the mechanism is an error, not a clean deny.

**Impact**: None to confidentiality — no row is returned and the object is
private. A self-inflicted 400 only, and only for a path the caller constructed.

**Fix**: none required; optionally wrap in a safe-cast helper
(`try_parse_uuid`) if a clean denial is wanted. Recorded for completeness.

---

### INFO — Harness apply-order couples the un-audited INSERT path's removal to one file's position

**Location**: `scripts/verify_policy_tests.sh:280-312`;
`supabase/policies/messages_insert.sql:39-58`;
`supabase/rpc/send_message.sql:90-91`

**Issue**: The rehearsal apply loop applies `policies/*.sql` alphabetically
(creating `grant insert on public.messages` + `messages_insert_assigned`) and
then `rpc/*.sql`, where `send_message.sql` performs the D-SM3 revocation
(`revoke insert ... ; drop policy if exists messages_insert_assigned ...`).
The end state is correct, and batteries 09.15/09.16 pin both halves
(privilege-layer deny + policy-gone), so a regression *is* caught. The
fragility is that the revocation lives in a file whose name determines when it
runs.

**Impact**: None today — the battery is the safety net. Noted so a future
rename/reorder of `send_message.sql` is recognised as security-relevant.

**Fix**: none required. Optionally add a comment to `messages_insert.sql`
naming `rpc/send_message.sql` as the required post-apply revocation (the file
header already says "REVOKED by the send-message D-SM3 slice").

---

## 2. Verified negatives (claims checked and *not* reproducible as findings)

Each of these was a specific hypothesis from the brief; each was opened and
refuted. Recording them so the consolidated report does not have to re-derive
them.

| Hypothesis | Result | Evidence |
|---|---|---|
| Client can grant itself a role / org / owner flag | **Refuted** — roles are server-owned. `create_organization` makes the caller partner in-RPC; `accept_invitation` uses the invitation's stored role; `platform_config` has no client grant and no policy. | `supabase/rpc/create_organization.sql`, `accept_invitation.sql:46-49`, `supabase/policies/platform_config.sql` |
| A client-supplied `org_id`/`role` is trusted for an authorization decision | **Refuted** — every RPC re-derives from `auth.uid()` + membership. `create_matter` calls `has_org_role(p_organization_id,'partner')` *inside* the body and validates each assignee is an active member of that org. | `supabase/rpc/create_matter.sql:11-38` |
| `SECURITY DEFINER` function without a membership check | **Refuted** — all 20 client-EXECUTE RPCs carry an in-body gate (`is_platform_owner()` / `has_org_role(...)` / `is_active_member(...)` / self-only). Trigger-invoked definer helpers (`write_audit`, `expire_stale_invitations`, `handle_new_user`, `refuse_platform_owner_assignment`, `mirror_audit_to_notifications`) are EXECUTE-revoked from `public, anon, authenticated`. | `supabase/migrations/02_rls_functions.sql:126-141`; `scripts/verify_policy_tests.sh:412-418` |
| A table without RLS | **Refuted** — 13 `create table`, 13 `alter table ... enable row level security`, exact 1:1 match. | grep over `supabase/` (§ below) |
| A policy with `using (true)` or a missing policy | **Refuted** — zero `using (true)` / `with check (true)` matches; the two intentional no-policy files (`audit_events.sql`, `platform_config.sql`) have no client grant either, so default-deny holds. | `supabase/policies/*.sql` |
| PostgREST/RPC injection via interpolated filters | **Refuted** — no `.eq()/.or()/.filter()/.from()/.rpc()` call interpolates a value; all use the typed builder (`query.eq(filterColumn, filterValue)`). | `lib/data/list_query_guards.dart:56-66`; grep for `.from('$` / `.eq('$` returns nothing |
| SQL injection in `supabase/` functions | **Refuted** — no dynamic `EXECUTE` of client input; all SQL is static PL/pgSQL with bound parameters. `format()` is not used. | grep `execute format`, `EXECUTE '` over `supabase/` |
| Storage path traversal in object keys | **Refuted** — the policy parses `storage.foldername(name)[1..2]`, requires segment 2 to resolve to a matter and segment 1 to equal that matter's authoritative org. `..` fails the UUID/equality test. The client is metadata-only (no download path exists, D-STR9). | `supabase/policies/storage_objects.sql:30-45`; `lib/data/storage/supabase_storage_gateway.dart:14-15` |
| Deep-link open redirect / unvalidated redirect param | **Refuted** — `AppLinkParser.parse` classifies by scheme/host only and accepts no redirect target. The auth callback is deliberately *not* consumed by the app (left to supabase_flutter's PKCE observer). | `lib/app/deep_link/app_link_parser.dart:86-104`; `lib/app/deep_link/app_link_listener.dart:62-70` |
| `startDemoSession` grants real access | **Refuted** — the only provider-backed implementation returns a hard failure; the session-minting fake is registered only when the build is unconfigured and touches no backend. | `lib/data/auth/supabase_auth_gateway.dart:119-128`; `lib/app/service_locator.dart:146-165`; `lib/data/auth/fake_auth_gateway.dart:87-97` |
| Sign-out leaves the persisted session behind | **Refuted** — GoTrue's `signedOut` event calls `_localStorage.removePersistedSession()`; `AuthCubit.signOut` also bumps `_hydrationEpoch` so a late-resolving membership refresh cannot re-emit an authenticated state. | `supabase_flutter-2.16.0/lib/src/supabase_auth.dart:185-192`; `lib/features/auth/presentation/auth_cubit.dart:352-367` |
| `shared_preferences` holds PII | **Refuted for the app's own stores** — locale, theme mode, active-org id and notification prefs only. The exposure is the provider's session key (finding 1). | `lib/data/local/*`, `lib/features/notifications/data/shared_preferences_notification_prefs_store.dart` |
| `toString()` on sensitive models leaks fields | **Refuted** — `Equatable.toString()` returns `'$runtimeType'` unless `EquatableConfig.stringify` is true; it is never set, so `InviteResult{email,token}` and `Message{body}` print only the type name. `BookingRequest` additionally overrides to `'[REDACTED]'`. | `equatable-2.1.0/lib/src/equatable.dart:60-66`; grep `EquatableConfig` → 0 hits; `lib/features/booking/domain/booking_request.dart:53` |
| Provider error text reaches the UI | **Refuted for the auth surfaces** — the sign-in screen shows a localized generic notice (`l10n.signInErrorNotice`), and recovery re-wraps every failure to `l10n.recoveryErrorNotice` (non-enumerating). `technicalMessage` is retained for diagnostics only. | `lib/features/auth/presentation/sign_in_screen.dart:60-68`; `.../forgot_password/recovery_error_localizer.dart:14-24` |
| `is_platform_owner()` probe surface | **Refuted** — EXECUTE revoked from `public, anon, authenticated`; capability is never client-readable. | `supabase/migrations/02_rls_functions.sql:141` |
| Audit rows forgeable by a client | **Refuted** — `audit_events` has no grant and no policy; `write_audit` is EXECUTE-revoked; the only write path is definer context. | `supabase/policies/audit_events.sql`; `02_rls_functions.sql:126-128` |

### Secret scan (tree + full history)

- **Tree:** no JWT (`eyJ…`), no `service_role` key literal, no private-key
  block, no cloud access key, no non-placeholder DB credential. The only
  `postgresql://` strings in the tree are the documented rehearsal placeholders
  (`postgresql://postgres:***@host:5432/postgres` in `supabase/README.md:146-147`,
  `scripts/verify_policy_tests.sh:100`, `scripts/verify_provider_loop.sh:40`)
  and loopback URLs with the Supabase CLI's default local password
  (`postgres:postgres@127.0.0.1:5432/54322/55432`) inside `docs/*_rehearsal_*`
  evidence files — standard local-dev credentials, not secrets.
- **History:** `git log --all -S"eyJ"` → **0 commits**. `git log --all -S"service_role_key"`
  → 0. `git log --all --diff-filter=A --name-only` shows `.env.example` as the
  only `.env*` file ever added; `.env` was never tracked. No secret was
  committed and later removed.
- **Ignore rules:** `.gitignore:48-55` covers `.env`, `.env.*`, `*.env`,
  `*.env.*` with `!.env.example` / `!*.env.example` re-includes.
  `git check-ignore -v` confirms `.env` → `.gitignore:51` and
  `supabase/.temp/pooler-url` → `.gitignore:69`. The local
  `supabase/.temp/pooler-url` contains a pooler host + project ref and **no
  password**; it is untracked and ignored.
- **CI:** two workflows, neither references `secrets.*`, neither builds or
  deploys; both declare `permissions: contents: read`.
- **`scripts/`:** the harness reads `SUPABASE_TEST_DB_URL` from the environment
  and refuses to run without it (`verify_policy_tests.sh:696-700`); no
  credential is hardcoded.

### Dependency check

`pubspec.lock` is committed (tracked, currently modified only by the Flutter
SDK constraint line). Direct set: `app_links 7.2.1`, `bloc 9.2.1`,
`equatable 2.1.0`, `flutter_bloc 9.1.1`, `get_it 9.2.1`, `go_router 17.3.0`,
`intl 0.20.2`, `shared_preferences 2.5.5`, `supabase_flutter 2.16.0`
(+ `http 1.6.0`, `mocktail 1.0.5`, `bloc_test 10.0.0` dev-only). 116 locked
packages. Transitive provider stack: `supabase 2.14.0`, `gotrue 2.26.0`,
`postgrest 2.8.0`, `realtime_client 2.11.0`, `storage_client 2.6.0`,
`functions_client 2.6.4`.

One advisory was checked and cleared: **`dart_jsonwebtoken`** (transitive,
pulled by `gotrue`) is locked at **3.4.1**. The published advisory
(AIKIDO-2024-10308 / "insufficient verification of data authenticity — expired
tokens accepted") affects `0.1.0 – 2.14.0`, fixed in `2.14.1`. 3.4.1 is well
past the fix; **not affected**. No other locked package could be tied to a
substantiated advisory from the sources consulted; `pointycastle 4.0.0` (also
transitive) is above the 3.4.0 GCM timing-leak fix. **No dependency finding.**

---

## 3. OWASP Mobile Top 10 mapping

| # | Category | Verdict for this app |
|---|---|---|
| M1 | Improper credential usage | **Mostly N/A.** No custom credential handling: GoTrue owns sign-in/reset/OTP, the client drops tokens at the seam (`supabase_auth_api_impl.dart:283-309`), and the anon key is the only credential in the build. Residual: the runtime-only anon-key guard (LOW finding) and the persisted session (MEDIUM finding). |
| M2 | Inadequate supply-chain security | **Low.** Committed lockfile, 11 direct deps, no new packages per slice; one advisory checked and cleared. Residual: tag-pinned CI actions (LOW finding). |
| M3 | Insecure authentication/authorization | **Strong.** Server-authoritative roles, default-deny RLS on all 13 tables, 20 RPCs with in-body gates, positive+negative battery coverage. MFA/SSO deferred (D-07) — accepted risk, not a defect. |
| M4 | Insufficient input/output validation | **Low.** No injection sink; enums/statuses parsed defensively; error output localized and non-enumerating. Residual: uneven row-cast guarding (LOW finding). |
| M5 | Insecure communication | **N/A / clean.** No `http://` in `lib/`, no `usesCleartextTraffic`, no ATS exception in `Info.plist`; provider endpoints are HTTPS. |
| M6 | Inadequate privacy controls | **Low–Medium.** `Redactor` + `toRedactedMap` + ADR-0003 cover auth PII; audit summaries are generic; no PII in the app's own prefs. Residual: the session token at rest and its backup eligibility (MEDIUM finding). |
| M7 | Insufficient binary protections | **Not assessed / expected gap.** No obfuscation flags, no `FLAG_SECURE`, no root/jailbreak detection. For a demo-scoped client with synthetic data this is appropriately deferred; it becomes a real item at production. (Release build config under `android/` was out of the audit's scope per the brief.) |
| M8 | Security misconfiguration | **Low.** `AndroidManifest` is minimal (INTERNET only, one exported launcher/deep-link activity, no backup rules); `Info.plist` declares no unnecessary permissions and no ATS relaxation. Residual: `allowBackup` default (folded into the MEDIUM finding) and the runtime-only anon-key guard (LOW finding). |
| M9 | Insecure data storage | **Weakest category.** The refresh token lands in plaintext `SharedPreferences`; no secure storage is wired (MEDIUM finding). The app's own stores are clean, which is why this is one finding and not a pattern. |
| M10 | Insufficient cryptography | **N/A.** No custom crypto. Invitation tokens use 32 random bytes + sha-256 hashing at rest (`supabase/rpc/invite_member.sql:59-72`); PKCE is used for the auth callback; hashing/JWT verification is provider-owned. |

---

## 4. Accepted risks / documented deferrals

These look like findings but are owner-approved, dated deviations — cite and
do not re-raise without new evidence.

| Item | Where documented |
|---|---|
| MFA/SSO/passwordless deferred; the single `platform_owner_admin` account is the highest-value target | `docs/p0_decision_capture.md` D-07; `docs/p4_findings_register_2026-08-09.md` F-02 — **ACCEPTED (demo-posture, 2026-08-09, Project Owner)** |
| No throttling beyond GoTrue defaults | F-07 — **ACCEPTED (demo-posture)**; provider limits recorded 2026-08-10 (`docs/f10_provider_posture_probes_2026-08-10.md` V-F10-4) |
| Invite emails not shipped; one-time token delivered out-of-band by the inviter | F-05 — **ACCEPTED (demo-posture)** |
| Accept-invite one-time token rides in a deep-link URL | F-06 — **OPEN, recorded Low** (the clipboard channel in this report is the adjacent, previously unrecorded half) |
| Signed-URL TTL window after membership removal | F-03 / D-STR4 — **ACCEPTED** |
| Denied RPC attempts are not written as `denied` audit rows (deliberate, no probe noise) | F-08 — **ACCEPTED** (pinned by battery 10.09) |
| Demo client accounts hold no membership rows (0-everything reads by design) | F-09 — **ACCEPTED as designed** |
| Self-scoped helpers (`is_active_member`, `has_org_role`) exposed as PostgREST `/rpc/` endpoints | F-11 — **ACCEPTED (safe today, `auth.uid()`-self-scoped)**; standing RLS-gate review criterion |
| Owner-deny on content tables is an operational invariant, not a policy clause | F-01 — chain **CLOSED 2026-08-09** (RPC refusal + categorical `BEFORE INSERT OR UPDATE` trigger + batteries 12/13); F-12 dev-data violation **RESOLVED 2026-08-09** |
| Realtime delivery proven by RLS proxy, not a live websocket round-trip | F-04 — **OPEN (verification gap, not a defect)** |
| AI / video consultation / real payments have no threat surface yet | D-07/D-08, D-15, D-11 — deferred |
| No backend package added before P0 closes | `docs/adr/0007-no-backend-until-p0-closes.md` |
| Flutter constraint loosened to a range in the working tree | in-flight change; CI still pins 3.44.4 — recorded in the LOW CI finding, not a deferral |

---

## 5. What's done well (preserve)

1. **Default-deny RLS with a real positive+negative battery.** 13 tables,
   13 `enable row level security`, zero `using (true)`, and every content
   policy carries the load-bearing org-equality clause
   (`matters.sql:22-27`, `documents.sql:31`, `message_threads.sql:32`,
   `messages.sql:34`, `files.sql:33`, `invoices.sql:34`,
   `storage_objects.sql:30-45`). The batteries
   (`supabase/tests/01…16`) impersonate roles via
   `set_config('request.jwt.claim.sub'…)` and assert both allow and deny rows,
   with the harness pinning the structural surface
   (`scripts/verify_policy_tests.sh` §1a–§1g). This is well above demo-grade.
2. **Server-side authorization is genuinely server-side.** Every one of the
   20 client-EXECUTE RPCs re-derives authority from `auth.uid()` inside the
   definer body — `create_matter` re-checks the partner gate and validates each
   assignee against live memberships (`supabase/rpc/create_matter.sql:11-38`),
   `accept_invitation` binds the server-owned role and matches the JWT email
   claim (`accept_invitation.sql:36-49`), and `write_audit` is unreachable from
   the client so audit rows cannot be forged
   (`02_rls_functions.sql:126-128`). A client-supplied `org_id` is a routing
   hint and nothing more, exactly as the contract requires.
3. **The anon-key guard is real and fail-fast.** `SupabaseEnv.ensureAnonKey`
   (`lib/data/auth/supabase_env.dart:63-74`) decodes the JWT and refuses any
   non-`anon` role at `configureDependencies` time
   (`lib/app/service_locator.dart:150`), with unit coverage for the
   `service_role` and undecodable cases
   (`test/data/auth/supabase_env_test.dart:54-72`). It is honest about being a
   configuration guard rather than a security boundary.
4. **A disciplined privacy seam.** `SupabaseAuthApiImpl` is the only file that
   imports provider auth types and it deliberately drops access/refresh tokens
   and GoTrue exceptions at the boundary
   (`supabase_auth_api_impl.dart:36-42,283-309`); `Redactor`
   (`lib/core/observability/error_reporter.dart:11-58`) masks
   password/otp/token/authorization/secret/anon_key/email/phone keys and
   regex-scrubs emails and `Bearer` values from free text; `toRedactedMap` is
   applied to the three PII-carrying request VOs under ADR-0003.
5. **A destructive-test guard on the shared dev project.**
   `scripts/verify_policy_tests.sh:696-713` refuses to run if
   `SUPABASE_TEST_DB_URL` points at the known dev project ref (the fixtures
   `DELETE from auth.users` / `platform_config`), requiring an explicit
   `ALLOW_DEV_PROJECT=1` override. That is a rare and genuinely good control.
6. **Least-privilege CI with no secrets.** `permissions: contents: read`, no
   `secrets.*` reference, no build/deploy/sign step, and two repo-local static
   gates (ledger + policy battery `--check`) that run before the toolchain
   (`.github/workflows/ci.yml`, `ledger-selftest.yml`), with a nightly
   `--selftest` that proves the gates still have teeth.

---

## 6. Dimension score

**Security: 7.5 / 10**

Justification: the strongest aspect is server-side authorization — default-deny
RLS on every table, 20 definer RPCs that re-derive membership from `auth.uid()`
with no client-supplied authority anywhere, and a policy battery that asserts
denials as well as allows, which is materially better than most demo-stage
work and better than much production work. The weakest aspect is client-side
secret-at-rest hygiene: the Supabase refresh token is persisted in plaintext
`SharedPreferences` with no secure-storage backend and app data left eligible
for Android Auto Backup, which is a genuine blocker the moment this points at
production and would then be HIGH. The score reflects a demo-scoped client
judged against what it claims to be: no CRITICAL, no reachable bypass, no
injection, no committed secret (including in full history), and one MEDIUM
storage gap that is a known, cheap fix — with the deduction taken specifically
for that gap and for the runtime-only anon-key guard, both of which must close
before any real-client-data cutover.
