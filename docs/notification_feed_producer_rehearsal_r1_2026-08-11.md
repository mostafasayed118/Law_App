# LegalHub — Notification Producer Slice: r1 Rehearsal Evidence (2026-08-11)

> **Record type:** r1 rehearsal evidence for the **notification producer
> slice** (`supabase/migrations/15_notification_producer.sql` (+ `.down`) +
> `supabase/tests/15_notification_producer_rls.sql` + the battery-14 re-pin
> 4→6/4→6/1 + the harness re-scope batteries-01–15, per
> `docs/notification_feed_producer_gate_review_2026-08-11.md` (Q1–Q6) and
> `docs/notification_feed_producer_slice_plan_2026-08-11.md` (D-P1..D-P6,
> RATIFIED). **Status: r1 PASSED — genuinely executed 2026-08-11, 88/0/0
> (twice).** This records observed output from a real Postgres run; it is
> not a static claim.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Rehearsal host:** local Docker Desktop (engine restarted after the host
> reboot) + Supabase CLI 2.109.1, running the **ephemeral scratch project**
> `lh-rehearsal` (the established throwaway stack) and **torn down
> after** — **never the live dev project** (`eutmvevpskerzpqmwplv`; target
> URL loopback-only `127.0.0.1:55432`).
>
> **What was run:** the **working tree at HEAD `0f95125` plus the
> uncommitted producer slice** — i.e. the exact slice under rehearsal,
> before any commit (the repo's rehearse-before-commit convention). Full
> transcripts at `/tmp/lh-rehearsal/producer_apply_r1.log`,
> `producer_battery_r1_run{1,2}.log` (ephemeral, not committed).

---

## 1. Setup (scratch stack, isolated ports)

| Item | Value |
|---|---|
| Scratch project | `lh-rehearsal` (`/tmp/lh-rehearsal/supabase`, the F-01/notification-feed rehearsal stack, re-booted after the host restart) |
| Ports | db `55432` (published) · api `55421` · studio `55423` · inbucket `55424` · meta `55427` · analytics `55429` |
| DB URL used | `postgresql://postgres:postgres@127.0.0.1:55432/postgres` (loopback only; the psql shim rewrites it to the container-internal `supabase_db_lh-rehearsal:5432`) |
| psql | 17.6, executed from the `supabase/postgres:17.6.1.143` image on the project network via the retained disposable shim (host has no psql) |
| Clean base | `supabase db reset --yes` before `--apply` — a clean Postgres with no migrations (the scratch project's `supabase/migrations` is empty; the harness applies the REPO's committed files) |
| Pre-existing local stack | The unrelated local `supabase` project on the default ports was **not touched** |

## 2. Commands actually run (and results)

```bash
export PATH="/tmp/lh-rehearsal/bin:$PATH"
export SUPABASE_TEST_DB_URL="postgresql://postgres:postgres@127.0.0.1:55432/postgres"

# 0) Boot the scratch stack (it had stopped with the host restart)
cd /tmp/lh-rehearsal/supabase && supabase start
#   -> containers up; `supabase status`: local development setup running

# 1) Clean base
supabase db reset --yes
#   -> Finished supabase db reset on branch main.

# 2) Build the scratch project from the committed supabase/ files
cd /c/flutter_projects/law_app && bash scripts/verify_policy_tests.sh --apply
#   -> RESULT: PASS — 47 passed, 0 warnings, 0 failures (47 files applied:
#      12 migrations + 14 policies + 21 RPCs — the feed slice's 46 grew by
#      migrations/15_notification_producer.sql;
#      03_platform_config_seed skipped by design)
#      [OK] apply migrations/15_notification_producer.sql   <- the producer trigger

# 3) Full battery (structural pins + fixtures + 01..15) — run twice
bash scripts/verify_policy_tests.sh
#   run 1 -> RESULT: PASS — 88 passed, 0 warnings, 0 failures
#   run 2 -> RESULT: PASS — 88 passed, 0 warnings, 0 failures (rc=0 both)
```

Transcripts: `/tmp/lh-rehearsal/producer_apply_r1.log`,
`/tmp/lh-rehearsal/producer_battery_r1_run1.log`,
`/tmp/lh-rehearsal/producer_battery_r1_run2.log`.

## 3. Observed output (key lines, final run — `producer_battery_r1_run2.log`)

```
[OK] RLS enabled on all thirteen (13)
[OK] authenticated SELECT on notifications (14_notifications.sql) (true)
[OK] mirror_audit_to_notifications denied to authenticated (15 producer D-P4) (f)
[OK] exactly twelve policies across the client tables (12 minus the D-SM3
     messages_insert_assigned drop, plus the notifications_select_org policy) (12)
[..] --- 2c. Battery file: 14_notification_rls.sql ---
[OK] 14_notification_rls.sql — all checks passed          <- RE-PINNED 6/6/1, green
[..] --- 2c. Battery file: 15_notification_producer_rls.sql ---
[OK] 15_notification_producer_rls.sql — all checks passed <- the producer battery
== summary: 88 passed, 0 warnings, 0 failures ==
RESULT: PASS
```

## 4. What the producer battery proved (14 check blocks, live)

| Block | Claim | Layer |
|---|---|---|
| 15.01 | partner-a `create_matter` in org-a → the mirror produces **exactly one** org-a row with the fixed D-P3 content (`Demo notification — matter created`, category `activity`, type `matter_updated`), **visible through `notifications_select_org` under RLS** (Q3 gate visibility) — then the whole chain **rolls back with the event** | D-P2 map + Q3 (in-txn, RLS view) |
| 15.01 residue | after rollback: **0** rows with the unique map summary — D-P6 atomicity (a rolled-back event's feed row vanishes with it) | D-P6 (postgres view) |
| 15.02 | partner-a `send_message` on thread 1 → **exactly +1** org-a `new message in thread` row (delta against the session-GUC baseline of battery 10's 2 committed sends), fixed content (`message_received`), rolled back, residue back to baseline | D-P2 map + delta (Q5) |
| 15.02 redaction | the matter **title** (15.01) and message **body** (15.02) probes never appear in the produced summary — D-P3 fixed-map redaction, the D-N3 mirror | D-P3 |
| 15.03 | `matter:create`/`denied` audit row → **no** produced row (outcome filter) | filter NEG |
| 15.04 | unmapped action (`membership:create`/`allowed`) → **no** produced row (v1 map is exactly `{matter:create, message:create}`) | filter NEG |
| 15.05 | `matter:create`/`allowed` with **NULL org** → **no** produced row, cleanly (the `is not null` guard — a NULL-org mirror attempt filters instead of crashing the NOT NULL org FK) | filter NEG (Q2/Q3) |
| 15.06 | `mirror_audit_to_notifications()` EXECUTE revoked from `authenticated` — trigger-invoked only (D-P4, the write_audit precedent); also pinned structurally in the harness 1c | D-P4 |

The review's Q1–Q6 check list is fully covered: audit-mirror mechanism (Q1),
exact action map (Q2), org resolution from the audit row + NULL-org skip +
gate visibility + transactional atomicity (Q3), privilege posture clean —
counts stay 13/13/12, RPC-EXECUTE stays 20 (Q4), delta-based battery-15
assertions (Q5), and the apply/rollback contract (Q6).

## 5. Empirical re-pin confirmation (post-battery probe)

The battery-14 re-pin rests on the premise that battery 10's two COMMITTED
sends leave exactly 2 org-a producer rows when battery 14 runs. Direct
post-battery query of the rehearsal DB (privileged path) confirms it with
real rows:

```
20000000-0000-4000-8000-000000000001 | Demo notification — consultation reminder | 1
20000000-0000-4000-8000-000000000001 | Demo notification — invoice issued        | 1
20000000-0000-4000-8000-000000000001 | Demo notification — matter status update  | 1
20000000-0000-4000-8000-000000000001 | Demo notification — scheduled maintenance | 1
20000000-0000-4000-8000-000000000001 | new message in thread                     | 2   <- producer rows (battery 10)
20000000-0000-4000-8000-000000000002 | Demo notification — new message in thread | 1
total 7 rows; 'Demo notification — matter created' = 0
```

→ org-a = **6** (4 seeded + 2 producer), org-b = **1**, total **7** — the
exact 6/6/1 the re-pinned battery 14 asserts, and **zero** matter:create
residue (every 15.01/15.02 produced row rolled back with its event).

## 6. Honest scope notes (per the repo's no-false-assurance rule)

- This r1 ran the **working-tree slice (uncommitted)** at HEAD `0f95125`,
  matching the rehearse-before-commit convention; the evidence above is for
  exactly that tree, not a post-commit state.
- The static `--check` on the same tree: **80/0/0 PASS** (battery 15 wired,
  14 named blocks; the 1c mirror deny-pin added) and `--selftest` **7/0/0**
  (all 6 drift classes; battery 15 auto-covered by the `1[0-9]_*.sql` glob).
- Batteries 01–14 all passed unchanged alongside 15 — the producer trigger
  caused **zero regression** in the prior slices (13/10's RPC surfaces stay
  byte-identical green; battery 14's re-pinned counts verified live).
- The rehearsal proved the **server-side** producer mechanism. The client
  already renders the feed (T8, shipped); the dev apply will make the feed
  **non-empty** — re-verified by the T8 re-run of the E2E walkthrough.
- **Remaining gates before the slice is live:** dated apply-approval (owner,
  T5) → apply to the dev project → dated matrix/applied-surface addenda
  (T7) → non-vacuous feed re-verification (T8 re-run). Nothing here touches
  the dev project.

## 7. Teardown

`supabase stop` executed; **0 containers remain** (`docker ps` count 0).
Local data are backed to the docker volume
(`label=com.supabase.cli.project=lh-rehearsal`); the scratch project dir
(`/tmp/lh-rehearsal`: config, psql shim, this run's transcripts) is
retained in case the follow-up rehearsals need the same stack.
