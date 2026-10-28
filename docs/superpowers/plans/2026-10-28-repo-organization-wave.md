# Repo Organization Wave — Phase 1 (P0 + P1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clear the repo root of ignored clutter and dissolve `lib/data/` into `lib/core/{supabase,persistence,platform}` and `lib/features/<x>/{domain,data}`, so every feature is self-contained — with zero behavior change.

**Architecture:** Pure relocation. Each task runs `git mv` for a fixed file set, rewrites package-path imports with one parameterized helper, then proves the tree green with `flutter analyze` + the full suite. No class, file, or API is renamed; the only editable lines are `import` statements plus three documentation paragraphs.

**Tech Stack:** Flutter/Dart, git, PowerShell 5.1 (Windows host), bash (repo verify scripts).

**Spec:** `docs/superpowers/specs/2026-10-28-repo-organization-wave-design.md`

## Global Constraints

- **Suite baseline is 2119 test declarations**, and `README.md` L458 claims `**2119 tests**`. Every task must leave that number unchanged.
- **Gate commands must exit 0** after every task: `flutter analyze`, `flutter test`, `bash scripts/verify_ledger.sh`, `bash scripts/verify_format.sh`, `bash scripts/verify_policy_tests.sh --check`.
- **No renames.** Only directory placement and import paths change. If a task tempts you to rename a file to fit, stop — the plan is wrong, not the file.
- **Never run a search-replace over `docs/`.** It holds ~50 frozen campaign records that mention `lib/data`; they are history. Only `README.md`, `INSTRUCTIONS.md`, and the spec are edited.
- **`main.dart` is the only file with relative imports that cross a moving boundary** (3 of them). Everything else is `package:legalhub/...`.
- **Do not add `* text=auto` to `.gitattributes`** — `core.autocrlf` is `true` and it would renormalize the repo.
- Run each task as its own commit. Do not push.

## Review Focus

1. **A rewrite that lands on a file that exists but is wrong.** The `data/auth/` prefix rule would send `supabase_env.dart` into `features/auth/data/` unless Task 2 moves it to `core/supabase/` first. Task 2 must precede Task 6, and Task 2 Step 6 asserts no `data/auth/supabase_env` reference survives.
2. **A test that is silently no longer discovered.** `test/data/` mirrors `lib/data/`; if a file stays behind in a directory that gets deleted, its tests vanish and the suite still passes. The 2119 declaration count is the only thing that catches this — it is checked in Task 7.
3. **`main.dart`'s three relative imports.** They are invisible to a `package:legalhub/data/` search and break the build only at analyze time.
4. **Rewriting frozen history.** A careless repo-wide replace inside `docs/` would corrupt 167 audit records that describe the tree as it was.
5. **Encoding drift across ~130 edited files.** Verified: `[IO.File]::ReadAllText` / `WriteAllText` round-trips byte-identically (same SHA-256, no BOM). `verify_format.sh` is the backstop.

---

### Task 1: P0 — root hygiene and ignore rules

**Files:**
- Modify: `.gitignore` (add `.kilo/`, `.kilocode/`)
- Delete: `flutter_01.log` … `flutter_13.log`, `projects/`
- Move out of repo: `stitch_legalhub_mobile_app/`, `stitch_legalhub_mobile_app.rar`

**Interfaces:**
- Consumes: nothing.
- Produces: a working tree with no ignored clutter; `.kilo/` ignored by the repo, not by `.git/info/exclude`.

- [ ] **Step 1: Confirm the current ignore source**

Run: `git check-ignore -v .kilo/worktrees/trail-fall`
Expected: `.../.git/info/exclude:9:.kilo/worktrees/` — machine-local, invisible to a fresh clone.

- [ ] **Step 2: Add the repo-local rules**

In `.gitignore`, after the `.workbuddy-ai/` line in the agent-scratch block, add:

```
.kilo/
.kilocode/
```

- [ ] **Step 3: Verify the rule now comes from the repo**

Run: `git check-ignore -v .kilo/worktrees/trail-fall`
Expected: `.gitignore:NN:.kilo/` (not `.git/info/exclude`).

- [ ] **Step 4: Delete the regenerable logs and the empty directory**

```powershell
Remove-Item flutter_*.log -Force
Remove-Item projects -Force -Recurse -Confirm:$false   # verified empty
```

