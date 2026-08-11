#!/usr/bin/env bash
#
# verify_policy_tests.sh — re-runnable policy-test harness for the P0-closure
# battery (docs/p0_closure_scope_2026-08-05.md slice P0C.1, D-P0C2).
#
# The committed SQL battery under supabase/tests/ proves, against an
# EPHEMERAL rehearsal project built from the committed supabase/ files:
#
#   1. STRUCTURAL + GRANT PINS — table existence, RLS enabled on all
#      thirteen, the narrow SELECT grants, the function EXECUTE surface
#      (the R-4 policy-helper grants present; the internal helpers +
#      write_audit denied), zero policies on audit_events/platform_config
#      (D-P0C4), the twelve-policy total (12 minus the D-SM3
#      messages_insert_assigned drop — the write path moved to the audited
#      send_message RPC; plus the notifications_select_org policy), the
#      storage-surface pins (matter-files bucket +
#      files_storage_select on storage.objects — the fourth §14
#      un-deferral), and the D-P0C1(b) forward pin (matters, documents,
#      message_threads, files + messages shipped as the first five §14
#      un-deferrals; individual message rows/bodies now present as the
#      sixth; live delivery now present as the seventh — re-scoped to pin
#      messages in the supabase_realtime publication, count 1, nothing
#      else; billing_invoices present as the ninth; notifications present
#      as the new-surface feed — the tenth applied table, read-only).
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
#      denies + the document_type CHECK + matter-delete cascade),
#      06_message_rls.sql (matrix §4 message rows — the real-messages read
#      path, the third §14 un-deferral: matter-scoped assignment positives +
#      org-role-alone / org-mismatch / cross-org / suspended / owner / anon
#      denies + the message_count CHECK + matter-delete cascade),
#      07_storage_rls.sql (matrix §4/§6 file rows — the real-storage read
#      path, the fourth §14 un-deferral: BOTH-layer positives (public.files
#      + storage.objects) + org-role-alone / org-mismatch / cross-org /
#      suspended / owner / anon denies + the guessed-path object row (matrix
#      §6) + the size_bytes CHECK + matter-delete cascade),
#      08_message_rls.sql (matrix §4 body rows — the realtime read path, the
#      sixth §14 un-deferral: thread-scoped individual-message positives +
#      org-role-alone / org-mismatch / cross-org / suspended / owner / anon
#      denies + the body CHECK + thread-delete cascade + the message-count
#      mapping-consistency pin),
#      09_realtime_push.sql (matrix §6 delivery + the D-SM3 revocation —
#      the realtime live-delivery path, the seventh §14 un-deferral,
#      RE-SCOPED by the send-message slice: the publication-membership pins
#      (messages in supabase_realtime, count 1, nothing else), the
#      privileged empty-body CHECK, the delivery-equivalence reads (assigned
#      attorney + client see the delivered row; suspended / cross-org /
#      owner / stranger see 0 — the read gate IS the delivery gate), and
#      the D-SM3 revocation pins (direct INSERT denied at the privilege
#      layer; messages_insert_assigned gone — the write surface moved to
#      the audited RPC),
#      10_send_message_rls.sql (the audited write path — the send-message
#      slice's battery: send_message positives (assigned attorney/client,
#      D-RT4 stored author from profiles), the §8 audit-row positive
#      (message:create/allowed, redacted summary, resource id), the
#      in-function gate deny rows (org-role-alone / cross-org / suspended /
#      owner / anon), the empty-body CHECK through the RPC, and the §8
#      negative (a denied send writes no audit row)),
#      11_invoice_rls.sql (matrix §4 invoice rows — the billing-invoices
#      read path, the ninth §14 un-deferral: matter-scoped assignment
#      positives (client-a 2 / partner-a 3 / orphan 1) + org-role-alone /
#      org-mismatch / cross-org / suspended / owner / anon denies + the
#      amount_cents + status CHECKs (D-11 metadata-only mapping contract)
#      + matter-delete cascade),
#      12_owner_assignment.sql (the F-01 owner-assignment invariant pin —
#      docs/p4_findings_register_2026-08-09.md F-01 step 1: the fixture
#      platform-owner id never appears in any matter assignment column or
#      content-table uuid column, with non-vacuity preconditions),
#      13_matter_write_rls.sql (the F-01 step 2 matter-write battery —
#      docs/f01_step2_matter_write_design_2026-08-09.md: create_matter
#      partner-gate + owner-assignment refusal + active-member assignee guard
#      + §8 audit rows, the categorical trigger-layer refusal + narrowness,
#      cross-org / anon / validation denials). Every matrix row has
#      ≥1 positive + ≥1 negative check (contract §9).
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
#       battery files present, every fixture UUID referenced by any battery
#       file (01-14) resolves in 00_fixtures.sql, every check block carries
#       the FAIL marker, the harness self-syntax-checks.
#   scripts/verify_policy_tests.sh --selftest
#       Drift-injection teeth check (no database, bash + git only): creates a
#       scratch worktree, injects each known drift class (missing battery
#       file, dangling fixture UUID, stripped FAIL marker, weakened harness
#       file list, dropped doc hook, broken harness syntax), and asserts the
#       --check battery FAILs on each. Never mutates the repo working tree;
#       wired into ledger-selftest.yml as a nightly teeth-prover alongside
#       verify_ledger.sh --selftest.
#   scripts/verify_policy_tests.sh --help
#
# Exit codes:
#   0 — all checks passed (WARNs allowed); --selftest: every injected drift
#       class detected
#   1 — one or more FAILs (grant/structural pin violated, battery file error,
#       or a drift class evaded the gate in --selftest mode)
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
  "06_message_rls.sql"
  "07_storage_rls.sql"
  "08_message_rls.sql"
  "09_realtime_push.sql"
  "10_send_message_rls.sql"
  "11_invoice_rls.sql"
  "12_owner_assignment.sql"
  "13_matter_write_rls.sql"
  "14_notification_rls.sql"
)

