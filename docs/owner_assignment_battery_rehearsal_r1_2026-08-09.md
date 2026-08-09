# LegalHub — F-01 Owner-Assignment Battery: r1 Rehearsal Evidence (2026-08-09)

> **Record type:** r1 rehearsal evidence for the **F-01 step 1** battery
> (`supabase/tests/12_owner_assignment.sql` +
> `scripts/verify_policy_tests.sh` wiring, per
> `docs/p4_findings_register_2026-08-09.md` F-01 step 1). **Status: r1
> PASSED — genuinely executed 2026-08-09, 79/0/0 (twice).** This records
> observed output from a real Postgres run; it is not a static claim.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Rehearsal host:** local Docker Desktop (engine 29.6.2) + Supabase CLI
> 2.109.1, running an **ephemeral scratch project** `lh-rehearsal` built for
> this rehearsal and **torn down after** — **never the live dev project**
> (`eutmvevpskerzpqmwplv`; the harness's DO-NOT-TOUCH guard was in force and
> the target URL was loopback-only `127.0.0.1`).
>
> **What was run:** the **working tree at HEAD `f16586e` plus the uncommitted
> F-01 step 1 changes** (the new battery file + harness wiring) — i.e. the
> exact slice under rehearsal, before any commit. The transcript of the full
> second execution is at `/tmp/lh-rehearsal/battery_r1.log` (ephemeral,
> not committed).

---

## 1. Setup (scratch stack, isolated ports)

| Item | Value |
|---|---|
| Scratch project | `lh-rehearsal` (init in `/tmp/lh-rehearsal`, config.toml ports shifted +1100 off the default range) |
| Ports | db `55432` (published) · api `55421` · studio `55423` · inbucket `55424` · meta `55427` · analytics `55429` · shadow `55430` |
| DB URL used | `postgresql://postgres:postgres@127.0.0.1:55432/postgres` (loopback only) |
| psql | 17.6, executed from the `supabase/postgres:17.6.1.143` image on the project network (host has no psql; a disposable shim was used — no system install) |
| Pre-existing local stack | An unrelated local `supabase` project was already running on the default ports (from earlier rehearsal work on this host); it was **not touched** — this rehearsal used its own port range |

## 2. Commands actually run (and results)

```bash
# 1) Build the scratch project from the committed supabase/ files
SUPABASE_TEST_DB_URL="postgresql://postgres:postgres@127.0.0.1:55432/postgres" \
  bash scripts/verify_policy_tests.sh --apply
#   -> RESULT: PASS — 42 passed, 0 warnings, 0 failures (42 files applied:
#      9 migrations + 14 policies + 19 RPCs; 03_platform_config_seed skipped by design)

# 2) Full battery (structural pins + fixtures + 01..12) — run twice
SUPABASE_TEST_DB_URL="postgresql://postgres:postgres@127.0.0.1:55432/postgres" \
  bash scripts/verify_policy_tests.sh
#   run 1 -> RESULT: PASS — 79 passed, 0 warnings, 0 failures
#   run 2 -> RESULT: PASS — 79 passed, 0 warnings, 0 failures (rc=0; transcript in battery_r1.log)
```

## 3. Observed output (key lines, second run — `/tmp/lh-rehearsal/battery_r1.log`)

```
[OK] twelve public tables present (12)
[OK] RLS enabled on all twelve (12)
[OK] authenticated SELECT on audit_events ABSENT (D-P0C4) (f)
[OK] authenticated SELECT on platform_config ABSENT (f)
[OK] anon SELECT on audit_events ABSENT (f)
[OK] is_platform_owner denied to authenticated (f)
[OK] zero policies on audit_events (0)
[OK] zero policies on platform_config (0)
[OK] exactly eleven policies across the client tables (12 minus the D-SM3 messages_insert_assigned drop) (11)
[OK] exactly one table in the publication (nothing else, D-P0C1(b) teeth) (1)
[OK] matter-files bucket present (1)
[OK] files_storage_select policy on storage.objects present (1)
[OK] exactly one storage-schema policy (the slice's only one) (1)
[OK] exactly one platform_config row after fixtures (1)
[OK] 03_platform_owner_boundary.sql — all checks passed
[OK] 12_owner_assignment.sql — all checks passed        <-- the F-01 invariant pin
== summary: 79 passed, 0 warnings, 0 failures
RESULT: PASS
```

## 4. What the F-01 battery (12) proved live

- **12.01/12.02 (non-vacuity):** exactly one `platform_config` owner row; at
  least one matter row carries an assignment — so the deny assertions below
  ran against real data, not an empty set.
- **12.03–12.05 (core invariant):** the platform-owner id (derived from
  `platform_config`, not hardcoded) appears **0 times** in
  `matters.assigned_client_id` / `assigned_attorney_id` (individually and in
  the union).
- **12.06–12.10 (defensive sweep):** the owner id appears **0 times** in any
  uuid column of `documents` / `message_threads` / `messages` / `files` /
  `billing_invoices`.
- **The whole battery passed on the same stack** (01–11 incl. the
  `platform_owner_admin` boundary and every per-slice content battery), so
  the F-01 pin landed with **no regression** in the existing matrix rows.

## 5. Honest scope notes (per the repo's no-false-assurance rule)

- This r1 ran the **working-tree slice (uncommitted)**, matching the
  rehearsal-before-commit convention; the evidence above is for exactly that
  tree, not a post-commit state.
- The battery's `--check` static gate re-run on 2026-08-09: **73/0/0 PASS**
  (corrected count — the 341 printed at the r1 run came from a latent
  UUID-scan bug in the harness that the F-01 step 2 build fixed;
  `docs/p4_findings_register_2026-08-09.md` §3b).
- The live run cannot assert **client-side** behavior (the app's env-gated
  gateways) — that remains the D-45.1 configured-build E2E, owner-side.
- The **categorical** owner deny on content tables remains an invariant until
  F-01 **step 2** (the future matter-write slice refuses owner assignment)
  ships; step 1 (this battery) makes the bad state un-seedable silently.

## 6. Teardown (executed 2026-08-09)

```bash
cd /tmp/lh-rehearsal && supabase stop --project-id lh-rehearsal
# Local data backed up to a docker volume (label com.supabase.cli.project=lh-rehearsal);
# 0 lh-rehearsal containers remain. Docker Desktop left running.
```

## 7. Cross-references

- Findings: `docs/p4_findings_register_2026-08-09.md` (F-01, change record).
- Threat model: `docs/p4_threat_model_2026-08-09.md` (§4.6, §6 residual 10).
- Battery: `supabase/tests/12_owner_assignment.sql`; harness
  `scripts/verify_policy_tests.sh` (12 wired into file list, static scans,
  run loop, selftest glob).
- Prior r-series convention: `docs/p14_plan_complete_2026-08-08.md` §3.
