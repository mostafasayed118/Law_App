# scripts/ — repo-local verification tooling

| Script | What it verifies | When to run |
|---|---|---|
| `verify_ledger.sh` | Governance-ledger integrity (below) | **Before committing any `docs/` amendment** that touches the audit plan or Gate 3 reconciliation; wire into CI as a cheap static gate |

## `verify_ledger.sh`

Re-runs the three-part verification battery used during the ledger audit, against
the **actual git object database** — not the docs' claims about it.

```bash
scripts/verify_ledger.sh                 # canonical docs (audit plan + gate3 reconciliation)
scripts/verify_ledger.sh path/to/other.md   # sweep extra docs for hash integrity only
scripts/verify_ledger.sh --selftest      # prove the gate's teeth (below)
```

### What it checks

1. **Hash integrity** — every backtick-wrapped hex token in the target docs must
   (a) resolve via `git cat-file -e` and (b) be reachable from `git rev-list --all`
   (all refs). A citation that resolves but is unreachable (dangling object) is a
   FAIL. UUIDs and prose never match the extractor (backtick-wrapped alnum, 5–40
   chars, closing backtick immediate), so rehearsal owner-ids and org-ids are
   correctly ignored; bare 6-char theme-color tokens (`#xxxxxx`) are skipped.
2. **Semantic row checks** —
   - the 16 Gate 3 as-built-table rows (`gate3_reconciliation.md` §2) have their
     **real commit subjects** compared to the doc summary via keyword overlap
     (paraphrase mismatch → WARN, never FAIL — the doc column is a paraphrase);
   - **byte-exact content markers** are asserted at their milestone commits
     (A-string in both Gate 3 docs at `45b0a48`, `.gitignore` rules at `ed38fd6`,
     README 190 count at `c6d4b69`, D-T2/D-T4 text at `1335512`, P1 approval row
     at `94c9607`, contract-§5 session fields at `1042daf`);
   - the §3 file-presence claims are re-verified at the approval commit
     (`f7621df`): 10 files present, the org-context trio absent (then and now),
     `password_recovery_cubit.dart` absent at approval;
   - **working-tree markers** (added to close the committed-content-only gap):
     the A-string in both Gate 3 docs, the D-T2/D-T4/D-T6 RESOLVED entries in
     `tracked_deviations.md`, the audit plan's header blockquote shell-nav
     arc entry (through `4b5e4fc`, suite 277/277), the P2 apply records'
     slice ref (`3704a1d` in both approval and execution), the r3/r4
     evidence verdicts (`NOT PASSED (R-4)` in the r3 record, `38 PASS +
     2 RECORDED` in the r4 record), the rehearsal plan's four evidence
     citations (`3266c23`, `2c31b27`, `38e4832`, `d0379d2`), and the README
     suite count are asserted against the **current on-disk docs**. The README
     count is checked dynamically —
     the pass counts `test(`/`testWidgets(`/`blocTest(` + `blocTest<...>`
     declarations in the working tree and greps the README for that exact
     number, so a committed doc that quietly drops a marker (or a README that
     drifts behind the suite) fails even when every cited hash still resolves.
3. **Suite reconciliation** — the audit plan's N/N suite claims for the 8
   milestone commits are recomputed from the tree at each revision and compared
   to the claimed figure. The count is `test(`/`testWidgets(`/`blocTest(` plain
   declarations **plus** the `blocTest<...>` generic form (the two shapes the
   cubit tests use), which is exactly what reconciles each claimed total.

### `--selftest` mode

Proves the battery's teeth on demand without touching the repo: creates a
scratch worktree at `HEAD`, then injects each known drift class — dead hash,
missing marker, wrong suite claim, dropped verdict, stale README count,
dropped citation — and asserts the battery FAILs with the expected message on
each. The baseline (unmutated scratch tree) must PASS first, or the selftest
aborts. Cleanup is automatic (the scratch worktree is removed and pruned on
exit). Runtime is roughly 7 battery runs (~15–30s on this repo). Note: the
selftest exercises the **committed tree at HEAD** — exactly what CI runs —
not uncommitted working-tree edits.

### Exit codes

- `0` — all checks passed (WARNs allowed); in `--selftest` mode, all drift
  classes were detected.
- `1` — at least one FAIL (unresolvable/dangling hash, missing marker,
  file-presence violation, suite-count mismatch); in `--selftest` mode, a
  drift class evaded the gate. Do not commit/push docs amendments on a FAIL.

### Extending

- **New working-tree markers**: add a `grep` assertion in the `2d` block of
  `semantic_rows()`. The README count check is dynamic (it recomputes the
  suite total and greps for that number), so it needs no maintenance as the
  suite grows — but the README itself must be kept in sync.
- The plan-header arc tokens (`4b5e4fc`, `277/277`), the apply-approval
  slice ref (`3704a1d`), the r3/r4 evidence verdict strings, and the
  rehearsal plan's four evidence citations (`3266c23`–`d0379d2`) are
  **intentionally pinned** to their records — when a future amendment
  supersedes them, advance the tokens deliberately in the same commit as the
  doc amendment, or the gate will red by design.
- **New milestone suite counts**: add a `hash:count` pair to the `pairs`
  variable in `suite_reconciliation()`. Verify the count first with
  `flutter test` at that commit, then record it.
- **New content markers**: add a `marker <hash> <path> <pattern> <label>` line
  in `semantic_rows()`. Use `-F` for literal patterns (e.g. the A-string);
  default is extended regex.
- **New docs to sweep**: pass paths as arguments.

### Honest limitations

- The suite reconciliation counts **declarations at a revision**, not executed
  tests — a loop inside a single `test()` body registers one test, and that is
  exactly how the recorded totals were produced (verified against the suite
  claims: all 8 milestones reconcile with zero diff).
- The as-built-table subject check is a paraphrase heuristic; a semantic
  mismatch that shares words (or a paraphrase that shares none) can slip past
  it. It is a reviewer aid, not a substitute for reading the diff.
- The working-tree marker pass greps the current docs but does not parse them;
  it catches a dropped marker or a stale count, not a subtly reworded claim.
- The dynamic README count uses `git grep` on the working tree, which counts
  *tracked* files only — an un-staged new test file is not counted until staged
  (a non-issue in CI's clean checkout, where working tree == pushed commit).
- It does not run `flutter test`; it is a static git-object gate. Pair it with
  the suite run when the change touches `test/`.
- The selftest's drift injections mutate the *scratch* worktree only; the
  repo working tree is never touched. The suite-claim drift is injected via a
  tampered script copy (the claim lives in the battery, not the docs).
