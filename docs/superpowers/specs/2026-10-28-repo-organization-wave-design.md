# Repo Organization Wave — Design

- **Date:** 2026-10-28
- **Status:** Approved in chat; awaiting written-spec review
- **Scope:** file and folder layout only. No behavior change, no dependency change, no product work.
- **Deliverable:** five independently landable phases (P0–P4), each with its own commit(s), gates, and rollback.

---

## 1. Why this wave

The repository grew through a long, well-governed campaign: 476 tracked files under `lib/`, 221 under `test/`, 210 under `docs/`, 177 under `supabase/`. The *code* structure held up; the *placement* rules did not. Four conventions compete for the same files, and 167 campaign records share one flat directory with the 15 specifications that are actually referenced.

This wave finishes migrations the codebase already started. It does not introduce a new architecture.

---

## 2. Measured current state

### 2.1 `lib/` — feature-first, with three leftover homes

20 features under `lib/features/`. Layer presence is not uniform:

| Shape | Features | Count |
|---|---|---|
| `domain` + `data` + `presentation` | approvals, auth, billing, booking, compliance, discovery, documents, matters, messaging, notifications, research, storage, tasks, video | 14 |
| `domain` + `presentation` | home, search | 2 |
| `presentation` only | admin, onboarding, orgs, profile | 4 |

The missing layers are supplied from two other trees:

| Location | Contents | Dart files |
|---|---|---|
| `lib/data/<feature>/` | Supabase implementations, API seams, and some test doubles | 84 across 18 dirs |
| `lib/data/*.dart` | Shared data-layer primitives (`row_reader`, `supabase_wire`, `postgrest_failures`, `list_query_guards`, `supabase_seam`) | 5 |
| `lib/core/<product-noun>/` | Domain contracts for `auth` (4), `admin` (2), `organizations` (3), `onboarding` (1 store contract) | 10 |

Two consequences, both measured:

1. **The data layer depends on feature internals.** `lib/data/**` imports `package:legalhub/features/**` **28 times** (14 files, e.g. `supabase_matter_gateway.dart` importing `features/matters/domain/matter.dart`). The outermost layer reaches into the feature tree.
2. **The same feature is spread over three directories.** `matters` = `features/matters/{domain,presentation}` + `features/matters/data` (2 test doubles) + `lib/data/matters` (6 implementations). `orgs` = `features/orgs/presentation` + `core/organizations` (3 contracts) + `lib/data/orgs` (14 files, including 8 test doubles). `auth` = `features/auth/{domain,data,presentation}` + `core/auth` (4) + `lib/data/auth` (9).

`lib/core/` otherwise holds genuinely cross-cutting infrastructure with no product noun: `async`, `contracts`, `errors`, `localization`, `observability`, `roles`, `state`, `use_cases`, `validation`.

Persistence is split the same way: contract + implementation pairs live in `lib/data/local/` (11 files) — **except** `onboarding`, whose contract lives in `lib/core/onboarding/` and whose implementations live in `lib/data/local/`.

### 2.2 `docs/` — 182 markdown files in one directory

| Kind | Count | Example |
|---|---|---|
| Dated campaign records | **167** | `matter_write_apply_approval_2026-08-09.md` |
| Canonical (undated) specifications | **15** | `permission_matrix.md`, `rollback_plan.md` |

Records by month: **2026-08 = 144**, 2026-09 = 12, 2026-10 = 11.

The filename already encodes the lifecycle phase: `_scope` (24), `_plan` (25), `_rehearsal` (20), `_completion_evidence` (16), `_apply_approval` (13), `_apply_execution` (13), `_gate_review` (10), `_design` (7), `_decision` (6), `_close_out` (2).

**The decisive measurement:** of roughly 360 path references to `docs/*.md` across `docs/` and `README.md` (only 7 of them markdown links — the rest are backtick prose references), **all of them point at the 15 canonical specifications. Zero point at the 167 dated records.** Moving the records therefore costs no prose churn — only the governance scripts.

### 2.3 `supabase/` — migrations are not replayable

| Path | Files | Role |
|---|---|---|
| `migrations/` | 58 | Schema only — **1** `CREATE POLICY` across all of them |
| `policies/` | 26 | RLS policies (source of truth) |
| `rpc/` | 57 | Functions; 56 `CREATE OR REPLACE FUNCTION` + `_down.sql` |
| `tests/` | 27 | Policy battery (`00_fixtures.sql` + 26 numbered suites) |

