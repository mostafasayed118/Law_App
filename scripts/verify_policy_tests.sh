#!/usr/bin/env bash
#
# verify_policy_tests.sh — re-runnable policy-test harness for the P0-closure
# battery (docs/p0_closure_scope_2026-08-05.md slice P0C.1, D-P0C2).
#
# The committed SQL battery under supabase/tests/ proves, against an
# EPHEMERAL rehearsal project built from the committed supabase/ files:
#
#   1. STRUCTURAL + GRANT PINS — table existence, RLS enabled on all eight,
#      the narrow SELECT grants, the function EXECUTE surface (the R-4
#      policy-helper grants present; the internal helpers + write_audit
#      denied), zero policies on audit_events/platform_config (D-P0C4), the
#      seven-policy total, and the D-P0C1(b) forward pin (matters + documents
#      shipped as the first two §14 un-deferrals; messages/files still
#      absent).
#   2. THE BEHAVIOR BATTERY — supabase/tests/00_fixtures.sql (deterministic
#      seed) then 01_identity_session.sql (matrix §2), 02_organization_
#      membership.sql (matrix §3 + 2026-08-03 hardening guards),
#      03_platform_owner_boundary.sql (matrix §5 + D-P0C1(a) deny-rows +
#      D-P0C3 single-account bound + D-P0C4 audit RPC-only),
#      04_matter_rls.sql (matrix §4 matter rows — the real-matters read
#      path, the first §14 un-deferral: assigned client/attorney positives +
#      org-role-alone / cross-org / suspended / owner / anon denies + the
#      practice_area CHECK + org-delete cascade),
#      05_document_rls.sql (matrix §4 document rows — the real-documents read
#      path, the second §14 un-deferral: matter-scoped assignment positives +
#      org-role-alone / org-mismatch / cross-org / suspended / owner / anon
#      denies + the document_type CHECK + matter-delete cascade). Every matrix
#      row has ≥1 positive + ≥1 negative check (contract §9).
#
# The harness NEVER runs against the live dev project — only against a
# throwaway rehearsal project (the P2 r1–r5 pattern). The project is built
# from the committed files via `--apply` (or externally via the supabase CLI);
# the battery then verifies the applied posture.
#
# Usage:
#   SUPABASE_TEST_DB_URL=postgresql://postgres:***@host:5432/postgres \
#     scripts/verify_policy_tests.sh
#       Runs the full battery (structural pins + fixtures + 01/02/03) against
#       the connected project. The URL must be the project's postgres role
#       (superuser): the fixtures seed auth.users + platform_config, which no
#       client role may do.
#   scripts/verify_policy_tests.sh --apply
#       Builds the project from the committed supabase/ files in the README
#       apply order (01, 02, policies, rpc; 03_platform_config_seed.sql is
#       apply-time-only — its owner token is a substitution placeholder, and
#       the battery seeds its own fixture owner row). Requires the same
#       SUPABASE_TEST_DB_URL.
#   scripts/verify_policy_tests.sh --check
#       Static validation WITHOUT a database (runs anywhere with bash + git):
#       battery files present, every fixture UUID referenced by 01/02/03
#       resolves in 00_fixtures.sql, every check block carries the FAIL
#       marker, the harness self-syntax-checks.
#   scripts/verify_policy_tests.sh --help
#
# Exit codes:
#   0 — all checks passed (WARNs allowed)
#   1 — one or more FAILs (grant/structural pin violated, battery file error)
#   2 — usage/environment error (missing SUPABASE_TEST_DB_URL, psql absent)
#
# Intended use: run against a fresh ephemeral rehearsal project before any
# P0-close decision (P0C.3); the rehearsal evidence record cites the commit
# the battery ran on. See supabase/README.md ("Policy-test battery").

set -u

FAILS=0
WARNS=0
PASSES=0

