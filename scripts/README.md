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
     `password_recovery_cubit.dart` absent at approval.
3. **Suite reconciliation** — the audit plan's N/N suite claims for the 8
   milestone commits are recomputed from the tree at each revision and compared
   to the claimed figure. The count is `test(`/`testWidgets(`/`blocTest(` plain
   declarations **plus** the `blocTest<...>` generic form (the two shapes the
   cubit tests use), which is exactly what reconciles each claimed total.

### Exit codes

- `0` — all checks passed (WARNs allowed).
- `1` — at least one FAIL (unresolvable/dangling hash, missing marker,
  file-presence violation, suite-count mismatch). Do not commit/push docs
  amendments on a FAIL.

### Extending

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
- It does not run `flutter test`; it is a static git-object gate. Pair it with
  the suite run when the change touches `test/`.