Run: `Get-ChildItem flutter_*.log; Test-Path projects`
Expected: no output; `False`.

- [ ] **Step 5: Move the design archives out of the repo**

Owner-confirmed destination: `C:\flutter_projects\_design_refs\legalhub_stitch\`.

```powershell
New-Item -ItemType Directory -Force C:\flutter_projects\_design_refs\legalhub_stitch | Out-Null
Move-Item stitch_legalhub_mobile_app      C:\flutter_projects\_design_refs\legalhub_stitch\
Move-Item stitch_legalhub_mobile_app.rar  C:\flutter_projects\_design_refs\legalhub_stitch\
```

Run: `Test-Path stitch_legalhub_mobile_app, stitch_legalhub_mobile_app.rar`
Expected: `False`, `False`. **Move, never delete** — the `.rar` may be the only copy.

- [ ] **Step 6: Confirm the tree is still clean and the gate passes**

Run: `git status --short` → expected: nothing but `.gitignore`.
Run: `bash scripts/verify_ledger.sh` → expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add .gitignore
git commit -m "chore(repo): ignore Kilo worktrees repo-locally and drop root clutter"
```

---

### Task 2: Extract provider primitives to `lib/core/supabase/`

**Files:**
- Create: `lib/core/supabase/`
- Move: `lib/data/{row_reader,supabase_wire,postgrest_failures,list_query_guards,supabase_seam}.dart`, `lib/data/auth/supabase_env.dart`
- Modify: `lib/main.dart` (1 relative import), and every importer of the six files

**Interfaces:**
- Consumes: nothing.
- Produces: `package:legalhub/core/supabase/{row_reader,supabase_wire,postgrest_failures,list_query_guards,supabase_seam,supabase_env}.dart`.

- [ ] **Step 1: Write the rewrite helper outside the repo**

Create `C:\Users\ASUS\AppData\Local\Temp\opencode\reorg_rewrite.ps1`:

```powershell
param(
  [Parameter(Mandatory)][string]$From,
  [Parameter(Mandatory)][string]$To
)
$files = @(Get-ChildItem lib,test -Recurse -File -Filter *.dart).FullName
$changed = 0
foreach ($f in $files) {
  $text = [System.IO.File]::ReadAllText($f)
  if ($text.Contains($From)) {
    [System.IO.File]::WriteAllText($f, $text.Replace($From, $To))
    $changed++
  }
}
Write-Output "rewrote $changed file(s): $From -> $To"
```

This round-trips byte-identically (verified: same SHA-256, no BOM).

- [ ] **Step 2: Move the six files**

```powershell
New-Item -ItemType Directory -Force lib\core\supabase | Out-Null
git mv lib/data/row_reader.dart          lib/core/supabase/row_reader.dart
git mv lib/data/supabase_wire.dart       lib/core/supabase/supabase_wire.dart
git mv lib/data/postgrest_failures.dart  lib/core/supabase/postgrest_failures.dart
git mv lib/data/list_query_guards.dart   lib/core/supabase/list_query_guards.dart
git mv lib/data/supabase_seam.dart       lib/core/supabase/supabase_seam.dart
git mv lib/data/auth/supabase_env.dart   lib/core/supabase/supabase_env.dart
```

- [ ] **Step 3: Rewrite the five root-file imports (~61 refs)**

```powershell
$s = "$env:TEMP\opencode\reorg_rewrite.ps1"
foreach ($n in 'row_reader','supabase_wire','postgrest_failures','list_query_guards','supabase_seam') {
  powershell -NoProfile -File $s -From "package:legalhub/data/$n.dart" -To "package:legalhub/core/supabase/$n.dart"
}
```

Expected: nonzero counts for each (supabase_wire 20, supabase_seam 18, postgrest_failures 17, row_reader 5, list_query_guards 1).

- [ ] **Step 4: Rewrite `supabase_env` importers**

```powershell
powershell -NoProfile -File $s -From "package:legalhub/data/auth/supabase_env.dart" -To "package:legalhub/core/supabase/supabase_env.dart"
```

Expected: 1 file (the test that imports it by package path).

- [ ] **Step 5: Fix the one relative import in `lib/main.dart`**

Line 24 becomes `import 'core/supabase/supabase_env.dart';`. This is the only `data/` relative import `supabase_env` has.

