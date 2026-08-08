# LegalHub — Storage Rehearsal r1 Evidence (2026-08-08)

> **Record type:** Rehearsal evidence for the real-storage (read) slice
> (plan `docs/storage_real_data_plan_2026-08-08.md` T4), the P2/P3 r-series
> pattern. Mirrors the matters/documents/messages r1 evidence records
> (`docs/matters_rehearsal_evidence_r1_2026-08-07.md`,
> `docs/documents_rehearsal_evidence_r1_2026-08-07.md`,
> `docs/messages_rehearsal_evidence_r1_2026-08-07.md`) — whose batteries
> ran green via **Path A** (Docker + `supabase start`) and whose records
> were filled from the actual runs.
>
> **Status: PASSED 2026-08-08 — genuinely executed on the Docker-backed
> scratch stack** (Path A, this machine — the stack was up and the psql
> shim present at run time, resolving the earlier infra finding of §2).
> Battery verbatim: **`== summary: 74 passed, 0 warnings, 0 failures ==` /
> `RESULT: PASS`**, with all structural pins (1a **11 tables / 11 RLS**,
> 1e **exactly ten public policies** (11 minus the D-SM3 drop), 1f forward
> pin, 1g storage surface) and all ten battery files (01–10 incl.
> `07_storage_rls.sql`) green. Both T4 watch-items resolved by the actual
> run (the minimal-column bucket insert applied cleanly; the
> exactly-one-storage-schema-policy pin = 1). Nothing beyond what was
> actually run is claimed (INSTRUCTIONS.md §1.3 #5); the dev project was
> never touched.

---

## 1. What is ready (committed, verified-without-a-database)

| Artifact | State |
|---|---|
| `docs/storage_rls_gate_review_2026-08-08.md` | T1, `6f52930` — Q1–Q6 answered (two-layer gate, path-encoded scoping, guessed-path + signed-URL negatives, rollback pairing) |
| `supabase/migrations/07_storage.sql` + `07_storage.down.sql` | Rehearsal-ready (T2, `87b6ef5` + watch-item `0bc21ed`); clean inverse (drop files + bucket); private `matter-files` bucket (`(id, name, public)` insert — **proven live by this r1 `--apply`**, watch-item (a) resolved); `public.files` metadata-only (D-STR3 — no content/body/url column, `size_bytes` CHECK, `storage_path`) |
| `supabase/policies/files.sql` + `supabase/policies/storage_objects.sql` | Rehearsal-ready (T2, `87b6ef5`): `files_select_assigned` (the documents `exists`-subquery pattern) + `files_storage_select` on `storage.objects` (path-derived org/matter gate with the **is_active_member arm on both layers** — the `bad9641` fold) |
| `supabase/tests/07_storage_rls.sql` | 22 check blocks (T3, `47150be` + findings `83b406c`): **BOTH-layer** positives (client-a 2/2, partner-a 3/3, orphan 1/1) + matrix §4/§6 deny rows incl. the **non-vacuous org-mismatch** (file row + path org segment) + **guessed-path object** (matrix §6 row 1) + `size_bytes` CHECK + matter-delete cascade; anon objects arm tolerant to either storage-schema posture |
| `supabase/tests/00_fixtures.sql` | +6 file rows + 6 `storage.objects` rows (one per fixture matter; object `name` == the file's `storage_path` — the D-STR4 path encoding; generated `path_tokens` column not inserted) + reserved ids listed + 6/6/1 sanity pins |
| `scripts/verify_policy_tests.sh` | 07 wired into list/run/scans; structural pins (now **11 tables / 11 RLS / 10 policies** after the realtime-push + send-message slices) + files grant rows + **1g storage pins**; forward pin narrowed to `('messages')`; `--apply` applies 07 (T3, `47150be` + `83b406c`) |
| `supabase/README.md` | Battery table gained the 07 row; the apply list + forward-pin wording re-scoped to the fourth un-deferral (T3, `47150be`) |
| `scripts/verify_policy_tests.sh --check` | **PASS 337/0/0** at the r1 run (the current tree, incl. the send-message 10 battery) |

## 2. Infra note (revised 2026-08-08 — the run is no longer owner-side)

- The original finding recorded here (DRAFT-era) — "no `psql`/`docker` on
  this machine; the run is owner-side" — was **resolved at r1 time**: the
  Docker-backed local stack was **up** (`supabase start` containers,
  healthy, Postgres on host port **54322**) and the psql shim
  (`/tmp/rt-bin/psql`, a docker-exec passthrough) was present, so the
  rehearsal was **genuinely executed on this machine** via Path A.
- The dev project (`eutmvevpskerzpqmwplv`, the harness's DO-NOT-TOUCH ref)
  remains **hard-refused** by the harness and untouched — the battery
  fixtures DELETE from `auth.users`/`platform_config`, so the rehearsal
  can only run on the scratch stack, which is exactly what happened
  (fresh-schema reset first, then `--apply`).
- **T4 watch-items (both resolved by the actual run, verify-don't-guess):**
  (a) the `storage.buckets` minimal-column `(id, name, public)` insert —
  `--apply` applied `07_storage.sql` **cleanly** on the rehearsal host
  (the bare insert works; no `type`/`avif_autodetection` column needed);
  (b) the 1g "exactly one storage-schema policy" pin — the run reported
  **1** (only the slice's `files_storage_select`), so the host's default
  storage-policy baseline was 0 as assumed.

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
  scripts/verify_policy_tests.sh --apply         # 40 passed / 0 failures
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  scripts/verify_policy_tests.sh                 # 74 passed / 0 failures — RESULT: PASS
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  scripts/verify_policy_tests.sh --selftest      # 7 passed — all 6 drift classes detected
```

## 4. Evidence (genuinely executed 2026-08-08 — recorded verbatim)

**`--apply`:** **`== summary: 40 passed, 0 warnings, 0 failures ==`** /
`RESULT: PASS — slice applied from committed files. Run the battery next.`
— 40 files applied incl. `07_storage.sql` (the bucket + files table), the
policies (`files.sql` + `storage_objects.sql`), and all RPCs (incl.
`send_message.sql`, the audited send path).

| Check | Result | Observed output (verbatim from the run) |
|---|---|---|
| 1a — eleven public tables / RLS on all eleven | ✅ | `[OK] eleven public tables present (11)` · `[OK] RLS enabled on all eleven (11)` |
| 1b — narrow SELECT grants | ✅ | authenticated SELECT on profiles/organizations/memberships/invitations/matters/documents/message_threads/**files** all `true`; audit_events/platform_config/anon SELECTs `ABSENT` (D-P0C4 default-deny) |
| 1e — exactly ten public policies | ✅ | `[OK] exactly ten policies across the client tables (11 minus the D-SM3 messages_insert_assigned drop) (10)` |
| 1f — forward pin | ✅ | matters 1 · documents 1 · message_threads 1 · **files 1** · messages 1 · live delivery PRESENT (1) · exactly one table in the publication (1) |
| **1g — storage surface** | ✅ | `[OK] matter-files bucket present (1)` · `[OK] files_storage_select policy on storage.objects present (1)` · `[OK] exactly one storage-schema policy (the slice's only one) (1)` |
| 2a/2b — fixtures + platform_config bound | ✅ | `[OK] fixtures seeded (deterministic baseline)` · `[OK] exactly one platform_config row after fixtures (1)` |
| 01 / 02 / 03 / 04 / 05 / 06 batteries | ✅ | all six `— all checks passed` (identity, membership, owner boundary, matter, document, message_threads) |
| **07_storage_rls.sql** (both-layers 2/3/1 · org-role-alone · org-mismatch · cross-org · suspended · owner · anon denied · guessed-path · CHECK · cascade) | ✅ | `[OK] 07_storage_rls.sql — all checks passed` (22 check blocks on **both layers** — client-a 2 files + 2 objects, partner-a 3/3, orphan 1/1, the non-vacuous org-mismatch + guessed-path negatives, the `size_bytes` CHECK, the matter-delete cascade) |
| 08 / 09 / 10 batteries | ✅ | `08_message_rls.sql — all checks passed` · `09_realtime_push.sql — all checks passed` · `10_send_message_rls.sql — all checks passed` |
| Final summary + RESULT | ✅ | **`== summary: 74 passed, 0 warnings, 0 failures ==` / `RESULT: PASS`** (exit 0) |
| Selftest (harness drift detection) | ✅ | `== summary: 7 passed, 0 warnings, 0 failures ==` / `RESULT: PASS — all 6 drift classes detected.` |

> **Verbatim run output (as executed):** `== summary: 74 passed, 0
> warnings, 0 failures ==` / `RESULT: PASS` — genuinely executed on the
> Docker-backed scratch stack, not a pasted expectation.

## 5. Next steps (gated)

1. ✅ **r1 — PASSED 2026-08-08** (this record; 74/0/0 + pins + all ten
   batteries + selftest 6/6). Committed as docs(storage).
2. **T5 — dated apply-approval** (`docs/storage_apply_approval_2026-08-08.md`)
   → owner signs §6 → apply `07_storage` + both policies + demo files/
   objects (referencing the applied demo matter ids) to the dev project
   with rollback pairing + cleanup; execution evidence
   (`docs/storage_apply_execution_2026-08-08.md`) captures the actual run
   per the matters/documents/messages pattern — **⏳ HELD on the owner's
   dated go** (this r1 PASSED unblocks it).
3. T6 dated matrix §4 + §6 addendum → T7 env-gated client swap (new
   surface, D-STR7) → T8 lockstep + close. (T6/T7/T8 already committed in
   the slice; the apply execution + the HELD markers resolve after T5.)
