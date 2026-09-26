# Verified links — owner deploy steps

The app accepts OS-verified links only after these files are served from
`https://legalhub.app/.well-known/` (until then the `com.legalhub.app://`
custom scheme remains the working fallback).

1. `assetlinks.json`: replace `REPLACE_WITH_RELEASE_SHA256_FINGERPRINT`
   with the release keystore fingerprint:
   `keytool -list -v -keystore <release.keystore> | grep SHA256`.
   Serve as `application/json`.
2. `apple-app-site-association`: replace `REPLACE_WITH_TEAM_ID` with the
   Apple Developer Team ID. Serve **without** a file extension and as
   `application/json` (iOS ignores it with the wrong content type).
3. Verify: Android `adb shell pm verify-app-links --re-verify
   com.legalhub.app`; iOS `swcutil verify -d legalhub.app`.
