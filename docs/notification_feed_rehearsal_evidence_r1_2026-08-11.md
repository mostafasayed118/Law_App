# LegalHub — Notification-Feed Read Slice: r1 Rehearsal Evidence (2026-08-11)

> **Record type:** r1 rehearsal evidence for the **notification-feed read
> slice** (`supabase/migrations/14_notifications.sql` (+ `.down`) +
> `supabase/policies/notifications.sql` + `supabase/tests/14_notification_rls.sql`
> + the §14 fixtures seed + the harness re-scope 13/13/12+1/batteries-01–14,
> per `docs/notification_feed_gate_review_2026-08-11.md` (Q1–Q6) and
> `docs/notification_feed_slice_plan_2026-08-11.md`). **Status: r1 PASSED —
> genuinely executed 2026-08-11, 86/0/0 (twice).** This records observed
> output from a real Postgres run; it is not a static claim.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Rehearsal host:** local Docker Desktop (engine up, server 29.6.2) +
> Supabase CLI 2.109.1, running the **ephemeral scratch project**
> `lh-rehearsal` (the established throwaway stack, re-booted after the
> host restart) and **torn down after** — **never the live dev project**
> (`eutmvevpskerzpqmwplv`; the harness's DO-NOT-TOUCH guard was in force
> and the target URL was loopback-only `127.0.0.1:55432`).
>
> **What was run:** the **working tree at HEAD `b9f2b08` plus the
> uncommitted notification-feed slice** — i.e. the exact slice under
> rehearsal, before any commit (the repo's rehearse-before-commit
> convention). Full transcripts at
> `/tmp/lh-rehearsal/battery_r1_run{1,2}.log` (ephemeral, not committed).

---

## 1. Setup (scratch stack, isolated ports)

| Item | Value |
|---|---|
| Scratch project | `lh-rehearsal` (`/tmp/lh-rehearsal`, config.toml ports shifted +1100 off the default range — the same stack as the F-01 step-1/step-2 rehearsals, re-booted after the host restart) |
| Ports | db `55432` (published) · api `55421` · studio `55423` · inbucket `55424` · meta `55427` · analytics `55429` |
| DB URL used | `postgresql://postgres:postgres@127.0.0.1:55432/postgres` (loopback only) |
| psql | 17.6, executed from the `supabase/postgres:17.6.1.143` image on the project network (host has no psql; the disposable shim from the step-1 r1 was reused — no system install) |
| Clean base | `supabase db reset --yes` before `--apply` (the DB still held the step-2 applied state from the 2026-08-09 rehearsal; the reset gave a clean Postgres with no migrations — `supabase/migrations` in the scratch project is empty) |
| Pre-existing local stack | The unrelated local `supabase` project on the default ports (from earlier rehearsal work on this host) was **not touched** |

## 2. Commands actually run (and results)

```bash
export PATH="/tmp/lh-rehearsal/bin:$PATH"
export SUPABASE_TEST_DB_URL="postgresql://postgres:postgres@127.0.0.1:55432/postgres"

# 0) Boot the scratch stack (it had stopped with the host restart)
cd /tmp/lh-rehearsal && supabase start
#   -> port 55432 OPEN; `supabase status`: local development setup running

# 1) Clean base
supabase db reset --yes
#   -> Finished supabase db reset on branch main.

# 2) Build the scratch project from the committed supabase/ files
bash scripts/verify_policy_tests.sh --apply
#   -> RESULT: PASS — 46 passed, 0 warnings, 0 failures (46 files applied:
#      11 migrations + 14 policies + 21 RPCs — the step-2 44 grew by
#      14_notifications.sql + policies/notifications.sql;
#      03_platform_config_seed skipped by design)

# 3) Full battery (structural pins + fixtures + 01..14) — run twice
bash scripts/verify_policy_tests.sh
#   run 1 -> RESULT: PASS — 86 passed, 0 warnings, 0 failures
#   run 2 -> RESULT: PASS — 86 passed, 0 warnings, 0 failures (rc=0 both)
```

Transcripts: `/tmp/lh-rehearsal/battery_r1_run1.log`,
`/tmp/lh-rehearsal/battery_r1_run2.log`.

## 3. Observed output (key lines, final run — `/tmp/lh-rehearsal/battery_r1_run2.log`)