- [ ] **Step 6: Verify no stale reference survives**

Run: `git grep -n "data/auth/supabase_env\|data/row_reader\|data/supabase_wire\|data/postgrest_failures\|data/list_query_guards\|data/supabase_seam"`
Expected: no output.

- [ ] **Step 7: Prove the tree is green**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Run the suite**

Run: `flutter test`
Expected: all pass. Declaration count unchanged:
`git grep -E "^\s*(test|testWidgets|blocTest)\s*[<(]" -- test | Measure-Object -Line` → `2119`.

- [ ] **Step 9: Commit**

```bash
git add -A lib test
git commit -m "refactor(lib): move Supabase provider primitives to core/supabase"
```

---

### Task 3: Extract persistence stores to `lib/core/persistence/`

**Files:**
- Create: `lib/core/persistence/`
- Move: 11 files from `lib/data/local/`, plus `lib/core/onboarding/onboarding_store.dart`
- Modify: `lib/main.dart` (1 relative import), 48 package references

**Interfaces:**
- Consumes: the helper script from Task 2 Step 1.
- Produces: `package:legalhub/core/persistence/<store>.dart` for `locale_store`, `theme_mode_store`, `org_selection_store`, `onboarding_store`, their `in_memory_*` and `shared_preferences_*` implementations.

- [ ] **Step 1: Move the eleven stores**

```powershell
New-Item -ItemType Directory -Force lib\core\persistence | Out-Null
Get-ChildItem lib\data\local -File -Filter *.dart | ForEach-Object {
  git mv $_.FullName "lib/core/persistence/$($_.Name)"
}
git mv lib/core/onboarding/onboarding_store.dart lib/core/persistence/onboarding_store.dart
```

Expected: `lib/data/local/` empty; `lib/core/onboarding/` empty (remove it in Task 3 Step 5 if `Test-Path` is true).

- [ ] **Step 2: Rewrite the package references (48 refs)**

```powershell
$s = "$env:TEMP\opencode\reorg_rewrite.ps1"
powershell -NoProfile -File $s -From "package:legalhub/data/local/" -To "package:legalhub/core/persistence/"
powershell -NoProfile -File $s -From "package:legalhub/core/onboarding/" -To "package:legalhub/core/persistence/"
```

- [ ] **Step 3: Fix the relative import in `lib/main.dart`**

Line 22 becomes `import 'core/persistence/onboarding_store.dart';`.

- [ ] **Step 4: Verify and gate**

Run: `git grep -n "data/local/\|core/onboarding/"` → expected: no output.
Run: `flutter analyze` → expected: `No issues found!`.

- [ ] **Step 5: Remove the empty directories**

```powershell
if (-not (Get-ChildItem lib\data\local -Force)) { Remove-Item lib\data\local }
if ((Test-Path lib\core\onboarding) -and -not (Get-ChildItem lib\core\onboarding -Force)) { Remove-Item lib\core\onboarding }
```

- [ ] **Step 6: Run the suite and commit**

Run: `flutter test` → all pass, 2119 declarations.

```bash
git add -A lib test
git commit -m "refactor(lib): move persistence stores to core/persistence"
```

---

### Task 4: Extract platform adapters to `lib/core/platform/`

**Files:**
- Move: `lib/data/files/file_selector_file_picker.dart`, `lib/data/files/url_launcher_uri_opener.dart`

**Interfaces:**
- Consumes: the helper script.
- Produces: `package:legalhub/core/platform/{file_selector_file_picker,url_launcher_uri_opener}.dart`.

- [ ] **Step 1: Move and rewrite (4 refs)**

```powershell
New-Item -ItemType Directory -Force lib\core\platform | Out-Null
git mv lib/data/files/file_selector_file_picker.dart lib/core/platform/file_selector_file_picker.dart
git mv lib/data/files/url_launcher_uri_opener.dart    lib/core/platform/url_launcher_uri_opener.dart
powershell -NoProfile -File "$env:TEMP\opencode\reorg_rewrite.ps1" -From "package:legalhub/data/files/" -To "package:legalhub/core/platform/"
```

- [ ] **Step 2: Verify and gate**

Run: `git grep -n "data/files/"` → expected: no output.
Run: `flutter analyze` → expected: `No issues found!`.
Run: `flutter test` → all pass.