usage() {
  # Print the leading comment block only (line 1 shebang, then all `#`
  # lines until the first non-comment line) — robust as the header grows.
  # (`next` after print: without it, the `{ exit }` rule re-evaluates the
  #  sub()-stripped record and would exit on the first `#` line.)
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

# ---------------------------------------------------------------------------
# --selftest mode: drift-injection teeth check (no database)
# ---------------------------------------------------------------------------
# Injects each known drift class into a scratch worktree and asserts the
# --check battery FAILs on each (proves the gate's teeth without mutating the
# repo or needing a database — mirrors verify_ledger.sh --selftest). All
# selftest state is global so the EXIT trap can clean up safely under `set -u`.
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
      "$TESTS_DIR/05_document_rls.sql"      "$TESTS_DIR/06_message_rls.sql" \
      "$TESTS_DIR/07_storage_rls.sql" "$TESTS_DIR/08_message_rls.sql" \
      "$TESTS_DIR/09_realtime_push.sql" "$TESTS_DIR/10_send_message_rls.sql" \
      "$TESTS_DIR/11_invoice_rls.sql" "$TESTS_DIR/12_owner_assignment.sql" \
      "$TESTS_DIR/13_matter_write_rls.sql" "$TESTS_DIR/14_notification_rls.sql" | sort -u)
  for ref in $uuids_from; do
    if grep -q "$ref" "$TESTS_DIR/00_fixtures.sql"; then
      ok "fixture UUID $ref resolves in 00_fixtures.sql"
    else
      fail "fixture UUID $ref referenced by a battery file but MISSING from 00_fixtures.sql"
    fi
  done

  note "static check: every battery check block carries the FAIL marker"
  local file blocks
  for f in 01_identity_session.sql 02_organization_membership.sql 03_platform_owner_boundary.sql 04_matter_rls.sql 05_document_rls.sql 06_message_rls.sql 07_storage_rls.sql 08_message_rls.sql 09_realtime_push.sql 10_send_message_rls.sql 11_invoice_rls.sql 12_owner_assignment.sql 13_matter_write_rls.sql 14_notification_rls.sql; do
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
  psql_apply "$SUPABASE_DIR/migrations/06_message_threads.sql" "apply migrations/06_message_threads.sql"
  psql_apply "$SUPABASE_DIR/migrations/07_storage.sql" "apply migrations/07_storage.sql"
  psql_apply "$SUPABASE_DIR/migrations/08_messages.sql" "apply migrations/08_messages.sql"
  psql_apply "$SUPABASE_DIR/migrations/09_realtime_push.sql" "apply migrations/09_realtime_push.sql"
  psql_apply "$SUPABASE_DIR/migrations/10_billing_invoices.sql" "apply migrations/10_billing_invoices.sql"
  psql_apply "$SUPABASE_DIR/migrations/11_matter_write.sql" "apply migrations/11_matter_write.sql"
  psql_apply "$SUPABASE_DIR/migrations/14_notifications.sql" "apply migrations/14_notifications.sql"
  # 03_platform_config_seed.sql is deliberately NOT applied: its owner token
  # is an apply-time substitution placeholder for the dev project; the
  # battery's fixtures seed the rehearsal project's own owner row (D-P0C3
  # proves the bound; the seed itself is a trusted migration, not a client
  # reachable path).
  note "apply: 03_platform_config_seed.sql skipped by design (apply-time token; fixtures seed the rehearsal owner)"
  # The structural pins (12 tables/RLS, 11 policies + the storage-surface
  # pins + the publication pin) and 00_fixtures' matters + documents +
  # message_threads + files + storage.objects + messages +
  # billing_invoices resets require all seven un-deferral slices — applied
  # above via 04_matters.sql + 05_documents.sql + 06_message_threads.sql +
  # 07_storage.sql + 08_messages.sql + 09_realtime_push.sql +
  # 10_billing_invoices.sql.
  # policies/matters.sql + policies/documents.sql + policies/message_threads.sql
  # + policies/files.sql + policies/storage_objects.sql + policies/messages.sql
  # + policies/messages_insert.sql + policies/invoices.sql are applied in
  # the policies loop below
  # (07_storage.sql requires the platform storage schema, present on the
  # rehearsal host).
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
  expect_eq "thirteen public tables present" \
    "$(run_sql "select count(*) from pg_tables where schemaname='public' and tablename in ('profiles','organizations','memberships','invitations','audit_events','platform_config','matters','documents','message_threads','files','messages','billing_invoices','notifications');")" "13"
  expect_eq "RLS enabled on all thirteen" \
    "$(run_sql "select count(*) from pg_tables where schemaname='public' and tablename in ('profiles','organizations','memberships','invitations','audit_events','platform_config','matters','documents','message_threads','files','messages','billing_invoices','notifications') and rowsecurity;")" "13"

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
  expect_tf "authenticated SELECT on message_threads (06_message_threads.sql)" \
    "$(run_sql "select has_table_privilege('authenticated','public.message_threads','SELECT');")"
  expect_eq "anon SELECT on message_threads ABSENT (default-deny)" \
    "$(run_sql "select has_table_privilege('anon','public.message_threads','SELECT');")" "f"
  expect_tf "authenticated SELECT on files (07_storage.sql)" \
    "$(run_sql "select has_table_privilege('authenticated','public.files','SELECT');")"
  expect_eq "anon SELECT on files ABSENT (default-deny)" \
    "$(run_sql "select has_table_privilege('anon','public.files','SELECT');")" "f"
  expect_tf "authenticated SELECT on messages (08_messages.sql)" \
    "$(run_sql "select has_table_privilege('authenticated','public.messages','SELECT');")"
  expect_eq "anon SELECT on messages ABSENT (default-deny)" \
    "$(run_sql "select has_table_privilege('anon','public.messages','SELECT');")" "f"
  expect_tf "authenticated SELECT on billing_invoices (10_billing_invoices.sql)" \
    "$(run_sql "select has_table_privilege('authenticated','public.billing_invoices','SELECT');")"
  expect_eq "anon SELECT on billing_invoices ABSENT (default-deny)" \
    "$(run_sql "select has_table_privilege('anon','public.billing_invoices','SELECT');")" "f"
  expect_tf "authenticated SELECT on notifications (14_notifications.sql)" \
    "$(run_sql "select has_table_privilege('authenticated','public.notifications','SELECT');")"
  expect_eq "anon SELECT on notifications ABSENT (default-deny)" \
    "$(run_sql "select has_table_privilege('anon','public.notifications','SELECT');")" "f"

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
  expect_eq "refuse_platform_owner_assignment denied to authenticated (11_matter_write F2-D3)" \
    "$(run_sql "select has_function_privilege('authenticated','public.refuse_platform_owner_assignment()','EXECUTE');")" "f"

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
    "send_message(uuid, text)"
    "create_matter(uuid, text, text, uuid, uuid)"
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
  expect_eq "exactly twelve policies across the client tables (12 minus the D-SM3 messages_insert_assigned drop, plus the notifications_select_org policy)" \
    "$(run_sql "select count(*) from pg_policies where schemaname='public';")" "12"

  note "--- 1f. Forward pin re-scoped (2026-08-08): matters, documents, message_threads, files + messages are the FIRST FIVE §14 un-deferrals ---"
  # D-P0C1(b) originally pinned 'no matter/document/message tables exist'. The
  # real-matters read slice (docs/matters_real_data_plan_2026-08-07.md) ships
  # the matters table + matters_select_assigned policy; the real-documents
  # read slice (docs/documents_real_data_plan_2026-08-07.md) ships the
  # documents table + documents_select_assigned policy; the real-messages
  # read slice (docs/messages_real_data_plan_2026-08-07.md) ships the
  # message_threads table + message_threads_select_assigned policy (thread
  # METADATA only, D-MSG1 — individual message rows/bodies were deferred);
  # the real-storage read slice (docs/storage_real_data_plan_2026-08-08.md)
  # ships the files table + files_select_assigned + storage.objects policy
  # (file METADATA + bytes); the realtime read slice
  # (docs/realtime_real_data_plan_2026-08-08.md) ships the messages table +
  # messages_select_assigned policy (individual message rows/bodies — the
  # sixth §14 un-deferral); the realtime live-delivery slice
  # (docs/realtime_push_real_data_plan_2026-08-08.md) ships the publication
  # membership + messages_insert_assigned INSERT policy (the seventh §14
  # un-deferral). The pin re-scoped at realtime-read T3 to LIVE DELIVERY
  # (absent) is now re-scoped again: live delivery is PRESENT — messages in
  # supabase_realtime, count 1, and the publication holds NOTHING else
  # (D-P0C1(b) teeth: no accidental table exposure via realtime). The
  # audited send-message slice (docs/send_message_rpc_plan_2026-08-08.md,
  # D-SM3) then moved the WRITE surface off the direct INSERT (grant
  # revoked, messages_insert_assigned dropped — policies 11 -> 10, pinned
  # in 09.15/09.16) onto the audited send_message RPC; the publication pin
  # is untouched (the SELECT policy remains the delivery gate). The
  # billing-invoices read slice (docs/billing_invoices_real_data_plan_2026-08-08.md,
  # D-BI2) ships the billing_invoices table + invoices_select_assigned
  # policy (invoice METADATA only — the ninth §14 un-deferral; D-11: no
  # card/payment columns, no write path) and re-scopes the public-policy
  # pin to 11 (12 minus the D-SM3 drop) and the table/RLS pins to 12.
  expect_eq "matters present (first un-deferral)" \
    "$(run_sql "select count(*) from information_schema.tables where table_schema='public' and table_name = 'matters';")" "1"
  expect_eq "documents present (second un-deferral)" \
    "$(run_sql "select count(*) from information_schema.tables where table_schema='public' and table_name = 'documents';")" "1"
  expect_eq "message_threads present (third un-deferral)" \
    "$(run_sql "select count(*) from information_schema.tables where table_schema='public' and table_name = 'message_threads';")" "1"
  expect_eq "files present (fourth un-deferral)" \
    "$(run_sql "select count(*) from information_schema.tables where table_schema='public' and table_name = 'files';")" "1"
  expect_eq "messages present (sixth un-deferral)" \
    "$(run_sql "select count(*) from information_schema.tables where table_schema='public' and table_name = 'messages';")" "1"
  expect_eq "billing_invoices present (ninth un-deferral)" \
    "$(run_sql "select count(*) from information_schema.tables where table_schema='public' and table_name = 'billing_invoices';")" "1"
  # The notification-feed slice (docs/notification_feed_gate_review_2026-08-11.md,
  # D-N1..D-N7) ships the notifications table + notifications_select_org
  # policy (redacted-metadata rows only — the NEW-surface feed, the tenth
  # applied table; review Q1: redaction is structural, no user-identity /
  # content / raw-text columns) and re-scopes the table/RLS pins to 13 and
  # the public-policy pin to 12.
  expect_eq "notifications present (new-surface feed)" \
    "$(run_sql "select count(*) from information_schema.tables where table_schema='public' and table_name = 'notifications';")" "1"
  expect_eq "live delivery PRESENT (messages in supabase_realtime — seventh un-deferral)" \
    "$(run_sql "select count(*) from pg_publication_tables where schemaname = 'public' and tablename = 'messages';")" "1"
  expect_eq "exactly one table in the publication (nothing else, D-P0C1(b) teeth)" \
    "$(run_sql "select count(*) from pg_publication_tables where pubname = 'supabase_realtime';")" "1"

  note "--- 1g. Storage surface (07_storage.sql — fourth un-deferral) ---"
  # The storage layer is platform-native (storage.buckets / storage.objects
  # exist on the rehearsal host): the slice ships the private matter-files
  # bucket + the single files_storage_select policy. The platform grants
  # SELECT on storage.objects to anon + authenticated by default (verified
  # live via a read-only probe on the dev project, 2026-08-08) — the RLS
  # policy is the gate; the battery asserts the behavior on both layers.
  # WATCH-ITEM (T4): the "exactly one" pin assumes the rehearsal host ships
  # zero DEFAULT storage policies (the 0 baseline was probed on the hosted
  # dev project, not the local supabase start schema) — verify the
  # rehearsal host's storage-policy baseline is 0 before --apply.
  expect_eq "matter-files bucket present" \
    "$(run_sql "select count(*) from storage.buckets where id = 'matter-files';")" "1"
  expect_eq "files_storage_select policy on storage.objects present" \
    "$(run_sql "select count(*) from pg_policies where schemaname='storage' and tablename='objects' and policyname='files_storage_select';")" "1"
  expect_eq "exactly one storage-schema policy (the slice's only one)" \
    "$(run_sql "select count(*) from pg_policies where schemaname='storage';")" "1"
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

  for f in 01_identity_session.sql 02_organization_membership.sql 03_platform_owner_boundary.sql 04_matter_rls.sql 05_document_rls.sql 06_message_rls.sql 07_storage_rls.sql 08_message_rls.sql 09_realtime_push.sql 10_send_message_rls.sql 11_invoice_rls.sql 12_owner_assignment.sql 13_matter_write_rls.sql 14_notification_rls.sql; do
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
# SELFTEST — prove the battery's teeth on demand (no database; never mutates
# the repo working tree)
# ---------------------------------------------------------------------------
expect_fail() {  # $1 drift label, $2 literal FAIL message the battery must emit
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

selftest() {
  local base wt out rc
  base=$(mktemp -d)
  SELFTEST_BASE="$base"
  wt="$base/wt"
  SELFTEST_WT="$wt"
  # Run the battery from the WORKTREE's own copy so its SCRIPT_DIR-derived
  # paths (TESTS_DIR/SUPABASE_DIR) resolve inside the scratch tree — the
  # ledger's selftest is cwd-relative, but this battery is location-relative.
  SELFTEST_SCRIPT="$wt/scripts/verify_policy_tests.sh"

  note "selftest: scratch worktree at $(git rev-parse --short HEAD) — $wt"
  if ! git worktree add --detach "$wt" HEAD >/dev/null 2>&1; then
    fail "selftest: could not create scratch worktree"
    return 1
  fi

  note "selftest: baseline — --check on the unmutated scratch tree (must PASS)"
  out=$( ( cd "$wt" && bash "$SELFTEST_SCRIPT" --check ) 2>&1 )
  rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "selftest: baseline --check FAILed (rc=$rc) — committed state is red; aborting"
    printf '%s\n' "$out" | tail -4
    return 1
  fi
  ok "selftest: baseline --check PASS (rc=0)"

  # 1. Missing battery file — a battery file vanishes
  ( cd "$wt" && rm supabase/tests/07_storage_rls.sql )
  expect_fail "missing battery file" "battery file missing or empty"
  ( cd "$wt" && git checkout -- supabase/tests/07_storage_rls.sql )

  # 2. Dangling fixture UUID — a battery-cited fixture UUID drops out of
  #    00_fixtures.sql (the static cross-ref scan must red)
  local fixture_uuid
  fixture_uuid=$(comm -12 \
    <(grep -hoE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$wt"/supabase/tests/0[1-9]_*.sql "$wt"/supabase/tests/1[0-9]_*.sql | sort -u) \
    <(grep -hoE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$wt/supabase/tests/00_fixtures.sql" | sort -u) \
    | head -1)
  if [ -z "$fixture_uuid" ]; then
    fail "selftest: no battery-cited fixture UUID found — cannot construct drift 2"
    return 1
  fi
  ( cd "$wt" && sed -i "s/$fixture_uuid/00000000-0000-4000-8000-0000000000ff/g" supabase/tests/00_fixtures.sql )
  expect_fail "dangling fixture UUID" "MISSING from 00_fixtures.sql"
  ( cd "$wt" && git checkout -- supabase/tests/00_fixtures.sql )

  # 3. Stripped FAIL marker — a battery file loses its check markers
  ( cd "$wt" && sed -i 's/POLICY-BATTERY FAIL/POLICY-BATTERY DONE/g' supabase/tests/06_message_rls.sql )
  expect_fail "stripped FAIL marker" "06_message_rls.sql: only"
  ( cd "$wt" && git checkout -- supabase/tests/06_message_rls.sql )

  # 4. Weakened harness file list — the battery expects a file that does not
  #    exist (the ledger's tampered-script analog: the harness's own claim
  #    drifts)
  ( cd "$wt" && sed -i 's/"07_storage_rls.sql"/"07_storage_rls.sql"\n  "99_bogus.sql"/' scripts/verify_policy_tests.sh )
  expect_fail "weakened harness file list" "99_bogus.sql"
  ( cd "$wt" && git checkout -- scripts/verify_policy_tests.sh )

  # 5. Dropped doc hook — supabase/README.md loses the battery section
  #    (note: the replacement must NOT keep the original as a substring, or
  #    grep -q would still match)
  ( cd "$wt" && sed -i 's/Policy-test battery/Policy battery/g' supabase/README.md )
  expect_fail "dropped doc hook" "supabase/README.md battery section missing"
  ( cd "$wt" && git checkout -- supabase/README.md )

  # 6. Broken harness syntax — a parse-broken battery must red the run (bash's
  #    own parse error is the detection; the battery's bash -n self-check is
  #    belt-and-braces)
  ( cd "$wt" && sed -i 's/^static_check() {/static_check() { if ; then/' scripts/verify_policy_tests.sh )
  expect_fail "broken harness syntax" "syntax error near unexpected token"
  ( cd "$wt" && git checkout -- scripts/verify_policy_tests.sh )

  note "selftest: $SELFTEST_OK/$SELFTEST_TOTAL drift classes detected"
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------
if [ "$SELFTEST_MODE" -eq 1 ]; then
  printf '\n== verify_policy_tests SELFTEST (drift-injection teeth check, no database) ==\n'
  selftest
  printf '\n== summary: %d passed, %d warnings, %d failures ==\n' "$PASSES" "$WARNS" "$FAILS"
  if [ "$FAILS" -gt 0 ]; then
    printf 'RESULT: FAIL — %d failure(s). A drift class evaded the gate. Fix the battery.\n' "$FAILS"
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
