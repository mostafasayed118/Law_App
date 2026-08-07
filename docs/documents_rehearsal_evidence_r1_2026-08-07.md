# LegalHub — Documents Rehearsal r1 Evidence (2026-08-07)

> **Record type:** Rehearsal evidence for the real-documents (read) slice
> (plan `docs/documents_real_data_plan_2026-08-07.md` T4), the P2/P3 r-series
> pattern. Mirrors the matters r1 evidence
> (`docs/matters_rehearsal_evidence_r1_2026-08-07.md`) — the first §14
> un-deferral — whose battery ran green via **Path A** (Docker + `supabase
> start` on the owner's Docker-capable host, run by the owner) and whose
> record was filled from the owner's actual run.
>
> **Status: PENDING — awaiting the owner's Path A run (2026-08-07).** The
> static half is green (harness `--check` 31/0/0, recorded in T3); the DB
> run is the first real execution of the 8-table / 7-RLS / 7-policy live
> pins and the `05_document_rls.sql` battery, and will be recorded in §4
> from the owner's run — the verbatim `== summary:` line is the one
> artifact to paste for the exact audit trail. Nothing beyond what is
> actually run will be claimed (INSTRUCTIONS.md §1.3 #5; the matters r1
> discipline — never record an unrun result).

---

## 1. What is ready (committed, verified-without-a-database)

| Artifact | State |
|---|---|
| `supabase/migrations/05_documents.sql` + `05_documents.down.sql` | Rehearsal-ready (T2); clean inverse |
| `supabase/policies/documents.sql` | Rehearsal-ready (T2): `documents_select_assigned` |
| `supabase/tests/05_document_rls.sql` | 11 checks (T3): positives + matrix §4 deny rows incl. the **org-mismatch invariant row** + `document_type` CHECK + matter-delete cascade |
| `supabase/tests/00_fixtures.sql` | +6 deterministic document rows referencing the six fixture matters (assignment source of truth) |
| `scripts/verify_policy_tests.sh` | 05 wired into list/run/scans; structural pins re-scoped (8 tables/RLS, 7 policies, documents grant rows, re-scoped forward pin); `--apply` now applies 05 (matters T3 finding pre-empted) |
| `scripts/verify_policy_tests.sh --check` | **PASS 31/0/0** (static: files present, every fixture UUID resolves, 11 FAIL markers, harness syntax) |

Branch `feat/documents-real-read` @ `b5bf0b2` (T1–T3, nothing applied,
nothing pushed). No dev-project contact of any kind.

## 2. Infra finding (re-verified 2026-08-07 — why the run is PENDING)

- **No `psql`, no `docker`, no `podman`, no `colima`** on this machine; WSL
  has no `docker` binary either (re-verified at T4 start — the same
  constraint the matters record §2 and this plan §6 recorded).
- **Supabase CLI 2.109.1 is present** but the local stack (`supabase
  start` / `supabase db start`) **requires Docker** — unavailable.
- **No rehearsal project is linked** (`supabase/config.toml` carries no
  project id); no `SUPABASE_TEST_DB_URL` exists in the environment; the
  dev project (`eutmvevpskerzpqmwplv`, the harness's DO-NOT-TOUCH ref) is
  hard-refused by the harness and forbidden by the hard gates.
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
r1 Path A established path**), or (B) a hosted ephemeral Supabase project
(the R1 rehearsal's original host — evidence
`docs/p3_r1_rehearsal_evidence_r1_2026-08-03.md`).

## 3. Owner-side runbook (execute either path, then fill §4)

**Path A — Docker local stack (no external project needed; the matters r1
precedent):**
```bash
supabase start                                  # Docker-backed local Postgres (auth schema included)
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:5432/postgres \
  scripts/verify_policy_tests.sh --apply         # builds the rehearsal project from the committed files
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:5432/postgres \
  scripts/verify_policy_tests.sh                 # runs the full battery incl. 05_document_rls.sql
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
applies 01, 02, 04, **05**, the policies (incl. `documents.sql`), and the
RPCs; the battery then shows the structural pins (**8 tables / 8 RLS /
7 policies** / documents SELECT grant + anon absence / re-scoped forward
pin: matters 1, documents 1, messages+files 0), the fixtures + the
platform_config single-account bound, the 01/02/03/04 regression
batteries, and `05_document_rls.sql` → `RESULT: PASS` with 0 failures.
The 05 checks assert: client-a sees 2, partner-a sees 3, orphan sees 1;
partner-a cannot read the unassigned matter's documents (org-role-alone
0); **the org-mismatch document denies for an assigned reader (0 — the
D-DR2 load-bearing clause)**; partner-b (cross-org) sees 0; suspended-a
sees 0; owner sees 0; anon denied; `document_type` CHECK rejects `'tax'`;
dropping a matter cascades its documents.

## 4. Evidence (recorded from the owner's Path A run — PENDING)

| Check | Result (from the actual run) | Observed output |
|---|---|---|
| `--apply` (01, 02, 04, 05, policies, RPCs) | ⏳ pending | — |
| Structural pins (8 tables / 8 RLS / 7 policies / documents grants / re-scoped forward pin) | ⏳ pending | — |
| 00_fixtures + platform_config single-account bound | ⏳ pending | — |
| 01 / 02 / 03 / 04 batteries | ⏳ pending | — |
| **05_document_rls.sql** | ⏳ pending | — |
| Final summary + RESULT line | ⏳ pending | — |

> **Verbatim run output (paste here for the exact audit trail):**
> `== summary: ___ passed, ___ warnings, ___ failures ==` / `RESULT: PASS`

## 5. Next steps (gated)

1. **r1 (this record)** — the owner runs Path A above; §4 is filled from
   the actual run and the status flips to **PASSED** (matters r1
   precedent, `ea3a15d`).
2. **T5 — dated apply-approval** (`docs/documents_apply_approval_2026-08-07.md`,
   drafted DRAFT) → owner signs §6 → apply `05_documents` + policy + demo
   seed (referencing the applied demo matter ids) to the dev project with
   rollback pairing + cleanup; execution evidence per the P2/P3/matters
   pattern.
3. T6 dated matrix addendum → T7 env-gated client swap → T8 lockstep +
   close.