note() { printf '  [..] %s\n' "$*"; }
ok()   { PASSES=$((PASSES + 1)); printf '  [OK] %s\n' "$*"; }
warn() { WARNS=$((WARNS + 1)); printf '  [WW] %s\n' "$*"; }
fail() { FAILS=$((FAILS + 1)); printf '  [XX] %s\n' "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$REPO_ROOT/supabase/tests"
SUPABASE_DIR="$REPO_ROOT/supabase"

BATTERY_FILES=(
  "00_fixtures.sql"
  "01_identity_session.sql"
  "02_organization_membership.sql"
  "03_platform_owner_boundary.sql"
  "04_matter_rls.sql"
  "05_document_rls.sql"
)

usage() {
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------------
# MODE: --check — static validation, no database required
# ---------------------------------------------------------------------------
static_check() {
  note "static check: battery file presence"
  local f
  for f in "${BATTERY_FILES[@]}"; do
    if [ -s "$TESTS_DIR/$f" ]; then
      ok "battery file present + non-empty: $f"
    else
      fail "battery file missing or empty: $TESTS_DIR/$f"
    fi
  done

  note "static check: every fixture UUID referenced by 01/02/03 resolves in 00_fixtures.sql"
  local uuids_from ref uuids_found
  uuids_from=$(grep -hoE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
      "$TESTS_DIR/01_identity_session.sql" "$TESTS_DIR/02_organization_membership.sql" \
      "$TESTS_DIR/03_platform_owner_boundary.sql" "$TESTS_DIR/04_matter_rls.sql" \
      "$TESTS_DIR/05_document_rls.sql" | sort -u)
  for ref in $uuids_from; do
    if grep -q "$ref" "$TESTS_DIR/00_fixtures.sql"; then
      ok "fixture UUID $ref resolves in 00_fixtures.sql"
    else
      fail "fixture UUID $ref referenced by a battery file but MISSING from 00_fixtures.sql"
    fi
  done

  note "static check: every battery check block carries the FAIL marker"
  local file blocks
  for f in 01_identity_session.sql 02_organization_membership.sql 03_platform_owner_boundary.sql 04_matter_rls.sql 05_document_rls.sql; do
    blocks=$(grep -c 'POLICY-BATTERY FAIL' "$TESTS_DIR/$f")
    if [ "$blocks" -ge 10 ]; then
      ok "$f: $blocks named check blocks"
    else
      fail "$f: only $blocks FAIL markers — battery looks incomplete"
    fi
  done

  note "static check: harness self-syntax + doc hooks"
  if bash -n "$0" 2>/dev/null; then
    ok "harness bash syntax clean"
  else
    fail "harness bash syntax error"
  fi
  if grep -q 'Policy-test battery' "$SUPABASE_DIR/README.md"; then
    ok "supabase/README.md battery section present"
  else
    fail "supabase/README.md battery section missing"
  fi
  if grep -q 'verify_policy_tests.sh' "$SCRIPT_DIR/README.md"; then
    ok "scripts/README.md harness row present"
  else
    fail "scripts/README.md harness row missing"
  fi
}

# ---------------------------------------------------------------------------
# MODE: --apply — build the rehearsal project from the committed files
# ---------------------------------------------------------------------------
apply_slice() {
  note "apply: building project from committed supabase/ files (README apply order)"
  local f ok_count=0
  psql_apply() { # $1 file, $2 label
    if psql "$SUPABASE_TEST_DB_URL" -X -q -v ON_ERROR_STOP=1 -f "$1" >/dev/null 2>&1; then
      ok "$2"
      ok_count=$((ok_count + 1))
    else
      fail "$2 — psql rejected $1"
    fi
  }

  psql_apply "$SUPABASE_DIR/migrations/01_org_schema.sql" "apply migrations/01_org_schema.sql"
  psql_apply "$SUPABASE_DIR/migrations/02_rls_functions.sql" "apply migrations/02_rls_functions.sql"
  psql_apply "$SUPABASE_DIR/migrations/04_matters.sql" "apply migrations/04_matters.sql"
  psql_apply "$SUPABASE_DIR/migrations/05_documents.sql" "apply migrations/05_documents.sql"
  # 03_platform_config_seed.sql is deliberately NOT applied: its owner token
  # is an apply-time substitution placeholder for the dev project; the
  # battery's fixtures seed the rehearsal project's own owner row (D-P0C3
  # proves the bound; the seed itself is a trusted migration, not a client
  # reachable path).
  note "apply: 03_platform_config_seed.sql skipped by design (apply-time token; fixtures seed the rehearsal owner)"
  # The structural pins (8 tables/RLS, 7 policies) and 00_fixtures' matters
  # + documents resets require both un-deferral slices — applied above via
  # 04_matters.sql + 05_documents.sql.
  # policies/matters.sql + policies/documents.sql are applied in the
  # policies loop below.
  for f in "$SUPABASE_DIR"/policies/*.sql; do
    psql_apply "$f" "apply $(basename "$f")"
  done
  for f in "$SUPABASE_DIR"/rpc/*.sql; do
    [ "$(basename "$f")" = "_down.sql" ] && continue
    psql_apply "$f" "apply $(basename "$f")"
  done
  note "apply: $ok_count files applied"
  return 0
}

# ---------------------------------------------------------------------------
# 1. STRUCTURAL + GRANT PINS
# ---------------------------------------------------------------------------
run_sql() { # $1 sql -> stdout (trimmed)
  psql "$SUPABASE_TEST_DB_URL" -X -q -A -t -c "$1" 2>&1 | tr -d '[:space:]'
}

expect_eq() { # $1 label, $2 actual, $3 expected
  if [ "$2" = "$3" ]; then
    ok "$1 ($2)"
  else
    fail "$1 — got '$2', want '$3'"
  fi
}

expect_tf() { # $1 label, $2 actual ('t'/'f')
  case "$2" in
    t|true)  ok "$1 (true)" ;;
    f|false) fail "$1 — expected true, got '$2'" ;;
    *)       fail "$1 — unparseable has_* output '$2'" ;;
  esac
}

structural_pins() {
  note "--- 1a. Tables + RLS ---"
  expect_eq "eight public tables present" \
    "$(run_sql "select count(*) from pg_tables where schemaname='public' and tablename in ('profiles','organizations','memberships','invitations','audit_events','platform_config','matters','documents');")" "8"
  expect_eq "RLS enabled on all eight" \
    "$(run_sql "select count(*) from pg_tables where schemaname='public' and tablename in ('profiles','organizations','memberships','invitations','audit_events','platform_config','matters','documents') and rowsecurity;")" "8"

  note "--- 1b. Narrow SELECT grants (01_org_schema.sql) ---"
  expect_tf "authenticated SELECT on profiles" \
    "$(run_sql "select has_table_privilege('authenticated','public.profiles','SELECT');")"
  expect_tf "authenticated SELECT on organizations" \
    "$(run_sql "select has_table_privilege('authenticated','public.organizations','SELECT');")"
  expect_tf "authenticated SELECT on memberships" \
    "$(run_sql "select has_table_privilege('authenticated','public.memberships','SELECT');")"
  expect_tf "authenticated SELECT on invitations" \
    "$(run_sql "select has_table_privilege('authenticated','public.invitations','SELECT');")"
  expect_eq "authenticated SELECT on audit_events ABSENT (D-P0C4)" \
    "$(run_sql "select has_table_privilege('authenticated','public.audit_events','SELECT');")" "f"
  expect_eq "authenticated SELECT on platform_config ABSENT" \
    "$(run_sql "select has_table_privilege('authenticated','public.platform_config','SELECT');")" "f"
  expect_eq "anon SELECT on profiles ABSENT (default-deny)" \
    "$(run_sql "select has_table_privilege('anon','public.profiles','SELECT');")" "f"
  expect_eq "anon SELECT on memberships ABSENT" \
    "$(run_sql "select has_table_privilege('anon','public.memberships','SELECT');")" "f"
  expect_eq "anon SELECT on audit_events ABSENT" \
    "$(run_sql "select has_table_privilege('anon','public.audit_events','SELECT');")" "f"
  expect_tf "authenticated SELECT on matters (04_matters.sql)" \
    "$(run_sql "select has_table_privilege('authenticated','public.matters','SELECT');")"
  expect_eq "anon SELECT on matters ABSENT (default-deny)" \
    "$(run_sql "select has_table_privilege('anon','public.matters','SELECT');")" "f"
  expect_tf "authenticated SELECT on documents (05_documents.sql)" \
    "$(run_sql "select has_table_privilege('authenticated','public.documents','SELECT');")"
  expect_eq "anon SELECT on documents ABSENT (default-deny)" \
    "$(run_sql "select has_table_privilege('anon','public.documents','SELECT');")" "f"

  note "--- 1c. Function EXECUTE surface (02_rls_functions.sql R-3/R-4) ---"
  expect_tf "policy helper is_active_member granted (R-4)" \
    "$(run_sql "select has_function_privilege('authenticated','public.is_active_member(uuid)','EXECUTE');")"
  expect_tf "policy helper has_org_role granted (R-4)" \
    "$(run_sql "select has_function_privilege('authenticated','public.has_org_role(uuid, public.org_role)','EXECUTE');")"
  expect_eq "write_audit denied to authenticated (audit-integrity)" \
    "$(run_sql "select has_function_privilege('authenticated','public.write_audit(text, text, uuid, text, uuid, uuid, text, uuid)','EXECUTE');")" "f"
  expect_eq "is_platform_owner denied to authenticated" \
    "$(run_sql "select has_function_privilege('authenticated','public.is_platform_owner()','EXECUTE');")" "f"
  expect_eq "active_membership denied to authenticated" \
    "$(run_sql "select has_function_privilege('authenticated','public.active_membership(uuid)','EXECUTE');")" "f"
  expect_eq "expire_stale_invitations denied to authenticated" \
    "$(run_sql "select has_function_privilege('authenticated','public.expire_stale_invitations()','EXECUTE');")" "f"
  expect_eq "handle_new_user denied to authenticated" \
    "$(run_sql "select has_function_privilege('authenticated','public.handle_new_user()','EXECUTE');")" "f"

  note "--- 1d. RPC EXECUTE grants (client surface intact) ---"
  local sig rpc_list=(
    "create_organization(text)"
    "accept_invitation(text)"
    "invite_member(uuid, text, public.org_role)"
    "resend_invitation(uuid)"
    "revoke_invitation(uuid)"
    "change_member_role(uuid, uuid, public.org_role)"
    "suspend_membership(uuid, uuid)"
    "reactivate_membership(uuid, uuid)"
    "remove_membership(uuid, uuid)"
    "delete_my_account()"
    "list_organizations_metadata()"
    "list_members_metadata()"
    "suspend_membership_platform(uuid, uuid)"
    "reactivate_membership_platform(uuid, uuid)"
    "delete_demo_account(uuid)"
    "read_org_audit(uuid)"
    "read_platform_audit()"
    "list_org_members_metadata(uuid)"
  )
  for sig in "${rpc_list[@]}"; do
    expect_tf "authenticated EXECUTE on public.$sig" \
      "$(run_sql "select has_function_privilege('authenticated','public.$sig','EXECUTE');")"
  done
  expect_eq "anon EXECUTE on invite_member ABSENT" \
    "$(run_sql "select has_function_privilege('anon','public.invite_member(uuid, text, public.org_role)','EXECUTE');")" "f"
  expect_eq "anon EXECUTE on list_members_metadata ABSENT" \
    "$(run_sql "select has_function_privilege('anon','public.list_members_metadata()','EXECUTE');")" "f"

  note "--- 1e. Policy inventory (D-P0C4: audit/platform_config RPC-only) ---"
  expect_eq "zero policies on audit_events" \
    "$(run_sql "select count(*) from pg_policies where schemaname='public' and tablename='audit_events';")" "0"
  expect_eq "zero policies on platform_config" \
    "$(run_sql "select count(*) from pg_policies where schemaname='public' and tablename='platform_config';")" "0"
  expect_eq "exactly seven policies across the client tables" \
    "$(run_sql "select count(*) from pg_policies where schemaname='public';")" "7"

  note "--- 1f. Forward pin re-scoped (2026-08-07): matters + documents are the FIRST TWO §14 un-deferrals ---"
  # D-P0C1(b) originally pinned 'no matter/document/message tables exist'. The
  # real-matters read slice (docs/matters_real_data_plan_2026-08-07.md) ships
  # the matters table + matters_select_assigned policy; the real-documents
  # read slice (docs/documents_real_data_plan_2026-08-07.md) ships the
  # documents table + documents_select_assigned policy. The pin is re-scoped
  # to the remaining content tables, which must still be ABSENT.
  expect_eq "matters present (first un-deferral)" \
    "$(run_sql "select count(*) from information_schema.tables where table_schema='public' and table_name = 'matters';")" "1"
  expect_eq "documents present (second un-deferral)" \
    "$(run_sql "select count(*) from information_schema.tables where table_schema='public' and table_name = 'documents';")" "1"
  expect_eq "messages/files STILL absent (forward pin baseline)" \
    "$(run_sql "select count(*) from information_schema.tables where table_schema='public' and table_name in ('messages','files','matter_documents','matter_messages');")" "0"
}

# ---------------------------------------------------------------------------
# 2. BEHAVIOR BATTERY
# ---------------------------------------------------------------------------
run_battery() {
  note "--- 2a. Fixtures (00_fixtures.sql) ---"
  local out rc f
  if psql "$SUPABASE_TEST_DB_URL" -X -q -v ON_ERROR_STOP=1 -f "$TESTS_DIR/00_fixtures.sql" >/tmp/policy_fixtures.out 2>&1; then
    ok "fixtures seeded (deterministic baseline)"
  else
    fail "fixtures FAILED — 00_fixtures.sql"
    tail -5 /tmp/policy_fixtures.out | sed 's/^/       /'
  fi

  note "--- 2b. platform_config single-account bound (D-P0C3, structural) ---"
  expect_eq "exactly one platform_config row after fixtures" \
    "$(run_sql "select count(*) from public.platform_config;")" "1"

  for f in 01_identity_session.sql 02_organization_membership.sql 03_platform_owner_boundary.sql 04_matter_rls.sql 05_document_rls.sql; do
    note "--- 2c. Battery file: $f ---"
    out=$(psql "$SUPABASE_TEST_DB_URL" -X -q -v ON_ERROR_STOP=1 -f "$TESTS_DIR/$f" 2>&1)
    rc=$?
    if [ "$rc" -eq 0 ]; then
      ok "$f — all checks passed"
    else
      fail "$f — battery FAILED (psql rc=$rc)"
      printf '%s\n' "$out" | grep -E 'POLICY-BATTERY FAIL|ERROR|CONTEXT' | head -6 | sed 's/^/       /'
    fi
  done
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "${1:-}" = "--check" ]; then
  printf '\n== verify_policy_tests --check (static, no database) ==\n'
  static_check
  printf '\n== summary: %d passed, %d warnings, %d failures ==\n' "$PASSES" "$WARNS" "$FAILS"
  if [ "$FAILS" -gt 0 ]; then
    printf 'RESULT: FAIL — fix before running the battery against a rehearsal project.\n'
    exit 1
  fi
  printf 'RESULT: PASS — static battery validated.\n'
  exit 0
fi

if ! command -v psql >/dev/null 2>&1; then
  printf 'RESULT: FAIL — psql is required for battery/apply modes (install the PostgreSQL client).\n'
  exit 2
fi

if [ -z "${SUPABASE_TEST_DB_URL:-}" ]; then
  printf 'RESULT: FAIL — SUPABASE_TEST_DB_URL is required (postgres role of an EPHEMERAL rehearsal project).\n'
  printf '  Never point this at the live dev project (DO-NOT-TOUCH).\n'
  exit 2
fi

# Dev-project guard: the fixtures DELETE from auth.users and platform_config.
# Pointing the URL at the live dev project (eutmvevpskerzpqmwplv, the
# DO-NOT-TOUCH ref recorded in the P2 records) would destructively wipe it
# before any check runs. Hard-refuse by default; ALLOW_DEV_PROJECT=1 is the
# explicit owner override (e.g. a read-only sweep that skips the battery).
if printf '%s' "$SUPABASE_TEST_DB_URL" | grep -qi 'eutmvevpskerzpqmwplv' \
   && [ "${ALLOW_DEV_PROJECT:-0}" != "1" ]; then
  printf 'RESULT: FAIL — SUPABASE_TEST_DB_URL points at the known DEV project (DO-NOT-TOUCH).\n'
  printf '  The battery fixtures DELETE from auth.users/platform_config and would wipe it.\n'
  printf '  Point the URL at an ephemeral rehearsal project, or set ALLOW_DEV_PROJECT=1 to override.\n'
  exit 2
fi

if [ "${1:-}" = "--apply" ]; then
  printf '\n== verify_policy_tests --apply ==\n'
  apply_slice
  printf '\n== summary: %d passed, %d warnings, %d failures ==\n' "$PASSES" "$WARNS" "$FAILS"
  if [ "$FAILS" -gt 0 ]; then
    printf 'RESULT: FAIL — apply errors above.\n'
    exit 1
  fi
  printf 'RESULT: PASS — slice applied from committed files. Run the battery next.\n'
  exit 0
fi

printf '\n== verify_policy_tests == target host: %s\n' "${SUPABASE_TEST_DB_URL##*@}"
printf '== 1. Structural + grant pins ==\n'
structural_pins
printf '== 2. Behavior battery ==\n'
run_battery

printf '\n== summary: %d passed, %d warnings, %d failures ==\n' "$PASSES" "$WARNS" "$FAILS"
if [ "$FAILS" -gt 0 ]; then
  printf 'RESULT: FAIL — %d failure(s). Rehearsal does not pass; fix before any P0-close decision.\n' "$FAILS"
  exit 1
fi
printf 'RESULT: PASS\n'
exit 0
