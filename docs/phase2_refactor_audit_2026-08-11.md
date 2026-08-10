# LegalHub — Phase-2 Refactor Audit: Next Duplication Clusters (2026-08-11)

> **Record type:** dated audit record for the Phase-2 refactor pass — the
> re-scan of the codebase for the next duplication clusters after the E1–E6
> extraction series (`docs/refactor_close_out_2026-08-11.md`), produced as
> the prioritized extraction list the owner asked for.
>
> **Status: EXECUTED 2026-08-11** — audit performed against `main` at
> `148ea95`; all four planned extractions (E7–E10) were subsequently
> implemented, tested, committed, and pushed to `origin/main` (§7). This
> record served as the approved extraction list for the execution slice.
> All claims were verified against the code with `file:line` citations at
> audit time.
>
> **Scope discipline:** every candidate below was judged against the
> Phase-1 rules — extract only what has a clear responsibility and is
> genuinely reused; keep feature-specific widgets local; do not abstract
> widgets that only look superficially similar; do not create abstractions
> used by a single screen. Candidates are classified **P0 (must extract)**,
> **P1 (recommended)**, **P2 (optional)**, or **do not extract (with the
> structural reason)**. Any extraction must be behavior-preserving
> byte-for-byte, following the E1–E6 pattern (dedicated shared-widget
> tests, untouched screen suites, all gates green).

## 1. Baseline at audit time

- `HEAD` = `148ea95` (`refactor(shared): normalize ViewStateList
  offline/unauthorized arms`), the last commit of the E1–E6 program.
- Working tree clean; `origin/main == HEAD`; `0 0` ahead/behind.
- Full suite: **1236 tests passing** (`flutter test`, 2026-08-11).
- Shared barrel `lib/shared/widgets/widgets.dart` now exports 8 components:
  `AppEntryCard`, `AppTile` (with multi-line `subtitles`), `ViewStateSwitch`,
  `ViewStateList`, `ViewStateView`, `LabelChip`, `showConfirmDialog`,
  `DirectionalIcon` (plus `lib/shared/formatting/date_formatting.dart`).
- The close-out record's residual list still stands at items #3 (audit
  `_OutcomeChip`), #4 (home `StatusChip`), #5 (centered-message screens),
  #6 (workspace rows / thread-detail `_MessageTile`) — **#6 is now
  addressable** (see E8 below, enabled by the `subtitles` generalization
  in `c11062c`).

## 2. Prioritized extraction list

### P0 — Must extract

**E7 · `AppFilterChips<T>` — two byte-identical chip rows**

- `_StatusFilterChips` (`lib/features/matters/presentation/matter_list_screen.dart:162`)
  and `_AreaFilterChips`
  (`lib/features/discovery/presentation/attorney_search_screen.dart:173`)
  are the same widget: a horizontal `SingleChildScrollView` → `Row` with an
  "All" `FilterChip` (clears the filter) plus one `FilterChip` per
  `enum.values`, separated by `spaceSm` gaps. They differ only in the enum
  type (`MatterStatus` vs `PracticeArea`), the label function
  (`matterStatusLabel` vs `practiceAreaLabel`), the cubit setter
  (`setStatus` vs `setPracticeArea`), and the l10n "All" key.
- Generic shape: `AppFilterChips<T>(values, selected, allLabel, labelOf,
  onSelected)` — explicit parameters, no hidden cubit reads; the widget
  stays presentational, call sites pass the cubit closure.
- Each site shrinks from ~40 lines to ~12. **Low risk, mechanical.**
- Tests: shared-widget suite (all-selected rendering, null-selected "All"
  state, callback on toggle, RTL/no-overflow) + existing screen suites
  unchanged (they already pin the two filter behaviors).

**E8 · Workspace section rows → `AppTile` — four identical card rows**

- `_DocumentRow` (`lib/features/matters/presentation/matter_documents_section.dart:125`),
  `_FileRow` (`lib/features/matters/presentation/matter_files_section.dart:127`),
  `_InvoiceRow` (`lib/features/matters/presentation/matter_invoices_section.dart:127`),
  and `_ThreadRow` (`lib/features/matters/presentation/matter_messages_section.dart:127`)
  all render the same shell: `Material(color: surfaceContainerLowest, shape:
  radiusLg + outlineVariant border)` → `Padding(spaceMd)` → title
  (`bodyMedium` w600) + 2px gap + secondary line (`bodySmall`
  `onSurfaceVariant`).
- This is exactly the `AppTile` row shape with `onTap: null`, no
  icon/leading/trailing, and `subtitles: [secondary]`. **Close-out residual
  #6 said "Column-layout rows — not AppTile rows" — that exclusion predates
  the `subtitles: List<String>` generalization (`c11062c`); the structural
  reason is gone.** Each row becomes a ~12-line `AppTile` call, and residual
  #6 is **ADDRESSED** for the workspace rows.