- [ ] **Step 3: Commit**

```bash
git add -A lib test
git commit -m "refactor(lib): move platform adapters to core/platform"
```

---

### Task 5: Move feature-owned seams into `features/<x>/data/`

**Files:** 44 files across 13 features, per the mapping below.

**Interfaces:**
- Consumes: the helper script.
- Produces: `package:legalhub/features/<feature>/data/<file>.dart` for each moved file.

| From | To | Files | Refs |
|---|---|---|---|
| `lib/data/billing/` | `lib/features/billing/data/` | 8 | 28 |
| `lib/data/messaging/` | `lib/features/messaging/data/` | 7 | 19 |
| `lib/data/matters/` | `lib/features/matters/data/` | 6 | 20 |
| `lib/data/documents/` | `lib/features/documents/data/` | 3 | 13 |
| `lib/data/storage/` | `lib/features/storage/data/` | 3 | 13 |
| `lib/data/notifications/` | `lib/features/notifications/data/` | 3 | 11 |
| `lib/data/booking/` | `lib/features/booking/data/` | 2 | 7 |
| `lib/data/research/` | `lib/features/research/data/` | 2 | 6 |
| `lib/data/tasks/` | `lib/features/tasks/data/` | 2 | 6 |
| `lib/data/video/` | `lib/features/video/data/` | 2 | 6 |
| `lib/data/discovery/` | `lib/features/discovery/data/` | 2 | 5 |
| `lib/data/approvals/` | `lib/features/approvals/data/` | 2 | 4 |
| `lib/data/compliance/` | `lib/features/compliance/data/` | 2 | 4 |

- [ ] **Step 1: Confirm no target collision**

For each feature above: the destination `lib/features/<f>/data/` must not already contain a file with the same basename. Verified clean at plan time — re-run the check if the branch has moved:

```powershell
Get-ChildItem lib\data -Directory | ForEach-Object {
  $t = "lib\features\$($_.Name)\data"
  if (Test-Path $t) {
    $src = Get-ChildItem $_.FullName -File -Filter *.dart | Select-Object -ExpandProperty Name
    $tgt = Get-ChildItem $t -File -Filter *.dart | Select-Object -ExpandProperty Name
    $src | Where-Object { $tgt -contains $_ } | ForEach-Object { "COLLISION: features/$($_.Name)/data/$_" }
  }
}
```

Expected: no output.

- [ ] **Step 2: Move the 44 files**

```powershell
foreach ($f in 'billing','messaging','matters','documents','storage','notifications','booking','research','tasks','video','discovery','approvals','compliance') {
  $target = "lib/features/$f/data"
  New-Item -ItemType Directory -Force $target | Out-Null
  Get-ChildItem "lib\data\$f" -File -Filter *.dart | ForEach-Object { git mv $_.FullName "$target/$($_.Name)" }
}
```

- [ ] **Step 3: Rewrite the 142 package references**

```powershell
$s = "$env:TEMP\opencode\reorg_rewrite.ps1"
foreach ($f in 'billing','messaging','matters','documents','storage','notifications','booking','research','tasks','video','discovery','approvals','compliance') {
  powershell -NoProfile -File $s -From "package:legalhub/data/$f/" -To "package:legalhub/features/$f/data/"
}
```

- [ ] **Step 4: Verify and gate**