4,626 SQL lines of policy and RPC live outside `migrations/`. They are assembled at apply time by `scripts/verify_policy_tests.sh --apply`. **A fresh `supabase db reset` produces no RLS and no RPC** — the schema-only tree would come up wide open and functionally incomplete.

### 2.4 Root and generated files

| Item | Size | Git status |
|---|---|---|
| `.kilo/worktrees/trail-fall` (nested git worktree) | 936 files | Ignored **only** by `.git/info/exclude` — machine-local, invisible to a fresh clone |
| `stitch_legalhub_mobile_app/` | 193 files | Ignored by `.gitignore` |
| `stitch_legalhub_mobile_app.rar` | 20 MB | Ignored by `.gitignore` |
| `flutter_01.log` … `flutter_13.log` | 13 files | Ignored by `*.log` |
| `projects/` | empty | — |
| `lib/l10n/app_localizations*.dart` | 4 files, 431,589 bytes | **Tracked**, generated, sitting beside the `.arb` sources |

`l10n.yaml` sets no `output-dir`, so generated Dart is emitted into `lib/l10n/` next to `app_en.arb` / `app_ar.arb` / `app_tr.arb`.

---

## 3. Invariants — what this wave must not break

1. **`scripts/verify_ledger.sh` must exit 0 after every phase.** It pins paths in two different ways, and they must not be confused:
   - *Working-tree* assertions (current path) — these follow a move.
   - *Historical* `marker` assertions executed as `git show <commit>:<path>` — these keep the path the file had **at that commit** and must not be rewritten.
2. **`scripts/verify_policy_tests.sh --check` must exit 0.** It asserts battery file presence, fixture-UUID resolution, and the audited RPC EXECUTE surface (34 `rpc/` files plus `mark_notifications_read`).
3. **`scripts/verify_arb_parity.sh` must exit 0.**
4. **`flutter analyze` clean; `flutter test` unchanged in count.** The test-count gate is declaration-based (`test(` / `testWidgets(` / `blocTest(`), so moving files cannot move the number — but the README is grepped against the recomputed total.
5. **No public API renames.** Class and file *names* stay identical through P1; only directory placement and import paths change.

### Gate-pinned documents (24 unique)

`codebase_audit_plan.md`, `gate3_decision.md`, `gate3_reconciliation.md`, `p0_decision_capture.md`, `p2_rehearsal_plan.md`, `tracked_deviations.md` — **6 canonical**, must not move.

**18 dated records** are also path-referenced by the three verify scripts and must have their references updated in the same commit as any move:

`billing_invoices_real_data_plan_2026-08-08` · `documents_real_data_plan_2026-08-07` · `f01_step2_matter_write_design_2026-08-09` · `matters_real_data_plan_2026-08-07` · `messages_real_data_plan_2026-08-07` · `notification_feed_gate_review_2026-08-11` · `p0_closure_scope_2026-08-05` · `p2_apply_approval_2026-08-01` · `p2_apply_execution_2026-08-01` · `p2_provider_loop_phase1_rehearsal_2026-08-08` · `p2_provider_loop_phase2_smoke_2026-08-08` · `p2_rehearsal_evidence_r3_2026-08-01` · `p2_rehearsal_evidence_r4_2026-08-01` · `p4_findings_register_2026-08-09` · `realtime_push_real_data_plan_2026-08-08` · `realtime_real_data_plan_2026-08-08` · `send_message_rpc_plan_2026-08-08` · `storage_real_data_plan_2026-08-08`

---

## 4. Decisions

### D1 — One feature, one folder (accepted)

`lib/data/` is dissolved. Every file moves to the tree that owns it:

| From | To | Files |
|---|---|---|
| `lib/data/<feature>/*` | `lib/features/<feature>/data/` | 70 across 16 features |
| `lib/data/local/*` | `lib/core/persistence/` | 11 |
| `lib/data/files/*` | `lib/features/storage/data/` | 2 |
| `lib/data/*.dart` | `lib/core/supabase/` | 5 |
| `lib/data/auth/supabase_env.dart` | `lib/core/supabase/` | 1 (build-time config consumed by `main.dart` before any feature exists) |
| `lib/data/.gitkeep` | deleted | 1 |