- The four identical `_empty` helpers (each `Padding(top: spaceXs)` +
  `Text(bodySmall onSurfaceVariant)`, e.g.
  `matter_documents_section.dart:108`) ride along — fold into a tiny shared
  inline-empty text or the E10 shell.
- **Risk note:** `_FileRow` carries a `sizeLabel` static helper (bytes →
  "240 KB / 1.5 MB / 512 B", `matter_files_section.dart:135`) — that logic
  stays in the files feature (it is domain formatting, not UI), only the row
  shell delegates to `AppTile`.

### P1 — Recommended

**E9 · `AppCenteredRetry` — two byte-identical centered error arms**

- `_error` in `lib/features/discovery/presentation/attorney_profile_screen.dart:115`
  and `lib/features/matters/presentation/matter_details_screen.dart:131` are
  identical: `Center` → `Column(mainAxisSize: min)` → error `Text`
  (center-aligned, `scheme.error`) + `TextButton(retry)` calling the
  cubit's `load()`. Only the l10n key (`discoveryError` vs `matterError`)
  and the cubit type differ.
- Shared widget: `AppCenteredRetry(message, onRetry)` — no cubit reads
  inside.
- Booking's `ViewError` arm (`lib/features/booking/presentation/booking_screen.dart:245`)
  is a **different shape** (start-aligned `Column` inside the scroll view,
  not centered) — documented as a variant, **not merged**. This partially
  addresses close-out residual #5 (centered-message screens).

**E10 · Workspace section shell — four duplicated bodies**

- All four section files repeat the same ~30-line skeleton:
  `BlocProvider` + `addPostFrameCallback(load)` + `BlocBuilder` +
  `ViewStateSwitch(loadingPadding: spaceMd, errorPadding: zero,
  errorTextStyle: bodySmall error)` + a `_rows` filter-by-matterRef + the
  `_empty` helper — differing only in cubit/gateway/l10n keys (e.g.
  `matter_documents_section.dart:60` vs `matter_invoices_section.dart:60`).
- A small `WorkspaceSection<T>` wrapper (or folding `_empty` into a shared
  widget) removes the boilerplate. **Slightly higher risk than E8** because
  it is generic over four cubit types — do **after** E8.

### P2 — Optional

- **`_GroupSection` (search:358)** — a titleMedium-w700-primary header +
  children column, used 4× *within search only* (search:218/248/278/309).
  Single-screen usage → **keep local** per the Phase-1 rules; noted here so
  it can be promoted if a second screen grows the same header shape.
- **Controller-fields `_SearchField`/`_TopicField`** — superficially
  similar (controller + listener → cubit) but differ in initialization
  (`_TopicField` seeds from `draft.topic` via `context.read` in a field
  initializer, `booking_screen.dart:160`) and in the cubit call. Only two
  sites, both thin wrappers over the existing `LegalHubTextField`. **Do not
  extract** — merging would risk a subtle behavior change for a marginal
  win.

## 3. Do NOT extract (verified structurally different)

These were examined and deliberately left alone — each is a genuinely
different geometry or domain meaning, not a superficial clone:

- **Label/value rows** — `_DetailRow` (`matter_details_screen.dart:239`,
  label-above-value `Column`), `_SummaryRow` (`booking_screen.dart:363`,
  `Row` with `Flexible` label + `Expanded` value), `_InfoRow`
  (`home_screen.dart:367`, icon card with title + body): three different
  layouts and meanings.
- **Member rows** — admin `_MemberRow` (`platform_admin_screen.dart:229`,
  `ListTile` with org-name + pending) vs orgs `_MemberRow`
  (`member_roster_screen.dart:352`, card with avatar + action menu):
  different content and layout.
- **Audit rows** — admin `_AuditRow` (`platform_admin_screen.dart:498`,
  `ListTile` + initial-avatar) vs orgs `_AuditRow` (`org_audit_screen.dart:116`,
  card with header row + `_OutcomeChip` + metadata) vs hub
  `_AuditEntryTile` (`organization_hub_screen.dart:122`): three distinct
  shapes.
- **`_MessageTile`** (`message_thread_detail_screen.dart:160`) — header row
  (author + date) + body text, no leading; genuinely not an `AppTile` row.
  Remains part of close-out residual #6 alongside the E8 workspace rows.
