# LegalHub — Matters Rehearsal r1 Evidence (2026-08-07)

> **Record type:** Rehearsal evidence for the real-matters read slice
> (plan `docs/matters_real_data_plan_2026-08-07.md` T4), the P2/P3 r-series
> pattern. Mirrors the P0C.1 evidence's honest separation of what was
> verified without a database from what is infra-pending
> (`docs/p0c1_verification_evidence_2026-08-05.md` §3).
>
> **Status: PENDING (infra) — the full DB battery has NOT been run.** The
> static half is green (harness `--check` 24/0/0). This record states the
> finding precisely, the two viable execution paths, and the expected
> results, so the owner can execute and fill §3 below without any further
> scaffolding. **No claim is made that the battery passes** (INSTRUCTIONS.md
> §1.3 #5 — never claim verified until actually run).

---

## 1. What is ready (committed, verified-without-a-database)

| Artifact | State |
|---|---|
| `supabase/migrations/04_matters.sql` + `04_matters.down.sql` | Rehearsal-ready (T2); clean inverse |
| `supabase/policies/matters.sql` | Rehearsal-ready (T2): `matters_select_assigned` |
| `supabase/tests/04_matter_rls.sql` | 10 checks (T3): positives + matrix §4 deny rows + CHECK + cascade |
| `supabase/tests/00_fixtures.sql` | +6 deterministic matters rows + reserved throwaway id |
| `scripts/verify_policy_tests.sh` | 04 wired into list/run/scans; structural pins re-scoped (7 tables/RLS, 6 policies, matters grants, re-scoped forward pin); `--apply` now applies 04 |
| `scripts/verify_policy_tests.sh --check` | **PASS 24/0/0** (static: files present, every fixture UUID resolves, 10 FAIL markers, harness syntax) |

Branch `feat/matters-real-read` @ `a08ef99` (T1–T3, nothing applied, nothing
pushed). No dev-project contact of any kind.

## 2. Infra finding (verified 2026-08-07 — why the run is PENDING)

- **No `psql`, no `docker`, no `podman`, no portable `initdb`/`pg_ctl`** on
  this machine (same constraint P0C.1 recorded, §3).
- **Supabase CLI 2.109.1 is present** but the local stack (`supabase start` /
  `supabase db start`) **requires Docker** — unavailable.
- The **only linked project** is the **dev project
  (`eutmvevpskerzpqmwplv`** — the harness's DO-NOT-TOUCH ref): pointing
  `SUPABASE_TEST_DB_URL` at it is hard-refused by the harness and forbidden
  by the hard gates. No rehearsal project is linked; no project URL/password
  exists on this machine.
- **No CI workflow provisions a battery database**: `ci.yml` runs the Flutter
  + ledger gates only; `ledger-selftest.yml` runs `verify_ledger.sh
  --selftest` only. `gh` is authenticated (owner), but there is no
  workflow_dispatch that builds a Supabase stack — wiring one in would
  require a push (hard gate, owner approval).
- The battery requires **Supabase-flavored Postgres** (the migrations
  reference `auth.users`; the checks use `auth.uid()` via
  `request.jwt.claims`) — a plain Postgres would fail at the auth-schema
  references and a hand-built auth shim risks false assurance (the P2/P0
  discipline: prove against the real stack, never a stand-in).

**Conclusion:** the first execution must happen owner-side, on either (A) a
Docker-capable machine with the Supabase CLI local stack, or (B) a hosted
ephemeral Supabase project (the R1 rehearsal's established host — evidence
`docs/p3_r1_rehearsal_evidence_r1_2026-08-03.md` §0/§17: CLI + Management
API as `postgres`).

## 3. Owner-side runbook (execute either path, then fill §4)

**Path A — Docker local stack (no external project needed):**
```bash
supabase start                                  # Docker-backed local Postgres (auth schema included)
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:5432/postgres \
  scripts/verify_policy_tests.sh --apply         # builds the rehearsal project from the committed files
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:5432/postgres \
  scripts/verify_policy_tests.sh                 # runs the full battery incl. 04_matter_rls.sql
supabase stop
```

**Path B — hosted ephemeral project (R1 pattern):**
```bash
supabase link --project-ref <ephemeral-ref>     # a throwaway rehearsal project, NEVER the dev ref
SUPABASE_TEST_DB_URL=<ephemeral project postgres URL> \
  scripts/verify_policy_tests.sh --apply
SUPABASE_TEST_DB_URL=<ephemeral project postgres URL> \
  scripts/verify_policy_tests.sh
```

**Expected result (do NOT record until actually seen):** `--apply` applies
01, 02, 04, the policies (incl. `matters.sql`), and the RPCs; the battery
then shows the structural pins (7 tables / 7 RLS / 6 policies / matters
grants / re-scoped forward pin), the fixtures, and `04_matter_rls.sql` →
`RESULT: PASS` with 0 failures. The 04 checks assert: client-a sees 2,
partner-a sees 3, orphan sees 1; partner-a cannot read unassigned matter-4;
partner-b (cross-org) sees 0; suspended-a sees 0; owner sees 0; anon denied;
CHECK rejects `'tax'`; org-a delete cascades its six matters.

## 4. Evidence (fill after a real run)

| Check | Result (from the actual run) | Observed output |
|---|---|---|
| `--apply` | ⏳ | |
| Structural pins (7/7/6/grants/forward) | ⏳ | |
| 00_fixtures + platform_config bound | ⏳ | |
| 01 / 02 / 03 batteries | ⏳ | |
| **04_matter_rls.sql** | ⏳ | |
| Final summary + RESULT line | ⏳ | |

## 5. Next steps (gated)

1. Owner executes Path A or B and fills §4 — **only then** does r1 pass.
2. **T5 — dated apply-approval** (owner) → apply `04_matters` + policy +
   demo seed to the dev project with rollback pairing + cleanup; execution
   record per the P2/P3 pattern.
3. T6 dated matrix addendum → T7 env-gated client swap → T8 lockstep +
   close.
