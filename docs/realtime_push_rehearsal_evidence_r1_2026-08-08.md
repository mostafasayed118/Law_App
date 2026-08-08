# LegalHub — Realtime Push Rehearsal r1 Evidence (2026-08-08)

> **Record type:** Rehearsal evidence for the realtime live-delivery (push)
> slice (plan `docs/realtime_push_real_data_plan_2026-08-08.md` T4), the
> seventh §14 per-feature un-deferral (matters → documents → message_threads
> → storage → audit surfacing → individual messages/bodies → live delivery).
> Mirrors the realtime-read r1 evidence format.
>
> **Status: PASSED 2026-08-08 — the full DB battery ran GREEN via Path A**
> (Docker + the Supabase CLI local stack). Like the realtime-read r1 (and
> unlike the four earliest records), **this run was genuinely executed on
> this machine**: the same Docker-backed `supabase start` stack from the
> read slice (scratch project, empty `migrations/`, the harness's `--apply`
> as the real schema-builder, the psql shim into the running container),
> then the full battery — **72 passed / 0 warnings / 0 failures** — with
> the new `09_realtime_push.sql` green. Verbatim output retained in §4.
> The T2 artifacts were additionally validated live (up/down/up round-trip
> + role-impersonated INSERTs) before the battery; those findings are in
> §6. Nothing beyond what was actually run is claimed (INSTRUCTIONS.md
> §1.3 #5).

---

## 1. What is ready (committed, verified-without-a-database)

| Artifact | State |
|---|---|
| `supabase/migrations/09_realtime_push.sql` + `09_realtime_push.down.sql` | Rehearsal-ready (T2, `f1d7903`); **publication membership only** — exactly `messages` in `supabase_realtime` (D-LV2), no new table/columns/RLS; the guard-create is a `do`-block (CREATE PUBLICATION has no IF NOT EXISTS form — a syntax error the T2 live check caught and fixed, §6 finding 1); the down is a clean idempotent inverse (membership drop guarded by a `pg_publication_tables` check) |
| `supabase/policies/messages_insert.sql` | Rehearsal-ready (T2, `f1d7903`): `messages_insert_assigned` — the read gate applied as WITH CHECK (`is_active_member` **and** an exists through `message_threads t` joined to `matters m` with the three-way org equality load-bearing **and** assigned client/attorney), D-LV1; **+ the INSERT grant**, added after the T2 live finding (08 granted SELECT only — §6 finding 2); insert-only, no UPDATE/DELETE policy |
| `supabase/tests/09_realtime_push.sql` | 12 checks (T3, `6302bdc`): publication-membership pins (09.01/09.02 — messages count 1 + nothing else), INSERT positives (09.03/09.04 — assigned attorney + client, rolled back), INSERT deny rows (09.05–09.09 — org-role-alone / cross-org / suspended / owner / anon, each a live RLS-violation catch), empty-body CHECK (09.10), delivery-equivalence pair (09.11/09.12 — the §6 matrix row enforced) |
| `supabase/tests/00_fixtures.sql` | + reserved 09 temp ids (`fff1`–`fff9`) in the throwaway-id comment block; 21-message seeded baseline untouched |
| `scripts/verify_policy_tests.sh` | 09 wired into list/run/scans/`--apply` order; policy pin **10→11**; forward pin re-scoped to **live delivery PRESENT** (`pg_publication_tables` = 1) + **exactly-one-publication-row**; selftest glob `0[1-9]` |
| `supabase/README.md` | battery section present (doc hook green) |
| `scripts/verify_policy_tests.sh --check` | **PASS 335/0/0** (static: files present, every fixture UUID incl. the 09 temp ids resolves, 14 FAIL markers in 09, harness syntax clean) |
| `scripts/verify_policy_tests.sh --selftest` | **PASS — 6/6 drift classes detected** (baseline green, missing file, dangling UUID, stripped marker, weakened list, dropped doc hook, broken syntax) |

Branch `main` @ `6302bdc` (T1–T3, nothing applied to the dev project,
nothing pushed). No dev-project contact of any kind — the harness
hard-refuses the dev URL.

## 2. Infra — this run (2026-08-08, executed locally)

The same environment as the realtime-read r1 (this session's Docker
precedent), carried forward:

- **Docker daemon live** on this machine; the Supabase CLI local stack is
  up (`supabase_db_supabase` healthy).
- **No host `psql`** — the thin shim (scratch, `/tmp/rt-bin`, never in the
  repo) execs the real client (psql 17.6) inside the container, rewriting
  `127.0.0.1:54322` to the container-internal endpoint. The harness calls
  `psql` unmodified.
- **CLI migration-runner collision** (the repo's `_down.sql` files) worked
  around exactly as before: the stack runs from a scratch project
  (`/tmp/rt-rehearsal`, empty `migrations/`), and the harness's `--apply`
  builds the schema from the repo's committed files — the battery's real
  schema-builder.
- The stack already carried the **T2-validated live state** (09 migration
  up, `messages_insert` policy + grant applied, publication membership
  exactly `messages`); the T3 battery re-probed it (publication 1 · 11
  policies · `messages_insert_assigned` present) and ran the full battery
  to completion.
- The **dev project** (`eutmvevpskerzpqmwplv`) remains hard-refused and
  untouched.

## 3. Runbook actually executed

```bash
# (the read slice's stack is still up; 09 + messages_insert policy applied in T2)
export PATH="/tmp/rt-bin:$PATH"
# state probe before the battery (read-only):
#   pg_publication_tables for supabase_realtime            -> 1 (messages only)
#   pg_policies where schemaname='public'                  -> 11 (10 + messages_insert_assigned)
#   pg_policies ... policyname='messages_insert_assigned'  -> 1
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_policy_tests.sh                # full battery incl. 09_realtime_push.sql
bash scripts/verify_policy_tests.sh --check          # static gate
bash scripts/verify_policy_tests.sh --selftest       # drift-injection teeth check
```

**Expected result (per the plan D-LV5):** the structural pins (**11 tables /
11 RLS / 11 policies**, messages SELECT + INSERT grants present, anon
absent, forward pin: messages present **and** live delivery present with
exactly one publication row), the fixtures, the 01–08 regression batteries,
and `09_realtime_push.sql` → `RESULT: PASS` with 0 failures.

## 4. Evidence (recorded from the actual run, 2026-08-08)

| Check | Result (from the actual run) | Observed output |
|---|---|---|
| State probe (pre-battery) | ✅ **PASS** | publication rows **1** (messages only) · public policies **11** · `messages_insert_assigned` present **1** — the T3 pins' preconditions hold on the applied posture |
| Structural pins 1a (tables + RLS) | ✅ **PASS** | eleven public tables present (11), RLS enabled on all eleven (11) — unchanged by 09 (no new table) |
| Structural pins 1b/1c/1d (grants + function/RPC surface) | ✅ **PASS** | messages SELECT + **INSERT** grants true, anon absent; R-4 helpers + 18-of-18 RPC rows green (0 failures in the 72-check summary) |
| Structural pins 1e (policy inventory) | ✅ **PASS** | zero policies on audit_events/platform_config (D-P0C4); **exactly eleven policies across the client tables (11)** — the 10→11 pin |
| Structural pins 1f (forward pin, re-scoped) | ✅ **PASS** | matters 1 · documents 1 · message_threads 1 · files 1 · messages 1 · **live delivery PRESENT (1)** · **exactly one table in the publication (1)** — the pin now holds the seventh un-deferral present and nothing else |
| Structural pins 1g (storage surface) | ✅ **PASS** | matter-files bucket 1 · files_storage_select policy 1 · exactly one storage-schema policy (1) — regression |
| 00_fixtures + platform_config bound | ✅ **PASS** | deterministic baseline seeded; exactly one platform_config row (1) |
| 01 / 02 / 03 / 04 / 05 / 06 / 07 / 08 batteries | ✅ **PASS** | regression batteries unaffected by the push slice |
| **09_realtime_push.sql** | ✅ **PASS** | all checks passed: publication 09.01/09.02 (count 1 + nothing else) · INSERT positives 09.03/09.04 (assigned attorney + client persist, rolled back) · deny rows 09.05–09.09 (org-role-alone / cross-org / suspended / owner / anon each an RLS-violation catch) · 09.10 empty-body CHECK · 09.11/09.12 delivery-equivalence (assigned reader sees the delivered row, suspended/cross-org/owner see 0) |
| Final summary + RESULT line | ✅ **PASS** | `== summary: 72 passed, 0 warnings, 0 failures ==` / `RESULT: PASS` |
| Static gate | ✅ **PASS** | `--check` **335/0/0** · `--selftest` **6/6** drift classes detected |

> **Verbatim tail of the battery run** (captured during the run):
> ```
>   [..] --- 2c. Battery file: 08_message_rls.sql ---
>   [OK] 08_message_rls.sql — all checks passed
>   [..] --- 2c. Battery file: 09_realtime_push.sql ---
>   [OK] 09_realtime_push.sql — all checks passed
>
> == summary: 72 passed, 0 warnings, 0 failures ==
> RESULT: PASS
> ```

**Honest limit (recorded, not papered over):** the delivery-equivalence
checks (09.11/09.12) prove the **RLS proxy** for live delivery — the
role-impersonated read under `messages_select_assigned`, which is the gate
Supabase Realtime RLS applies to `postgres_changes` delivery (the
documented mechanism, review Q2). A real websocket round-trip (channel →
event → UI) is NOT claimed here; that is the env-gated client slice (D-LV4,
plan T7). The publication-membership pins ARE the enablement layer,
verified directly against `pg_publication_tables`.

## 5. Next steps (gated)

1. ✅ **r1 PASSED 2026-08-08** (this record, §4) — the push slice has
   rehearsal evidence against the committed files on the applied posture.
2. **T5 — dated apply-approval** (`docs/realtime_push_apply_approval_2026-08-08.md`,
   DRAFT) → owner signs → apply `09_realtime_push` + `policies/messages_insert`
   + the demo send (the first live INSERT observed verbatim, rollback
   standing by) to the dev project with rollback pairing + cleanup;
   execution evidence per the established pattern.
3. T6 dated matrix addenda (§4 write row + §6 delivery row) → T7 env-gated
   client swap (subscription + composer, D-LV1/D-LV4) → T8 lockstep + close.

## 6. Rehearsal findings (fixed + committed)

1. **`CREATE PUBLICATION` has no `IF NOT EXISTS` form (T2, live).** The
   first draft of `09_realtime_push.sql` used a bare `create publication`
   guard that is a syntax error — the T2 live round-trip caught it. Fixed
   with a `do`-block guard (`if not exists … then create publication …`),
   recorded in the migration comment. Committed in `f1d7903`.
2. **08 granted SELECT only — an INSERT policy without a grant never fires
   (T2, live).** The T2 rehearsal proved `authenticated_insert = f` on the
   messages table: the partner's INSERT was denied at the **privilege
   layer**, before the policy could be evaluated. The slice therefore adds
   the INSERT grant alongside `messages_insert_assigned` (a grant without a
   policy still passes; a policy without a grant never fires), with the
   finding in the policy file comment. Committed in `f1d7903`.
3. **No new battery findings in T3** — the 09 battery passed on its first
   execution (72/0/0); the only mechanical harness change was the selftest
   fixture glob `0[1-8]`→`0[1-9]` so the drift-injection cross-ref covers
   09. Both prior findings were T2 artifacts validated live before the
   battery, which is why the T3 run needed no fixes.