- **`_SelectableTile`** (`booking_screen.dart:472`), **`_AuditSection**
  (`platform_admin_screen.dart:363`), **org_audit `_EmptyState`**
  (`org_audit_screen.dart:211`, distinct check-circle icon shape) —
  single-use, local.

## 4. Verification at audit time

- `git status --short` — clean
- `git log --oneline -3` — `148ea95` / `c11062c` / `d1d2444`
- `git rev-list --left-right --count HEAD...@{upstream}` — `0 0`
- `flutter test` — **1236 passed** (2026-08-11, re-run at record time)

## 5. Suggested execution order

1. **E7** `AppFilterChips<T>` — smallest, 2 sites, mechanical.
   **COMPLETE 2026-08-11** — `lib/shared/widgets/app_filter_chips.dart`
   (+6 tests, suite 1236 → 1242), both chip rows re-pointed.
2. **E8** workspace rows → `AppTile` — kills close-out residual #6, 4
   sites, enabled by the `subtitles` generalization.
   **COMPLETE 2026-08-11** — the four workspace rows now delegate to
   `AppTile` (`title` + `subtitles`, no icon/leading, `onTap: null`);
   `fileSizeLabel` kept in the storage feature as a top-level helper; the
   thread-detail `_MessageTile` remains excluded (different shape).
   Close-out residual #6 **PARTIALLY ADDRESSED**; +1 AppTile test (suite
   1242 → 1243).
3. **E9** `AppCenteredRetry` — 2 sites, partial #5 resolution.
   **COMPLETE 2026-08-11** — `lib/shared/widgets/app_centered_retry.dart`
   (+4 tests, suite 1243 → 1247), both error arms re-pointed; booking's
   start-aligned `ViewError` arm documented as a separate shape. Close-out
   residual #5 **PARTIALLY ADDRESSED**.
4. **E10** workspace section shell — only if the boilerplate still
   justifies it after E8. **COMPLETE 2026-08-11** —
   `lib/shared/widgets/workspace_section.dart` (the `ViewStateSwitch` arm
   config, the filter-by-matterRef rows column, and the inline empty copy
   unified as `WorkspaceSection<T>`; the four sections keep their own
   `BlocProvider`/`BlocBuilder` wiring and pass state/retry/copies/
   item-builder), +7 tests, suite 1247 → 1254.

Each lands as its own commit with focused shared-widget tests, following
the E1–E6 pattern; all gates (`dart format`, `flutter analyze`,
`flutter test`, `verify_ledger.sh`, `verify_policy_tests.sh --check`)
must be green before each commit. The close-out doc's residual list would
gain **#6 ADDRESSED** and **#5 partially ADDRESSED** on completion.

## 6. Follow-ups (not extraction)

- After E8, re-check whether the `_empty` helper folding belongs in E10 or
  is small enough to ride with E8. **RESOLVED 2026-08-11** — the `_empty`
  helper folded into `WorkspaceSection<T>` (E10) as its inline empty copy;
  no separate widget was needed.
- The org-audit `_OutcomeChip` (residual #3) and home `StatusChip`
  (residual #4) remain deliberately distinct geometries — no change.

## 7. Execution close-out (2026-08-11)

All four planned extractions were implemented, tested, committed, and
pushed as separate commits, following the E1–E6 pattern:

| # | Commit | Content | Tests |
|---|---|---|---|
| E7 | `821631e` | `AppFilterChips<T>` + 2 re-pointed chip rows | +6 (suite 1242) |
| E8 | `b1d7725` | 4 workspace rows → `AppTile` + `fileSizeLabel` | +1 (suite 1243) |
| E9 | `b3d21c9` | `AppCenteredRetry` + 2 re-pointed error arms | +4 (suite 1247) |
| E10 | `74970ae` | `WorkspaceSection<T>` + 4 re-pointed sections | +7 (suite 1254) |

Plus the audit record itself (`38fe212`). **Suite: 1236 → 1254** (+18
new tests, none deleted or weakened).

### Gates at close-out

- `dart format --set-exit-if-changed lib test` — clean
- `flutter analyze` — No issues found
- `flutter test` — **1254 passed**
- `bash scripts/verify_ledger.sh` — PASS 115/0/0
- `bash scripts/verify_policy_tests.sh --check` — PASS 73/0/0
- `git status` — clean; `origin/main == HEAD` at `74970ae`

### Residual-list outcome (vs the E1–E6 close-out)

- Close-out residual #5 (centered-message screens): **PARTIALLY ADDRESSED
  (E9)** — the two identical error arms unified; booking's start-aligned
  `ViewError` arm stays excluded.
- Close-out residual #6 (workspace rows): **PARTIALLY ADDRESSED (E8 + E10)**
  — the four workspace rows delegate to `AppTile`, and the section shells
  delegate to `WorkspaceSection`; the thread-detail `_MessageTile` stays
  excluded (genuinely different shape).
- Residuals #3 (`_OutcomeChip`) and #4 (home `StatusChip`) unchanged —
  deliberately distinct geometries.

### Remaining planned surface (from §2 P2 — deliberately not extracted)

- `_GroupSection` (search) — single-screen; promoted only if a second
  screen grows the same header.
- Controller-fields `_SearchField`/`_TopicField` — differ in
  initialization and cubit calls; merging risks a subtle behavior change.
