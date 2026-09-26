#!/usr/bin/env bash
#
# verify_arb_parity.sh — ARB key-parity gate (R9, 2026-09-24).
#
# The non-English locales must carry exactly the same message keys as the
# English source of truth: a missing key renders as an untranslated fallback
# (or a blank) on-device, and the pre-launch audit found a 4-key drift that
# reached HEAD unnoticed. Plural/gender variants are NOT exempted silently —
# if a variant is ever legitimately locale-only, it goes on the allowlist
# below with a comment, not into the key sets unchecked.
#
# DB-free (bash + python3 only) so it runs before the Flutter toolchain to
# fail fast, like the ledger and policy-battery static checks.
#
# Usage:
#   scripts/verify_arb_parity.sh
#
# Exit codes:
#   0 — en/ar/tr key sets identical (modulo the allowlist)
#   1 — drift found
#   2 — usage/environment error (python3 absent, ARB file missing)
#
# Intended use: wired into ci.yml ahead of the Flutter setup; run locally
# after any ARB edit (and after regenerating lib/l10n/).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

for f in "$REPO_ROOT/lib/l10n/app_en.arb" "$REPO_ROOT/lib/l10n/app_ar.arb" "$REPO_ROOT/lib/l10n/app_tr.arb"; do
  if [ ! -s "$f" ]; then
    printf 'RESULT: FAIL — ARB file missing or empty: %s\n' "$f"
    exit 2
  fi
done

if ! command -v python3 >/dev/null 2>&1; then
  printf 'RESULT: FAIL — python3 is required (install Python 3).\n' >&2
  exit 2
fi

python3 - "$REPO_ROOT/lib/l10n" <<'EOF'
import json
import sys
from pathlib import Path

l10n = Path(sys.argv[1])

def keys(locale: str) -> set[str]:
    raw = (l10n / f"app_{locale}.arb").read_bytes().decode("utf-8-sig")
    data = json.loads(raw)
    return {k for k in data if not k.startswith("@")}

en, ar, tr = keys("en"), keys("ar"), keys("tr")
failures = 0

for locale, got in (("ar", ar), ("tr", tr)):
    missing = sorted(en - got)
    extra = sorted(got - en)
    if missing:
        print(f"  [XX] {locale} missing {len(missing)} key(s): {missing}")
        failures += 1
    else:
        print(f"  [OK] {locale} carries every en key ({len(got)} total)")
    if extra:
        print(f"  [XX] {locale} has {len(extra)} undocumented extra key(s): {extra}")
        failures += 1

print(f"== summary: en={len(en)} ar={len(ar)} tr={len(tr)} ==")
if failures:
    print("RESULT: FAIL — ARB key drift found. Sync the locales and regenerate lib/l10n/.")
    sys.exit(1)
print("RESULT: PASS — ARB key parity holds.")
EOF
