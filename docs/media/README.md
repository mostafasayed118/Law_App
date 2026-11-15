# Media capture checklist

Everything the front page needs lives here. The files are **not committed yet**;
capture them, drop them in `screenshots/`, and the README table starts working
with no further edits.

## Target device

| Setting | Value |
|---|---|
| Device | Pixel 7 AVD (or a physical Pixel 7) |
| Resolution | 1080 × 2400, 420 dpi |
| Build | `flutter run --flavor development -t lib/main_development.dart` (demo mode, no `.env`) |
| Locale | English unless noted |
| Theme | Light unless noted |

Run on a phone-shaped AVD, not a tablet — the front page is about the phone
experience, and the tablet story is already proved by the responsive tests.

## The six screenshots

Capture with `adb exec-out screencap -p > <name>.png`, then crop the status bar
if you want a clean edge. Keep the full 1080 × 2400 frame.

| File | Screen | State to capture |
|---|---|---|
| `01_home.png` | Home dashboard | Signed in, demo session, scrolled to the top so the greeting, search field and the first entry cards are visible |
| `02_matters.png` | Matters list | Default filter, at least four matter rows with mixed statuses |
| `03_discovery.png` | Attorney search | A practice-area filter applied so the chips read as active |
| `04_messages.png` | Message thread detail | A thread with three or four messages, composer visible |
| `05_research.png` | AI research | A completed run with two findings, so the "AI-generated, not legal advice" label is in frame |
| `06_settings.png` | Settings | Language, theme, role and session posture all visible |

## Variants

| Requirement | File |
|---|---|
| Arabic, right-to-left | `<name>_ar.png` for `01_home` and `02_matters` — the two most convincing RTL frames |
| Dark mode | `<name>_dark.png` for `01_home` and `04_messages` |

To switch: Settings → Language → العربية, and Settings → Theme → Dark.
Screenshot the **same populated state** you captured in English, otherwise the
comparison reads as two different apps.

## Demo GIF

`docs/media/demo.gif`, 30–40 seconds, 1080 × 2400 captured then downscaled to
~540 px wide so the file stays under ~10 MB.

Script, in one continuous take, no cuts:

1. **0–5 s** — Home. Pause on the dashboard so the hierarchy is readable.
2. **5–12 s** — Tap a matter entry card, land on the matter detail, scroll once.
3. **12–19 s** — Open Messages, open the first thread, type a short message and
   send it.
4. **19–27 s** — Settings → Language → العربية. Let the whole UI flip to RTL and
   stay there for a beat.
5. **27–35 s** — Settings → Theme → Dark. Hold on the dark home screen.

Record with `adb shell screenrecord --time-limit 40 /sdcard/demo.mp4`, pull it,
then convert:

```bash
ffmpeg -i demo.mp4 -vf "fps=12,scale=540:-1:flags=lanczos" -loop 0 demo.gif
```

## Rules

- Demo data only. Never capture a real client name, matter title or message.
- No notifications, no battery warnings, no debug banner in frame.
- English and Arabic frames must come from the same build and the same session.
