# Deep-link release checklist (2026-10-24)

Truth pass for the auth/deep-link audit findings. "Enforced in code" means the
repository now prevents the failure; "owner input" means a value or console
change only the owner can provide.

## 1. What is enforced in code now

| Item | State |
|---|---|
| Session from URI | `initializeSupabase` sets `detectSessionInUri: false`. The provider observer no longer decides which URI may mint a session. |
| Accepted auth callback | `lib/data/auth/auth_callback.dart` accepts **only** `com.legalhub.app://auth/v1/callback` or `https://legalhub.app/auth/v1/callback`, with a non-empty query `code`, no fragment, and no `access_token` / `refresh_token` / `provider_token` / `provider_refresh_token`. |
| Exchange | `lib/data/auth/auth_callback_observer.dart` calls `exchangeCodeForSession` (PKCE-only, verifier-bound) and ignores everything else without logging the URI/code. Started once from `SupabaseAuthApiImpl.bind`. |
| Tests | `test/data/auth/auth_callback_test.dart` pins accept + reject cases (not run in this change; see §7). |
| Android custom scheme | Retained (shipped producers still emit it) but host-scoped to `accept-invite` and `auth`/`/v1/callback`. It remains hijackable by design; see §5 for the removal gate. |
| assetlinks.json | Release/upload keystore SHA-256 filled (see §2). |
| AASA | Intentionally inert (`details: []`) until the Apple Team ID is known (see §3). No invented values. |

## 2. Android App Links — sha256_cert_fingerprints

`web/.well-known/assetlinks.json` now contains:

```
F5:51:AA:06:FF:B1:2A:4A:71:90:E8:64:7E:13:82:51:47:C1:30:BB:6A:51:40:43:AF:92:6A:4A:A2:FB:45:F3
```

Derived from the keystore referenced by `android/key.properties` (the
keystore lives outside the repository) with:

```powershell
# From the repo root. Reads key.properties in memory; prints ONLY the public
# certificate line (never the passwords).
$props = @{}
Get-Content android\key.properties | ForEach-Object {
  if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)$') { $props[$matches[1].Trim()] = $matches[2].Trim() }
}
& keytool -list -v -keystore $props['storeFile'] `
    -storepass $props['storePassword'] -alias $props['keyAlias'] |
  Select-String 'SHA256:'
```

Use Android Studio's JBR `keytool.exe` if `keytool` is not on `PATH`.

**Owner input (Play distribution):** Google Play re-signs with the **app
signing key**, not the upload key. If the store build is distributed by Play,
copy the SHA-256 from Play Console → *Test and release → App integrity → App
signing key certificate* and add it to the `sha256_cert_fingerprints` array
(both fingerprints may coexist). Without it, Play-installed builds fail
`assetlinks` verification.

Deploy `assetlinks.json` to `https://legalhub.app/.well-known/assetlinks.json`
(HTTP 200, `Content-Type: application/json`, no redirects), then verify on a
device:

```bash
curl -sS https://legalhub.app/.well-known/assetlinks.json
adb shell pm get-app-links com.legalhub.app
adb shell pm verify-app-links --re-verify com.legalhub.app
```

Expect `legalhub.app` to report `verified` (Google may re-check
asynchronously).

## 3. iOS Universal Links — Apple Team ID

The Team ID cannot be inferred from the repository, so the AASA file is
deliberately fail-safe and claims nothing:

```json
{ "applinks": { "apps": [], "details": [] } }
```

**Owner input:** the 10-character Apple Developer Team ID (*Apple Developer →
Membership details → Team ID*). Then replace the file with:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "<TEAM_ID>.com.legalhub.app",
        "paths": ["/accept-invite*", "/auth/v1/callback*"]
      }
    ]
  }
}
```

Serve it at `https://legalhub.app/.well-known/apple-app-site-association`
(200, `Content-Type: application/json`, no redirects, **no** `.json`
extension). The production bundle ID is `com.legalhub.app`; add a
`<TEAM_ID>.com.legalhub.app.dev` entry only if dev universal links are wanted.

## 4. Supabase redirect allowlist

Authentication → URL Configuration → Redirect URLs must include:

- `com.legalhub.app://auth/v1/callback` — current recovery target; keep it
  while the custom-scheme filters exist.
- `https://legalhub.app/auth/v1/callback` — required **before** switching the
  recovery target to https (see §5).

The Site URL is not a redirect target. A missing allowlist entry makes the
recovery email inert.

## 5. Removing the custom-scheme filters (gated)

The custom scheme is **not** development-only today: the accept-invite share
link (`AppLinkParser.acceptInviteUri`) and the recovery `emailRedirectTo` still
target it. Removing the filters now would break both. Sequence:

1. Deploy `assetlinks.json` with every signing certificate (upload + Play app
   signing) and confirm `verified`.
2. Add `https://legalhub.app/auth/v1/callback` to the Supabase allowlist.
3. Switch producers to https: use `AppLinkParser.acceptInviteHttpsUri` for the
   share link and change `_recoveryDeepLinkUri` to the https callback. Ship
   and smoke-test both links on a device.
4. Then remove the two custom-scheme `<intent-filter>` blocks from the
   **production** variant (a production-only manifest overlay with
   `tools:node="remove"`, or simply delete them once dev has its own overlay).
   Keep the development flavor's scheme so the daily loop is unaffected.
5. The validator's custom-scheme branch can stay only while a flavor still
   registers that scheme; once production's filters are gone, the production
   app no longer receives those URIs at all.

## 6. Residual risk / what is still owner input

- Apple Team ID (blocks Universal Links; AASA stays inert until provided).
- Play App Signing SHA-256 (blocks Play-installed App Links if omitted).
- Deploy the two `.well-known` files and confirm the Android verification.
- Custom-scheme interception remains possible until §5 completes (the scheme
  can launch the app, but the PKCE verifier check means an injected `code`
  cannot mint a session; injected implicit tokens/fragments are rejected).
- iOS still declares the custom URL scheme in `ios/Runner/Info.plist`
  (outside this change); the same PKCE-only accept rule applies.

## 7. Not verified in this change

- `flutter analyze` / `flutter test` were intentionally not run (brief
  constraint); the new pure test has not been executed.
- No on-device replay of `assetlinks` verification, warm/cold recovery, or
  accept-invite links.
- `assetlinks.json` is a repository file only; it is not deployed by this
  change.
