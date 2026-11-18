# LegalHub — Next wave verification report

Owner GO run, 2026-11-18. Branch `feat/legalhub-next-wave` (tasks 1–3 were already implemented; this run verifies them, completes task 4 and records the result). No re-implementation of conflict flows.

## 1. Pre-flight

| Check | Measured |
|---|---|
| `git fetch origin` | OK |
| `main` local / origin | `56f9599314f7fa4b9a151bbc1ea0d6528a29fc7d` (both) |
| PR #23 | `MERGED`, `mergedAt=2026-11-18T11:42:21Z` (verified in prior pre-flight) |
| Branch tip | `1a5d78322ebd673337ad73ee4c0af6b96b9b3293` |
| Tree | clean (`## feat/legalhub-next-wave`) |
| `flutter --version` (PATH) | 3.47.5 — global SDK left untouched (has unrelated local modifications) |
| `flutter --version` (FVM 3.50) | **3.50.0 / Dart 3.14.0** — SDK used for all gates in this run |
| Baseline (reviewer, re-measured here) | format 834/0 → now 836/0 (+2 new test files); analyze 0; tests 2,442/13/0 → now 2,447/13/0; coverage 83.7534 % (21,820/18,275) → now 84.6016 % (21,827/18,466) |

## 2. Task 1 — Flutter 3.50 migration (verified DONE)

- Version before: Flutter 3.47.5 / Dart 3.13.4. After: **Flutter 3.50.0 / Dart 3.14.0**, installed in the pre-existing FVM cache (`C:\Users\ASUS\fvm\versions\3.50.0`); no `.fvmrc` created, global SDK untouched.
- Pins verified: `.github/workflows/ci.yml` `flutter-version: '3.50.0'` (3 jobs), `pubspec.yaml` `flutter: '>=3.50.0 <4.0.0'`, README badge `Flutter-3.50.0`.
- `flutter analyze` on 3.50: **0 issues, 0 deprecation diagnostics**.
- Deprecations fixed in commit `390b331` (full diff reviewed): `package:flutter/material.dart` → `package:material_ui/material_ui.dart` in 234 Dart files (e.g. `lib/app/legalhub_theme.dart:1`); `lib/l10n/app_localizations.dart:91-92` global delegates re-imported from `material_ui` / `cupertino_ui` after generation; 222 `directives_ordering` fixes. Three 3.50-only test-harness adjustments (font-change callback flush in `capture_screenshots_test.dart`, offstage assertion + no font load in `research_capture_fixture_test.dart`, two awaited `unregister` calls).
- Dependency bumps (all required by 3.50, recorded before→after): `material_ui none→^1.10.0` (resolved 1.11.1), `cupertino_ui none→^1.1.6` (resolved 1.1.7); transitive `_fe_analyzer_shared 99.0.0→111.0.0`, `analyzer 12.1.0→14.7.0`, `clock 1.1.2→1.1.3`, `listen none→1.0.1`, `stack_trace 1.12.1→1.12.2`, `test 1.31.1→1.32.0`, `test_api 0.7.12→0.7.14`, `test_core 0.6.18→0.6.20`. Reason: 3.50 SDK constraint + standalone design-widget packages.
- Golden verification under 3.50: **4 pins fail** (`test/golden/breakpoint_golden_test.dart`: `home at 1024 (rail)`, `home at 320`, `matters two-pane at 1024`, `messages two-pane at 1024`). NOT regenerated locally; generated failure PNGs removed. Owner must regenerate via the CI workflow before merge.

## 3. Task 2 — coverage ≥84.5 % (verified DONE)

- Before (this branch after migration): LF=21,821 LH=18,276 = 83.7542 %; required LH ≥ 18,439.
- After: LF=21,827 LH=18,466 = **84.6016 %** (final re-measurement, target exceeded).
- Least-covered production files measured at the time: `delete_account_sheet.dart` 1/82, `highlight_editor_sheet.dart` 2/78, `supabase_library_user_data_api_impl.dart` 0/71, `supabase_compliance_api_impl.dart` 0/42, `supabase_approval_api_impl.dart` 0/40, `supabase_library_api_impl.dart` 0/27, `supabase_matter_write_gateway.dart` 1/27, `fake_attorney_admin_gateway.dart` 2/41, `file_selector_file_picker.dart` 1/16, `supabase_password_api_impl.dart` 0/12.
- Tests added (4, in `test/features/coverage/high_risk_sheets_test.dart`): *highlight editor saves a chosen colour and trimmed note*; *highlight editor hides delete when not allowed*; *highlight editor delete path honours confirmation*; *delete-account sheet explains limits and gates submit on DELETE*. No production code, exclusions, or test deletions used to move coverage.

## 4. Task 3 — localized LegalConfig date (verified DONE)

