# LegalHub — Refactor Close-Out: E1–E6 Shared-Component Extraction (2026-08-11)

> **Record type:** dated close-out record for the E1–E6 extraction series —
> the de-duplication pass planned during the Phase-1 codebase analysis and
> executed as five independently reviewable commits on `main`.
>
> **Status: COMPLETE 2026-08-11** — all six extractions (E6+E1, E3, E2, E4,
> E5) implemented, tested, committed, and pushed to `origin/main`. All
> gates green at the final state: `dart format` clean, `flutter analyze`
> **0 issues**, **1228 tests passing** (was 1193), `verify_ledger.sh`
> **PASS 115/0/0**, `verify_policy_tests.sh --check` **PASS 73/0/0**.
>
> **Scope discipline:** behavior-preserving by contract — no navigation,
> auth, RPC, state-management, model, l10n-key, or fake/demo-seam changes.
> Each extraction's visual output is byte-identical to the pre-extraction
> structure (pinned by new shared-widget tests and the untouched screen
> suites). Residual duplication that is structurally different — not a
> superficial clone — is documented below rather than forced into the new
> components.

## 1. Commits (in execution order)

| Commit | Extraction | Files | Net diff | New tests |
|---|---|---|---|---|
| `c052d63` | E6 date formatting + E1 `AppEntryCard` | 26 | +429 / −581 | 12 |
| `f6e8597` | E3 `ViewStateSwitch` | 15 | +423 / −418 | 7 |
| `ff81016` | E2 `AppTile` | 10 | +396 / −611 | 8 |
| `cb786c8` | E4 `showConfirmDialog` | 7 | +193 / −90 | 4 |
| `2e86303` | E5 `LabelChip` | 8 | +202 / −97 | 4 |
| **Total** | | **66** | **+1643 / −1797** | **35** |

## 2. Extractions and the duplication removed

### E6 — centralized date formatting (`lib/shared/formatting/date_formatting.dart`)
- **Before:** 12 inline `DateFormat.yMMMd(l10n.localeName)` call sites across
  11 screens, each building its own `intl` pattern.
