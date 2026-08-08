#!/usr/bin/env bash
#
# verify_provider_loop.sh — ephemeral provider-loop rehearsal harness
# (D-45.1 Phase 1, docs/p2_provider_loop_phase1_rehearsal_2026-08-08.md).
#
# Proves the GoTrue provider loop — signup → email-confirm → sign-in →
# password-reset — end-to-end against a THROWAWAY local/CI Supabase stack
# (zero external effect: no real email leaves the machine; the local mail
# catcher receives everything). This is the P2 r1–r4 rehearsal pattern
# applied to the auth provider, and the Phase 1 prerequisite for the
# dev-project smoke (docs/p2_provider_loop_phase2_smoke_2026-08-08.md).
#
# What it verifies (the five legs, mirroring the Phase 2 plan §2):
#
#   L1. SIGN-IN (existing account) — password grant on an already-existing
#       identity → session minted (proves the applied schema + GoTrue
#       together on the ephemeral stack).
#   L2. SIGN-UP → PENDING — a NEW synthetic identity on the mail catcher →
#       D-07 pending state: NO session minted until email confirms (the
#       exact semantics the typed SupabaseSignUpResult maps).
#   L3. EMAIL CONFIRM — read the confirmation message from the local mail
#       catcher (Inbucket), extract the confirmation token/link, complete
#       the confirm → session minted + auth.users.email_confirmed_at set.
#   L4. SIGN-IN (confirmed user) — password grant on the confirmed identity
#       → session; profile row created by the applied handle_new_user
#       trigger (display_name from sign-up metadata).
#   L5. PASSWORD-RESET round trip — recover → read the recovery email from
#       the mail catcher → verify the token → update the password → sign-in
#       with the new password.
#
# The harness NEVER runs against the live dev project — only against an
# ephemeral stack (supabase start on the Docker/CI host, or a throwaway
# remote project). The dev-project guard below hard-refuses the known dev
# project ref.
#
# Usage:
#   SUPABASE_HTTP_URL=http://127.0.0.1:54321 \
#   SUPABASE_ANON_KEY=<anon key> \
#   INBUCKET_URL=http://127.0.0.1:54324 \
#   SUPABASE_TEST_DB_URL=postgresql://postgres:***@127.0.0.1:54322/postgres \
#   scripts/verify_provider_loop.sh
#       Runs the five legs against the ephemeral stack. Requires curl +
#       psql + the committed migrations applied (see --apply).
#   scripts/verify_provider_loop.sh --apply
#       Applies the committed supabase/ migrations + policies + RPCs to the
#       connected ephemeral database (the verify_policy_tests.sh --apply
#       order), then runs the legs. Requires SUPABASE_TEST_DB_URL.
#   scripts/verify_provider_loop.sh --check
#       Static validation WITHOUT a stack (runs anywhere with bash + git):
#       spec doc + companion docs present, the five-leg marker + mail-catcher
#       mention in the spec, the scripts/README.md + supabase/README.md
#       doc hooks, harness self-syntax.
#   scripts/verify_provider_loop.sh --selftest
#       Drift-injection teeth check (no stack, bash + git only): scratch
#       worktree, injects each known drift class, asserts --check FAILs on
#       each. Wired alongside the other --selftest teeth-provers.
#   scripts/verify_provider_loop.sh --help
#
# Exit codes:
#   0 — all checks passed; --selftest: every injected drift class detected
#   1 — one or more FAILs
#   2 — usage/environment error (missing env, curl/psql absent, dev-project
#       ref in the URL)
#
# Intended use: run against a fresh ephemeral stack (supabase start on the
# Docker/CI host) as D-45.1 Phase 1; the rehearsal evidence record cites
# the commit the loop ran on (the P0C.1 evidence format).

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
SUPABASE_DIR="$REPO_ROOT/supabase"
DOCS_DIR="$REPO_ROOT/docs"