- RED test `507446d` (`test/legal/legal_date_localization_test.dart`) failed on the raw ISO string before the fix, passed after.
- Only render site: `lib/features/legal/presentation/legal_document_screen.dart:114-121`, now `formatMediumDate(l10n, DateTime.parse(LegalConfig.lastUpdated))`.
- Stored values verified unchanged: `AL-3TAR`, `al3rar401@gmail.com`, `2026-11-17`, `Laws of Egypt`. No new ARB keys.
- Rendered strings (measured): en `Nov 17, 2026`; ar `١٧ نوفمبر ٢٠٢٦`; tr `17 Kas 2026`. Widget test covers all three and asserts the raw ISO string is absent.
- Only PNG changed between `main` and branch tip: `docs/media/screenshots/10_privacy.png` (visually verified: `Last updated: Nov 17, 2026`). RTL visual screenshot inspection NOT VERIFIED — headless `toImage` capture timed out; the RTL widget test passed.

## 5. Gates after (exact commands, Flutter 3.50.0)

| Gate | Command | Measured |
|---|---|---|
| Format | `dart format --output=none --set-exit-if-changed .` | 836 files, 0 changed |
| Analyze | `flutter analyze` | 0 issues |
| Tests | `flutter test` | 2,447 passed / 13 skipped / 0 failed |
| Coverage | `flutter test --coverage` + lcov sum | LF=21,827 LH=18,466 → 84.6016 % |
| Ledger | `bash scripts/verify_ledger.sh` | 115 passed, PASS |
| ARB | `bash scripts/verify_arb_parity.sh` | en=1,074 ar=1,074 tr=1,074, PASS |
| Policy | `bash scripts/verify_policy_tests.sh --check` | 126 passed, PASS |

Pins re-verified in README / DEEP_DIVE: 2,420 declarations / 2,447 runtime / 84.60 %. The 27-case gap is expected, not a stale pin: the ledger counts **source declaration lines** (`git grep -hE '(test|testWidgets|blocTest)\(' -- test/` plus `blocTest<`), while `flutter test` counts **instantiated runtime cases**. Several suites generate multiple cases from one declaration with loops over real fixtures — e.g. `test/accessibility/guideline_test.dart:93-95` (screen map), `test/accessibility/theme_contrast_test.dart:62-63,106-107` (colour pairs), `test/responsive/responsive_smoke_test.dart:111-118,140-147` (sizes/routes), and the parity of the gap across baselines (2,423−2,396 = 27 before this wave; 2,447−2,420 = 27 now) confirms no drift. No test count was changed to match the pin. Conflict-flow files touched by this branch: `conflict_check_screen.dart`, `conflict_take_action_sheet.dart`, `disclosure_wizard_screen.dart` (import migration only) and `test/features/conflicts/conflict_flows_test.dart` (import migration) — no behavioural change. Total diff `main...HEAD` measured at the current tip with `git diff main...HEAD --shortstat`: **243 files changed, 644 insertions(+), 328 deletions(-)** (the earlier 242/552/328 figure predated this report commit).

## 6. What was NOT done

No merge into main, no PR, no tag, no APK rebuild, no live Supabase writes/migrations/token use, no new migrations, no new legal text, no new features, no local golden regeneration, no dependency changes beyond the 3.50-required bumps.

## 7. Owner actions / questions

1. Regenerate the 4 golden baselines via the CI workflow before merging this branch.
2. Confirm the Arabic RTL date visually on a device (headless capture unavailable).
3. Re-record `docs/media/demo.gif` from a non-debug build; counsel review of `docs/legal/*`; rotate the standing Supabase token.
4. CI on branch tip: NOT verified — no run triggered by a branch push; owner opens the PR and checks CI.

```json
{
  "head_before": "56f9599314f7fa4b9a151bbc1ea0d6528a29fc7d",
  "branch": "feat/legalhub-next-wave",
  "branch_head": "1a5d78322ebd673337ad73ee4c0af6b96b9b3293",
  "flutter_before": "3.47.5",
  "flutter_after": "3.50.0",
  "gates_after": {
    "flutter_analyze": "0 issues",
    "dart_format": "836 files (0 changed)",
    "flutter_test": "2447 passed / 13 skipped / 0 failed",
    "coverage": "84.6016% (lcov LF=21827 LH=18466)",
    "verify_ledger": "115 passed, PASS",
    "verify_arb_parity": "en=1074 ar=1074 tr=1074, PASS",
    "verify_policy_tests": "126 passed, PASS"
  },
  "tasks_done": ["Task 1 Flutter 3.50 migration", "Task 2 coverage >=84.5%", "Task 3 LegalConfig date localization", "Task 4 final verification + report"],
  "tasks_not_done": ["none"],
  "commits": ["390b331 build(deps): migrate to Flutter 3.50", "bbc205c test(coverage): raise line coverage to 84.55%", "507446d test(legal): RED localized last-updated date in en/ar/tr", "1a5d783 feat(legal): localize the LegalConfig last-updated date"],
  "pushed_branch": true,
  "merged_to_main": false,
  "ci_on_branch": "not verified (no run triggered on branch push)",
  "owner_actions": ["Regenerate 4 golden baselines via CI workflow", "Visually confirm Arabic RTL date on a device", "Re-record demo GIF from non-debug build", "Counsel review of docs/legal/*", "Rotate Supabase token", "Open PR and confirm CI green before merge"],
  "blockers": ["4 golden pins fail under Flutter 3.50; regeneration is owner-only via CI workflow"],
  "recommended_next_task": "Owner regenerates the 4 golden baselines via CI, then opens a PR for feat/legalhub-next-wave and confirms CI green before merge."
}
