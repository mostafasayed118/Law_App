# scripts/ — repo-local verification tooling

| Script | What it verifies | When to run |
|---|---|---|
| `verify_ledger.sh` | Governance-ledger integrity (below) | **Before committing any `docs/` amendment** that touches the audit plan or Gate 3 reconciliation; wired into CI as a cheap static gate (`ci.yml` on every push/PR) plus a **nightly teeth-prover** (`ledger-selftest.yml`, 02:00 UTC + `workflow_dispatch`) |
| `verify_policy_tests.sh` | P0-closure policy battery (below) | Against an **ephemeral rehearsal project only**, before any P0-close decision; `--check` is static and runs anywhere, and is wired into `ci.yml` as a DB-free gate on every push/PR, with a **nightly teeth-prover** (`ledger-selftest.yml` runs `--selftest`, 02:00 UTC + `workflow_dispatch`) |
| `verify_format.sh` | **Whole-repo** Dart formatting, mirroring `ci.yml`'s exact command | **Before committing any Dart change** — the format step of the standard slice gate. Use this instead of a `lib test`-scoped `dart format` check, which can drift from CI's whole-repo scope (see below) |

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

## `verify_format.sh`

The whole-repo Dart format gate. Runs exactly what `ci.yml`'s "Verify
formatting" step runs:

```bash
scripts/verify_format.sh
scripts/verify_format.sh --selftest   # prove the gate's teeth (below)
```

### Why whole-repo, and why a script

CI runs `dart format --output=none --set-exit-if-changed .` — the **entire
tree**, not just `lib/` and `test/`. A local gate scoped to `lib test` can
accept bytes CI rejects: the audit T2–T4 files (2026-08-08) passed a
`lib test`-scoped check under one formatter revision and then failed CI when
flutter stable 3.44.4's formatter wanted tall-style trailing commas in 6
files. `verify_format.sh` makes the local gate byte-identical to the CI
step, so a formatter-revision bump surfaces locally instead of on the
runner. It also keeps one canonical command in the gate docs instead of an
inline `dart format` incantation that can be scoped differently.

### `--selftest` mode

Proves the gate's teeth on demand, mirroring the ledger/policy selftests:
(1) the embedded command still matches `ci.yml`'s "Verify formatting" step
byte-for-byte — the drift class this script exists to prevent; (2) a
misformatted file in a scratch temp dir still trips the FAIL path. The
baseline gate must pass first (or the selftest aborts); the repo working
tree is never mutated. Both classes are verified to FAIL on injection.

### Exit codes

- `0` — whole repo formatted (nothing changed); in `--selftest`, all drift
  classes detected.
- `1` — ≥1 file needs formatting; run `dart format .` and re-check; in
  `--selftest`, a drift class evaded the gate.
- `2` — usage error or `dart` not on PATH.

## `verify_policy_tests.sh`

The P0-closure policy battery runner (`supabase/tests/` + this script,
D-P0C2). Mirrors `verify_ledger.sh`'s structure: named `[OK]`/`[XX]`
checks, a summary line, and a `RESULT: PASS|FAIL` verdict with exit codes.

```bash
SUPABASE_TEST_DB_URL=postgresql://postgres:***@host:5432/postgres scripts/verify_policy_tests.sh
scripts/verify_policy_tests.sh --apply   # build an ephemeral project from the committed supabase/ files
scripts/verify_policy_tests.sh --check   # static validation, no database
```

### What it checks

1. **Structural + grant pins** — the six tables exist with RLS enabled; the
   narrow SELECT grants (audit_events/platform_config deliberately absent);
   the R-4 policy-helper EXECUTE grants present while `write_audit`,
   `is_platform_owner`, `active_membership`, `expire_stale_invitations`,
   `handle_new_user` stay denied; the full 18-RPC EXECUTE surface;
   zero policies on audit_events/platform_config (D-P0C4); the D-P0C1(b)
   forward pin (matters, documents + message_threads shipped as the first
   three §14 un-deferrals; individual message rows/bodies + files still
   absent).
2. **Behavior battery** — `00_fixtures.sql` then the per-matrix-block SQL
   files `01/02/03` (matrix §2/§3/§5, D-P0C1(a)/D-P0C3/D-P0C4) + the three
   §14 un-deferral batteries `04_matter_rls.sql` / `05_document_rls.sql` /
   `06_message_rls.sql` (matrix §4 rows), each check a DO block that raises
   `POLICY-BATTERY FAIL <id>: <detail>` on violation.

### Dev-project guard

`SUPABASE_TEST_DB_URL` hosts containing the known live-dev-project ref
(`eutmvevpskerzpqmwplv`, the DO-NOT-TOUCH project) are hard-refused: the
battery fixtures `DELETE` from `auth.users`/`platform_config`, so a typo’d
URL would be destructive. `ALLOW_DEV_PROJECT=1` overrides for an explicit,
read-only owner sweep.

### Honest limitations

- Requires a database for the real run; the battery is only as trustworthy
  as the ephemeral project it runs against — the evidence record must cite
  the committed refs it was built from (R2).
- `--check` validates file structure and fixture-UUID consistency; it does
  not execute SQL.
- Provider-level flows and storage/realtime rows stay out of scope (P2 r5
  methodology); content-table deny rows are the forward pin (D-P0C1b), not
  executable tests — those tables do not exist yet.

## CI wiring

- **`ci.yml`** runs `scripts/verify_ledger.sh` (the plain battery, no
  `--selftest`) on every push to `main` and PR targeting `main` — the
  committed-ledger gate on the exact pushed bytes.
- **`ci.yml`** runs `dart format --output=none --set-exit-if-changed .` as
  its "Verify formatting" step — `scripts/verify_format.sh` is the local
  mirror of that exact command, so the gate docs and CI can never disagree
  on scope. CI keeps the inline command (no bash dependency for a one-line
  step); the script exists for the local slice gate.
- **`ci.yml`** also runs `scripts/verify_policy_tests.sh --check` (the
  DB-free static mode) on every push to `main` and PR targeting `main` —
  the policy battery's structural gate on the exact pushed bytes (battery
  file presence, fixture-UUID resolution, FAIL-marker coverage, harness
  self-syntax). The **live** battery stays the owner-side ephemeral-rehearsal
  gate: no database is provisioned in CI.
- **`ledger-selftest.yml`** runs `scripts/verify_ledger.sh --selftest`
  nightly (02:00 UTC, default branch) and on demand via `workflow_dispatch`.
  It proves the battery still detects all six drift classes on the runner,
  catching a silent regression in the gate's detection logic even without a
  push. Needs only bash + git (no Flutter toolchain), and checkouts with full
  history (`fetch-depth: 0`) because the selftest creates a scratch worktree
  at HEAD and the battery validates cited hashes against the whole object
  database.
- **`ledger-selftest.yml`** also runs `scripts/verify_policy_tests.sh
  --selftest` nightly (02:00 UTC, default branch) and on demand via
  `workflow_dispatch` — the policy battery's teeth-prover: it injects each
  known drift class (missing battery file, dangling fixture UUID, stripped
  FAIL marker, weakened harness file list, dropped doc hook, broken harness
  syntax) into a scratch worktree and asserts the DB-free `--check` battery
  FAILs on each, mirroring the ledger's six-class selftest.
