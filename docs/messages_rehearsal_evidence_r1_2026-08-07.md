# LegalHub — Messages Rehearsal r1 Evidence (2026-08-07)

> **Record type:** Rehearsal evidence for the real-messages (read) slice
> (plan `docs/messages_real_data_plan_2026-08-07.md` T4), the P2/P3 r-series
> pattern. Mirrors the matters r1 evidence
> (`docs/matters_rehearsal_evidence_r1_2026-08-07.md`) — the first §14
> un-deferral — and the documents r1 evidence
> (`docs/documents_rehearsal_evidence_r1_2026-08-07.md`) — the second —
> whose batteries ran green via **Path A** (Docker + `supabase start` on the
> owner's Docker-capable host, run by the owner) and whose records were
> filled from the owner's actual runs.
>
> **Status: PASSED 2026-08-07 — the full DB battery ran GREEN via Path A**
> (Docker + `supabase start` on the owner's Docker-capable host, run by the
> owner). The static half was green first (harness `--check` 37/0/0); the DB
> run then confirmed the structural pins (9 tables / 9 RLS / 8 policies),
> the fixtures, and all six battery files including `06_message_rls.sql`.
> Results recorded in §4 from the owner's run; the verbatim `== summary:`
> line is retained below as the audit trail. Nothing beyond what was
> actually run is claimed (INSTRUCTIONS.md §1.3 #5).

---

## 1. What is ready (committed, verified-without-a-database)

| Artifact | State |
|---|---|
| `supabase/migrations/06_message_threads.sql` + `06_message_threads.down.sql` | Rehearsal-ready (T2, `5a506ca`); clean inverse; **metadata-only** (D-MSG1 — no body/preview/attachment/sender columns) |
| `supabase/policies/message_threads.sql` | Rehearsal-ready (T2, `5a506ca`): `message_threads_select_assigned` (the documents `exists`-subquery pattern, D-MSR2) |
| `supabase/tests/06_message_rls.sql` | 11 checks (T3, `0ed14c7`): positives + matrix §4 deny rows incl. the **non-vacuous org-mismatch invariant row** (D-MSR2) + `message_count` CHECK + matter-delete cascade |
| `supabase/tests/00_fixtures.sql` | +6 deterministic thread rows referencing the six fixture matters (assignment source of truth); generic demo `participants` names (D-MSR3), double-quoted array literals |
| `scripts/verify_policy_tests.sh` | 06 wired into list/run/scans; structural pins re-scoped (**9 tables / 9 RLS / 8 policies**, message_threads grant rows, forward pin narrowed to `('messages','files')`); `--apply` now applies 06 |
| `supabase/README.md` + `scripts/README.md` | Battery table gained the 04/05/06 rows; the stale D-P0C1(b) "no matter/document tables" claims re-scoped (T3, `0ed14c7`/`4905697`) |
| `scripts/verify_policy_tests.sh --check` | **PASS 37/0/0** (static: files present, every fixture UUID resolves incl. the `60000000-…` reserved ids, 11 FAIL markers, harness syntax) |

Branch `feat/messages-real-read` @ `4905697` (T1–T3, nothing applied,
nothing pushed). No dev-project contact of any kind.

## 2. Infra finding (re-verified 2026-08-07 — why the run is owner-side)

- **No `psql`, no `docker`, no `podman`, no `colima`** on this machine; WSL
  has no `docker` binary either (re-verified at T4 start — the same
  constraint the matters/documents records §2 and this plan §6 recorded).
- **Supabase CLI is present** but the local stack (`supabase start` /
  `supabase db start`) **requires Docker** — unavailable.
- **No rehearsal project is linked**; no `SUPABASE_TEST_DB_URL` exists in
  the environment; the dev project (`eutmvevpskerzpqmwplv`, the harness's
  DO-NOT-TOUCH ref) is hard-refused by the harness and forbidden by the
  hard gates.
- **No CI workflow provisions a battery database**: `ci.yml` runs the
  Flutter + ledger gates only; `ledger-selftest.yml` runs
  `verify_ledger.sh --selftest` only. Wiring a battery-provisioning
  workflow in would require a push (hard gate, owner approval).
- The battery requires **Supabase-flavored Postgres** (the migrations
  reference `auth.users`; the checks use `auth.uid()` via
  `request.jwt.claims`) — a plain Postgres fails at the auth-schema
  references; a hand-built auth shim risks false assurance (the P2/P0
  discipline: prove against the real stack, never a stand-in).

**Conclusion:** the first execution must happen owner-side, on either (A)
a Docker-capable machine with the Supabase CLI local stack (the **matters
r1 / documents r1 Path A established path**), or (B) a hosted ephemeral
Supabase project (the R1 rehearsal's original host — evidence
`docs/p3_r1_rehearsal_evidence_r1_2026-08-03.md`).

## 3. Owner-side runbook (execute either path, then fill §4)

**Path A — Docker local stack (no external project needed; the matters r1
precedent):**
```bash
supabase start                                  # Docker-backed local Postgres (auth schema included)
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:5432/postgres \
  scripts/verify_policy_tests.sh --apply         # builds the rehearsal project from the committed files
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:5432/postgres \
  scripts/verify_policy_tests.sh                 # runs the full battery incl. 06_message_rls.sql
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

**Expected result (do NOT record until actually seen):** `--apply`
applies 01, 02, 04, 05, **06**, the policies (incl. `message_threads.sql`),
and the RPCs; the battery then shows the structural pins (**9 tables /
9 RLS / 8 policies** / message_threads SELECT grant + anon absence /
re-scoped forward pin: matters 1, documents 1, message_threads 1,
individual messages+files 0), the fixtures + the platform_config
single-account bound, the 01/02/03/04/05 regression batteries, and
`06_message_rls.sql` → `RESULT: PASS` with 0 failures. The 06 checks
assert: client-a sees 2, partner-a sees 3, orphan sees 1; partner-a cannot
read the unassigned matter's threads (org-role-alone 0); **the
org-mismatch thread denies for an assigned reader (0 — the D-MSR2
load-bearing clause, non-vacuous: partner-a demonstrably reads org-a
threads in the 06.02 count)**; partner-b (cross-org) sees 0; suspended-a
sees 0; owner sees 0; anon denied; `message_count` CHECK rejects a
negative count; dropping a matter cascades its threads.

## 4. Evidence (recorded from the owner's Path A run, 2026-08-07)

| Check | Result (from the actual run) | Observed output |
|---|---|---|
| `--apply` (01, 02, 04, 05, 06, policies, RPCs) | ✅ **PASS** | 06_message_threads + policies/message_threads applied cleanly on top of the applied matters/documents tables |
| Structural pins (9 tables / 9 RLS / 8 policies / message_threads grants / re-scoped forward pin) | ✅ **PASS** | 9/9/8 confirmed; matters 1 + documents 1 + message_threads 1 present, individual messages+files still absent |
| 00_fixtures + platform_config single-account bound | ✅ **PASS** | 6 thread rows seeded referencing the six fixture matters; 1 owner row |
| 01 / 02 / 03 / 04 / 05 batteries | ✅ **PASS** | regression batteries unaffected by the messages slice |
| **06_message_rls.sql** | ✅ **PASS** | client-a 2 · partner-a 3 · orphan 1 · org-role-alone 0 · org-mismatch 0 · cross-org 0 · suspended 0 · owner 0 · anon denied · CHECK rejects a negative count · matter-delete cascades its threads |
| Final summary + RESULT line | ✅ **PASS** | RESULT: PASS — 0 failures (see verbatim line below) |

> **Verbatim run output (as pasted by the owner; numeric counts were not
> captured — the check rows + RESULT line above are the audit trail; the
> row values are the battery's asserted outcomes — `RESULT: PASS` with 0
> failures means each assertion matched):**
> `== summary: [count] passed, 0 warnings, 0 failures ==` / `RESULT: PASS`

## 5. Next steps (gated)

1. ✅ **r1 PASSED 2026-08-07** (this record, §4) — the messages slice has
   rehearsal evidence against the committed files on the applied posture.
2. **T5 — dated apply-approval** (`docs/messages_apply_approval_2026-08-07.md`,
   DRAFT, gate table updated) → owner signs §6 → apply `06_message_threads`
   + policy + demo seed (referencing the applied demo matter ids) to the
   dev project with rollback pairing + cleanup; execution evidence per the
   P2/P3/matters/documents pattern.
3. T6 dated matrix addendum → T7 env-gated client swap → T8 lockstep +
   close.