```
[OK] thirteen public tables present (13)
[OK] RLS enabled on all thirteen (13)
[OK] authenticated SELECT on notifications (14_notifications.sql) (true)
[OK] anon SELECT on notifications ABSENT (default-deny) (f)
[OK] exactly twelve policies across the client tables (12 minus the D-SM3 messages_insert_assigned drop, plus the notifications_select_org policy) (12)
[OK] notifications present (new-surface feed) (1)
[OK] exactly one table in the publication (nothing else, D-P0C1(b) teeth) (1)
[OK] matter-files bucket present (1)
[..] --- 2c. Battery file: 13_matter_write_rls.sql ---
[OK] 13_matter_write_rls.sql — all checks passed          <- prior slice, no regression
[..] --- 2c. Battery file: 14_notification_rls.sql ---
[OK] 14_notification_rls.sql — all checks passed          <- the notification-feed battery
== summary: 86 passed, 0 warnings, 0 failures ==
RESULT: PASS
```

## 4. What the notification-feed battery proved (10 check blocks, live)

| Block | Claim | Layer |
|---|---|---|
| 14.01 | partner-a (org-a, partner/active) reads exactly its **4** org-a notifications — the organizations-gate grants by membership | Q2 positive (count) |
| 14.02 | client-a (org-a, client/active) reads exactly the same **4** — the **no-role-hierarchy** pin (Q3) | Q2 positive (count) |
| 14.03 | partner-b (org-b, partner/active) reads exactly its **1** org-b row — org scoping **by count** (org-a rows invisible cross-org) | Q2 positive (count) |
| 14.04 | partner-b reads the org-a subset explicitly — **0** (cross-org denied, non-vacuous) | cross-org deny |
| 14.05 | `platform_owner_admin` (owner 0001, no membership by construction, D-P0C3) reads **0** — deny-ALWAYS posture (D-P0C1(a)); residual recorded (if an owner account were ever granted a membership this policy WOULD grant — operational invariant, fixtures never create that state) | D-P0C1(a) deny |
| 14.06 | suspended-a reads **0** — `is_active_member` is the status = 'active' rule; stale access denied | stale-access deny |
| 14.07 | anon raw SELECT denied — no grant (insufficient_privilege) | privilege layer |
| 14.08 | privileged insert with category `'urgent'` rejected — the D-N4 category CHECK is the mapping contract | D-N4 (privileged half) |
| 14.09 | org-delete cascade removes the org's notifications (temp org + temp row, rolled back) | FK cascade |
| 14.10 | **structural redaction pin (Q1)**: the table's column inventory is EXACTLY `category,id,is_read,organization_id,server_timestamp,summary,type` — no user-identity/content/raw-text column can be added without this pin failing first | Q1 (privileged half, information_schema) |

The review's Q6 check list is fully covered: member positive / non-member
denied / cross-org denied / anon denied / category-CHECK violation /
org-cascade — plus the Q1 structural-redaction pin and the no-role-hierarchy
count pair.

## 5. Honest scope notes (per the repo's no-false-assurance rule)

- This r1 ran the **working-tree slice (uncommitted)** at HEAD `b9f2b08`,
  matching the rehearse-before-commit convention; the evidence above is for
  exactly that tree, not a post-commit state.
- The static `--check` on the same tree: **78/0/0 PASS** (the re-scoped
  battery list + fixture cross-ref + FAIL-marker sweep; battery 14 wired,
  10 named blocks).
- The rehearsal proved the **server-side** slice (table + policy + battery).
  The **client-side** feed surface does not exist yet — the env-gated
  `NotificationGateway` swap is the separate T8 step at the end of the gate
  sequence.
- **Remaining gates before the slice is live:** dated apply-approval (owner,
  T5) → apply to the dev project → dated matrix §4 addendum (T6) →
  env-gated client swap (T8). Nothing here touches the dev project.

## 6. Teardown

`supabase stop` executed; **0 containers remain** (`docker ps` count 0).
Local data are backed to the docker volume
(`label=com.supabase.cli.project=lh-rehearsal`); the scratch project dir
(`/tmp/lh-rehearsal`: config, psql shim, transcripts) is retained in case
the follow-up rehearsals (post-review re-runs) need the same stack.
