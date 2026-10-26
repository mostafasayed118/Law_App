# Hardcoded Values Remediation — Close-out (2026-10-24)

Task 28 of the hardcoded-values remediation. Scope: full gates and close-out
reconciliation only. No commits, no push, no staging.

- **Worktree:** `C:\flutter_projects\law_app_hardcoded`
- **Branch:** `refactor/hardcoded-values`
- **HEAD (campaign base):** `7e6f80bae48647161f0c2df5ce7f81d7a1c671b8`
- **Merged integration base:** `0b52374f820a538d8c2e568479651cd442774ec0`
- **Baseline:** `docs/hardcoded_values_baseline_2026-10-24.md` (Task 1)
- **Inventory:** `docs/hardcoded_values_inventory_2026-10-24.md`
- **Execution ledger:** `.superpowers/sdd/2026-10-24-hardcoded-values-remediation/progress.md`

## 1. Test counts

| Measurement | Declarations | Runtime | Delta |
|---|---:|---:|---:|
| Task 1 baseline | 1924 | 1930 | — |
| Task 24 checkpoint (`progress.md`) | — | 1963 | +33 vs baseline |
| Task 28 final | 1976 | 1982 | +52 vs baseline |
| **Final-review fix wave (2026-10-26)** | **1982** | **1988** | **+58 vs baseline** |
| **Merged onto `0b52374` (2026-10-26)** | **1983** | **1989** | **+58 vs audit base 1925/1931** |

The delta is campaign test coverage, not pre-existing work:

- Tasks 3–24 net **+33** (1963 − 1930). This includes new suites for motion,
  timeouts, server limits, approval wire status, research wire codes, message
  keys, and the demo corpus, net of the Batch 20–22 test consolidations.
- Task 25 **+2** (`test/features/home/home_screen_test.dart`).
- Task 26 **+13** across its seven posture/localization test files.
- Task 27 **+4** (home +1, search +2, research +1).
- 25 + 26 + 27 = **+19**; 33 + 19 = **+52**.

The declaration/runtime gap stays at six parameterized loop cases, matching
the baseline convention. The full suite was run three times with
`flutter test --reporter expanded`: before the format pass, on the formatted
tree, and after the late `lib/app/flavor.dart` format extension. All three runs
ended with `+1982: All tests passed!`, exit 0. No failures and no skipped
tests.

The final-review fix wave added six tests (keyed research screen copy, AR keyed
view-state copy, explicit view-state fallback, args-only `AppError` inequality,
shared Edge Function timeout, and missing-args l10n fallbacks). Its full-suite
run ended with `+1988: All tests passed!`, exit 0. The same
`test|testWidgets|blocTest<` census now finds 1982 declarations; README carries
the updated 1982/1988 pair.

## 2. Analyzer

`flutter analyze` → `No issues found!` before formatting (85.7 s), after the
main format pass (97.4 s), and on the final tree (79.8 s). No analyzer fixes
were needed in Task 28.

## 3. Format gate

Manifest: 219 Dart files = 188 unique paths copied into
`.superpowers/sdd/2026-10-24-hardcoded-values-remediation/task-*-baseline/`,
28 campaign-new Dart files (staged, untracked, or plan-owned tests/tools), and
3 task-edited tracked files whose tasks created no baseline copy
(`lib/app/flavor.dart`, `lib/features/discovery/presentation/discovery_cubit.dart`,
`lib/features/search/presentation/search_screen.dart`). Parked-audit-only files
were not included.

First run of `dart format --output=none --set-exit-if-changed` (chunked to stay
under the Windows command-line limit): 14 dirty files. A completeness check
against the Task 3 and Task 10 reports then found the three unbudgeted files
above; one (`lib/app/flavor.dart`) was dirty. All 15 were formatted, then the
full 219-file gate was re-run and exited 0.

```
lib\app\flavor.dart
lib\data\admin\supabase_platform_admin_api_impl.dart
lib\data\approvals\supabase_approval_api_impl.dart
lib\data\approvals\supabase_approval_gateway.dart
lib\data\billing\supabase_payment_api_impl.dart
lib\data\compliance\supabase_compliance_api_impl.dart
lib\data\compliance\supabase_compliance_gateway.dart
lib\data\discovery\supabase_attorney_api_impl.dart
lib\data\matters\supabase_matter_api_impl.dart
lib\data\research\supabase_research_api_impl.dart
lib\data\supabase_wire.dart
lib\data\tasks\supabase_task_api_impl.dart
lib\data\video\supabase_video_api_impl.dart
test\policy\hardcoded_values_policy_test.dart
tool\error_copy_inventory.dart
```