Reference scale (measured recursively): **334** `package:legalhub/data/<dir>/…` references and **61** `package:legalhub/data/<file>.dart` references across roughly 130 files, plus exactly **2** relative imports in `lib/main.dart`. All other imports are `package:legalhub/…`, and the 279 intra-folder relative imports survive a folder move unchanged.

Rationale: `lib/features/<x>/` becomes self-contained for 20 of 20 features; the 28 inverted imports disappear because `features/<x>/data` importing `features/<x>/domain` is an intra-feature dependency, not a cross-tree one.

**Rejected:** recentralizing the 20 test doubles into `lib/data/` (cheaper, but `data/` keeps mirroring `features/` forever). **Rejected:** documenting the split and fixing only the 4 outliers (cheapest, but permanently institutionalizes two answers to "where does this file go?").

### D2 — Canonical specs stay, records get dates (accepted)

`docs/records/YYYY-MM/` receives the 167 dated records, filenames unchanged. The 15 canonical specifications stay at `docs/` root. A new `docs/README.md` becomes the index.

Rationale: the 167 records are append-only history with **zero inbound references**; the 15 canonical files carry **all 368** inbound references. Splitting on that line means one group moves at no prose cost and the other never moves at all.

**Rejected:** index-only (does not fix the 182-file wall). **Rejected:** sub-folders per lifecycle phase (`scope/`, `plan/`, `evidence/`) — the filename already encodes the phase, so the folder duplicates the key and doubles the path churn for no new information.

### D3 — Generated schema bundle for replayability (accepted)

`supabase/migrations/99_policies_and_rpc.generated.sql` is produced by a new `scripts/build_schema_bundle.sh`, concatenating `policies/*.sql` then `rpc/*.sql` in filename order, **excluding `rpc/_down.sql`**. CI (or the local gate) regenerates into a temp file and asserts `git diff --exit-code` — the same static-gate + drift-proof pattern `verify_ledger.sh` and `verify_format.sh` already use in this repo.

Authoring stays in the 83 readable files: `policies/` and `rpc/` remain the source of truth; the bundle is a build artifact that makes `db reset` honest.

**Rejected:** folding 4,626 SQL lines into the table migrations — true single-source, but it rewrites the policy battery's file-list assertions and makes policy review harder. **Rejected:** documenting the limitation and changing nothing — leaves a fresh environment without RLS.

### D4 — Domain placement rule (**accepted 2026-10-28**)

> `lib/core/` holds no product noun.

Under that rule, `core/auth` → `features/auth/domain/`, `core/admin` → `features/admin/domain/`, `core/organizations` → `features/orgs/domain/`, and `core/onboarding/onboarding_store.dart` joins `lib/core/persistence/`. Total: 10 files, and **5 import sites across the three domain directories** (`core/auth` 2, `core/organizations` 2, `core/admin` 1); the onboarding store's own import sites need counting during execution.

**D4 is required by D1, not optional.** `INSTRUCTIONS.md` L252 documents the pre-existing rule ("a *core-owned* contract is implemented in `lib/data/<name>/`"), introduced by audit 2026-09-21 finding H-2 to end three coexisting conventions. Executing D1 while keeping that rule would put `auth`/`orgs`/`admin` contracts in `core/` and their implementations in `features/` — re-creating the split D1 removes. D4 supersedes L252, and P1 rewrites that section in the same commit.

Note the repo is already mid-migration under the old rule: `matters`, `documents`, `messaging`, `storage`, `billing`, `notifications` were documented as moving to `features/<x>/data/` "when next touched". This wave is that moment.

---

## 5. Target trees

### After P1

```
lib/
  main.dart  main_development.dart  main_production.dart
  app/            # router, theme, service locator, deep_link, localization
  core/
    async/ contracts/ errors/ localization/ observability/ roles/ state/ use_cases/ validation/
    supabase/     # NEW: row_reader, supabase_wire, postgrest_failures, list_query_guards, supabase_seam
    persistence/  # NEW: *locale/theme/onboarding/org_selection*_store.dart + in_memory_* + shared_preferences_*
  features/<20 features>/{data,domain,presentation}
  shared/
  l10n/
```

`lib/data/` no longer exists.

### After P2

```
docs/
  README.md                      # NEW index
  <15 canonical specifications>  # unchanged, never moved
  adr/  audit/  l10n/  superpowers/  waves/
  records/
    2026-08/   (144 files)
    2026-09/   (12 files)
    2026-10/   (11 files)
```

