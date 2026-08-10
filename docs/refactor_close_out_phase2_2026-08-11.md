# LegalHub — Refactor Close-Out: Phase-2 E7–E10 + Re-audit Candidates A/B (2026-08-11)

> **Record type:** dated close-out addendum for the Phase-2 refactor
> program — the extraction series planned in
> `docs/phase2_refactor_audit_2026-08-11.md` (E7–E10) and executed after
> the E1–E6 close-out (`docs/refactor_close_out_2026-08-11.md`), plus the
> post-E10 re-audit (Candidates A/B) that the follow-on scan surfaced.
>
> **Status: COMPLETE 2026-08-11** — all four planned extractions, both
> re-audit candidates, and the Phase-3 draft slate (C1/C2) implemented,
> tested, committed, and pushed to `origin/main`. Suite **1254 → 1261**
> since the E7–E10 close-out record (`9d142ff`), **1236 → 1261** across
> the whole Phase-2/3 program. All gates green at the final state:
> `dart format` clean, `flutter analyze` **0 issues**, **1261 tests
> passing**, `verify_ledger.sh` **PASS 115/0/0**,
> `verify_policy_tests.sh --check` **PASS 73/0/0**.
>
> **Scope discipline:** behavior-preserving by contract — no navigation,
> auth, RPC, state-management, model, l10n-key, or fake/demo-seam changes.
> Every extraction's visual output is byte-identical to the pre-extraction
> structure, pinned by shared-widget tests and the untouched screen
> suites. Where the re-audit found a shape that was *similar but not a
> clone*, it was documented and left alone rather than forced into a new
> component.

## 1. Commits (Phase-2 program, `148ea95..227b7a5`)

| # | Commit | Content | Tests |
|---|---|---|---|
| — | `38fe212` | Phase-2 audit record (E7–E10 list) | — |
| E7 | `821631e` | `AppFilterChips<T>` + 2 re-pointed chip rows | +6 |
| E8 | `b1d7725` | 4 workspace rows → `AppTile` + `fileSizeLabel` | +1 |
| E9 | `b3d21c9` | `AppCenteredRetry` + 2 re-pointed error arms | +4 |
| E10 | `74970ae` | `WorkspaceSection<T>` + 4 re-pointed sections | +7 |
| — | `9d142ff` | Phase-2 close-out record (E7–E10 executed, suite 1254) | — |
| — | `7d26669` | Post-E10 re-audit (Candidates A/B list) | — |
| A | `6087a4e` | `AppCenteredMessage` + 2 re-pointed `_message` helpers | +3 |
| B | `227b7a5` | org-audit centered icon-state trio → local `_CenteredState` | — (screen tests pin) |
| C1 | `c840a36` | matter-details workspace headers → local `_WorkspaceBlock` | — (screen tests pin) |
| C2 | `a5e6c5c` | `AppSectionHeader` (search + matter-details unified, shared) | +4 |

Suite: **1236 → 1261** (+25 new tests, none deleted or weakened).

## 2. Extraction-by-extraction

- **E7 `AppFilterChips<T>`** — the matter status and practice-area
  single-select chip rows were the same horizontal "All + one chip per
  enum value" row differing only in enum type, label fn, cubit setter, and
  l10n key. Now a presentational shared widget; call sites pass the label
  fn and selection callback as closures.
- **E8 workspace rows → `AppTile`** — the four matter workspace rows
  (`_DocumentRow`/`_FileRow`/`_InvoiceRow`/`_ThreadRow`) were identical
  card rows. This addressed the E1–E6 close-out residual #6 — excluded
  then only because `AppTile.subtitle` was single-line; the
  `subtitles: List<String>` generalization (`c11062c`) removed the
  structural reason. `fileSizeLabel` (bytes → human label) stayed in the
  storage feature as a top-level helper — domain formatting, not UI.
- **E9 `AppCenteredRetry`** — the attorney-profile and matter-details
  centered error arms (error text + retry button) were identical; the
  localized retry label is passed in. Partially addressed the E1–E6
  residual #5 (centered-message screens).
