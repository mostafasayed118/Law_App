# Media assets

## Screenshots (generated, reproducible)

The PNGs in `screenshots/` are **generated artifacts**, not manual captures.
They come from the real router/app shell with the credential-free fake
gateways and the app's bundled fonts, at 390×844 logical pixels and
`devicePixelRatio = 3.0`. There is no status bar, no device frame and no
emulator — the same command rerenders every image.

Regenerate all 15 images from the repository root:

```bash
CAPTURE_SCREENSHOTS=1 flutter test test/screenshots --update-goldens
```

PowerShell:

```powershell
$env:CAPTURE_SCREENSHOTS='1'; flutter test test/screenshots --update-goldens
```

The generator is `test/screenshots/capture_screenshots_test.dart`. It is
**skipped** in the default `flutter test` run and in CI (`CAPTURE_SCREENSHOTS`
is unset), so it cannot slow or destabilize the gates. It uses the golden file
comparator purely as a deterministic byte writer; never hand-edit the PNGs.

| File | Surface | Locale / theme |
|---|---|---|
| `01_home.png` | Home dashboard | English / light |
| `02_matters.png` | Matters list | English / light |
| `03_discovery.png` | Attorney directory | English / light |
| `04_messages.png` | Message thread detail | English / light |
| `05_research.png` | AI research (with the not-legal-advice banner) | English / light |
| `06_settings.png` | Settings | English / light |
| `07_library.png` | Library index with category chips | English / light |
| `08_article_reader.png` | Article with a visible highlight and sample badge | English / light |
| `09_saved.png` | Bookmarks / highlights / history | English / light |
| `10_privacy.png` | In-app Privacy Policy | English / light |
| `01_home_ar.png` | Home dashboard | Arabic / RTL light |
| `07_library_ar.png` | Library index | Arabic / RTL light |
| `08_article_reader_ar.png` | Article reader | Arabic / RTL light |
| `01_home_dark.png` | Home dashboard | English / dark |
| `08_article_reader_dark.png` | Article reader | English / dark |

Library screenshots are seeded with one bookmark, one highlight and one
history row so the saved state is populated. All Library rows are **sample
data** (`is_sample = true`) and badged as such in the UI.

## Demo GIF (manual — owner item)

`docs/media/demo.gif`, 30–40 seconds, captured on a phone-shaped emulator or
device from the demo build, downscaled to ~540 px wide and kept under 10 MB.

One continuous take, no cuts:

1. **0–5 s** — Home. Pause so the hierarchy reads.
2. **5–12 s** — Open a matter, land on its detail, scroll once.
3. **12–19 s** — Open Messages, open a thread, type a short message and send it.
4. **19–27 s** — Settings → Language → العربية. Let the UI flip to RTL, hold a beat.
5. **27–35 s** — Open the Library, search, open an article, select a few words
   and create a highlight.
6. **35–40 s** — Toggle dark mode and hold on the reader.

Record with `adb shell screenrecord --time-limit 40 /sdcard/demo.mp4` (or
`scrcpy --record demo.mp4`), pull it, then convert:

```bash
ffmpeg -i demo.mp4 -vf "fps=12,scale=540:-1:flags=lanczos" -loop 0 demo.gif
```

If the GIF is over 10 MB, drop `fps` to 8 before scaling. It is deliberately
not generated here: screen recording is a manual human step, and the README
links to it only once the file exists.

## Rules

- Demo data only. Never capture a real client name, matter title or message.
- No notifications, no battery warnings, no debug banner in frame.
- English and Arabic frames come from the same build and the same seeded state.
- Review every generated PNG by eye before treating a regeneration as done;
  overflow stripes or missing glyphs are real defects, not cosmetic noise.
