# Owner Review — Hardcoded Values Remediation

- **Date:** 2026-10-26
- **Merged worktree:** `C:\flutter_projects\law_app_merged`
- **Integration base:** `0b52374` (`fix/audit-remediation` tip; audit campaign landed)
- **State:** committed on `refactor/hardcoded-values-merged` at `5ea0218`; clean tree; no push
- **Verdict:** **Committed — pending push GO**

## Gates (merged tree)

| Gate | Result |
|---|---|
| `flutter analyze` | **No issues found!** |
| Full `flutter test` | **1989 passed**, 0 failed |
| `dart format --set-exit-if-changed lib test tool` | **677 files, 0 changed** |
| `scripts/verify_ledger.sh` | **115 passed, 0 failures** (README 1983) |
| README counts | **1983 declarations / 1989 runtime** |

## What changed

- **Canonical homes:** theme/motion, `server_limits`, `pagination`, Supabase
  tables/RPCs/edge functions, postgrest/HTTP codes, deep-link config, demo
  corpus, research wire codes, audit outcome constants.
- **129 failure keys:** exhaustive `AppMessageKey`, `AppError.messageKey`,
  `appErrorLabel` on view/list/switch/task surfaces, EN/AR/TR ARBs, all 129
  mapped with no fallback. AR/TR are machine-drafted and carry `[REVIEW]`.
- **Demo gating:** home Recent Activity, notification summaries, home
  subtitles, search notes, research no-match — configured builds no longer
  show demo fixtures or demo copy.
- **Six behavior changes:** dev deep links/recovery/share links, Edge invoke
  timeout, client caps (120/2000), localized failure copy, configured-build
  demo gating, explicit unknown research-code state.
- **Integration:** 195 tracked content changes + 34 new files (the 281
  porcelain entries include 56 EOL-only artifacts). Three conflicts resolved:
  `error_reporter.dart` + test (audit version; campaign only formatted),
  `message_thread_detail_cubit.dart` (campaign keys + audit busy/closed guard).
  ARBs merged by key: **902 EN / 1027 AR / 1027 TR**; `fake_async` added as a
  direct dev dependency.

## Deferred / owner decisions

1. **Push GO (next).** The campaign is committed as `5ea0218` on
   `refactor/hardcoded-values-merged` (from `0b52374`); the tree is clean and
   the post-commit gates are green. Push remains a separate GO.
2. **Human AR/TR review.** 156 `[REVIEW]` entries each; the translation review
   doc lists every key and checkbox.
3. **Accepted minors.** 38 review minors are itemized in the close-out and
   inventory; none are merge-blocking. One keyed message-too-long copy is not
   user-visible because the composer uses its older localized mapping (Minor).

## Evidence

- Close-out: `docs/hardcoded_values_closeout_2026-10-24.md`
- Inventory: `docs/hardcoded_values_inventory_2026-10-24.md`
- Translation review: `docs/l10n/translation_review_2026-10-24.md`
- Error-copy TSV: `docs/l10n/error_copy_inventory_2026-10-24.tsv`
- Execution ledger: `.superpowers/sdd/2026-10-24-hardcoded-values-remediation/progress.md`
- Campaign diff vs `0b52374`: `merged-integration-review.diff` in the ledger
  workspace (kept in the campaign worktree; not copied into the repo).

**No commits, no push, no live Supabase change.**