PHASE1_SPEC="$DOCS_DIR/p2_provider_loop_phase1_rehearsal_2026-08-08.md"
PHASE2_PLAN="$DOCS_DIR/p2_provider_loop_phase2_smoke_2026-08-08.md"
D451_DECISION="$DOCS_DIR/p2_provider_loop_decision_2026-08-05.md"
APPLY_ORDER=(
  "migrations/01_org_schema.sql"
  "migrations/02_rls_functions.sql"
  "migrations/04_matters.sql"
  "migrations/05_documents.sql"
  "migrations/06_message_threads.sql"
  "migrations/07_storage.sql"
  "migrations/08_messages.sql"
  "migrations/09_realtime_push.sql"
  "migrations/10_billing_invoices.sql"
)

usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

# ---------------------------------------------------------------------------
# --selftest mode: drift-injection teeth check (no stack)
# ---------------------------------------------------------------------------
SELFTEST_MODE=0
SELFTEST_BASE=""
SELFTEST_WT=""
SELFTEST_SCRIPT=""
SELFTEST_OK=0
SELFTEST_TOTAL=0

if [ "$#" -gt 0 ] && [ "$1" = "--selftest" ]; then
  SELFTEST_MODE=1
  shift
fi

trap 'if [ -n "$SELFTEST_BASE" ]; then rm -rf "$SELFTEST_BASE"; git worktree prune >/dev/null 2>&1; fi' EXIT

# ---------------------------------------------------------------------------
# MODE: --check — static validation, no stack required
# ---------------------------------------------------------------------------
static_check() {
  note "static check: Phase 1 spec + companion docs present"
  local f
  for f in "$PHASE1_SPEC" "$PHASE2_PLAN" "$D451_DECISION"; do
    if [ -s "$f" ]; then
      ok "doc present + non-empty: $(basename "$f")"
    else
      fail "doc missing or empty: $f"
    fi
  done

  note "static check: the spec carries the five-leg marker + the mail catcher"
  if grep -q 'L5' "$PHASE1_SPEC" && grep -qi 'mail catcher\|inbucket' "$PHASE1_SPEC"; then
    ok "five-leg marker + mail-catcher mention present in the Phase 1 spec"
  else
    fail "Phase 1 spec missing the five-leg marker or the mail-catcher mention"
  fi

  note "static check: the spec mirrors the Phase 2 plan's legs"
  if grep -q 'L1' "$PHASE2_PLAN" && grep -q 'L5' "$PHASE2_PLAN"; then
    ok "Phase 2 plan carries the L1–L5 leg markers"
  else
    fail "Phase 2 plan missing the leg markers"
  fi

  note "static check: harness self-syntax + doc hooks"
  if bash -n "$0" 2>/dev/null; then
    ok "harness bash syntax clean"
  else
    fail "harness bash syntax error"
  fi
  if grep -q 'verify_provider_loop.sh' "$SCRIPT_DIR/README.md"; then
    ok "scripts/README.md harness row present"
  else
    fail "scripts/README.md harness row missing"
  fi
  if grep -q 'Provider-loop rehearsal' "$SUPABASE_DIR/README.md"; then
    ok "supabase/README.md provider-loop section present"
  else
    fail "supabase/README.md provider-loop section missing"
  fi
}

