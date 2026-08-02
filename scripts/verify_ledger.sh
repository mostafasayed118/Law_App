#!/usr/bin/env bash
#
# verify_ledger.sh — re-runnable verification battery for the repo's
# governance ledger.
#
# Verifies, against the *actual git object database*:
#
#   1. HASH INTEGRITY — every backtick-wrapped hex token cited in the target
#      docs resolves via `git cat-file` AND is reachable from
#      `git rev-list --all` (all refs). A citation that resolves but is
#      unreachable (dangling) is flagged, not forgiven.
#
#   2. SEMANTIC ROW CHECKS —
#      a. The Gate 3 as-built table's 16 commit rows (`gate3_reconciliation.md`
#         §2) get their REAL commit subjects compared to the doc summaries via
#         keyword overlap (paraphrase match → WARN when no overlap, never a
#         hard FAIL, because the doc column is a paraphrase, not a subject).
#      b. Byte-exact content markers are asserted at their milestone commits
#         (A-string in both Gate 3 docs, .gitignore rules, README 190 count,
#         D-T2/D-T4 text, P1 approval row, contract-§5 session fields).
#      c. The §3 file-presence claims are re-verified at the approval commit
#         (`f7621df`): 10 files present, the org-context trio absent (then and
#         now), and `password_recovery_cubit.dart` absent at approval.
#      d. Working-tree markers: the A-string in both Gate 3 docs, the D-T2/D-T4
#         RESOLVED entries, the plan header's shell-nav arc entry (through
#         `4b5e4fc`, suite 277/277), and the README suite count are also
#         asserted against the CURRENT on-disk docs (not just committed
#         content at cited hashes), so a committed doc that quietly drops a
#         marker fails CI even without breaking a cited hash.
#
#   3. SUITE RECONCILIATION — the audit plan's N/N suite claims for the 8
#      milestone commits are recomputed from the tree at each revision
#      (plain `test(`/`testWidgets(`/`blocTest(` declarations + the
#      `blocTest<...>` generic form) and compared to the claimed figure.
#
# Usage:
#   scripts/verify_ledger.sh [doc ...]
#     With no args, verifies docs/codebase_audit_plan.md and
#     docs/gate3_reconciliation.md (the canonical ledger). Extra doc paths are
#     swept for hash integrity only.
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more FAILs (unresolvable/dangling hash, missing marker,
#       file-presence mismatch, suite-count mismatch)
#   WARNs do not fail the run (paraphrase overlap is fuzzy by nature).
#
# Intended use: run before committing any docs amendment; wire into CI as a
# cheap static gate. See scripts/README.md.

set -u

DEFAULT_DOCS=("docs/codebase_audit_plan.md" "docs/gate3_reconciliation.md")
if [ "$#" -gt 0 ]; then
  DOCS=("$@")
else
  DOCS=("${DEFAULT_DOCS[@]}")
fi

FAILS=0
WARNS=0
PASSES=0

note() { printf '  [..] %s\n' "$*"; }
ok()   { PASSES=$((PASSES + 1)); printf '  [OK] %s\n' "$*"; }
warn() { WARNS=$((WARNS + 1)); printf '  [WW] %s\n' "$*"; }
fail() { FAILS=$((FAILS + 1)); printf '  [XX] %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. HASH INTEGRITY
# ---------------------------------------------------------------------------
hash_integrity() {
  local doc tok low len tmp_ok tmp_bad rev_all total=0 checked=0 skipped=0
  for doc in "${DOCS[@]}"; do
    [ -f "$doc" ] || fail "doc not found: $doc"
  done
  tmp_ok=$(mktemp)
  tmp_bad=$(mktemp)
  rev_all=$(mktemp)
  git rev-list --all | sort -u > "$rev_all"

  # Backtick-wrapped alnum tokens, 5-40 chars (UUIDs and prose never match:
  # UUIDs contain dashes, and the closing backtick must follow immediately).
  grep -rhoE '`[A-Za-z0-9]{5,40}`' "${DOCS[@]}" 2>/dev/null \
    | tr -d '`' | tr '[:upper:]' '[:lower:]' | sort -u > "$tmp_ok"
  total=$(wc -l < "$tmp_ok")

  while read -r tok; do
    case "$tok" in *[!0-9a-f]*) continue ;; esac   # hex-only are hash candidates
    len=${#tok}
    # A bare backticked 6-char hex that sits on a color code (#xxxxxx) is a
    # theme token, not a hash — skip it explicitly.
    if [ "$len" -lt 7 ]; then
      if grep -q "#$tok" "${DOCS[@]}" 2>/dev/null; then
        skipped=$((skipped + 1)); continue
      fi
    fi
    checked=$((checked + 1))
    if ! git cat-file -e "$tok" 2>/dev/null; then
      fail "unresolvable hash: $tok"
      printf '%s\n' "$tok" >> "$tmp_bad"
      continue
    fi
    if ! grep -q "^$tok" "$rev_all"; then
      fail "dangling hash (resolves but not reachable from any ref): $tok"
      printf '%s\n' "$tok" >> "$tmp_bad"
      continue
    fi
    ok "hash $tok resolves + reachable"
  done < "$tmp_ok"

  note "hash integrity: $checked candidates checked across $total backtick tokens ($skipped color/short tokens skipped)"
  rm -f "$tmp_ok" "$tmp_bad" "$rev_all"
}

# ---------------------------------------------------------------------------
# 2. SEMANTIC ROW CHECKS
# ---------------------------------------------------------------------------
STOPWORDS=" the and for with into from that this test tests commit wire wiring add added feat fix chore docs refactor session model ";

normalize_words() {  # echoes lowercase alnum words, one per line, with a trailing newline
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/ /g' | tr -s ' ' '\n'; printf '\n'
}

keyword_overlap() {  # $1 summary, $2 subject -> prints count of shared significant words
  local w count=0
  while read -r w; do
    [ "${#w}" -lt 4 ] && continue
    case "$STOPWORDS" in *" $w "*) continue ;; esac
    if printf '%s' "$2" | tr '[:upper:]' '[:lower:]' | grep -q "$w"; then
      count=$((count + 1))
    fi
  done < <(normalize_words "$1")
  printf '%d' "$count"
}

semantic_rows() {
  local gate3="docs/gate3_reconciliation.md"
  local plan="docs/codebase_audit_plan.md"

  note "--- 2a. Gate 3 as-built table: doc summary vs real commit subject ---"
  if [ -f "$gate3" ]; then
    local line hash summary subject overlap
    while IFS= read -r line; do
      hash=$(printf '%s' "$line" | awk -F'|' '{gsub(/[ `]/,"",$2); print $2}')
      case "$hash" in *[!0-9a-f]*) continue ;; esac
      [ "${#hash}" -eq 7 ] || continue
      summary=$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')
      subject=$(git log -1 --format='%s' "$hash" 2>/dev/null)
      if [ -z "$subject" ]; then
        fail "as-built row hash missing from history: $hash"
        continue
      fi
      overlap=$(keyword_overlap "$summary" "$subject")
      if [ "$overlap" -eq 0 ]; then
        warn "row $hash: '$summary' shares no words with subject '$subject' — review paraphrase"
      else
        ok "row $hash ($summary) ↔ '$subject'"
      fi
    done < <(grep -E '^\| `[0-9a-f]{7}` \|' "$gate3")
  fi

  note "--- 2b. Byte-exact content markers ---"
  marker() { # marker <hash> <path> <pattern> <label> [flags]
    local h=$1 p=$2 pat=$3 label=$4 flags=${5:-E}
    if [ "$flags" = "-F" ]; then
      if git show "$h:$p" 2>/dev/null | grep -qF "$pat"; then ok "$label"; else fail "$label (missing at $h:$p)"; fi
    else
      if git show "$h:$p" 2>/dev/null | grep -qE "$pat"; then ok "$label"; else fail "$label (missing at $h:$p)"; fi
    fi
  }

  marker 45b0a48 docs/gate3_reconciliation.md 'Project Owner (github.com/mostafasayed118)' 'A-string in reconciliation §10' -F
  marker 45b0a48 docs/gate3_decision.md         'Project Owner (github.com/mostafasayed118)' 'A-string in gate3_decision §2.2' -F
  marker ed38fd6 .gitignore '^\.freebuff/$'     '.freebuff/ rule in .gitignore'
  marker ed38fd6 .gitignore '^\.openclaude/$'   '.openclaude/ rule in .gitignore'
  marker c6d4b69 README.md '190 total|\*\*190 tests\*\*' 'README test count 190'
  marker 1335512 docs/tracked_deviations.md '^## D-T2:.*RESOLVED \(2026-07-31\)' 'D-T2 RESOLVED ledger entry'
  marker 1335512 docs/tracked_deviations.md '^## D-T4: Demo `Session \{id, displayName, role\}`' 'D-T4 recorded entry'
  marker 94c9607 docs/p0_decision_capture.md 'P1 APPROVED \(2026-07-31\)' 'P1 approval recorded'
  marker 1042daf lib/core/auth/session.dart 'required this.userId' 'session.dart userId field' -F
  marker 1042daf lib/core/auth/session.dart 'required this.memberships' 'session.dart memberships field' -F
  marker 1042daf lib/core/auth/session.dart 'required this.expiresAt' 'session.dart expiresAt field' -F

  note "--- 2c. Gate 3 §3 file-presence at approval commit (f7621df) ---"
  local f present="lib/core/auth/auth_gateway.dart lib/core/auth/auth_state.dart lib/data/auth/fake_auth_gateway.dart lib/features/auth/presentation/auth_cubit.dart lib/features/home/presentation/settings_screen.dart lib/app/router.dart lib/app/service_locator.dart lib/main.dart test/bootstrap_boundaries_test.dart test/widget_test.dart"
  for f in $present; do
    if git cat-file -e "f7621df:$f" 2>/dev/null; then
      ok "present at approval: $f"
    else
      fail "§3.1a claim violated: $f NOT at f7621df"
    fi
  done
  local absent="lib/core/auth/organization_context.dart lib/features/auth/presentation/organization_context_cubit.dart test/auth_domain_p1_test.dart"
  for f in $absent; do
    if git cat-file -e "f7621df:$f" 2>/dev/null; then
      fail "§3.1b claim violated: $f IS at f7621df (should be never-created)"
    elif [ -e "$f" ]; then
      fail "§3.1b claim violated: $f exists in working tree today (should be never-created)"
    else
      ok "never-created confirmed: $f"
    fi
  done
  if git cat-file -e "f7621df:lib/features/auth/presentation/password_recovery_cubit.dart" 2>/dev/null; then
    fail "§3.1c claim violated: password_recovery_cubit.dart IS at f7621df (should be untracked WIP)"
  else
    ok "password_recovery_cubit.dart untracked at approval (confirmed)"
  fi

  note "--- 2d. Working-tree markers (current docs, not committed content) ---"
  local wt_file wt_count head_plain head_gen head_total plan_hdr
  for wt_file in docs/gate3_reconciliation.md docs/gate3_decision.md; do
    wt_count=$(grep -cF 'Project Owner (github.com/mostafasayed118)' "$wt_file" 2>/dev/null || true)
    if [ "${wt_count:-0}" -gt 0 ]; then
      ok "A-string present in working tree: $wt_file"
    else
      fail "A-string MISSING from working tree: $wt_file"
    fi
  done
  if grep -qE '^## D-T2:.*RESOLVED \(2026-07-31\)' docs/tracked_deviations.md 2>/dev/null; then
    ok "D-T2 RESOLVED entry in working tree tracked_deviations.md"
  else
    fail "D-T2 RESOLVED entry MISSING from working tree tracked_deviations.md"
  fi
  if grep -qE '^## D-T4:.*RESOLVED \(2026-07-31\)' docs/tracked_deviations.md 2>/dev/null; then
    ok "D-T4 RESOLVED entry in working tree tracked_deviations.md"
  else
    fail "D-T4 RESOLVED entry MISSING from working tree tracked_deviations.md"
  fi
  plan_hdr=$(awk 'BEGIN{p=0} /^>/{p=1; print; next} p && !/^>/{exit}' docs/codebase_audit_plan.md 2>/dev/null)
  if printf '%s' "$plan_hdr" | grep -q 'Shell navigation arc' \
      && printf '%s' "$plan_hdr" | grep -q '4b5e4fc' \
      && printf '%s' "$plan_hdr" | grep -q '277/277'; then
    ok "plan header blockquote: shell-nav arc entry through 4b5e4fc, suite 277/277"
  else
    fail "plan header blockquote missing shell-nav arc entry (through 4b5e4fc, suite 277/277)"
  fi
  head_plain=$(git grep -hE '(^|[^A-Za-z])(test|testWidgets|blocTest)\(' -- test/ 2>/dev/null | wc -l | tr -d ' ')
  head_gen=$(git grep -hE 'blocTest<' -- test/ 2>/dev/null | wc -l | tr -d ' ')
  head_total=$((head_plain + head_gen))
  if [ -f README.md ] && grep -qE "Tests \($head_total total\)" README.md && grep -qE "\*\*$head_total tests\*\*" README.md; then
    ok "README test count ($head_total) matches suite in working tree"
  else
    fail "README test count stale: suite in working tree is $head_total, README claim differs"
  fi
}

