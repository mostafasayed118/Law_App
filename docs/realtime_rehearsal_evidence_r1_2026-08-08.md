# LegalHub — Realtime Rehearsal r1 Evidence (2026-08-08)

> **Record type:** Rehearsal evidence for the real-messages-rows (read)
> slice (plan `docs/realtime_real_data_plan_2026-08-08.md` T4), the sixth
> §14 per-feature un-deferral (matters → documents → message_threads →
> storage → audit surfacing → individual messages/bodies). Mirrors the
> matters/documents/messages r1 evidence format.
>
> **Status: PASSED 2026-08-08 — the full DB battery ran GREEN via Path A**
> (Docker + the Supabase CLI local stack). Unlike the four prior r1
> records — whose runs were pasted in by the owner — **this run was
> genuinely executed on this machine**: a Docker-backed `supabase start`
> stack in a scratch project (empty `migrations/`, so the CLI never sees
> the repo's `_down.sql` files), the repo's committed files applied by the
> harness's own `--apply` (the real schema-builder), and the battery run
> to completion. Verbatim output retained in §4. Two rehearsal findings
> surfaced and are fixed + committed with this record (§6). Nothing beyond
> what was actually run is claimed (INSTRUCTIONS.md §1.3 #5).

---

## 1. What is ready (committed, verified-without-a-database)

| Artifact | State |
|---|---|
| `supabase/migrations/08_messages.sql` + `08_messages.down.sql` | Rehearsal-ready (T2, `60198e2`); clean inverse; **the first content column** (`body text` with a non-empty CHECK, D-RT3/D-MSG1 consummation); thread FK + cascade; `(thread_id, sent_at)` fetch index; narrow authenticated SELECT grant only (Q5) |
| `supabase/policies/messages.sql` | Rehearsal-ready (T2, `60198e2`): `messages_select_assigned` — `is_active_member` **and** an exists through `message_threads t` joined to `matters m` with the **three-way org equality load-bearing** (`messages.organization_id = t.organization_id = m.organization_id`), D-RT2 |
| `supabase/tests/08_message_rls.sql` | 12 checks (T3, `9f01870`): per-thread 2/3/1 positives (client-a 3, attorney-a 6, orphan 4), org-role-alone / non-vacuous org-mismatch / cross-org / suspended / owner / anon denies, `body` CHECK, thread-delete cascade, 08.12 mapping-consistency (live count = `message_count` column) |
| `supabase/tests/00_fixtures.sql` | +21 message rows (thread-1: 1 … thread-6: 6, each matching its thread's `message_count`); generic non-PII demo bodies/author names; reserved org-mismatch ids; reset order children-first; **+ storage-GUC host-compat set** (§6 finding 1) |
| `scripts/verify_policy_tests.sh` | 08 wired into list/run/scans/`--apply` order; structural pins re-scoped (**11 tables / 11 RLS / 10 policies**); forward pin flipped to messages-PRESENT + **live-delivery-ABSENT** (`pg_publication_tables` = 0); selftest glob `0[1-8]` |
| `supabase/README.md` | 08 battery row + apply-order note (six §14 slices) |
| `scripts/verify_policy_tests.sh --check` | **PASS 333/0/0** (static: files present, every fixture UUID resolves, 12 FAIL markers, harness syntax) |

Branch `main` @ `9f01870` (T1–T3, nothing applied, nothing pushed). No
dev-project contact of any kind.

## 2. Infra — this run (2026-08-08, executed locally)

The four prior r1 records documented a host without `psql`/Docker and the
first execution was owner-side. For this slice the environment changed:

- **Docker daemon is live on this machine** (`docker info` OK) and the
  Supabase CLI is present — the **Path A** precedent becomes runnable
  here.
- **No `psql` binary on the host**, but the running
  `supabase_db_supabase` container carries one (psql 17.6). A thin `psql`
  shim (scratch, under `/tmp/rt-bin`, never in the repo) execs the real
  client inside the container, rewriting `127.0.0.1:54322` to the
  container-internal endpoint and piping `-f` files via stdin. The harness
  calls `psql` unmodified.
- **CLI migration-runner collision:** the repo keeps `_down.sql` files in
  `supabase/migrations/`, which the CLI records as duplicate version "01"
  (both `01_org_schema.sql` and `01_org_schema.down.sql`). Worked around
  by starting the stack from a **scratch project** (`/tmp/rt-rehearsal`,
  empty `migrations/`) via `supabase start --workdir`, then letting the
  harness's `--apply` build the schema from the repo's committed files —
  the battery's real schema-builder. Nothing in the repo tree is touched;
  the scratch dir is disposable.
- The battery requires **Supabase-flavored Postgres** (auth schema +
  `auth.uid()` JWT claims) — the Docker local stack provides it, so the
  run is against the real stack, never a stand-in.
- The **dev project** (`eutmvevpskerzpqmwplv`) remains hard-refused by the
  harness and untouched by the hard gates.

**Conclusion:** this r1 is the first **genuinely executed** battery in the
slice history — which is exactly why the two latent findings in §6 (one
storage-api host-compat, one pre-existing battery defect) surfaced here
rather than in the pasted-summary records.

## 3. Runbook actually executed

```bash
mkdir /tmp/rt-rehearsal && cd /tmp/rt-rehearsal     # scratch project, empty migrations/
supabase start --workdir /tmp/rt-rehearsal           # Docker-backed local stack (auth schema included)
# psql shim: /tmp/rt-bin/psql -> exec psql inside supabase_db_supabase
export PATH="/tmp/rt-bin:$PATH"
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_policy_tests.sh --apply        # builds the rehearsal project from the committed files
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_policy_tests.sh                # runs the full battery incl. 08_message_rls.sql
```

**Expected result (per the plan §6):** `--apply` applies 01…08, the
policies (incl. `messages.sql`), and the RPCs; the battery then shows the
structural pins (**11 tables / 11 RLS / 10 policies**, messages SELECT
grant + anon absence, forward pin: matters/documents/message_threads/
files/messages present, live delivery absent), the fixtures, the 01–07
regression batteries, and `08_message_rls.sql` → `RESULT: PASS` with 0
failures.

## 4. Evidence (recorded from the actual run, 2026-08-08)

| Check | Result (from the actual run) | Observed output |
|---|---|---|
| `--apply` (01…08, policies, RPCs) | ✅ **PASS** | 37 files applied cleanly incl. `08_messages.sql` + `policies/messages.sql`, on top of the applied matters/documents/threads/storage tables |
| Structural pins 1a (tables + RLS) | ✅ **PASS** | **eleven public tables present (11)**, RLS enabled on all eleven (11), authenticated SELECT on messages (true), anon SELECT on messages ABSENT (default-deny) |
| Structural pins 1b (narrow grants) | ✅ **PASS** | messages SELECT grant true + anon absent; all four prior slices' grants intact; audit_events/platform_config SELECT absent (D-P0C4) |
| Structural pins 1c/1d (function/RPC surface) | ✅ **PASS** | `is_active_member`/`has_org_role` R-4 granted; 18-of-18 RPC EXECUTE rows green; write_audit/is_platform_owner denied to authenticated |
| Structural pins 1e (policy inventory) | ✅ **PASS** | zero policies on audit_events/platform_config (RPC-only); **exactly ten policies across the client tables (10)** |
| Structural pins 1f (forward pin, re-scoped) | ✅ **PASS** | matters 1 · documents 1 · message_threads 1 · files 1 · **messages present (1)** · **live delivery STILL absent (0)** — the pin now holds the sixth un-deferral present and the deferred live-push path absent |
| Structural pins 1g (storage surface) | ✅ **PASS** | matter-files bucket present (1) · files_storage_select policy on storage.objects present (1) · exactly one storage-schema policy (1) |
| 00_fixtures + platform_config bound | ✅ **PASS** | deterministic baseline seeded (21 message rows); exactly one platform_config row (1) |
| 01 / 02 / 03 / 04 / 05 / 06 / 07 batteries | ✅ **PASS** | regression batteries unaffected by the realtime slice (incl. the fixed 01.08, §6 finding 2) |
| **08_message_rls.sql** | ✅ **PASS** | all checks passed: per-thread 2/3/1 positives (client-a 3, attorney-a 6, orphan 4), org-role-alone 0, non-vacuous org-mismatch 0, cross-org 0, suspended 0, owner 0, anon denied, `body` CHECK rejects empty, thread-delete cascades, 08.12 mapping-consistency (count = `message_count`) |
| Final summary + RESULT line | ✅ **PASS** | `== summary: 70 passed, 0 warnings, 0 failures ==` / `RESULT: PASS` |

> **Verbatim tail of the run** (the full log was captured to a scratch
> file during the run; the summary + RESULT lines are reproduced
> verbatim):
> ```
>   [..] --- 2c. Battery file: 08_message_rls.sql ---
>   [OK] 08_message_rls.sql — all checks passed
>
> == summary: 70 passed, 0 warnings, 0 failures ==
> RESULT: PASS
> ```

## 5. Next steps (gated)

1. ✅ **r1 PASSED 2026-08-08** (this record, §4) — the realtime slice has
   rehearsal evidence against the committed files on the applied posture.
2. **T5 — dated apply-approval** (`docs/realtime_apply_approval_2026-08-08.md`,
   DRAFT) → owner signs → apply `08_messages` + `policies/messages` + demo
   seed (referencing the applied demo matter/thread ids) to the dev
   project with rollback pairing + cleanup; execution evidence per the
   established pattern.
3. T6 dated matrix addendum → T7 env-gated client swap → T8 lockstep +
   close.

## 6. Rehearsal findings (both fixed + committed with this record)

1. **Storage-api host-compat (fixtures reset).** This stack's storage-api
   (v1.68.1) ships a `protect_objects_delete` trigger on `storage.objects`
   that blocks the fixtures' direct `delete from storage.objects` reset
   unless the session GUC `storage.allow_delete_query = 'true'` is set —
   the trigger's own documented escape hatch. The fixtures run as the
   privileged connection role and MUST reset the objects rows, so the
   reset now sets the GUC (session-local, privileged-session only;
   harmless on hosts without the trigger). Committed in
   `supabase/tests/00_fixtures.sql` (`feat(realtime)` battery-fix commit).
2. **Pre-existing battery defect 01.08 (surfaced by the first genuinely
   executed run).** CHECK 01.08 verifies the partner-roster read's audit
   row by reading `audit_events` — but the session was still
   `set role authenticated`, and `authenticated` holds **no SELECT on
   `audit_events` by design** (D-P0C4 — audit is RPC-only), so the check
   could never pass as written. It is a privileged observation and must
   run as the connection role — fixed with the in-file
   `reset role` → observe → `set role authenticated` pattern (the same
   as the 01.13 orphan-probe). The four prior r1 records never surfaced
   this because they were filled from pasted summary lines; this is the
   first real execution against the committed schema. Committed in
   `supabase/tests/01_identity_session.sql` (same battery-fix commit).