# ---------------------------------------------------------------------------
# MODE: --apply — build the ephemeral project from the committed files
# ---------------------------------------------------------------------------
apply_slice() {
  note "apply: building ephemeral project from committed supabase/ files"
  local f ok_count=0
  psql_apply() { # $1 file, $2 label
    if psql "$SUPABASE_TEST_DB_URL" -X -q -v ON_ERROR_STOP=1 -f "$1" >/dev/null 2>&1; then
      ok "$2"
      ok_count=$((ok_count + 1))
    else
      fail "$2 — psql rejected $1"
    fi
  }

  for f in "${APPLY_ORDER[@]}"; do
    psql_apply "$SUPABASE_DIR/$f" "apply $f"
  done
  # 03_platform_config_seed.sql is deliberately NOT applied (apply-time
  # owner-token placeholder; the policy battery's fixtures seed the rehearsal
  # owner row — D-P0C3).
  note "apply: 03_platform_config_seed.sql skipped by design (apply-time token)"
  for f in "$SUPABASE_DIR"/policies/*.sql; do
    psql_apply "$f" "apply policies/$(basename "$f")"
  done
  for f in "$SUPABASE_DIR"/rpc/*.sql; do
    [ "$(basename "$f")" = "_down.sql" ] && continue
    psql_apply "$f" "apply rpc/$(basename "$f")"
  done
  note "apply: $ok_count files applied"
  return 0
}

# ---------------------------------------------------------------------------
# The five legs (run mode — ephemeral stack only)
# ---------------------------------------------------------------------------
PL_BODY=/tmp/provider_loop_body.out
PL_CODE=/tmp/provider_loop_code.out

http_json() { # $1 label, $2 method, $3 url, $4 data (JSON or empty) — sets PL_HTTP_CODE, PL_BODY
  local label="$1" method="$2" url="$3" data="${4:-}"
  local args=(-s -o "$PL_BODY" -w '%{http_code}' -X "$method" "$url"
    -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json')
  if [ -n "$data" ]; then
    args+=(-d "$data")
  fi
  PL_HTTP_CODE=$(curl "${args[@]}")
  PL_BODY=$(cat "$PL_BODY")
}

expect_http() { # $1 label, $2 expected code, $3 actual code, $4 body-contains (or '')
  if [ "$3" = "$2" ] && { [ -z "$4" ] || printf '%s' "$PL_BODY" | grep -qF "$4"; }; then
    ok "$1 (HTTP $3)"
  else
    fail "$1 — expected HTTP $2${4:+ containing '$4'}, got HTTP $3: $(printf '%s' "$PL_BODY" | head -c 200)"
  fi
}

poll_mailcatcher() { # $1 label, $2 address, $3 subject-grep, $4 outfile
  local label="$1" address="$2" subject_grep="$3" outfile="$4" i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    curl -s "$INBUCKET_URL/api/v1/mailbox/$(printf '%s' "$address" | sed 's/@/%40/g')" \
      -o "$outfile"
    if grep -q "$subject_grep" "$outfile"; then
      ok "$label (mail catcher)"
      return 0
    fi
    sleep 2
  done
  fail "$label — no '$subject_grep' message arrived in the mail catcher (10 polls)"
  return 1
}

run_loop() {
  note "== provider loop target: $SUPABASE_HTTP_URL =="
  note "== mail catcher: $INBUCKET_URL =="

  local existing_email="${PROVIDER_LOOP_EXISTING_EMAIL:-}"
  local existing_password="${PROVIDER_LOOP_EXISTING_PASSWORD:-}"
  local new_email="${PROVIDER_LOOP_EMAIL:?PROVIDER_LOOP_EMAIL is required (synthetic signup identity)}"
  local new_password="${PROVIDER_LOOP_PASSWORD:-Synthetic!Pass1}"
  local new_display="${PROVIDER_LOOP_DISPLAY_NAME:-Demo Provider-Loop User}"

  # --- L1. Sign-in (existing account) — optional if no existing creds given
  if [ -n "$existing_email" ] && [ -n "$existing_password" ]; then
    http_json "L1 sign-in" POST "$SUPABASE_HTTP_URL/auth/v1/token?grant_type=password" \
      "{\"email\":\"$existing_email\",\"password\":\"$existing_password\"}"
    expect_http "L1 — existing-account sign-in mints a session" 200 "$PL_HTTP_CODE" '"access_token"'
  else
    warn "L1 skipped — PROVIDER_LOOP_EXISTING_EMAIL/PASSWORD not set (leg is optional)"
  fi

  # --- L2. Sign-up → pending (D-07: no session until email confirms)
  http_json "L2 sign-up" POST "$SUPABASE_HTTP_URL/auth/v1/signup" \
    "{\"email\":\"$new_email\",\"password\":\"$new_password\",\"data\":{\"display_name\":\"$new_display\",\"full_name\":\"$new_display\",\"name\":\"$new_display\"}}"
  expect_http "L2 — sign-up accepted (D-07 pending, no session)" 200 "$PL_HTTP_CODE" ''
  if printf '%s' "$PL_BODY" | grep -q '"access_token"'; then
    fail "L2 — sign-up minted a session; D-07 email-confirm-REQUIRED violated on this stack"
  else
    ok "L2 — no session before confirm (pending state, the SupabaseSignUpPending semantics)"
  fi

  # --- L3. Email confirm via the mail catcher
  local msg_confirm=/tmp/provider_loop_confirm.json
  if ! poll_mailcatcher "L3 — confirmation email arrived" "$new_email" 'Confirm your email\|Confirm signup\|confirm' "$msg_confirm"; then
    return 1
  fi
  # Extract the confirmation token from the message body (the local stack's
  # confirm link carries token=…&type=signup). Fall back to the OTP in the
  # same message if the link shape differs on the host.
  local token
  token=$(grep -oE 'token=[A-Za-z0-9_.-]+' "$msg_confirm" | head -1 | sed 's/^token=//')
  if [ -z "$token" ]; then
    token=$(grep -oE '"token":"[^"]+"' "$msg_confirm" | head -1 | sed 's/"token":"//;s/"//')
  fi
  if [ -z "$token" ]; then
    fail "L3 — could not extract the confirmation token from the mail-catcher message"
    return 1
  fi
  http_json "L3 confirm" GET "$SUPABASE_HTTP_URL/auth/v1/verify?token=$token&type=signup&redirect_to=$SUPABASE_HTTP_URL" ''
  expect_http "L3 — confirm completes with a session" 200 "$PL_HTTP_CODE" '"access_token"'
  local confirmed
  confirmed=$(psql "$SUPABASE_TEST_DB_URL" -X -q -A -t -c \
    "select coalesce(email_confirmed_at is not null, false) from auth.users where email = '$new_email';" 2>/dev/null | tr -d '[:space:]')
  if [ "$confirmed" = "t" ]; then
    ok "L3 — auth.users.email_confirmed_at set"
  else
    fail "L3 — email_confirmed_at not set (got '$confirmed')"
  fi

  # --- L4. Sign-in (confirmed user) + trigger-created profile
  http_json "L4 sign-in" POST "$SUPABASE_HTTP_URL/auth/v1/token?grant_type=password" \
    "{\"email\":\"$new_email\",\"password\":\"$new_password\"}"
  expect_http "L4 — confirmed-user sign-in mints a session" 200 "$PL_HTTP_CODE" '"access_token"'
  local profile
  profile=$(psql "$SUPABASE_TEST_DB_URL" -X -q -A -t -c \
    "select display_name from public.profiles p join auth.users u on u.id = p.user_id where u.email = '$new_email';" 2>/dev/null | tr -d '[:space:]')
  if [ -n "$profile" ]; then
    ok "L4 — trigger-created profile present (display_name = '$profile')"
  else
    fail "L4 — no profile row for the confirmed user (handle_new_user trigger did not fire?)"
  fi

  # --- L5. Password-reset round trip
  http_json "L5 recover" POST "$SUPABASE_HTTP_URL/auth/v1/recover" \
    "{\"email\":\"$new_email\"}"
  expect_http "L5 — recover acknowledged (generic non-enumerating)" 200 "$PL_HTTP_CODE" ''
  local msg_recovery=/tmp/provider_loop_recovery.json
  if ! poll_mailcatcher "L5 — recovery email arrived" "$new_email" 'Reset Your Password\|reset\|recover' "$msg_recovery"; then
    return 1
  fi
  local rtoken
  rtoken=$(grep -oE 'token=[A-Za-z0-9_.-]+' "$msg_recovery" | head -1 | sed 's/^token=//')
  if [ -z "$rtoken" ]; then
    rtoken=$(grep -oE '"token":"[^"]+"' "$msg_recovery" | head -1 | sed 's/"token":"//;s/"//')
  fi
  if [ -z "$rtoken" ]; then
    fail "L5 — could not extract the recovery token from the mail-catcher message"
    return 1
  fi
  http_json "L5 verify-recovery" GET "$SUPABASE_HTTP_URL/auth/v1/verify?token=$rtoken&type=recovery&redirect_to=$SUPABASE_HTTP_URL" ''
  expect_http "L5 — recovery verify mints a session" 200 "$PL_HTTP_CODE" '"access_token"'
  local session_token
  session_token=$(printf '%s' "$PL_BODY" | grep -oE '"access_token":"[^"]+"' | head -1 | sed 's/"access_token":"//;s/"//')
  local new_password2="${PROVIDER_LOOP_NEW_PASSWORD:-Synthetic!Pass2}"
  # PUT requires the bearer session (apikey alone does not authorize user
  # updates) — issue with the recovery session's access token
  PL_HTTP_CODE=$(curl -s -o "$PL_BODY" -w '%{http_code}' -X PUT \
    "$SUPABASE_HTTP_URL/auth/v1/user" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $session_token" \
    -H 'Content-Type: application/json' \
    -d "{\"password\":\"$new_password2\"}")
  PL_BODY=$(cat "$PL_BODY")
  expect_http "L5 — password updated" 200 "$PL_HTTP_CODE" '"id"'
  http_json "L5 re-sign-in" POST "$SUPABASE_HTTP_URL/auth/v1/token?grant_type=password" \
    "{\"email\":\"$new_email\",\"password\":\"$new_password2\"}"
  expect_http "L5 — sign-in with the NEW password mints a session" 200 "$PL_HTTP_CODE" '"access_token"'

  note "provider loop complete: L1–L5 exercised on the ephemeral stack"
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------
if [ "$SELFTEST_MODE" -eq 1 ]; then
  printf '\n== verify_provider_loop SELFTEST (drift-injection teeth check, no stack) ==\n'
  base=$(mktemp -d)
  SELFTEST_BASE="$base"
  wt="$base/wt"
  SELFTEST_WT="$wt"
  SELFTEST_SCRIPT="$wt/scripts/verify_provider_loop.sh"
  note "selftest: scratch worktree at $(git rev-parse --short HEAD) — $wt"
  if ! git worktree add --detach "$wt" HEAD >/dev/null 2>&1; then
    fail "selftest: could not create scratch worktree"
    exit 1
  fi
  note "selftest: baseline — --check on the unmutated scratch tree (must PASS)"
  out=$( ( cd "$wt" && bash "$SELFTEST_SCRIPT" --check ) 2>&1 )
  rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "selftest: baseline --check FAILed (rc=$rc) — committed state is red; aborting"
    printf '%s\n' "$out" | tail -4
    exit 1
  fi
  ok "selftest: baseline --check PASS (rc=0)"

  expect_fail() { # $1 drift label, $2 literal FAIL message the battery must emit
    SELFTEST_TOTAL=$((SELFTEST_TOTAL + 1))
    local out rc
    out=$( ( cd "$SELFTEST_WT" && bash "$SELFTEST_SCRIPT" --check ) 2>&1 )
    rc=$?
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF "$2"; then
      SELFTEST_OK=$((SELFTEST_OK + 1))
      ok "selftest: $1 — --check FAILed (rc=$rc), matched '$2'"
    else
      fail "selftest: $1 — --check rc=$rc, expected FAIL matching '$2'"
      printf '%s\n' "$out" | tail -4
    fi
  }

  # 1. Missing Phase 1 spec — the harness's own source doc vanishes
  ( cd "$wt" && rm docs/p2_provider_loop_phase1_rehearsal_2026-08-08.md )
  expect_fail "missing Phase 1 spec" "missing or empty"
  ( cd "$wt" && git checkout -- docs/p2_provider_loop_phase1_rehearsal_2026-08-08.md )

  # 2. Stripped five-leg marker — the spec loses its L5 leg
  ( cd "$wt" && sed -i 's/L5/L4/g' docs/p2_provider_loop_phase1_rehearsal_2026-08-08.md )
  expect_fail "stripped five-leg marker" "missing the five-leg marker"
  ( cd "$wt" && git checkout -- docs/p2_provider_loop_phase1_rehearsal_2026-08-08.md )

  # 3. Dropped scripts/README.md doc hook
  ( cd "$wt" && sed -i 's/verify_provider_loop.sh/verify_provider_loopX.sh/' scripts/README.md )
  expect_fail "dropped scripts README hook" "scripts/README.md harness row missing"
  ( cd "$wt" && git checkout -- scripts/README.md )

  # 4. Dropped supabase/README.md section — the replacement must NOT keep
  #    the original as a substring, or grep -q would still match (the same
  #    trap the policy-battery selftest documents)
  ( cd "$wt" && sed -i 's/## Provider-loop rehearsal/## Provider loop/' supabase/README.md )
  expect_fail "dropped supabase README section" "supabase/README.md provider-loop section missing"
  ( cd "$wt" && git checkout -- supabase/README.md )

  # 5. Broken harness syntax
  ( cd "$wt" && sed -i 's/^static_check() {/static_check() { if ; then/' scripts/verify_provider_loop.sh )
  expect_fail "broken harness syntax" "syntax error near unexpected token"
  ( cd "$wt" && git checkout -- scripts/verify_provider_loop.sh )

  note "selftest: $SELFTEST_OK/$SELFTEST_TOTAL drift classes detected"
  printf '\n== summary: %d passed, %d warnings, %d failures ==\n' "$PASSES" "$WARNS" "$FAILS"
  if [ "$FAILS" -gt 0 ]; then
    printf 'RESULT: FAIL — %d failure(s). A drift class evaded the gate. Fix the harness.\n' "$FAILS"
    exit 1
  fi
  printf 'RESULT: PASS — all %d drift classes detected.\n' "$SELFTEST_TOTAL"
  exit 0
fi

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "${1:-}" = "--check" ]; then
  printf '\n== verify_provider_loop --check (static, no stack) ==\n'
  static_check
  printf '\n== summary: %d passed, %d warnings, %d failures ==\n' "$PASSES" "$WARNS" "$FAILS"
  if [ "$FAILS" -gt 0 ]; then
    printf 'RESULT: FAIL — fix before running the loop against an ephemeral stack.\n'
    exit 1
  fi
  printf 'RESULT: PASS — static provider-loop harness validated.\n'
  exit 0
fi

if ! command -v psql >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  printf 'RESULT: FAIL — psql and curl are required for loop/apply modes.\n'
  exit 2
fi

if [ -z "${SUPABASE_HTTP_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ] || [ -z "${INBUCKET_URL:-}" ] || [ -z "${SUPABASE_TEST_DB_URL:-}" ]; then
  printf 'RESULT: FAIL — SUPABASE_HTTP_URL, SUPABASE_ANON_KEY, INBUCKET_URL and\n'
  printf '  SUPABASE_TEST_DB_URL are required (ephemeral stack only).\n'
  exit 2
fi

# Dev-project guard: never point the loop at the live dev project.
if printf '%s' "$SUPABASE_HTTP_URL" | grep -qi 'eutmvevpskerzpqmwplv' \
   || printf '%s' "$SUPABASE_TEST_DB_URL" | grep -qi 'eutmvevpskerzpqmwplv'; then
  printf 'RESULT: FAIL — a URL points at the known DEV project (DO-NOT-TOUCH).\n'
  printf '  The provider loop is for the EPHEMERAL stack only (D-45.1 Phase 1).\n'
  exit 2
fi

if [ "${1:-}" = "--apply" ]; then
  printf '\n== verify_provider_loop --apply ==\n'
  apply_slice
  printf '\n== summary: %d passed, %d warnings, %d failures ==\n' "$PASSES" "$WARNS" "$FAILS"
  if [ "$FAILS" -gt 0 ]; then
    printf 'RESULT: FAIL — apply errors above.\n'
    exit 1
  fi
  printf 'RESULT: PASS — ephemeral project built from committed files. Run the loop next.\n'
  exit 0
fi

printf '\n== verify_provider_loop == target: %s (mail catcher %s)\n' "$SUPABASE_HTTP_URL" "$INBUCKET_URL"
run_loop

printf '\n== summary: %d passed, %d warnings, %d failures ==\n' "$PASSES" "$WARNS" "$FAILS"
if [ "$FAILS" -gt 0 ]; then
  printf 'RESULT: FAIL — %d failure(s). The provider loop did not pass; record the finding.\n' "$FAILS"
  exit 1
fi
printf 'RESULT: PASS — the GoTrue provider loop (L1–L5) completed on the ephemeral stack.\n'
exit 0