Run: `git grep -nE "legalhub/data/(billing|messaging|matters|documents|storage|notifications|booking|research|tasks|video|discovery|approvals|compliance)/"` → expected: no output.
Run: `flutter analyze` → expected: `No issues found!`.
Run: `flutter test` → all pass, 2119 declarations.

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "refactor(lib): move feature-owned data seams into their features"
```

---

### Task 6: Move core-owned seams and adopt D4 (one uniform rule)

Contracts move first, then implementations, so each half compiles on its own.

**Files:**
- Move contracts (9): `lib/core/auth/*` → `features/auth/domain/`; `lib/core/admin/*` → `features/admin/domain/`; `lib/core/organizations/*` → `features/orgs/domain/`
- Move implementations (26): `lib/data/auth/*` (8) → `features/auth/data/`; `lib/data/admin/*` (4) → `features/admin/data/`; `lib/data/orgs/*` (14) → `features/orgs/data/`
- Modify: `lib/main.dart` (1 relative import)

**Interfaces:**
- Consumes: the helper script.
- Produces: `features/auth/domain/{auth_gateway,auth_state,session,auth_outcome}.dart`, `features/admin/domain/{platform_admin_gateway,audit_entry}.dart`, `features/orgs/domain/{organization_gateway,organization_models,membership_repository}.dart`, and their implementations under the matching `data/` directories.

- [ ] **Step 1: Move the nine domain contracts**

```powershell
$moves = @{
  'auth/auth_gateway.dart'                   = 'auth'
  'auth/auth_state.dart'                     = 'auth'
  'auth/session.dart'                        = 'auth'
  'auth/auth_outcome.dart'                   = 'auth'
  'admin/platform_admin_gateway.dart'        = 'admin'
  'admin/audit_entry.dart'                   = 'admin'
  'organizations/organization_gateway.dart'  = 'orgs'
  'organizations/organization_models.dart'   = 'orgs'
  'organizations/membership_repository.dart' = 'orgs'
}
foreach ($src in $moves.Keys) {
  $file    = Split-Path $src -Leaf
  $feature = $moves[$src]
  New-Item -ItemType Directory -Force "lib/features/$feature/domain" | Out-Null
  git mv "lib/core/$src" "lib/features/$feature/domain/$file"
}
```

A `@(@('a','b'), @('c','d'))` literal would flatten in PowerShell and silently break the loop — the hashtable avoids that.

- [ ] **Step 2: Rewrite the five contract import sites**

```powershell
$s = "$env:TEMP\opencode\reorg_rewrite.ps1"
powershell -NoProfile -File $s -From "package:legalhub/core/auth/" -To "package:legalhub/features/auth/domain/"
powershell -NoProfile -File $s -From "package:legalhub/core/admin/" -To "package:legalhub/features/admin/domain/"
powershell -NoProfile -File $s -From "package:legalhub/core/organizations/" -To "package:legalhub/features/orgs/domain/"
```

Run: `flutter analyze` → expected: `No issues found!`.

- [ ] **Step 3: Move the 26 implementations**

```powershell
foreach ($f in 'auth','admin','orgs') {
  $target = "lib/features/$f/data"
  New-Item -ItemType Directory -Force $target | Out-Null
  Get-ChildItem "lib\data\$f" -File -Filter *.dart | ForEach-Object { git mv $_.FullName "$target/$($_.Name)" }
}
```

- [ ] **Step 4: Rewrite the 140 package references**

```powershell
$s = "$env:TEMP\opencode\reorg_rewrite.ps1"
foreach ($f in 'auth','admin','orgs') {
  powershell -NoProfile -File $s -From "package:legalhub/data/$f/" -To "package:legalhub/features/$f/data/"
}
```

- [ ] **Step 5: Fix the last relative import in `lib/main.dart`**

Line 23 becomes `import 'features/auth/data/supabase_auth_api_impl.dart';`.

- [ ] **Step 6: Remove the emptied `core` directories**

```powershell
foreach ($d in 'auth','admin','organizations') {
  if ((Test-Path "lib\core\$d") -and -not (Get-ChildItem "lib\core\$d" -Force)) { Remove-Item "lib\core\$d" }
}
```

- [ ] **Step 7: Verify no stale boundary remains**

Run: `git grep -nE "legalhub/(data|core/(auth|admin|organizations))/"` → expected: no output.
Run: `flutter analyze` → expected: `No issues found!`.
Run: `flutter test` → all pass, 2119 declarations.

- [ ] **Step 8: Commit**

```bash
git add -A lib test
git commit -m "refactor(lib): give auth, admin and orgs one folder each (D4)"
```

---

### Task 7: Mirror the move in `test/`, delete `lib/data/`, run the docs truth pass

**Files:**
- Move: `test/data/<feature>/` → `test/features/<feature>/data/` (16 features); `test/data/local/` → `test/core/persistence/`; 6 root test files → `test/core/supabase/`
- Delete: `lib/data/` (now empty) and its `.gitkeep`
- Modify: `README.md` L403, `INSTRUCTIONS.md` L252 (and its `INSTRUCTIONS.md` L214 mention of the path), the spec's phase status

**Interfaces:**
- Consumes: all prior tasks.
- Produces: `test/` mirroring `lib/`; no `lib/data/`; documentation matching the tree.

- [ ] **Step 1: Move the test subdirectories**

```powershell
foreach ($d in Get-ChildItem test\data -Directory) {
  $name = $d.Name
  if ($name -eq 'local') { $target = 'test/core/persistence' }
  else { $target = "test/features/$name/data" }
  New-Item -ItemType Directory -Force $target | Out-Null
  Get-ChildItem $d.FullName -File -Filter *.dart | ForEach-Object { git mv $_.FullName "$target/$($_.Name)" }
}
```

- [ ] **Step 2: Move the six cross-cutting test files**

```powershell
New-Item -ItemType Directory -Force test\core\supabase | Out-Null
foreach ($f in 'api_fault_injection_test.dart','gateway_parity_test.dart','list_query_guards_test.dart','rls_denial_matrix_test.dart','row_reader_test.dart','supabase_wire_test.dart') {
  git mv "test/data/$f" "test/core/supabase/$f"
}
```

- [ ] **Step 3: Verify no test file was left behind**

```powershell
if (Get-ChildItem test\data -Recurse -File -Filter *.dart) { "LEFTOVER FILES" } else { "test/data empty" }
```

Expected: `test/data empty`. **If anything remains, stop** — those tests would vanish silently.

- [ ] **Step 4: Delete `lib/data/`**

```powershell
if (Get-ChildItem lib\data -Recurse -File -Filter *.dart) { "LEFTOVER FILES - STOP" } else { Remove-Item lib\data -Recurse -Force }
```

Run: `Test-Path lib/data` → expected: `False`.

- [ ] **Step 5: Prove the count did not drift**

Run: `git grep -E "^\s*(test|testWidgets|blocTest)\s*[<(]" -- test | Measure-Object -Line`
Expected: `2119`. A lower number means a test was orphaned in a deleted directory.

- [ ] **Step 6: Rewrite the two live documentation claims**

- `README.md` L403: replace the `lib/data/**/supabase_*_impl.dart` phrasing with the new placement — provider adapters now live in `lib/features/<feature>/data/`, and provider primitives in `lib/core/supabase/`.
- `INSTRUCTIONS.md` L252: replace the whole "Adapter placement — the seam's owner decides the home" paragraph with the single rule: **a feature owns its `domain/`, `data/` and `presentation/`; `lib/core/` holds only primitives with no product noun; `lib/data/` no longer exists.** Also update the `lib/data/list_query_guards.dart` path in L214 to `lib/core/supabase/list_query_guards.dart`.
- Do **not** touch `docs/*_YYYY-MM-DD*.md` — frozen records.
- In the spec (`docs/superpowers/specs/2026-10-28-repo-organization-wave-design.md`), update the P1 phase line to record that commits 1–7 landed in this wave, so the spec stops describing already-executed work.

- [ ] **Step 7: Run every gate**

```bash
flutter analyze
flutter test
bash scripts/verify_ledger.sh
bash scripts/verify_format.sh
bash scripts/verify_policy_tests.sh --check
```

Expected: analyze `No issues found!`; suite green with 2119 declarations; every script exit 0.

- [ ] **Step 8: Add the final zero-reference assertion**

Run: `git grep -nE "legalhub/(data/|core/(auth|admin|organizations)/)"`
Expected: no output. This is the wave's completion proof — no `lib/data/` path and no `core/` product domain survives anywhere in `lib/` or `test/`.

- [ ] **Step 9: Commit**

```bash
git add -A lib test README.md INSTRUCTIONS.md
git commit -m "refactor(test): mirror the data-layer move and retire lib/data"
```

---

## Self-review notes

- **Spec coverage:** P0 → Task 1. P1 commits 1–7 → Tasks 2, 3, 4, 5, 6, 7 (Task 7 covers commits 6 and 7). D4 → Task 6. The docs truth pass the spec requires → Task 7 Step 6.
- **Deferred by design:** P2 (docs records), P3 (schema bundle), P4 (l10n output dir) are separate plans; each phase in the spec is independently landable.
- **Not covered on purpose:** removing the nested worktree `.kilo/worktrees/trail-fall` (owner confirmation pending) and the empty `config/`, `memory/` agent directories (gitignored by design).
