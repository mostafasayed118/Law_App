# LegalHub — Documents Apply Approval Decision Record (2026-08-07)

> **Record type:** The dated decision record that closes the apply-approval
> gate for the real-documents read slice (plan
> `docs/documents_real_data_plan_2026-08-07.md` T5), per the P2/P3 discipline
> (`docs/matters_apply_approval_2026-08-07.md` is the immediate precedent
> shape; `docs/p2_apply_approval_2026-08-01.md` is the original). This record,
> **once the r1 rehearsal is PASSED and this record is signed in §6**, is the
> owner's explicit authorization to apply the reviewed + rehearsed slice to
> the shared dev project, with the rollback pairing standing by.
>
> **Status: DRAFT (2026-08-07).** Awaiting two preconditions before the
> owner's dated sign-off flips this to APPLY APPROVED: (a) the **ephemeral
> rehearsal r1** (`docs/documents_rehearsal_evidence_r1_2026-08-07.md`) must
> report PASSED (plan T4, owner's Docker host, matters r1 Path A precedent),
> and (b) the owner's dated sign-off in §6.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/documents_real_data_plan_2026-08-07.md` (T5) ·
> `docs/documents_rls_gate_review_2026-08-07.md` (Q1–Q6, §6 rollback) ·
> `docs/documents_rehearsal_evidence_r1_2026-08-07.md` (r1, once executed) ·
> `docs/matters_apply_execution_2026-08-07.md` (applied demo matter ids this
> seed references) · `docs/rollback_plan.md` §1/§5 ·
> `docs/permission_matrix.md` §4/§7 · `supabase/README.md` ·
> `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| §14 un-deferral gate (P0 closes + policy tests) | `docs/p0_closure_scope_2026-08-05.md` RATIFIED + `scripts/verify_policy_tests.sh` + the **matters precedent SHIPPED + applied** (the FK target + assignment source) | ✅ Met 2026-08-07 |
| RLS-gate design review | `docs/documents_rls_gate_review_2026-08-07.md` (`77f14fb`) | ✅ Passed 2026-08-07 |
| Schema artifacts (rehearsal-ready) | `supabase/migrations/05_documents.sql` + `05_documents.down.sql` (`f8cc6c6`, `7c8ab79`) | ✅ Committed — NOT applied |
| Policy artifact | `supabase/policies/documents.sql` (`f8cc6c6`) | ✅ Committed — NOT applied |
| Policy battery + harness | `supabase/tests/05_document_rls.sql`, `00_fixtures.sql`, `scripts/verify_policy_tests.sh` (`b5bf0b2`) | ✅ Committed; static `--check` PASS 31/0/0 |
| **Ephemeral rehearsal (r1)** | `docs/documents_rehearsal_evidence_r1_2026-08-07.md` (pending) | ⏳ **Pending** — owner's Docker host (matters r1 Path A precedent) |
| **Apply approval (this record)** | this document | ⏳ **DRAFT** — awaits r1 PASSED + owner's dated sign-off (§6) |
| Apply execution (dev project) | `docs/documents_apply_execution_2026-08-07.md` (pending) | ⏳ Pending — runs only after this record is APPLY APPROVED |

## 2. Gate criteria — what the r1 rehearsal must prove

Against the ephemeral project built from the committed files (r1, once run,
evidence `docs/documents_rehearsal_evidence_r1_2026-08-07.md`), the battery
must verify — mirroring the matters r1 five:

| # | Criterion | r1 evidence to capture | Verdict |
|---|---|---|---|
| 1 | `--apply` builds the slice cleanly (01, 02, 04, **05**, policies, RPCs) — `05_documents.sql` + `policies/documents.sql` applied on top of the already-applied `matters` table | rehearsal §4 | ⏳ pending |
| 2 | Structural pins hold on the applied posture | rehearsal §4: **8 tables / 7 RLS / 7 policies** / documents SELECT grant + anon absence / **no body or content column** (metadata-only, D-V1) / matters + its policies still present | ⏳ pending |
| 3 | 00/01/02/03/**04** regression batteries unaffected | rehearsal §4: fixtures + single-account bound + 01/02/03 + the six-matter battery all PASS | ⏳ pending |
| 4 | `documents_select_assigned` enforces the matrix §4 contract | rehearsal §4: client-a 2 · partner-a 3 · orphan 1 · org-role-alone 0 · **org-mismatch 0** · cross-org 0 · suspended 0 · owner 0 · anon denied | ⏳ pending |
| 5 | Mapping contract + teardown safety | rehearsal §4: `document_type` CHECK rejects `'tax'` · matter-delete cascades its documents (FK on delete cascade) | ⏳ pending |

**Verdict (pending):** all five criteria are contractually specified above and
each has a committed battery row; the r1 rehearsal is the first real
execution. Once r1 reports PASSED with these rows green, the apply-approval
gate is unblocked pending the owner's signature in §6.

## 3. Decision (scope this record authorizes — once signed)

**APPLY APPROVED (pending §6):** apply the reviewed + rehearsed documents
slice to the shared dev project (`eutmvevpskerzpqmwplv`, `eu-central-1`) in
this order:

1. `supabase/migrations/05_documents.sql` — the `documents` table
   (metadata-only, D-V1: **no body/content/size/url column**), `organization_id`
   FK → `organizations` cascade, `matter_id` FK → the **applied** `matters`
   cascade, `document_type` with the client-`DocumentType` CHECK
   (`contract`/`brief`/`evidence`/`correspondence`), org + matter indexes,
   RLS enable, default-deny revoke, narrow `select` grant.
2. `supabase/policies/documents.sql` — `documents_select_assigned`
   (`is_active_member(organization_id)` AND exists on the matter row with
   the **org-mismatch clause** `m.organization_id = documents.organization_id`
   AND assigned client/attorney = `auth.uid()`).
3. **Demo seed** — a small set of demo document rows (3–4) referencing the
   **applied demo matter ids** on the dev project (resolved at apply time
   from the dev project's own `matters` rows — never guessed, never the
   rehearsal project's synthetic `40000000-…` ids; the four applied demo
   matter ids recorded in `docs/matters_apply_execution_2026-08-07.md` §2.2
   are `a6715e17-…`, `d155dc92-…`, `4f4a935f-…`, `575391b6-…`). Each seeded
   row carries `organization_id` = **its matter's org** (the D-DR2 invariant
   applied at seed time), `document_type` from the CHECK set, and a generic
   demo title (D-V4 — no real client/legal copy, no PII). The exact rows +
   ids are recorded in the execution record.

plus the post-apply verification (structural subset + demo reads as assigned
roles) per §4 condition 5, and the execution evidence record
(`docs/documents_apply_execution_2026-08-07.md`).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline probe (read-only):** confirm `documents` does not yet
   exist on the dev project, `matters` **does** exist with its four applied
   demo rows + `matters_select_assigned`, and note the current `pg_policies`
   count (**6** today → **7** after apply) — the up sequence runs against the
   same baseline the rehearsal proved.
2. **Verify, don't guess (demo seed):** matter ids come from the **dev
   project's own applied `matters` rows**; the seed never uses rehearsal
   synthetic ids, never touches non-demo matters, never uses real PII, and
   every seeded row's `organization_id` equals its matter's org (D-DR2).
3. **Rollback pairing standing by (rollback_plan §1/§5):**
   `05_documents.down.sql` (`drop table public.documents` — the policy dies
   with its table) + a targeted delete of the seeded demo rows is ready
   before step 1; **any** trigger condition (a matrix negative row starts
   passing, cross-tenant data visible, a demo row lands on a real matter/
   account) = immediate revert, never fix-forward.
4. **Per-step verification:** after each of the three steps, probe the
   applied state (table exists → policy present → seed rows scoped
   correctly: right org, right matter, right type) with the observed output
   pasted verbatim into the execution record.
5. **Post-apply smoke (dev project):** the structural subset the rehearsal
   proved — table + RLS enabled + policy present + grants; then demo reads
   with role impersonation (`set local role authenticated` +
   `request.jwt.claims` via `supabase db query --linked`, the R1 pattern):
   the partner/attorney demo account (the **only** dev member, per the
   matters execution baseline) reads the documents on its assigned demo
   matters; the assigned demo clients read **0** because they hold no dev
   membership rows — the D-MR1 membership guard firing live, recorded as an
   honest expectation (the matters smoke precedent), never as a defect.
6. **No scope beyond the slice:** no other table/RPC/policy change, no body/
   content storage, no write path, no email, no storage/realtime, no
   production, no service-role key, no real client/legal data.

## 5. What this approval does NOT authorize

- No other schema, policy, or RPC change beyond §3; **no write path** to
  documents (the slice is read-only metadata; the body column and any
  upload/storage path stay §14-deferred — D-V1, matrix §4 body row).
- No change to the Flutter client (`lib/`) — the env-gated `DocumentGateway`
  swap is plan **T7**, a separate slice with its own gate.
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
Signature is valid only after r1 (plan T4) reports PASSED per §2.

- **Project Owner:** github.com/mostafasayed118 — **date: \_\_\_\_** —
  **approval wording (recorded from the pair-programming session):**
  "Apply approved — documents read slice (05_documents + policy + demo
  seed referencing the applied demo matter ids), per this record §3–§5,
  with the §4 guardrails and rollback pairing."

> **Signed \_\_\_\_\_\_\_\_.** The execution record
> (`docs/documents_apply_execution_2026-08-07.md`) captures the actual run;
> on success, plan T7 (client swap) follows (T6 — the dated matrix §4
> addendum for the "View a document (metadata)" row — is a separate commit).

## 7. Ledger

- On signature: this record's status flips ⏳ DRAFT → ✅ APPLY APPROVED
  (dated); the plan's T5 row updates.
- On apply success: the execution record (`docs/documents_apply_execution_2026-08-07.md`)
  is written from the actual run, T6 (matrix addendum) and T7 (client swap)
  follow, and the roadmap §14/§13 + README/ledger lockstep is re-run on the
  merged tree (T8).