- **After:** two helpers — `formatMediumDate` (yMMMd) and
  `formatMediumDateTime` (yMMMd + `jm`, the profile's datetime site) —
  byte-identical output pinned by tests comparing helper output against the
  direct `DateFormat` call (EN + AR). `.toLocal()` stays at the audit call site.

### E1 — shared `AppEntryCard` (`lib/shared/widgets/app_entry_card.dart`)
- **Before:** 9 near-identical ~78-line feature entry cards (booking,
  discovery, matters, documents, messaging, billing, compliance, tasks,
  approvals), differing only in class name, icon, and l10n keys.
- **After:** one `AppEntryCard` (icon bubble, title/subtitle, chevron,
  InkWell, RTL-safe, theme-aware) + 9 thin compatibility wrappers keeping the
  public names (the home screen and l10n tests construct three by type).

### E3 — `ViewStateSwitch` (`lib/shared/widgets/view_state_switch.dart`)
- **Before:** the loading/empty/error/offline/unauthorized switch duplicated
  in ~17 list surfaces (the plan counted ~19 including the state-block
  variants).
- **After:** one `ViewStateSwitch<T>` — the feature supplies `empty`,
  `errorCopy`, `onRetry`, and the success `builder`; the arms render
  identically. Re-pointed **11 sites** (7 plain list screens + 4 matter
  workspace sections, the latter via the `loadingPadding`/`errorPadding`/
  `errorTextStyle` defaults). Complements, and is documented as distinct
  from, the existing `ViewStateView` (centered full-page message).

### E2 — `AppTile` (`lib/shared/widgets/app_tile.dart`)
- **Before:** the `radiusLg` outlined card row (avatar/icon, title over a
  metadata line, optional chips, chevron) duplicated by the 4 search result
  tiles and the list-screen rows.
- **After:** one `AppTile` with the **D-C2** nullable-`onTap` posture (no
  InkWell, no chevron, no clip when null) and the **D-MSG1** `showChevron`
  opt-out (the messaging thread row is whole-row tappable yet deliberately
  chevron-free). The 4 search tiles and the matter tile were inlined
  (search 692→379 lines, matter_list 271→192); the document, message,
  approval, and task tiles were slimmed to thin wrappers.

### E4 — `showConfirmDialog` (`lib/shared/widgets/confirm_dialog.dart`)
- **Before:** 3 identical destructive-confirm dialogs (roster member-removal,
  profile delete-account, admin demo-account-delete) — title, content,
  cancel→false, error-tinted confirm→true.
- **After:** one `showConfirmDialog({context, title, content, confirmLabel})`
  with the localized cancel resolved internally; each site keeps its own l10n
  keys (profile's audit-note content Column stays at the call site).

### E5 — `LabelChip` (`lib/shared/widgets/label_chip.dart`)
- **Before:** 5 chips duplicating the `spaceSm`-padded `radiusSm` container
  with a single-line label (matter status, document type, message count,
  roster role, roster status).
- **After:** one `LabelChip(label, background, foreground, style, maxLines)`
  — foreground always applied over the base style, 1-line ellipsis default
  with a null-clamp opt-out. The 3 public feature chips (one test-constructed)
  and the 2 roster chips became thin wrappers; the roster status chip keeps
  its per-status color switch.

## 3. Before/after summary

| Metric | Before | After |
|---|---|---|
| Duplicated component bodies | 9 entry cards + 4 search tiles + 5 list rows + 3 dialogs + 5 chips + 12 date sites + 11 state switches | each in one shared component (+ thin wrappers where the public name is part of the API) |
| Shared widgets in `lib/shared/widgets/` | — | `AppEntryCard`, `AppTile`, `ViewStateSwitch`, `showConfirmDialog`, `LabelChip` + `date_formatting.dart` helpers (all barrel-exported) |
| Test suite | 1193 | 1228 (+35 shared-widget tests, none deleted or weakened) |
| Net code | — | +1643 / −1797 across 66 file-touches |

## 4. Residual duplication (deliberately not extracted)

These shapes are structurally different from the extracted components, so
forcing them in would require flag sprawl or a behavior change. Each is
documented at its site and kept as-is:

1. **Pattern-B list screens — approvals, compliance, tasks.** Their
   loading/empty/error arms are wrapped in `ListView`s with local-only
   notes, and their offline/unauthorized arms render the *plain* empty copy
   while the empty arm renders the note-wrapped variant. **ADDRESSED
   2026-08-11** by `lib/shared/widgets/view_state_list.dart` (design:
   `docs/view_state_list_followup_design_2026-08-11.md`) — a sibling of
   `ViewStateSwitch` that owns the ListView + note layout; the
   offline/unauthorized quirk is preserved and pinned by tests.
2. **Invoice tile (billing).** Two subtitle lines plus a stray trailing
   `SizedBox` gap — does not fit the single-subtitle `AppTile` row without
   a multi-line variant (designed follow-up).
3. **Audit `_OutcomeChip` (orgs).** `spaceXs` vertical padding, `radiusLg`,
   `labelMedium` — different geometry from `LabelChip`'s `spaceSm`/`radiusSm`.
4. **Home `StatusChip` (dashboard).** Uppercase text transform, `spaceXs`
   vertical padding, `labelLarge` + 0.5 tracking — different behavior, not a
   superficial clone.
5. **Centered-message screens — `attorney_profile`, `matter_details`,
   `booking`. `Center(spinner)` loading and centered message shapes differ
   from `ViewStateSwitch`'s start-aligned arms.
6. **Column-layout rows — thread-detail `_MessageTile` and the matter
   workspace `_*Row`s.** No leading avatar, vertical text stack — not
   `AppTile` rows.

## 5. Verification at close-out

- `dart format --set-exit-if-changed lib test` — clean
- `flutter analyze` — No issues found
- `flutter test` — 1228 passed
- `bash scripts/verify_ledger.sh` — PASS 115/0/0
- `bash scripts/verify_policy_tests.sh --check` — PASS 73/0/0
- `git status` — clean; `origin/main == HEAD` at `2e86303`

## 6. Follow-ups

- **Pattern-B scrollable-state variant — DONE 2026-08-11** (`ViewStateList`,
  approvals/compliance/tasks re-pointed). Optional owner decision remains:
  normalize the offline/empty-arm quirk (see the design doc §4).
- Invoice-tile two-subtitle-line variant so billing joins `AppTile`.
- Optional: fold `_OutcomeChip`/home `StatusChip` into a parameterized
  `LabelChip` only if a second consumer of their geometry appears.