Twelve of the 15 are the audit-interleaved `lib/data/**` files whose format
gate was explicitly deferred to Task 28 by the Task 7 ruling.

## 4. Behavior-change proofs

One expanded command (final-review finding #3):

```
flutter test test/app/deep_link test/app/localization test/features/admin test/features/approvals test/features/booking test/features/notifications test/features/search test/features/home test/features/research test/core/async test/core/contracts test/data/research test/l10n test/shared/widgets/view_state_view_test.dart
```

Result: **387 passed**, exit 0 (final re-run after the fix wave).

| Path | Behavior proven |
|---|---|
| `test/app/deep_link` | Config-aware scheme/host parsing and auth callback (Task 9). |
| `test/app/localization/app_localizations_test.dart` | `AppMessageKey` ARB parity, locale copy, and generated getters (Tasks 16–23). |
| `test/l10n/app_message_l10n_test.dart` | Exhaustive `appMessage` mapping and the missing-args `stateError` fallbacks (Tasks 16–23; fix-wave test). |
| `test/features/admin` | Platform-admin flows, denials, and localized error surfaces. |
| `test/features/approvals` | Approval status wire mapping and screen states (Task 13). |
| `test/features/booking` | Booking limits, slot-race recovery, and localized failure copy. |
| `test/features/notifications` | Notification feed, read-flag, prefs filtering, and error copy. |
| `test/features/search` | Search paging cap and partial-result/error states (Task 12). |
| `test/features/home` | Recent-activity posture gate and honest empty state (Tasks 25/27). |
| `test/features/research` | Research screen error copy, including the keyed unknown-code path (Task 14b; fix wave). |
| `test/data/research` | Unknown wire code → `research_failed` with its `messageKey` preserved (Task 14b; fix wave). |
| `test/core/async` | Request-timeout helper and the shared Edge Function 15 s invoke deadline (Task 8; fix wave). |
| `test/core/contracts` | Canonical server limits and network contracts (Task 11). Cap-widget rendering is covered separately below. |
| `test/shared/widgets/view_state_view_test.dart` | Capped view-state error copy: keyed EN/AR, explicit caller fallback, and the generic unkeyed default (fix wave). |

The command covers the behavior areas across fourteen test paths; `test/core/contracts` does not cover the cap widgets, so the view-state widget test is included explicitly.

## 5. Inventory reconciliation

Appended a close-out section to
`docs/hardcoded_values_inventory_2026-10-24.md` and reconciled every row:

| Final status | Rows | Composition |
|---|---:|---|
| `done` | 272 | 266 `extract` + 6 `component-local` |
| `deferred` | 0 | No value row deferred |
| `leave` | 14 | 9 text-theme font sizes, 4 fixture durations, 1 material color |
| **Total** | **286** | 154 primary + 132 supplement |

All `extract` rows are landed in their owning waves; the six
`component-local` rows were named in their component files by Task 4. The
`leave` rows retain `n/a` and their triage rationale. The SDD execution ledger
(`progress.md`) now records Tasks 2–27 complete and the Task 28 gate results.

## 6. Deferred items

No hardcoded-value row is deferred. The 38 review minors recorded in
`progress.md` remain documentation/test-quality notes; 34 are itemized in the
inventory close-out, and the remaining four are itemized here (fix wave,
finding #13; reconstructed from the Task 23–25 reports' recorded concerns
because `progress.md` stored counts only):

- **Task 23 (2):** AR/TR mapper copy is still machine-drafted and requires
  human translation review before release; the two inner `stateError`
  argument-guard defaults remain by design (removing them would not compile
  and would change missing-argument behavior).
- **Task 24 (1):** Task 24 edited `lib/shared/demo_labels.dart` despite the
  earlier ruling that Task 26 owns the class conversion; the switch bodies were
  left unchanged for Task 26 to build on.
- **Task 25 (1):** `test/features/home/widgets/home_cards_test.dart` was left
  untouched because the configured empty state is a private widget inside
  `home_screen.dart`, covered by the screen-level posture test.

## 7. README and ledger reconciliation

README counts moved from 1924 declarations / 1930 runtime to **1976
declarations / 1982 runtime** in Task 28, then to **1982 declarations / 1988
runtime** in all three places (quality-gates bullet, test summary, and
current-suite paragraph) after the final-review fix wave.

`scripts/verify_ledger.sh` previously counted declarations with
`git grep -- test/`, which ignores untracked files. Because Task 28 is
forbidden from staging, 30 declarations in campaign-new test files were
invisible and the dynamic README check would have failed. The two working-tree
counts now use `git grep --untracked`; the historical milestone reconciliation
is unchanged.

Task 28 historical ledger run (Git Bash, LF-normalized temp copy):

```
== summary: 115 passed, 0 warnings, 0 failures ==
RESULT: PASS
[OK] README test count (1976) matches suite in working tree
```

The final-review fix wave did not re-run the 115-check ledger. Its
working-tree declaration census is 1982, matching the README; the dynamic
README assertion in `verify_ledger.sh` is therefore expected to remain PASS.

## 8. Parked-audit integration note

- The Task 1 baseline is the parked `fix/audit-remediation` changeset, copied
  byte-exact (121 paths, patch SHA-1
  `6c4f5f43ff769f7ec5aa93da76b5d6021cf3de3d`). Campaign work and the parked
  audit remain interleaved in the working tree: 299 porcelain entries at
  close-out. Nothing was staged, committed, or pushed.
- Integration must diff the campaign manifest against `main`, not commit the
  worktree as one patch. For the 15 format-touched files above, the format-only
  whitespace must be separated from parked-audit edits; the Task 7 ruling
  anticipated this and assigned the format gate to Task 28.
- The main tree `C:\flutter_projects\law_app` was not modified.
- Seven staged additions and nine staged modifications were already present
  at Task 28 start (docs/tools plus `lib/app/legalhub_motion.dart`,
  `test/app/legalhub_motion_test.dart`, and
  `test/policy/hardcoded_values_policy_test.dart` among the additions; Task 10
  had staged `lib/app/flavor.dart` among the modifications). They were left
  as-is; the inventory,
  `tool/error_copy_inventory.dart`, and the policy test show `AM`, and
  `lib/app/flavor.dart` shows `MM`, only because their worktree content was
  edited by this close-out while the index still holds the earlier version.

## 9. Deviations and concerns

1. **Pre-existing staged entries.** The handover said all changes were
   unstaged, but seven additions (`A`) and nine modifications (`M`, including
   `lib/app/flavor.dart`) were already in the index. They were not re-staged;
   the edited additions now read `AM`, and flavor reads `MM`, because Task 28
   changed their worktree content only.
2. **Manifest completeness extension.** The briefed manifest (baselines plus
   new files) omitted three Task 3/Task 10 tracked files whose tasks created no
   baseline copy: `lib/app/flavor.dart`,
   `lib/features/discovery/presentation/discovery_cubit.dart`, and
   `lib/features/search/presentation/search_screen.dart`. They were added to
   the gate; only flavor was dirty and was formatted.
3. **Format scope.** Formatting the 12 audit-interleaved data files also
   reformatted parked-audit lines inside them. This follows the recorded
   Task 7 ruling, but the integration diff must not attribute those whitespace
   hunks to the parked audit.
4. **Ledger script behavior.** `git grep --untracked` requires Git 2.31+ (the
   worktree uses 2.50.1). This keeps the README check truthful before staging;
   CI should use the same Git capability.
5. **Script line endings.** `scripts/verify_ledger.sh` is CRLF; WSL bash cannot
   resolve this worktree's Windows-style `.git` pointer. The ledger was run
   with Git Bash against an LF-normalized temporary copy. This predates Task 28.
6. **Count convention.** README records declarations (1982), while the runtime
   suite count is 1988; both figures are stated explicitly to avoid the earlier
   ambiguity.

## 10. Final-review fix wave (2026-10-26)

Findings from the whole-branch review, all landed in the worktree without
staging or committing:

1. **Critical — behavior #6 surfaced.** `_errorMessage` now resolves the
   gateway's `AppMessageKey` through `appMessage` (args preserved) before the
   wire-code switch, so the unknown-code `research_failed` path renders
   `errUnableToRunAIResearchPleaseTryAgain`. Pinned by the updated
   `test/data/research/supabase_research_api_impl_test.dart` and a new screen
   test that asserts the localized keyed copy and rejects raw provider text.
2. **Important — proof command expanded and corrected.** Section 4 now runs
   admin, booking, notifications, search, `test/data/research`, `test/l10n`,
   `test/app/localization`, and the cap-widget test; the parity/unknown-code
   paths are attributed correctly.
3. **Important — Edge-timeout wiring tested.** `SupabaseSeam.invokeWithTimeout`
   now wraps the closure and applies `kSupabaseRequestTimeout`; video, payment,
   and research delegate to it. A `fakeAsync` test proves the 15 s deadline
   (`fake_async` added as a direct dev dependency; no behavior change).
4. **Important — exact wire names pinned.** `test/data/supabase_wire_test.dart`
   now asserts the exact 10 table names and 48 RPC names, not counts only.
5. **Minor — `messageArgs` equality.** Added to `AppError.props`; an args-only
   difference now compares unequal (test added).
6. **Minor — view-state fallback.** `ViewStateView` defaults an unkeyed error
   to `l10n.stateError`, never raw `error.userMessage`. The review's "unused in
   lib" premise was false: five auth/profile surfaces render it with localized
   copy. An explicit `errorFallback` parameter lets those five pass their
   localized message, so their copy is unchanged; the new default is covered by
   a widget test, plus an AR keyed-copy test.
7. **Minor — research fallback code.** Added
   `ResearchWireCodes.researchFailed` and used it at the gateway.
8. **Minor — deferred minors.** The four previously un-itemized notes are
   itemized in section 6.
9. **Minor — proof-table paths.** Corrected in section 4.
10. **Minor — AR keyed error test.** Added at the widget level (not
    mapper-only).
11. **Minor — args-missing fallback arms.** Both interpolation guards are
    tested in EN/AR/TR.

Gates after the wave: expanded proof **387 passed**; requested scoped command
`flutter test test/features/research test/data/research test/shared/widgets test/data test/core/errors test/l10n test/app/localization` → **854 passed**; full suite **1988 passed**; `flutter analyze` → `No issues found!`. All edits were baseline-copied under
`.superpowers/sdd/2026-10-24-hardcoded-values-remediation/final-review-fix-baseline/`.

## 11. Post-merge integration (2026-10-26)

The parked audit campaign landed at `fix/audit-remediation` HEAD
`0b52374` while the campaign was in flight. A separate worktree,
`C:\flutter_projects\law_app_merged`, was created at that commit and the
campaign changes were 3-way merged onto it (no commits, no push):

- Base: pre-task snapshot at `7e6f80b` + the 121-path parked changeset.
- Ours: the campaign worktree. Theirs: `0b52374`.
- ARBs merged by key: 158 EN / 312 AR / 312 TR campaign keys merged into the
  audit ARBs; totals **902 EN / 1027 AR / 1027 TR**.
- Three whole-file conflicts resolved: `error_reporter.dart` and its test took
  the audit version (campaign only formatted them); the messaging cubit was
  re-merged with normalized line endings and both the campaign message keys and
  the audit busy/closed guard are present.
- `fake_async: ^1.3.3` was added to `dev_dependencies` (the audit base did not
  have it; the timeout test imports it directly).
- Gates on the merged tree: `flutter analyze` → **No issues found!**; full
  suite → **1989 passed**, exit 0. README and `verify_ledger.sh` carry the
  merged **1983 declarations / 1989 runtime** counts.
- The campaign is committed as `5ea0218` on
  `refactor/hardcoded-values-merged` (from `0b52374`), 230 files, clean tree;
  no push. The main tree and the audit branch were not modified.

## 12. Integration review (2026-10-26)

Independent review of the merged tree returned **merge-ready** with no code
fixes. Verified: no conflict markers or duplicate ARB keys; the campaign message
keys and the audit busy/closed guard coexist; audit keys were not lost;
generated l10n matches the ARBs; `fake_async` is a direct dev dependency; README
1983/1989 matches the static census; ledger 115/0/0; format 677/0; analyzer
clean. The campaign is committed as `5ea0218` on
`refactor/hardcoded-values-merged` (the original branch name is held by the
stale campaign worktree). Post-commit gates: analyze clean, 1989 tests, ledger
115/0/0. The owner review package is
`docs/hardcoded_values_owner_review_2026-10-26.md`.
