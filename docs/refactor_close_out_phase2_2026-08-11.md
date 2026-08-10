# LegalHub — Refactor Close-Out: Phase-2 E7–E10 + Re-audit Candidates A/B (2026-08-11)

> **Record type:** dated close-out addendum for the Phase-2 refactor
> program — the extraction series planned in
> `docs/phase2_refactor_audit_2026-08-11.md` (E7–E10) and executed after
> the E1–E6 close-out (`docs/refactor_close_out_2026-08-11.md`), plus the
> post-E10 re-audit (Candidates A/B) that the follow-on scan surfaced.
>
> **Status: COMPLETE 2026-08-11** — all four planned extractions and both
> re-audit candidates implemented, tested, committed, and pushed to
> `origin/main`. Suite **1254 → 1257** since the E7–E10 close-out record
> (`9d142ff`), **1236 → 1257** across the whole Phase-2 program. All gates
> green at the final state: `dart format` clean, `flutter analyze`
> **0 issues**, **1257 tests passing**, `verify_ledger.sh` **PASS
> 115/0/0**, `verify_policy_tests.sh --check` **PASS 73/0/0**.
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
| C2 | *(pending)* | `AppSectionHeader` (search + matter-details unified, shared) | +4 |

Suite: **1236 → 1261** (+25 new tests, none deleted or weakened) once C2
lands.

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
- `git status` — clean; `origin/main == HEAD` at `227b7a5`

## 6. Program summary

The full refactor program (E1–E6 + follow-ups + E7–E10 + A/B) ran from
suite 1193 → 1257 (**+64 tests**), every commit individually gated and
pushed, with two dated close-out records
(`docs/refactor_close_out_2026-08-11.md`, this addendum) and the live
audit ledger (`docs/phase2_refactor_audit_2026-08-11.md`) tracking the
execution and residuals.
