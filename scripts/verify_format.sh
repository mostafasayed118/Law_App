#!/usr/bin/env bash
#
# verify_format.sh — re-runnable whole-repo formatting gate.
#
# Mirrors ci.yml's "Verify formatting" step EXACTLY:
#
#   dart format --output=none --set-exit-if-changed .
#
# Whole-repo scope ('.', not 'lib test') is the point: CI formats the entire
# tree, so a local gate that scopes to lib/ + test/ can accept bytes CI will
# reject (e.g. a formatter-revision bump in flutter stable changing the
# default style, as happened with the audit T2-T4 files on 2026-08-08).
# Run this before committing any Dart change; wire it into the local gate
# wherever the docs say "format clean".
#
# Usage:
#   scripts/verify_format.sh
#     Runs the exact CI command and reports the verdict.
#   scripts/verify_format.sh --selftest
#     Proves the gate's teeth: (1) the embedded command still matches
#     ci.yml's "Verify formatting" step, and (2) a misformatted file still
#     trips the FAIL path. Never mutates the repo working tree (the
#     misformatted file lives in a scratch temp dir).
#   scripts/verify_format.sh --help
#     Prints this usage.
#
# Exit codes:
#   0 — all files formatted (nothing changed); in --selftest, all drift
#       classes detected
#   1 — one or more files need formatting (CI would fail); in --selftest, a
#       drift class evaded the gate
#   2 — usage error or dart not on PATH
#
# Intended use: the whole-repo format gate in the standard slice gate,
# replacing the narrower `lib test`-scoped check. See scripts/README.md.

set -u

usage() {
  sed -n '2,24p' "$0" | awk 'NR > 1 && !/^#/ { exit } /^#/ { sub(/^# ?/, ""); print }'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi
if [ $# -gt 0 ] && [ "$1" != "--selftest" ]; then
  printf 'verify_format.sh: unexpected argument(s): %s\n' "$*" >&2
  printf 'Try scripts/verify_format.sh --help\n' >&2
  exit 2
fi

if ! command -v dart >/dev/null 2>&1; then
  printf '[XX] dart not found on PATH — run inside the Flutter toolchain environment.\n' >&2
  exit 2
fi

selftest() {
  failures=0
  printf '\n== verify_format --selftest ==\n'

  # Drift class 1: the embedded command must still match ci.yml's
  # "Verify formatting" step. If either side drifts, the local gate and CI
  # disagree — the exact failure this script exists to prevent.
  embedded='dart format --output=none --set-exit-if-changed .'
  ci_step="$(sed -n '/- name: Verify formatting/,/^[[:space:]]*[a-z]/p' .github/workflows/ci.yml | grep 'run:' | head -1 | sed 's/^[[:space:]]*run:[[:space:]]*//')"
  if [ "$embedded" = "$ci_step" ]; then
    printf '[OK] embedded command matches ci.yml: %s\n' "$embedded"
  else
    printf '[XX] drift: script runs %s but ci.yml runs %s\n' "$embedded" "$ci_step" >&2
    failures=$((failures + 1))
  fi

  # Drift class 2: a misformatted file must trip the FAIL path. The scratch
  # file lives in a temp dir so the repo working tree is never touched.
  scratch="$(mktemp -d)"
  printf 'void main(){print(1);}\n' > "$scratch/bad.dart"
  out="$(cd "$scratch" && dart format --output=none --set-exit-if-changed . 2>&1)"
  status=$?
  rm -rf "$scratch"
  if [ "$status" -ne 0 ]; then
    printf '[OK] misformatted file trips the FAIL path (exit %s)\n' "$status"
  else
    printf '[XX] drift: a misformatted file passed the format check (exit 0)\n' >&2
    failures=$((failures + 1))
  fi

  if [ "$failures" -gt 0 ]; then
    printf 'RESULT: FAIL — %d drift class(es) evaded the gate.\n' "$failures"
    exit 1
  fi
  printf 'RESULT: PASS — all drift classes detected.\n'
  exit 0
}

if [ "${1:-}" = "--selftest" ]; then
  selftest
fi

printf '== verify_format == whole-repo dart format check (mirrors ci.yml) ==\n'
# The exact CI command. Capture its output; exit status is authoritative.
output="$(dart format --output=none --set-exit-if-changed . 2>&1)"
status=$?

printf '%s\n' "$output"

if [ "$status" -ne 0 ]; then
  changed="$(printf '%s\n' "$output" | grep -c '^Changed ' || true)"
  printf '== summary: 0 passed, 0 warnings, %d failure(s) ==\n' "$changed"
  printf 'RESULT: FAIL — %d file(s) need formatting. Run `dart format .` and re-check.\n' "$changed"
  exit 1
fi

printf '== summary: 1 passed, 0 warnings, 0 failures ==\n'
printf 'RESULT: PASS — whole repo is formatted per the CI formatter.\n'
exit 0
