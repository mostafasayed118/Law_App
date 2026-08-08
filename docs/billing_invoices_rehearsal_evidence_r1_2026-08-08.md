# LegalHub — Billing Invoices Rehearsal r1 Evidence (2026-08-08)

> **Record type:** Rehearsal evidence for the billing-invoices (read-
> metadata) slice (plan `docs/billing_invoices_real_data_plan_2026-08-08.md`
> T4), the P2/P3 r-series pattern. Mirrors the storage r1 evidence record
> (`docs/storage_rehearsal_evidence_r1_2026-08-08.md`) — whose battery ran
> green via **Path A** (Docker + `supabase start`) and whose record was
> filled from the actual run.
>
> **Status: PASSED 2026-08-08 — genuinely executed on the Docker-backed
> scratch stack** (Path A, this machine — the stack was up
> (`supabase_db_supabase`, healthy) and the psql shim present at run
> time). Battery verbatim: **`== summary: 78 passed, 0 warnings, 0
> failures ==` / `RESULT: PASS`**, with all structural pins (1a **12
> tables / 12 RLS**, 1e **exactly eleven public policies** (12 minus the
> D-SM3 drop), 1f forward pin **incl. `billing_invoices` present (ninth
> un-deferral)**, 1g storage surface) and **all eleven battery files
> (01–11 incl. `11_invoice_rls.sql`) green**. The `--apply` built the
> scratch project from the committed files incl. `10_billing_invoices.sql`
> + `policies/invoices.sql` (**42 passed / 0 failures**). Nothing beyond
> what was actually run is claimed (INSTRUCTIONS.md §1.3 #5); the dev
> project was never touched.

---

## 1. What is ready (committed, verified-without-a-database)

| Artifact | State |
|---|---|
| `docs/billing_invoices_gate_review_2026-08-08.md` | T1, `7d0ab93` — Q1–Q6 answered (metadata-only table, the documents exists-subquery gate verbatim + org-mismatch invariant, CHECK rows, rollback pairing, harness re-scope 12/12/11-public) |
| `supabase/migrations/10_billing_invoices.sql` + `10_billing_invoices.down.sql` | Rehearsal-ready (T2, `844a00e`); clean inverse (drop table); `public.billing_invoices` **metadata-only** (D-BI1 — no card/payment columns of any kind, the D-11 PCI constraint structural; `amount_cents >= 0` + `status in ('issued','paid')` CHECKs; select-only grant per Q5) |
| `supabase/policies/invoices.sql` | Rehearsal-ready (T2, `844a00e`): `invoices_select_assigned` (the documents `exists`-subquery pattern verbatim with the **load-bearing org-mismatch clause**, D-BI2) |
| `supabase/tests/11_invoice_rls.sql` | 12 check blocks (T3, `9a1310b`): client-a 2 / partner-a 3 / orphan 1 positives + org-role-alone / **non-vacuous org-mismatch** / cross-org / suspended / owner / anon denies + the `amount_cents` + `status` CHECK rows (D-11 mapping contract) + matter-delete cascade |
| `supabase/tests/00_fixtures.sql` | +6 invoice rows referencing the six fixture matters (generic numbers/amounts/copy — no card/payment columns) + reserved ids listed + 6-row sanity pin |
| `scripts/verify_policy_tests.sh` | 11 wired into list/run/scans; structural pins (now **12 tables / 12 RLS / 11 policies**) + billing grants rows + the 1f ninth-un-deferral pin; `--apply` applies `10_billing_invoices.sql` (T3, `9a1310b`) |
| `scripts/verify_policy_tests.sh --check` | **PASS 339/0/0** at the r1 run (the current tree, incl. the 11 battery) |
| `scripts/verify_policy_tests.sh --selftest` | **PASS — all 6 drift classes detected** at the r1 run |

## 2. Infra note

- The rehearsal was **genuinely executed on this machine** via Path A: the
  Docker-backed local stack was **up** (`supabase start` containers —
  `supabase_db_supabase`, healthy, Postgres on host port **54322**) and
  the psql shim (`/tmp/rt-bin/psql`, a docker-exec passthrough) was
  present at run time.
- The dev project (`eutmvevpskerzpqmwplv`, the harness's DO-NOT-TOUCH ref)
  remains **hard-refused** by the harness and untouched — the battery
  fixtures DELETE from `auth.users`/`platform_config`, so the rehearsal
  can only run on the scratch stack, which is exactly what happened
  (fresh-schema reset first, then `--apply`).
- **T4 watch-items (resolved by the actual run, verify-don't-guess):**
  (a) the `10_billing_invoices.sql` migration applied **cleanly** in
  `--apply` (42/0/0) — the metadata-only column set + CHECKs are accepted
  by the rehearsal host's Postgres; (b) the 1e pin re-scoped to **11**
  (12 minus the D-SM3 drop) reported **11** live, and the 1f
  `billing_invoices present (ninth un-deferral)` pin reported **1** — no
  re-scope drift.

## 3. Owner-side runbook (the path this record executed)

**Path A — Docker local stack (executed 2026-08-08 on this machine):**
```bash
supabase start                                  # stack up; Postgres on 127.0.0.1:54322
# fresh-slate reset (--apply targets a fresh project; the accumulated
# scratch state rejects the create-table migrations)
psql "$URL" -c "drop schema public cascade; create schema public;
  grant all on schema public to postgres;
  grant all on schema public to service_role;
  grant usage on schema public to anon, authenticated;"
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  scripts/verify_policy_tests.sh --apply         # 42 passed / 0 failures
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  scripts/verify_policy_tests.sh                 # 78 passed / 0 failures — RESULT: PASS
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  scripts/verify_policy_tests.sh --selftest      # 7 passed — all 6 drift classes detected
```

## 4. Evidence (genuinely executed 2026-08-08 — recorded verbatim)

**`--apply`:** **`== summary: 42 passed, 0 warnings, 0 failures ==`** /
`RESULT: PASS — slice applied from committed files. Run the battery next.`
— 42 files applied incl. `10_billing_invoices.sql` (the metadata-only
table), the policies (`invoices.sql` + all others), and all RPCs (incl.
`send_message.sql`, the audited send path).

| Check | Result | Observed output (verbatim from the run) |
|---|---|---|
| 1a — twelve public tables / RLS on all twelve | ✅ | `[OK] twelve public tables present (12)` · `[OK] RLS enabled on all twelve (12)` |
| 1b — narrow SELECT grants | ✅ | authenticated SELECT on profiles/organizations/memberships/invitations/matters/documents/message_threads/files/messages/**billing_invoices** all `true`; audit_events/platform_config/anon SELECTs `ABSENT` (D-P0C4 default-deny) incl. **anon on billing_invoices ABSENT** |
| 1e — exactly eleven public policies | ✅ | `[OK] exactly eleven policies across the client tables (12 minus the D-SM3 messages_insert_assigned drop) (11)` |
| 1f — forward pin | ✅ | matters 1 · documents 1 · message_threads 1 · files 1 · messages 1 · live delivery PRESENT (1) · exactly one table in the publication (1) · **`[OK] billing_invoices present (ninth un-deferral) (1)`** |
| 1g — storage surface | ✅ | `matter-files` bucket 1 · `files_storage_select` on storage.objects 1 · exactly one storage-schema policy (1) — unchanged by this slice |
| 2a/2b — fixtures + platform_config bound | ✅ | `[OK] fixtures seeded (deterministic baseline)` · `[OK] exactly one platform_config row after fixtures (1)` |
| 01 / 02 / 03 / 04 / 05 / 06 / 07 / 08 / 09 / 10 batteries | ✅ | all ten — `— all checks passed` (identity, membership, owner boundary, matter, document, message_threads, storage, realtime read, realtime push, send-message) |
| **11_invoice_rls.sql** (2/3/1 positives · org-role-alone · org-mismatch · cross-org · suspended · owner · anon denied · amount/status CHECKs · cascade) | ✅ | `[OK] 11_invoice_rls.sql — all checks passed` (12 check blocks — client-a 2, partner-a 3, orphan 1, the non-vacuous org-mismatch negative, the `amount_cents` + `status` CHECK rows, the matter-delete cascade) |
| Final summary + RESULT | ✅ | **`== summary: 78 passed, 0 warnings, 0 failures ==` / `RESULT: PASS`** (exit 0) |
| Selftest (harness drift detection) | ✅ | `== summary: 7 passed, 0 warnings, 0 failures ==` / `RESULT: PASS — all 6 drift classes detected.` |

> **Verbatim run output (as executed):** `== summary: 78 passed, 0
> warnings, 0 failures ==` / `RESULT: PASS` — genuinely executed on the
> Docker-backed scratch stack, not a pasted expectation.

## 5. Next steps (gated)

1. ✅ **r1 — PASSED 2026-08-08** (this record; 78/0/0 + pins + all eleven
   batteries + selftest 6/6). Committed as docs(billing).
2. **T5 — dated apply-approval** (`docs/billing_invoices_apply_approval_2026-08-08.md`)
   → owner signs §6 → apply `10_billing_invoices` + `policies/invoices` +
   demo invoices (referencing the applied demo matter ids) to the dev
   project with rollback pairing + cleanup; execution evidence
   (`docs/billing_invoices_apply_execution_2026-08-08.md`) captures the
   actual run per the matters/documents/messages/storage pattern — **⏳
   HELD on the owner's dated go** (this r1 PASSED unblocks it).
3. T6 dated matrix §4 addendum → T7 env-gated client swap (new surface,
   D-BI5) → T8 lockstep + close. (T6/T7/T8 not yet committed; the slice
   proceeds after T5.)