- **E10 `WorkspaceSection<T>`** — the four matter workspace sections
  duplicated the `ViewStateSwitch` arm config (spaceMd loading / zero
  error padding / bodySmall error text), the filter-by-matterRef rows
  column, and the inline empty copy. The shell is now shared; each
  section keeps its own `BlocProvider`/`BlocBuilder` wiring (which
  differs only in cubit/gateway types — genericizing over four cubit
  types would have been the over-abstraction the audit warned about).
- **Candidate A `AppCenteredMessage`** — the attorney-profile and
  matter-details `_message` helpers (centered, `spaceLg`-padded,
  `onSurfaceVariant` plain text) were byte-identical; the matter copy even
  carried an unused `l10n` parameter, now dropped. The plain-text half of
  residual #5.
- **Candidate B org-audit `_CenteredState`** — the org-audit
  `_EmptyState`/`_DeniedState`/`OrgAuditFailedBlock` trio was the same
  `Center` → `Padding(marginMobile)` → `Column(min)` → `Icon(40)` +
  `spaceMd` → centered `Text` shell (the failed arm adds a retry button).
  Consolidated into one private parameterized widget — **local, not in
  the shared barrel**, per the single-screen rule (orgs only).

## 3. Before/after duplication

- Duplication collapsed: **10 shared widgets** from E1–E10 + A (barrel
  now 21 exports incl. form/layout helpers), plus the local
  `_CenteredState`.
- Lines: E7 −42/−43, E8 −121 net, E9 −45 net, E10 −196 net, A −41 net,
  B −45 net across the modified feature files (offsets by the new shared
  widgets + tests).

## 4. Residuals (deliberately not merged)

Each of these is a genuinely different geometry or single-screen shape —
documented, not forced:

- **Audit `_OutcomeChip`** (E1–E6 residual #3) — `spaceXs` vertical
  padding, `radiusLg`, `labelMedium` vs `LabelChip`'s `spaceSm`/`radiusSm`.
- **Home `StatusChip`** (E1–E6 residual #4) — uppercase transform,
  `spaceXs` vertical, `labelLarge` + 0.5 tracking.
- **Thread-detail `_MessageTile`** — header row (author + date) + body,
  no leading; not an `AppTile` row.
- **Booking `_SuccessStep`** — centered success celebration (56px icon,
  headline, `ListView`), not the plain-message or icon-state shapes.
- **Admin `_DeniedState`/`_FailedState`** — similar to the org-audit
  family but different geometry (`spaceSm` gaps, `headlineSmall` title,
  32px icon, `TextButton` retry); kept separate from `_CenteredState`.
- **Label/value rows** (`_DetailRow`/`_SummaryRow`/`_InfoRow`), **member
  rows** (admin vs orgs), **audit rows** (admin/orgs/hub),
  **`_SelectableTile`**, **`_AuditSection`**, **`_GroupSection`**,
  **controller-fields** (`_SearchField`/`_TopicField`) — from the
  Phase-2 audit §3; each a different layout, meaning, or single-screen
  use.

## 5. Verification at close-out

- `dart format --output=none --set-exit-if-changed lib test` — clean
- `flutter analyze` — No issues found
- `flutter test` — **1257 passed**
- `bash scripts/verify_ledger.sh` — PASS 115/0/0
- `bash scripts/verify_policy_tests.sh --check` — PASS 73/0/0
- `git status` — clean; `origin/main == HEAD` at `a5e6c5c`

## 6. Program summary

The full refactor program (E1–E6 + follow-ups + E7–E10 + A/B + C1/C2)
ran from suite 1193 → 1261 (**+68 tests**), every commit individually
gated and pushed, with two dated close-out records
(`docs/refactor_close_out_2026-08-11.md`, this addendum) and the live
audit ledger (`docs/phase2_refactor_audit_2026-08-11.md`) tracking the
execution and residuals. The Phase-3 draft slate (§9 of the audit
ledger) is fully executed: C1 (workspace headers, superseded by C2) and
C2 (`AppSectionHeader`, shared barrel). Remaining duplication is the
documented distinct-geometry residual set — no planned extraction
outstanding.

## 7. Phase-4 decision (2026-08-11): extraction program COMPLETE

> **Decision:** declare the shared-component extraction program **COMPLETE**.
> The remaining residual list is all deliberate-distinct geometry — no
> further duplication clusters exist.

**Evidence (three independent scans, all at green gates):**

1. **Post-E10 re-audit (§8 of the audit ledger)** — the only remaining
   centered-state duplication was Candidates A (`AppCenteredMessage`,
   shared) and B (org-audit `_CenteredState`, local), both executed.
2. **Admin-pair review (2026-08-11)** — admin `_DeniedState`/
   `_FailedState` differ from `_CenteredState` on four axes (padding,
   icon size, gaps, text lines, action style); absorbing them would need
   five parameters of flag sprawl — STAY SEPARATE.
3. **Post-C2 scan (2026-08-11)** — `_GroupSection`/`_WorkspaceBlock`
   deleted; the only remaining `fontWeight.w700` headers are the intended
   `titleStyle:` overrides into `AppSectionHeader` and two non-header
   shapes (home app-bar title, invite-token chip).

**The 500+ line screens are co-location, not duplication** — the private
step/section widgets (`_BookingWizard` steps, `_AdminLists`/
`_AuditSection`, roster rows/chips) are each single-responsibility and
feature-local per the Phase-1 rules; the roster chips already delegate to
`LabelChip`. Splitting them into separate files would remove zero
duplication — it is an optional readability refactor, not an extraction.

**Phase-4 readability pass executed (2026-08-11)** — the optional file
decomposition candidates, both 500+ line screens now split into
`part` files:

- **Booking** (`lib/features/booking/presentation/`): the wizard step
  pipeline split into `booking_category_step.dart`,
  `booking_datetime_step.dart`, `booking_review_step.dart`,
  `booking_success_step.dart`, and `booking_selectable_tile.dart`;
  `booking_screen.dart` remains the library file with the screen + wizard
  shell and the centralized imports.
- **Admin** (`lib/features/admin/presentation/`):
  `platform_admin_screen.dart` (596 lines) slimmed to the screen +
  state + `_LoadOnMount` shell; the three-section lists shell
  (`platform_admin_lists.dart`), member rows
  (`platform_admin_member_row.dart`), the fetch-on-mount audit section
  with its rows (`platform_admin_audit_section.dart`), and the
  denied/failed terminal states (`platform_admin_states.dart`) moved to
  `part` files.

Chosen mechanics for both: `part`/`part of`, so every widget stays
private (no public-API change) and the imports stay in one place — a pure
mechanical readability split with zero behavior change; the admin tests
pin by l10n text and pass unchanged (14), suite stays 1261.

**Phase-4 close-out (2026-08-11)** — the readability candidate list is
EXHAUSTED. Both 500+ line screens are split and pushed:

- Booking `4bce267` — `refactor(booking): split step pipeline into part
  files (Phase-4 readability pass)`
- Admin `61d9191` — `refactor(admin): split section widgets into part
  files (Phase-4 readability pass)`

No further readability candidates remain; the only Phase-4-adjacent items
left on the table are the non-extraction ones (coverage deepening,
feature work), not splits. Verified at `61d9191`: suite 1261, all gates
green (format clean, analyze clean, ledger PASS, policy PASS), tree
clean, `origin/main == HEAD`.

**Program totals at decision time** (`e105ce6`, suite 1261): 12
extractions + 2 consolidations (E1–E6, E7–E10, A/B, C1/C2), 13 shared
widgets in the barrel, suite 1193 → 1261 (**+68 tests**), all gates
green, every commit gated and pushed. The honest Phase-4 candidates, if
any further code-quality work is wanted, are **not** extraction: the
optional file decomposition of the two 500+ line screens (readability)
— executed, see the close-out above — plus coverage deepening
(admin/booking step tests) or moving to feature work per the roadmap.
