# Responsive & Adaptive Hardening — Audit and Implementation Plan

> **Status:** Waves 0–4 executed (2026-11-07/08). The remaining items are
> listed at the end of §7.

**Goal:** Prove the whole app renders correctly at every supported width,
height and text scale — then fix every defect the proof finds, and close the
adaptive (large-screen) gaps the proof cannot see.

**Architecture:** A shared width contract (`AppBreakpoints`) drives four
adaptive decisions: the shell swaps the bottom bar for a leading
`NavigationRail` at ≥840dp (expanded), matters/messages render a two-pane
master/detail at the same breakpoint, modal surfaces become a centered
dialog, and readable content caps at 840dp. Layout robustness is pinned by
an exhaustive widget-test matrix that pumps the real app (router + shell +
screens + fakes) across widths, text scales, RTL and keyboard insets.

**Tech stack:** Flutter 3.47.5 / Dart 3.13.4, go_router 17, flutter_bloc,
Material 3. No new dependencies.

**Spec:** This document (the audit is the spec); findings cite current
`path:line`.

## Global Constraints

- No new package: the fixes use Flutter primitives only.
- Phone-first visuals must stay unchanged at width < 600 and text scale 1.0.
- The proof is a widget matrix, not a visual opinion: a route that overflows
  fails with route + size + scale in the message.
- The governance ledger (`scripts/verify_ledger.sh`) compares the README test
  count with the declarations in `test/`; every added test must update README.
- Frozen campaign records under `docs/` are history and are never edited.

## Review Focus

- A **short landscape phone** (640×360) at text scale 2.0: the viewport is
  height-constrained, not width-constrained, and is the case most likely to
  break scroll/Column assumptions.
- **Arabic RTL** at 320px / 2.0: longer localized strings and mirrored
  direction combine to expose rows that only fit in English at 1.0.
- **Keyboard-open forms** at 2.0: the inset plus enlarged fields must keep
  the primary action reachable.
- **Modal sheets** on a 1024px window: full-bleed sheets are a visual defect
  even when nothing overflows.
- **Navigation on tablets**: a bottom bar stretched across 1024px is
  responsive (it fits) but not adaptive (it ignores the device class).

---

## 1. What the audit covered

| Dimension | Coverage |
| --- | --- |
| Widths | 320, 390, 600, 768, 1024 (and 640×360 short landscape) |
| Text scale | 1.0 and 2.0 (accessibility ceiling), plus RTL at 2.0 |
| Routes | All 26 authenticated shell routes + all 7 signed-out routes |
| Modals | Shared sheet helper at 320, 1200, and 320 @ 2.0 |
| Keyboard | Booking and create-matter at 320 @ 2.0 |
| Navigation | Bottom bar below 840; rail on expanded (≥840) windows |

The matrix lives in `test/responsive/responsive_matrix_test.dart`; the sheet
contract lives in `test/shared/widgets/app_modal_sheet_test.dart`.

## 2. Findings and fixes (Wave 1)

All five were real overflow exceptions at **320×568, text scale 2.0**, found
by the matrix and fixed at the root.

### F1 — Create-matter no-org surface overflowed by 328px

- Evidence: `lib/features/matters/presentation/matter_create_surface.dart:102`
  rendered the long "no organization selected" copy in a fixed `Column`
  inside a non-scrollable `Padding`.
- Fix: the no-org arm is now a `SingleChildScrollView`.
- Impact: crash-striped screen in the demo/no-org state at 2.0.

### F2 — Thread detail overflowed by 96px

- Evidence:
  `lib/features/messaging/presentation/message_thread_detail_surface.dart:53`
  put the demo disclaimer as a fixed sibling of the `Expanded` transcript;
  at 2.0 the disclaimer alone was taller than the remaining body.
- Fix: the disclaimer is now item 0 of the scrollable transcript (success and
  empty arms), so it scrolls instead of consuming body height.

### F3 — Sign-up CTA overflowed by 121px (right)

- Evidence:
  `lib/features/auth/presentation/widgets/loading_elevated_button.dart:30`
  laid the label + icon in a `Row(mainAxisSize: min)` with an unbounded
  `Text`.
- Fix: the label is `Flexible` and may wrap. Also fixes the reset screen.

### F4 — Password-reset CTA overflowed by 121px (right)

- Same root cause and fix as F3 (`LoadingElevatedButton`).

### F5 — Onboarding success overflowed by 456px (bottom)

- Evidence:
  `lib/features/onboarding/presentation/onboarding_success_screen.dart:31`
  centered a fixed `Column` with no scroll.
- Fix: the screen now follows the established onboarding pattern —
  `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight)`,
  so it stays vertically centered when there is room and scrolls when there
  is not.

### F6 — Thread tile author/date row overflowed by 26px (right)

- Evidence:
  `lib/features/messaging/presentation/message_thread_detail_tile.dart:34`
  used `Expanded(author) + Text(date)`; at 2.0 the localized date's intrinsic
  width (340px) exceeded the row, collapsing the author to 0 and overflowing.
- Fix: the pair is now a `Wrap(spaceBetween)`; the date drops to a second
  line on narrow/large-text layouts instead of overflowing.

