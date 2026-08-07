# LegalHub — Storage Apply Approval Decision Record (2026-08-08)

> **Record type:** The dated decision record that closes the apply-approval
> gate for the real-storage read slice (plan
> `docs/storage_real_data_plan_2026-08-08.md` T5), per the P2/P3 discipline
> (`docs/messages_apply_approval_2026-08-07.md` is the immediate precedent
> shape; `docs/documents_apply_approval_2026-08-07.md` and
> `docs/matters_apply_approval_2026-08-07.md` are the originals). This
> record, **once the r1 rehearsal is PASSED and this record is signed in
> §6**, is the owner's explicit authorization to apply the reviewed +
> rehearsed slice to the shared dev project, with the rollback pairing
> standing by.
>
> **Status: APPLY APPROVED (2026-08-08).** The owner's dated sign-off in §6
> (recorded from the pair-programming session, the documents/messages
> precedent) authorizes the §3 up sequence against the shared dev project
> (`eutmvevpskerzpqmwplv`, `eu-central-1`) per the §4 execution conditions,
> with the rollback pairing standing by. **Execution is HELD pending the r1
> rehearsal evidence**: the owner asserts r1 PASSED, but the rehearsal
> record (`docs/storage_rehearsal_evidence_r1_2026-08-08.md`) is still ⏳
> PENDING (no observed run output in the repo) — per §4 condition 1 +
> `rollback_plan.md` §2, the apply runs only after the r1 evidence lands.
> The read-only baseline probes (2026-08-08) confirm the dev project is in
> the exact pre-apply state (§4.1): `files` 0 · bucket 0 · public policies
> 8 · storage policies 0 · the four demo matter ids resolve (org
> `ef43087b-adf4-4480-9bb2-28c26f46ec71`), and the T4 watch-items resolve:
> `storage.buckets.type` is NOT NULL **with default
> `'STANDARD'::storage.buckettype`** — the bare `(id, name, public)` insert
> is valid — and `storage.foldername` exists.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/storage_real_data_plan_2026-08-08.md` (T5,
> D-STR8) · `docs/storage_rls_gate_review_2026-08-08.md` (Q1–Q6, §6
> rollback) · `docs/storage_rehearsal_evidence_r1_2026-08-08.md` (r1,
> ⏳ PENDING) · `docs/matters_apply_execution_2026-08-07.md` (the applied
> demo matter ids + demo accounts this seed references) ·
> `docs/rollback_plan.md` §1/§5 · `docs/permission_matrix.md` §4/§6/§7 ·
> `supabase/README.md` · `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| §14 un-deferral gate (P0 closes + policy tests) | `docs/p0_closure_scope_2026-08-05.md` RATIFIED + `scripts/verify_policy_tests.sh` + the **matters + documents + messages precedents SHIPPED + applied** (the FK targets + assignment source) | ✅ Met — P0 RATIFIED 2026-08-05 · three precedents SHIPPED + applied 2026-08-07 |
| RLS-gate design review | `docs/storage_rls_gate_review_2026-08-08.md` (`6f52930` + nits `0d7bdca`) | ✅ Passed 2026-08-08 |
| Schema artifacts (rehearsal-ready) | `supabase/migrations/07_storage.sql` + `07_storage.down.sql` (`87b6ef5` + watch-item `0bc21ed`) | ✅ Committed — NOT applied |
| Policy artifacts | `supabase/policies/files.sql` + `supabase/policies/storage_objects.sql` (`87b6ef5`) | ✅ Committed — NOT applied |
| Policy battery + harness | `supabase/tests/07_storage_rls.sql`, `00_fixtures.sql`, `scripts/verify_policy_tests.sh` (`47150be`, `83b406c`) | ✅ Committed; static `--check` PASS **331/0/0** |
| **Ephemeral rehearsal (r1)** | `docs/storage_rehearsal_evidence_r1_2026-08-08.md` | ⏳ **PENDING** — owner's Docker host (Path A); the failed-attempt finding (no Docker/psql here) recorded in its §2. The owner asserts PASSED; **no observed output in the repo yet — the apply execution is held on this** (§4.1, rollback_plan §2) |
| **Apply approval (this record)** | this document | ✅ **APPROVED 2026-08-08** (owner's dated sign-off, §6 — recorded from the session; r1 asserted PASSED, evidence pending — execution held) |
| Apply execution (dev project) | `docs/storage_apply_execution_2026-08-08.md` | ⏳ Held — pending the r1 evidence landing in the rehearsal record; the read-only baseline (§4.1) is already verified |

## 2. Gate criteria — what the r1 rehearsal must prove

Against the ephemeral project built from the committed files (r1, to be
run; evidence `docs/storage_rehearsal_evidence_r1_2026-08-08.md`), the
battery must verify — mirroring the messages r1 five:

| # | Criterion | r1 evidence to capture | Verdict |
|---|---|---|---|
| 1 | `--apply` builds the slice cleanly (01, 02, 04, 05, 06, **07**, policies, RPCs) — `07_storage.sql` + `policies/files.sql` + `policies/storage_objects.sql` applied on top of the already-applied `matters` + `documents` + `message_threads` tables | rehearsal §4 | ⏳ PENDING |
| 2 | Structural pins hold on the applied posture | rehearsal §4: **1a ten tables / ten RLS** · **1e exactly nine public policies** · **1g matter-files bucket 1 + `files_storage_select` on storage.objects 1 + exactly one storage-schema policy 1** · files SELECT grant + anon absence · forward pin (matters/documents/message_threads/**files** present, individual messages 0) | ⏳ PENDING |
| 3 | 00/01/02/03/04/05/**06** regression batteries unaffected | rehearsal §4: fixtures (6 files + 6 objects + 1 bucket) + single-account bound + 01/02/03 + the six-matter/six-document/six-thread batteries all PASS | ⏳ PENDING |
| 4 | `files_select_assigned` + `files_storage_select` enforce the matrix §4/§6 contract on **BOTH layers** | rehearsal §4: client-a 2 files + 2 objects · partner-a 3/3 · orphan 1/1 · org-role-alone 0/0 · **org-mismatch 0/0 (non-vacuous — D-STR2, file row + path org segment)** · cross-org 0/0 · **suspended 0/0 (the is_active_member arm on the objects layer)** · owner 0/0 · anon denied (files = no grant; objects = 0 via RLS) · **guessed-path object 0 (matrix §6 row 1, non-vacuous)** | ⏳ PENDING |
| 5 | Mapping contract + teardown safety | rehearsal §4: `size_bytes` CHECK rejects a negative size · matter-delete cascades its files rows (FK on delete cascade) | ⏳ PENDING |

**Verdict (⏳ PENDING):** none of the five criteria is claimed until the
owner's Path A run lands (§4 of the rehearsal record). The two
storage-specific T4 watch-items must also resolve green there: the bare
`(id, name, public)` bucket insert proves on the rehearsal host (the
`type`/`avif_autodetection` nullability the hosted probe could not see —
if the host demands `type`, the apply uses the rehearsal-proven column
list), and the host's storage-policy baseline is **0** before `--apply`
(the 1g "exactly one" pin depends on it).

## 3. Decision (scope this record authorizes — once signed)

**APPLY APPROVED (on signature):** apply the reviewed + rehearsed storage
slice to the shared dev project (`eutmvevpskerzpqmwplv`, `eu-central-1`) in
this order:

1. `supabase/migrations/07_storage.sql` — the private **`matter-files`
   bucket** (idempotent `insert into storage.buckets (id, name, public)
   values ('matter-files','matter-files',false) on conflict (id) do
   nothing`; the minimal column set **verified live** against the dev
   project's storage schema 2026-08-08 + **proven by the rehearsal host**
   at T4 — `type` added from the rehearsal-proven list only if the host
   schema demands it) **and** the `public.files` metadata table
   (D-STR3 — **metadata only, no content/body/url column**: `id`,
   `organization_id` FK → `organizations` cascade, `matter_id` FK → the
   **applied** `matters` cascade, `name` (never PII by convention),
   `mime_type`, `size_bytes` with the client-`FileMetadata.sizeBytes` CHECK
   (`>= 0`), `storage_path` (the single source of truth —
   `{org_id}/{matter_id}/{filename}`), org + matter indexes, RLS enable,
   default-deny revoke, narrow `select` grant).
2. `supabase/policies/files.sql` — `files_select_assigned`
   (`is_active_member(organization_id)` AND exists on the matter row with
   the **org-mismatch clause** `m.organization_id = files.organization_id`
   AND assigned client/attorney = `auth.uid()`), and
   `supabase/policies/storage_objects.sql` — `files_storage_select` on
   `storage.objects` (`bucket_id = 'matter-files'` AND
   `is_active_member((storage.foldername(name))[1]::uuid)` AND exists on
   the path's matter with the path-org equality — the **is_active_member
   arm + path-org invariant on the bytes layer**, D-STR2; guessed-path
   denies).
3. **Demo seed** — a small set of demo file rows (4) **and demo objects
   (4, in the `matter-files` bucket)** referencing the **applied demo
   matter ids** on the dev project (resolved at apply time from the dev
   project's own `matters` rows — never guessed, never the rehearsal
   project's synthetic `40000000-…`/`70000000-…`/`80000000-…` ids; the
   four applied demo matter ids recorded in
   `docs/matters_apply_execution_2026-08-07.md` §2.2 are `a6715e17-…`,
   `d155dc92-…`, `4f4a935f-…`, `575391b6-…`, org `ef43087b-…`). Each
   seeded row + object carries the **matter's own org** in the path
   (`{org}/{matter}/{file}` — the D-STR2 invariant applied at seed time),
   **generic demo file names only** (D-STR8 — no real client/legal copy,
   no PII), and `storage_path` == the object's `name` (the D-STR4
   encoding, so the follow-up `download(storage_path)` resolves). The
   exact rows + ids are recorded in the execution record.

plus the post-apply verification (structural subset + demo reads as
assigned roles) per §4 condition 6, and the execution evidence record
(`docs/storage_apply_execution_2026-08-08.md`).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline probe (read-only):** confirm `public.files` does not
   yet exist on the dev project, the `matter-files` bucket does not exist,
   `matters` **does** exist with its four applied demo rows + the applied
   `documents`/`message_threads` tables, the current `pg_policies` count
   is **8 public** (→ **9** after apply) + **0 storage-schema** (→ **1**
   after apply), and the four demo matter ids resolve from the dev
   project's own rows — the up sequence runs against the same baseline the
   rehearsal proved.
2. **Verify, don't guess (bucket + demo seed):** the bucket column list is
   the **rehearsal-proven** one (T4 watch-item: the bare `(id, name,
   public)` insert — `type` added only if the rehearsal host demanded it);
   the storage-policy baseline was **0** on the rehearsal host before
   `--apply` (the 1g pin); matter ids come from the **dev project's own
   applied `matters` rows**; the seed never uses rehearsal synthetic ids,
   never touches non-demo matters, never uses real PII or real account
   identities in file names/object paths (generic demo names only,
   D-STR8), and every seeded path's org segment equals its matter's org
   (D-STR2).
3. **Rollback pairing standing by (rollback_plan §1/§5):**
   `07_storage.down.sql` (`drop table public.files` + `delete from
   storage.buckets where id = 'matter-files'` — the platform bucket-delete
   cascades its objects) + a targeted delete of the seeded demo rows **and
   demo objects** (+ `git revert` of the two policy commits per the
   RLS-gate review §6 convention — self-contained here) is ready before
   step 1; **any** trigger condition (a matrix negative row starts passing,
   cross-tenant data visible, a demo row/object lands on a real
   matter/account, a non-generic file name or path appears) = immediate
   revert, never fix-forward.
4. **Per-step verification:** after each of the three steps, probe the
   applied state (bucket present → table exists → both policies present →
   seed rows/objects scoped correctly: right org, right matter, generic
   names, `storage_path` == object `name`) with the observed output pasted
   verbatim into the execution record.
5. **Post-apply smoke (dev project):** the structural subset the rehearsal
   proved — 10 tables / 9 public policies + the storage pins (bucket 1,
   `files_storage_select` 1, storage policies 1) + grants; then demo reads
   with role impersonation (`set local role authenticated` +
   `request.jwt.claims` via `supabase db query --linked`, the R1 pattern):
   the partner/attorney demo account (the **only** dev member, per the
   matters execution baseline) reads the files + objects on its assigned
   demo matters; the assigned demo clients read **0** because they hold no
   dev membership rows — the D-STR2 membership guard firing live, recorded
   as an honest expectation (the matters/documents/messages smoke
   precedent), never as a defect.
6. **No scope beyond the slice:** no other table/RPC/policy change, no
   bucket other than `matter-files`, no upload/write path, **no download
   affordance** (D-STR9 — the bytes are RLS-gated and battery-proven
   server-side; a download UX is a separate reviewed slice), no realtime,
   no production, no service-role key, no real client/legal data.

## 5. What this approval does NOT authorize

- No other schema, policy, or RPC change beyond §3; **no write path** to
  files or storage objects (the slice is read-only; uploads and any
  storage write path stay §14-deferred — matrix §4/§6, D-STR9).
- No bucket beyond `matter-files`, no change to any existing bucket's
  `public` flag or policies.
- No change to the Flutter client (`lib/`) — the env-gated
  `SupabaseStorageGateway` swap + the new metadata surface is plan **T7**,
  a separate slice with its own gate.
- No battery run against the dev project (the harness hard-refuses the dev
  ref; the battery is ephemeral-only by design).
- No push, no production deployment, no service-role credentials, no real
  data beyond the demo seed of §3.
- The actual apply **execution** is a separate execution slice with its own
  evidence record; this record authorizes the apply decision only.

## 6. Owner sign-off

By signing below, the Project Owner authorizes the §3 apply against the
shared dev project (`eutmvevpskerzpqmwplv`), subject to the §4 execution
conditions and the §5 exclusions, with the rollback pairing standing by.
**Signature is valid only once the r1 rehearsal reports PASSED** (plan T4 —
the owner asserts it is; the evidence record
`docs/storage_rehearsal_evidence_r1_2026-08-08.md` is still ⏳ PENDING and
must fill + flip before the execution slice runs).

- **Project Owner:** github.com/mostafasayed118 — **date: 2026-08-08**
  — **approval wording (recorded from the pair-programming session, the
  documents/messages precedent):** "Apply approved — storage read slice
  (07_storage + policies/files + policies/storage_objects + demo
  files/objects referencing the applied demo matter ids), per this record
  §3–§5, with the §4 guardrails and rollback pairing."

> **Signed 2026-08-08** (wording recorded from the session). The execution
> record (`docs/storage_apply_execution_2026-08-08.md`) captures the actual
> run — **held until the r1 evidence lands (⏳ PENDING — §4 condition 1 +
> rollback_plan §2)**; on success, plan T6 (dated matrix §4 + §6 addendum)
> and T7 (client swap) follow.## 7. Ledger

- Approved 2026-08-08: this record's status is ✅ **APPLY APPROVED**
  (dated sign-off, §6 — recorded from the session); the plan's T5 row is
  annotated.
- The read-only baseline (§4.1) verified 2026-08-08: `files` 0 · bucket 0
  · public policies **8** (→ 9) · storage policies **0** (→ 1) · the four
  demo matter ids resolve (org `ef43087b-adf4-4480-9bb2-28c26f46ec71`) ·
  `storage.buckets.type` NOT NULL **with default** (the bare insert is
  valid) · `storage.foldername` present.
- **Execution HELD** on the r1 evidence (rehearsal record ⏳ PENDING — §4
  condition 1 + rollback_plan §2): the up sequence runs only after the r1
  record fills + flips to PASSED; the execution record then flips to
  APPLIED, and T6/T7/T8 follow with the roadmap §14/§13 + README/ledger
  lockstep on the merged tree.
- This session: docs-only — **no `lib/`/`test/` change, no README-count
  change, no dev-project change** (read-only probes only, 2026-08-08);
  `verify_ledger.sh` PASS 115; nothing pushed; branch
  `feat/storage-real-read` @ `41ce8ec` (+ this commit).
