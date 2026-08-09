# LegalHub — F-01 Step 2 Matter-Write Slice: r1 Rehearsal Evidence (2026-08-09)

> **Record type:** r1 rehearsal evidence for the **F-01 step 2** slice
> (`supabase/rpc/create_matter.sql` + `supabase/migrations/11_matter_write.sql`
> (+ `.down`) + `supabase/tests/13_matter_write_rls.sql` + harness re-scope,
> per `docs/f01_step2_matter_write_design_2026-08-09.md`). **Status: r1
> PASSED — genuinely executed 2026-08-09, 82/0/0 (twice, final battery).**
> The battery grew to 16 blocks after the mechanism/RLS-gate review
> (13.14/13.15 UPDATE-arm + 13.16 F2-D5 — see
> `docs/matter_write_slice_review_2026-08-09.md` R-1/R-2) and was re-run;
> this record reflects the FINAL state. This records
> observed output from a real Postgres run; it is not a static claim.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Rehearsal host:** local Docker Desktop (engine up) + Supabase CLI
> 2.109.1, running the **ephemeral scratch project** `lh-rehearsal` (the same
> throwaway stack used for the step-1 r1) and **torn down after** — **never
> the live dev project** (`eutmvevpskerzpqmwplv`; the harness's DO-NOT-TOUCH
> guard was in force and the target URL was loopback-only `127.0.0.1:55432`).
>
> **What was run:** the **working tree at HEAD `f16586e` plus the uncommitted
> F-01 step 1 + step 2 changes** — i.e. the exact slice under rehearsal,
> before any commit (the repo's rehearse-before-commit convention). Full
> transcripts of runs 1–4 at `/tmp/lh-rehearsal/battery_r2_run{1..4}.log`
> (ephemeral, not committed).

---

## 1. Setup (scratch stack, isolated ports)

| Item | Value |
|---|---|
| Scratch project | `lh-rehearsal` (`/tmp/lh-rehearsal`, config.toml ports shifted +1100 off the default range — the same stack as the step-1 r1, re-booted) |
| Ports | db `55432` (published) · api `55421` · studio `55423` · inbucket `55424` · meta `55427` · analytics `55429` |
| DB URL used | `postgresql://postgres:postgres@127.0.0.1:55432/postgres` (loopback only) |
| psql | 17.6, executed from the `supabase/postgres:17.6.1.143` image on the project network (host has no psql; the disposable shim from the step-1 r1 was reused — no system install) |
| Clean base | `supabase db reset --yes` before `--apply` (the DB still held the step-1 applied state; the reset gave a clean Postgres with no migrations — `supabase/migrations` in the scratch project is empty) |
| Pre-existing local stack | The unrelated local `supabase` project on the default ports (from earlier rehearsal work on this host) was **not touched** |

## 2. Commands actually run (and results)

```bash
export PATH="/tmp/lh-rehearsal/bin:$PATH"
export SUPABASE_TEST_DB_URL="postgresql://postgres:postgres@127.0.0.1:55432/postgres"

# 1) Build the scratch project from the committed supabase/ files
bash scripts/verify_policy_tests.sh --apply
#   -> RESULT: PASS — 44 passed, 0 warnings, 0 failures (44 files applied:
#      10 migrations + 14 policies + 20 RPCs — the step-1 42 grew by
#      11_matter_write.sql + create_matter.sql; 03_platform_config_seed
#      skipped by design)

# 2) Full battery (structural pins + fixtures + 01..13) — run twice
bash scripts/verify_policy_tests.sh
#   run 1 -> RESULT: PASS — 82 passed, 0 warnings, 0 failures
#   run 2 -> RESULT: PASS — 82 passed, 0 warnings, 0 failures (rc=0 both)
```

Run history on this stack: runs 1–2 (81/0/0) preceded the §1c pin
(`refuse_platform_owner_assignment denied to authenticated`); runs 3–4
(82/0/0, `/tmp/lh-rehearsal/battery_r3_run{1,2}.log`) are the final state
AFTER the mechanism/RLS-gate review added blocks 13.14/13.15/13.16. The two
runs above are that final pinned state.

## 3. Observed output (key lines, final run — `/tmp/lh-rehearsal/battery_r2_run3.log`)

```
[OK] twelve public tables present (12)
[OK] RLS enabled on all twelve (12)
[OK] authenticated EXECUTE on public.send_message(uuid, text) (true)
[OK] authenticated EXECUTE on public.create_matter(uuid, text, text, uuid, uuid) (true)
[OK] refuse_platform_owner_assignment denied to authenticated (11_matter_write F2-D3) (f)
[OK] exactly eleven policies across the client tables (12 minus the D-SM3 messages_insert_assigned drop) (11)
[OK] exactly one table in the publication (nothing else, D-P0C1(b) teeth) (1)
[OK] matter-files bucket present (1)
[..] --- 2c. Battery file: 12_owner_assignment.sql ---
[OK] 12_owner_assignment.sql — all checks passed          <- step-1 pin, no regression
[..] --- 2c. Battery file: 13_matter_write_rls.sql ---
[OK] 13_matter_write_rls.sql — all checks passed          <- the F-01 step 2 battery
== summary: 82 passed, 0 warnings, 0 failures ==
RESULT: PASS
```

## 4. What the F-01 step 2 battery proved (16 check blocks, live)

| Block | Claim | Layer |
|---|---|---|
| 13.01 | partner-a (active partner, org-a) creates a matter with client-a + partner-a; the id resolves to exactly one row visible to the assigned attorney | RPC happy path + RLS read-back |
| 13.02 / 13.03 | the platform owner as assigned **client** / **attorney** is refused with the typed message; no row created | F2-D2 (RPC) |
| 13.04 | a **direct INSERT** (connection role — the "any path" case) assigning the owner is refused by the trigger | F2-D3 (categorical) |
| 13.05 | a direct INSERT with **non-owner** assignees succeeds — the trigger is narrow, demo-seed path stays viable | F2-D3 narrowness |
| 13.06 | a **denied** create writes **no** `matter:create` audit row (10.09 pattern) | §8 negative |
| 13.07 | an **allowed** create writes exactly one `matter:create` audit row with the redacted summary `matter created` (never the title) | §8 positive |
| 13.08 | a **non-partner** (client-a) cannot create (generic `permission denied`) | F2-D1 |
| 13.09 | a **non-member** assignee (partner-b in org-b) is refused | F2-D4 |
| 13.10 | a **suspended** membership cannot be assigned | F2-D4 |
| 13.11 | **cross-org** create (partner of org-a into org-b) refused — tenant isolation | F2-D1 |
| 13.12 | a **blank title** is refused (`matter title is required`) | validation |
| 13.13 | **anon** cannot create — no EXECUTE grant (insufficient_privilege) | privilege layer |
| 13.14 | an UPDATE **re-assigning** an existing matter's client to the owner is refused by the trigger (review R-1 — the UPDATE arm) | F2-D3 (categorical) |
| 13.15 | an UPDATE re-assigning to **non-owner** assignees succeeds — UPDATE-arm narrowness (review R-1) | F2-D3 narrowness |
| 13.16 | a partner creates a matter with **no assignments** (F2-D5) — the orphan row, invisible even to its creator under RLS (review R-2) | F2-D5 |

Every matrix row has ≥1 positive + ≥1 negative (contract §9); the Q4
residual state (owner assigned) is now uncreatable through **both** the RPC
and the data layer.

## 5. Honest scope notes (per the repo's no-false-assurance rule)

- This r1 ran the **working-tree slice (uncommitted)** at HEAD `f16586e`,
  matching the rehearse-before-commit convention; the evidence above is for
  exactly that tree, not a post-commit state.
- The static `--check` gate on the same tree: **73/0/0 PASS** (unchanged —
  the two new §1c/§1d pins are live-only and were exercised in this run).
- The rehearsal proved the **server-side** slice. The **client-side** matter
  creation surface does not exist yet — wiring the app to `create_matter` is
  the separate env-gated client swap at the end of the gate sequence.
- The step-1 r1 count cited in the register (§3b) was corrected for a latent
  harness UUID-scan bug; this run's numbers are the **executed psql results**
  and are unaffected by that static-scan issue.
- **Remaining gates before the slice is live:** mechanism/RLS-gate review →
  **dated apply-approval (owner)** → apply to the dev project → dated matrix
  §4 addendum → env-gated client swap.

## 6. Teardown

`supabase stop` executed; **0 containers remain** (`docker ps` count 0).
Local data are backed to the docker volume
(`label=com.supabase.cli.project=lh-rehearsal`); the scratch project dir
(`/tmp/lh-rehearsal`: config, psql shim, transcripts) is retained in case
the evidence needs re-inspection. The dev project was never contacted.