## 3. Adaptive gaps closed (Wave 2)

### A1 — Bottom navigation on every window size

- Before: `_AppShell` always rendered a `NavigationBar`, so a 1024px desktop
  window showed a phone bar stretched across the bottom.
- After (`lib/app/router_app_shell.dart`): at `width >= 840` (Material 3
  expanded) the shell renders a leading `NavigationRail` + divider + the
  content column; below 840 the existing bottom bar is unchanged (compact and
  medium windows). The rail reuses the same destinations, selected index,
  capability projection and stack-reset tap behavior as the bar. Its width
  scales with the user's text scale so labels do not clip at 2.0.

### A2 — Full-bleed modal sheets on large windows

- Before: 9 `showModalBottomSheet` call sites produced 1024px-wide forms.
- After: one shared `showAppSheet` helper
  (`lib/shared/widgets/app_modal_sheet.dart`) caps the sheet at 640dp and
  keeps `isScrollControlled: true`. All 9 sites migrated:
  approvals (create/detail), compliance (create/detail), tasks
  (create/assign), video (create), orgs (invite), billing (payment).

### A3 — Scattered breakpoints

- Added `lib/shared/responsive/breakpoints.dart` (`AppBreakpoints.expanded`
  840, `.sheetMaxWidth` 640, `.authContentMaxWidth` 520) and wired the shell,
  `ResponsiveContent`, the sheet helper, and the sign-in/sign-up form widths
  to it. No visual change; one source of truth.

## 4. Verification

| Gate | Result |
| --- | --- |
| `flutter analyze` | clean (no issues) |
| `dart format` on changed files | clean |
| `test/responsive/responsive_matrix_test.dart` | 9/9 pass |
| `test/responsive/two_pane_test.dart` | 11/11 pass |
| `test/responsive/desktop_adaptive_test.dart` | 7/7 pass |
| `test/responsive/responsive_smoke_test.dart` | 7/7 pass |
| `test/shared/widgets/app_modal_sheet_test.dart` | 3/3 pass |
| `test/features/video/video_call_screen_test.dart` | 11/11 pass |
| `test/widget_test.dart` (shell round-trip) | 3/3 pass |
| `test/app/router_test.dart` (shell pins) | 71/71 pass |
| `test/golden` in the pinned image | 4/4 pass (regenerate + compare) |
| Android 16 emulator (411×914 and 1280×800) | rail, two-pane, tap-swap, font scale 2.0 verified |
| Full suite (goldens skipped by default) | 2163/2163 pass, 10 capture/golden-only tests skipped |

The matrix asserts the *absence of framework layout exceptions* on every
route at every tested size/scale. It is intentionally strict: a
`RenderFlex overflowed` or clipped-text assertion fails the run with the
route, size and scale in the message.

## 5. Wave 3 — executed (2026-11-07)

1. **Two-pane master/detail on expanded (≥840).**
   - Matters: `MatterListScreen` keeps the list on the left and renders
     `MatterDetailsScreen(embedded: true)` on the right; the first loaded
     matter is auto-selected, a tap swaps the detail without losing the
     list, and `/matters/:id` deep links open the same two-pane with that
     matter selected. Below 840 the push flow is unchanged.
   - Messages: `MessageListScreen` does the same with
     `MessageThreadDetailScreen(embedded: true)`; the embedded transcript
     keeps its own title header and insert-only composer.
   - Shared layout: `lib/shared/widgets/layout/two_pane.dart` (2/5 list,
     3/5 detail, 1px divider).
   - The expanded decision uses the **window** width, not the capped
     content width, so a text-scaled rail (which narrows the content
     column) cannot flip the two-pane off on a desktop window.
2. **Short sheets → dialogs on expanded.** `showAppSheet` now renders a
   centered `Dialog` (max 560dp wide) at ≥840 and keeps the capped bottom
   sheet below it. All nine create/detail/payment sites inherit it from the
   shared helper.
3. **Landscape layouts.**
   - Booking: the wizard shows a persistent draft summary beside the step
     (category and date-time steps) on ≥840; review/success keep full width.
   - Video call: the participant grid switches to 16:9 tiles (and a third
     column at 5+ participants) when the viewport is landscape instead of
     stretching portrait tiles past a short viewport.
4. **Text scale 3.0 sweep.** All 26 signed-in routes at 320×568 and
   1024×768 plus all 7 signed-out routes at 320×568. One defect surfaced:
   the org-audit row overflowed 50px right at 3.0; the outcome chip now
   drops to its own line above 2.0 (`org_audit_row.dart`). The sweep is
   green.
5. **Screenshot harness + breakpoint captures.**
   `test/responsive/screenshot_capture_test.dart` (skipped unless
   `CAPTURE_SCREENSHOTS=1`) loads the app fonts and writes PNGs to
   `build/responsive_screens/` for home at 320/600/1024, matters two-pane,
   messages two-pane, and booking landscape. The harness uses
   `tester.runAsync` for `toImage` (without it the test harness hangs after
   capture).
