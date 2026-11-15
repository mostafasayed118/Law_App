# Verified links — current state

Android App Links and iOS Universal Links only work after these files are
served over HTTPS from `https://legalhub.app/.well-known/`. **That domain does
not serve them today**, so the `com.legalhub.app://` custom scheme remains the
only working entry point. This directory is the source of truth that gets
deployed once hosting exists; it is not a live deployment.

| File | State |
|---|---|
| `assetlinks.json` | **Real.** Carries the release-keystore SHA-256 fingerprint for `com.legalhub.app`. Ready to deploy as-is. |
| `apple-app-site-association` | **Intentionally empty.** `details: []` because the app has no Apple Developer Team ID and no signed iOS build — see `README.md` → Deferred work. Emptying the details list is deliberate: a stub that names a Team ID that does not exist would make iOS silently fail verification instead of failing closed. |

## What is still required

1. **Host this directory** at `https://legalhub.app/.well-known/`, served as
   `application/json`. `apple-app-site-association` must be served **without a
   file extension**.
2. **Fill `apple-app-site-association`** with `appID: <TEAM_ID>.com.legalhub.app`
   and the `/accept-invite*`, `/auth/v1/callback*` paths once an Apple Team ID
   exists.
3. **Rotate the fingerprint** in `assetlinks.json` if the release keystore
   changes — the current value belongs to the upload keystore recorded in
   `docs/audit/LegalHub_AUDIT_2026-09-21.md` §12.19.
4. **Verify on device:**
   - Android: `adb shell pm verify-app-links --re-verify com.legalhub.app`
   - iOS: `swcutil verify -d legalhub.app`

Until step 1 lands, the custom-scheme intent filters in
`android/app/src/main/AndroidManifest.xml` carry the documented hijack risk
described in `docs/deep_link_release_checklist.md`.
