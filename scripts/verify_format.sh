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
#   scripts/verify_format.sh --help
#     Prints this usage.
#
# Exit codes:
#   0 — all files formatted (nothing changed)
#   1 — one or more files need formatting (CI would fail)
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
if [ $# -gt 0 ]; then
  printf 'verify_format.sh: unexpected argument(s): %s\n' "$*" >&2
  printf 'Try scripts/verify_format.sh --help\n' >&2
  exit 2
fi

if ! command -v dart >/dev/null 2>&1; then
  printf '[XX] dart not found on PATH — run inside the Flutter toolchain environment.\n' >&2
  exit 2
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