# ---------------------------------------------------------------------------
# 3. SUITE RECONCILIATION
# ---------------------------------------------------------------------------
suite_reconciliation() {
  note "--- 3. Suite counts (declarations at each milestone revision) ---"
  local pairs="a508013:190 e98e61b:205 88c3005:220 75ff17b:222 e8c70b9:235 7f2bf39:261 8aa0414:275 4b5e4fc:277"
  local pair h claim plain gen total
  for pair in $pairs; do
    h=${pair%%:*}
    claim=${pair##*:}
    plain=$(git grep -hE '(^|[^A-Za-z])(test|testWidgets|blocTest)\(' "$h" -- test/ 2>/dev/null | wc -l | tr -d ' ')
    gen=$(git grep -hE 'blocTest<' "$h" -- test/ 2>/dev/null | wc -l | tr -d ' ')
    total=$((plain + gen))
    if [ "$total" -eq "$claim" ]; then
      ok "$h suite $claim/$claim (plain $plain + blocTest<> $gen)"
    else
      fail "$h suite mismatch: claimed $claim, tree shows $total (plain $plain + blocTest<> $gen)"
    fi
  done
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------
printf '\n== verify_ledger == docs: %s\n' "${DOCS[*]}"
printf '== 1. Hash integrity ==\n'
hash_integrity
printf '== 2. Semantic row checks ==\n'
semantic_rows
printf '== 3. Suite reconciliation ==\n'
suite_reconciliation

printf '\n== summary: %d passed, %d warnings, %d failures ==\n' "$PASSES" "$WARNS" "$FAILS"
if [ "$FAILS" -gt 0 ]; then
  printf 'RESULT: FAIL — %d failure(s). Fix before committing docs amendments.\n' "$FAILS"
  exit 1
fi
printf 'RESULT: PASS\n'
exit 0