### After P4

```
lib/l10n/
  app_en.arb  app_ar.arb  app_tr.arb
  app_error_label.dart  app_message_l10n.dart   # hand-written
  generated/                                     # NEW: 4 generated files
    app_localizations.dart  app_localizations_{en,ar,tr}.dart
```

---

## 6. Phases

Each phase is independently landable, independently revertable, and leaves the repo green.

### P0 — Root hygiene and ignore rules

**Zero tracked-file moves.**

1. Add `.kilo/` and `.kilocode/` to `.gitignore` (currently machine-local only via `.git/info/exclude`).
2. Move `stitch_legalhub_mobile_app/` and `stitch_legalhub_mobile_app.rar` out of the repo tree (suggested: `C:\flutter_projects\_design_refs\legalhub_stitch\`).
3. Delete the 13 `flutter_*.log` files.
4. Delete the empty `projects/` directory.
5. Owner decision: remove the nested worktree `.kilo/worktrees/trail-fall` (`git worktree remove`) — **only after** confirming no uncommitted work at `d3baef5`. Not done automatically.

**Acceptance:** `git status --short` empty · `git status --ignored --short` reports `!! .kilo/` sourced from `.gitignore` (not `.git/info/exclude`) · no `stitch_*` entry, no `flutter_*.log`, and no `projects/` in a full directory listing · `bash scripts/verify_ledger.sh` exits 0.

**Gates:** `verify_ledger.sh`, `verify_policy_tests.sh --check`.

### P1 — Consolidate the data layer (D1 + D4)

**Status: landed (2026-10-28).** All seven commits below shipped in this wave; `lib/data/` no longer exists and the tree is green at 2119 declarations. The numbered list is kept as the executed record.

Seven landable commits, least entangled first. Every commit leaves `flutter analyze` clean and the suite green.

1. **`lib/core/supabase/`** — the 5 provider primitives + `supabase_env.dart`; rewrite 61 package refs and 1 of the 2 `main.dart` relative imports.
2. **`lib/core/persistence/`** — 11 stores from `data/local/` + `core/onboarding/onboarding_store.dart`; rewrite 48 refs.
3. **`lib/features/storage/data/`** — 2 adapters from `data/files/`; rewrite 4 refs.
4. **Feature-owned seams** (13 features) — 44 files into `features/<x>/data/`; 142 refs.
5. **Core-owned seams** (D4) — 9 contracts into `features/{auth,admin,orgs}/domain/`, then 26 implementations into `features/<x>/data/`; 140 refs + 5 contract import sites.
6. **`test/data/` mirror** — 17 subdirectories and 6 root files into `test/features/<x>/data/`, `test/core/persistence/`, `test/core/supabase/`.
7. **Delete `lib/data/`** and run the docs truth pass: `README.md` L403, `INSTRUCTIONS.md` L252 (the superseded adapter-placement rule), and `docs/superpowers/specs/2026-10-28-repo-organization-wave-design.md`.

Filenames and class names are unchanged throughout, so the diff is import lines plus `git mv` renames.

**Verified gate facts:**
- `verify_ledger.sh`'s file-presence block runs `git cat-file -e "f7621df:$f"` — a **historical** commit. Moving `lib/data/auth/fake_auth_gateway.dart` does not break it.
- No test asserts the adapter-placement paths; `test/bootstrap_boundaries_test.dart` covers `Result`/`ViewState`/`Redactor` behavior only.
- Frozen campaign records under `docs/` mention `lib/data` in ~50 files. They are history and must **not** be rewritten.

**Acceptance:** `Test-Path lib/data` → False · `flutter analyze` clean · suite count equals the pre-P1 baseline (2119 declarations, matching `README.md` L458) · zero `package:legalhub/data/` references · zero imports of `core/{auth,admin,organizations}` · `verify_ledger.sh` exits 0 · `verify_format.sh` exits 0.

**Rollback:** `git revert` per commit.

### P2 — `docs/records/YYYY-MM/` (D2)

1. `git mv` 167 dated records into `docs/records/{2026-08,2026-09,2026-10}/`.
2. Update the **18** path references in `scripts/verify_ledger.sh`, `verify_policy_tests.sh`, `verify_provider_loop.sh` — working-tree assertions only. Historical `marker` lines keep their old paths.
3. Add `docs/README.md`: canonical specs, folder map, and the record-naming convention.
4. Add a drift check to `verify_ledger.sh` (or a sibling script): no `docs/*_YYYY-MM-DD*.md` may remain at the root.

**Acceptance:** `docs/` root contains 15 `.md` specifications + `README.md` · all three verify scripts exit 0 · `git grep "docs/<old path>"` returns nothing for every moved file · the canonical-spec reference count is unchanged (no prose edits were made).

**Why medium risk:** it is the only phase that touches governance scripts. It must be one commit, not two, or CI fails in between.

### P3 — Replayable schema bundle (D3)

1. Add `scripts/build_schema_bundle.sh` (concatenate `policies/*.sql`, then `rpc/*.sql`, exclude `_down.sql`, emit a provenance header).
2. Generate `supabase/migrations/99_policies_and_rpc.generated.sql`.
3. Add the drift check: regenerate to a temp file, `git diff --exit-code`.
4. Document in `supabase/README.md` that `db reset` now reproduces RLS + RPC.

**Acceptance:** `supabase db reset` on a local stack yields the 17 public tables **with RLS enabled and policies present** · bundle regeneration is byte-identical · `verify_policy_tests.sh --apply` and `--check` pass · the audited RPC EXECUTE surface assertion still passes.

**Rollback:** delete the generated file and the script; no source file is modified.

### P4 — Generated-file hygiene

1. Add `output-dir: lib/l10n/generated` to `l10n.yaml`; regenerate; `git mv` the 4 files.
2. Fix the **2** import sites for `l10n/app_localizations.dart`.
3. Add `.gitattributes` marking `lib/l10n/generated/*` and `supabase/migrations/*.generated.sql` as `linguist-generated=true`. **Do not add `* text=auto`** in this wave — with `core.autocrlf` active that would renormalize every tracked file and bury the real diff.
4. *Optional:* split `scripts/` into `scripts/verify/` and `scripts/assets/` — **filenames and paths unchanged**, since CI and four documents reference them by name. Recommend deferring; low value, nonzero churn.

**Acceptance:** `flutter gen-l10n` writes only under `lib/l10n/generated/` · `flutter analyze` clean · `flutter test` unchanged · `verify_arb_parity.sh` exits 0.

---

## 7. Non-goals

- Renaming features, classes, widgets, or test files.
- Introducing a state-management, DI, or routing change.
- Splitting `app_localizations.dart` (4,397 generated lines) into per-feature filespaces.
- Refactoring `lib/features/video/presentation/video_call_screen.dart` (539 lines) or any oversized file — that is a code wave, not a folder wave.
- Touching `test/` layout: it already mirrors `lib/` and will follow automatically only where paths are asserted.
- Consolidating `docs/adr/`, `docs/audit/`, `docs/l10n/`, `docs/waves/`, `docs/superpowers/` — already organized.

---

## 8. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| P2 breaks `verify_ledger.sh` because a historical `marker` path was bulk-replaced | Medium | Split editing: `wt_file`/working-tree assertions follow the move; `marker <commit> <path>` lines never do. Re-run the gate before committing. |
| P1 misses an import in a test using a relative path | Low | `flutter analyze` fails loudly; packages use `package:legalhub/...` throughout, so a single `rg` sweep finds stragglers. |
| P1 collides with an in-flight worktree (`law_app_hardcoded`, `law_app_merged`) | Medium | Rebase or land those first; the wave is path-only and rebases cleanly, but run it on a single worktree. |
| P3's bundle drifts from `policies/`+`rpc/` silently | Medium | The drift check is the whole point — it must run in CI, not just locally. |
| P0 deletes something still needed (`.rar` is the only copy of the design export) | Low | *Move*, do not delete, the design archives. Only delete regenerable logs. |
| Nested worktree removal destroys uncommitted work | Low | Owner explicitly confirms before `git worktree remove`. |

---

## 9. Open owner decisions

1. ~~**D4** — adopt "`lib/core/` holds no product noun"?~~ **Accepted 2026-10-28**; it ships as part of P1 (commit 5).
2. **P0** — confirm the nested worktree `.kilo/worktrees/trail-fall` can be removed.
3. **P0** — confirm the destination for the 20 MB design archive (`C:\flutter_projects\_design_refs\legalhub_stitch\`).
4. **Order** — P2 and P3 are independent. If you prefer the riskiest move last, run P0 → P1 → P3 → P2 → P4.