6. **Dialog-width dropdown fix (F7).** Moving video/approval/task sheets to
   a 560dp dialog exposed a long-matter-title overflow in
   `DropdownButtonFormField` (RenderFlex, 464dp row). The matter, assignee,
   and member dropdowns now use `isExpanded: true` + single-line ellipsis,
   so dynamic names cannot overflow a narrow dialog or a phone.
7. **Real-device leg (Android 16 / API 36 emulator).**
   - Phone logical 411×914: onboarding → demo sign-in → home rendered with
     the bottom bar, no overflow.
   - Tablet override 1280×800 @160dpi: NavigationRail + capped content;
     `/matters` rendered the two-pane and a tap swapped the detail from
     "Demo acquisition review" to "Family status consultation";
     `/messages` rendered the list + transcript + composer.
   - System font scale 2.0: sign-in and home re-rendered with the larger
     type and no overflow.
   - Captures: `build/device_phone_home.png`, `build/device_tablet_home.png`,
     `build/device_tablet_matters.png`,
     `build/device_tablet_matter_selected.png`,
     `build/device_tablet_messages.png`,
     `build/device_scale2_tablet_home.png` (all git-ignored).

Remaining backlog after Wave 3:

- Hover/focus and keyboard-traversal audit for the desktop rail (done in
  Wave 4).
- Golden regression pinning in CI (done in Wave 4).
- Foldable / multi-window posture and a 3.0 sweep on a real device (hinge
  geometry shipped in Wave 4; a physical foldable leg remains).

## 7. Wave 4 — documents/invoices detail, desktop, goldens

1. **Documents metadata detail + two-pane.**
   - New route `/vault/:documentId` (`AppRoutes.documentDetail`), screen
     `DocumentDetailsScreen` (`embedded` mode for the pane).
   - The detail is **metadata only** (title, type, matter cross-link, created
     date, local note). There is still no body/viewer/download/preview/share
     anywhere — the domain type carries none.
   - `/vault` at ≥840 is a two-pane list+detail with auto-selection; below
     840 the row pushes the detail route.
   - The AC-2 structural pin was updated deliberately: the row is now a tap
     target (chevron + row InkWell), while the content/download absence pins
     stay intact.
2. **Invoice metadata detail + two-pane.**
   - New route `/invoices/:invoiceId` (`AppRoutes.invoiceDetail`), screen
     `InvoiceDetailsScreen` (embedded mode included).
   - Metadata only (number, amount/currency, status, matter, issued/due) plus
     the existing pay action for an issued invoice when payments are enabled.
     No card/payer/address data exists on the type.
   - `/invoices` at ≥840 is a two-pane; below 840 the row pushes the detail.
   - The billing "metadata only, no InkWell" pin was re-scoped: the row opens
     the metadata detail; the no-pay-button pin remains.
3. **Desktop hover/focus + keyboard traversal.**
   - Shared tappable cards (`AppTile`, `AppEntryCard`, `PracticeAreaCard`,
     `MatterLinkChip`) now set `SystemMouseCursors.click` explicitly —
     Material's adaptive default resolves to `basic` on touch platforms, so
     desktop/web rows were indistinguishable from static text.
   - The shell body is wrapped in `FocusTraversalGroup` with
     `ReadingOrderTraversalPolicy`, so Tab visits the rail then the content
     deterministically as panes are added.
4. **Foldable hinge geometry.**
   - `TwoPane` reads `MediaQuery.displayFeaturesOf`: a vertical hinge inside
     the window replaces the 1px divider with its physical width; a fold
     (crease) keeps the divider. Tests pin both.
5. **Golden pins in CI (pinned renderer).**
   - `test/golden/breakpoint_golden_test.dart` pins home 320/1024 and the
     matters/messages two-pane at 1024. It is skipped unless
     `RUN_GOLDENS=1`, so a Windows developer never compares against Linux
     pixels.
   - Baselines are generated inside `tool/ci/flutter-golden.Dockerfile`
     (Ubuntu 24.04 + Flutter 3.44.4, the CI version).
   - CI job `golden-pins` runs the same tests on ubuntu-latest with the same
     pinned Flutter version.

Remaining after Wave 4:

- A physical foldable / dual-screen device leg (the hinge geometry is
  covered by widget tests only).
- Optional two-pane for search results (search has no detail route yet).
- Localization coverage for the new detail strings in a live translator
  pass (the AR/TR additions are in-tree but not translator-reviewed).

## 6. Close-out

- Suite declarations: 2167 (was 2119 at the start of the campaign).
- Screenshot captures: `build/responsive_screens/` (git-ignored), generated
  by `CAPTURE_SCREENSHOTS=1 flutter test
  test/responsive/screenshot_capture_test.dart`.
- Golden pins: `test/golden/goldens/` (committed), regenerated in the pinned
  renderer (`tool/ci/flutter-golden.Dockerfile`, Ubuntu 24.04 + Flutter
  3.44.4). The container's `pub get` downgraded 11 lock entries to the
  versions Flutter 3.44.4 resolves; `pubspec.lock` was reverted afterwards,
  and the committed lock remains the project's source of truth (CI re-resolves
  identically to the golden run).
- No commit or push was performed; the working tree holds the implementation
  for owner review.
