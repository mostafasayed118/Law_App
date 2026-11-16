# v1.0.0-portfolio — release notes

A portfolio release of LegalHub. This is a **demo build**: install it, open it,
and click through every screen without an account, a `.env` file or a backend.

## What it is

LegalHub is a Flutter + Supabase legal practice-management platform with a
Legal Library. The app ships matters, a document vault, secure messaging,
consultation booking, invoicing, approvals, compliance alerts, video and AI
research surfaces, and a library with search, bookmarks, highlights and
reading history. English, Arabic (RTL) and Turkish are supported.

## Install the demo APK

Asset: `LegalHub-development-demo.apk` (development flavor, debug-signed).

```bash
adb install -r LegalHub-development-demo.apk
```

Minimum Android version is set by the project's `minSdk` (Android 21+). The
APK carries `arm64-v8a`, `armeabi-v7a` and `x86_64` libraries, so it runs on
phones and on most x86 emulators.

- SHA-256: `9503568EE8C393495C2D820BFE2728D4E9B96ED98578B20C8C125DEAE38F292B`
- Size: 240,250,909 bytes
- Built with: `flutter build apk --debug --flavor development -t lib/main_development.dart`
- Signing: Android debug key only. **No store key, no real signing credential.**

## Demo versus real

| In this APK | Not in this APK |
|---|---|
| Credential-free fake gateways; seeded deterministic data | Connection to any Supabase project |
| Legal Library sample corpus, every row badged `Sample content` | Official legal text (owner supplies it through the importer) |
| Provider-gated demo screens for payments, AI research and video | Live Paymob / AI / LiveKit accounts |
| In-app privacy policy and terms drafts | Owner contact details and governing law (`LegalConfig` placeholders) |

## Known limitations

- Account deletion is **partial**: it removes app-owned identity, profile,
  memberships, library rows and the caller's uploaded files, but not
  provider-side records. The UI says this before confirmation (ADR-0011).
- Push delivery, offline outbox, iOS release and live payments are not done.
- Migrations 32–34 are not applied to any live project by this repository's
  automation; applying them to dev is an owner action.
- The privacy and terms drafts require review by qualified counsel and an
  owner-filled `LegalConfig` before production use.

## Reproduce from source

```bash
flutter pub get
flutter run --flavor development -t lib/main_development.dart
```

Full verification commands are in [`docs/DEEP_DIVE.md`](docs/DEEP_DIVE.md).
Screenshots are regenerated with the command in [`docs/media/README.md`](docs/media/README.md).
