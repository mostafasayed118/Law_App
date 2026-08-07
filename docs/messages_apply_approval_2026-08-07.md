# LegalHub — Messages Apply Approval Decision Record (2026-08-07)

> **Record type:** The dated decision record that closes the apply-approval
> gate for the real-messages read slice (plan
> `docs/messages_real_data_plan_2026-08-07.md` T5), per the P2/P3 discipline
> (`docs/documents_apply_approval_2026-08-07.md` is the immediate precedent
> shape; `docs/matters_apply_approval_2026-08-07.md` is the original). This
> record, **once the r1 rehearsal is PASSED and this record is signed in
> §6**, is the owner's explicit authorization to apply the reviewed +
> rehearsed slice to the shared dev project, with the rollback pairing
> standing by.
>
> **Status: APPLY APPROVED (2026-08-07).** The owner's dated sign-off in §6
> authorizes the §3 up sequence against the shared dev project
> (`eutmvevpskerzpqmwplv`, `eu-central-1`) per the §4 execution conditions,
> with the rollback pairing standing by. The ephemeral rehearsal r1
> (`docs/messages_rehearsal_evidence_r1_2026-08-07.md`) reported **PASSED
> 2026-08-07** (plan T4, owner's Docker host, matters r1 Path A precedent —
> §4 evidence). Nothing beyond the §3 scope; the §5 exclusions hold.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/messages_real_data_plan_2026-08-07.md` (T5,
> D-MSR8) · `docs/messages_rls_gate_review_2026-08-07.md` (Q1–Q6, §6
> rollback) · `docs/messages_rehearsal_evidence_r1_2026-08-07.md` (r1,
> PASSED `a37c6dc`) · `docs/documents_apply_execution_2026-08-07.md` (the
> applied demo matter ids + demo accounts this seed references) ·
> `docs/rollback_plan.md` §1/§5 · `docs/permission_matrix.md` §4/§7 ·
> `supabase/README.md` · `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| §14 un-deferral gate (P0 closes + policy tests) | `docs/p0_closure_scope_2026-08-05.md` RATIFIED + `scripts/verify_policy_tests.sh` + the **matters + documents precedents SHIPPED + applied** (the FK targets + assignment source) | ✅ Met — P0 RATIFIED 2026-08-05 · matters + documents precedents SHIPPED + applied 2026-08-07 |
| RLS-gate design review | `docs/messages_rls_gate_review_2026-08-07.md` (`443f42e`) | ✅ Passed 2026-08-07 |
| Schema artifacts (rehearsal-ready) | `supabase/migrations/06_message_threads.sql` + `06_message_threads.down.sql` (`5a506ca`) | ✅ Committed — NOT applied |
| Policy artifact | `supabase/policies/message_threads.sql` (`5a506ca`) | ✅ Committed — NOT applied |
| Policy battery + harness | `supabase/tests/06_message_rls.sql`, `00_fixtures.sql`, `scripts/verify_policy_tests.sh` (`0ed14c7`, `4905697`) | ✅ Committed; static `--check` PASS 37/0/0 |
| **Ephemeral rehearsal (r1)** | `docs/messages_rehearsal_evidence_r1_2026-08-07.md` (`a37c6dc`) | ✅ **PASSED 2026-08-07** — owner's Path A run (§4 evidence) |
| **Apply approval (this record)** | this document | ✅ **APPROVED 2026-08-07** (owner's dated sign-off, §6) |
| Apply execution (dev project) | `docs/messages_apply_execution_2026-08-07.md` | ✅ **APPLIED 2026-08-07** — baseline probe → 06_message_threads → policy → demo seed → post-apply smoke all verified; rollback pairing standing by |

## 2. Gate criteria — what the r1 rehearsal must prove

Against the ephemeral project built from the committed files (r1, already
run, evidence `docs/messages_rehearsal_evidence_r1_2026-08-07.md`), the
battery verified — mirroring the documents r1 five:

| # | Criterion | r1 evidence to capture | Verdict |
|---|---|---|---|
| 1 | `--apply` builds the slice cleanly (01, 02, 04, 05, **06**, policies, RPCs) — `06_message_threads.sql` + `policies/message_threads.sql` applied on top of the already-applied `matters` + `documents` tables | rehearsal §4 | ✅ **PASSED 2026-08-07** |
| 2 | Structural pins hold on the applied posture | rehearsal §4: **9 tables / 9 RLS / 8 policies** / threads SELECT grant + anon absence / **no body/preview/attachment/sender column** (metadata-only, D-MSG1) / matters + documents + their policies still present | ✅ **PASSED 2026-08-07** |
| 3 | 00/01/02/03/04/**05** regression batteries unaffected | rehearsal §4: fixtures + single-account bound + 01/02/03 + the six-matter + six-document batteries all PASS | ✅ **PASSED 2026-08-07** |
| 4 | `message_threads_select_assigned` enforces the matrix §4 contract | rehearsal §4: client-a 2 · partner-a 3 · orphan 1 · org-role-alone 0 · **org-mismatch 0 (non-vacuous — D-MSR2)** · cross-org 0 · suspended 0 · owner 0 · anon denied | ✅ **PASSED 2026-08-07** |
| 5 | Mapping contract + teardown safety | rehearsal §4: `message_count` CHECK rejects a negative count · matter-delete cascades its threads (FK on delete cascade) | ✅ **PASSED 2026-08-07** |

**Verdict (2026-08-07):** all five criteria **PASSED** on the owner's Path A
rehearsal run (evidence §4 — rows green, 0 failures). The apply-approval
gate is unblocked pending the owner's dated signature in §6.

## 3. Decision (scope this record authorizes — once signed)

**APPLY APPROVED (on signature):** apply the reviewed + rehearsed messages
slice to the shared dev project (`eutmvevpskerzpqmwplv`, `eu-central-1`) in
this order:

1. `supabase/migrations/06_message_threads.sql` — the `message_threads`
   table (**thread metadata only**, D-MSG1: **no body/preview/attachment/
   sender column**), `organization_id` FK → `organizations` cascade,
   `matter_id` FK → the **applied** `matters` cascade, `title`,
   **`participants text[]`** (generic demo display names, D-MSR3/D-MSG4 —
   never an identity claim, no real PII by convention), `message_count`
   with the client-`MessageThread.messageCount` CHECK (`>= 0`),
   `last_activity_at`, org + matter indexes, RLS enable, default-deny
   revoke, narrow `select` grant.
2. `supabase/policies/message_threads.sql` — `message_threads_select_assigned`
   (`is_active_member(organization_id)` AND exists on the matter row with
   the **org-mismatch clause** `m.organization_id = message_threads.organization_id`
   AND assigned client/attorney = `auth.uid()`).
3. **Demo seed** — a small set of demo thread rows (4) referencing the
   **applied demo matter ids** on the dev project (resolved at apply time
   from the dev project's own `matters` rows — never guessed, never the
   rehearsal project's synthetic `40000000-…` ids; the four applied demo
   matter ids recorded in `docs/matters_apply_execution_2026-08-07.md` §2.2
   are `a6715e17-…`, `d155dc92-…`, `4f4a935f-…`, `575391b6-…`). Each seeded
   row carries `organization_id` = **its matter's org** (the D-MSR2
   invariant applied at seed time), `participants` = **generic demo names
   only** (D-MSG4 — never the real account names/emails), `message_count`
   from the CHECK set, and a generic demo title (no real client/legal copy,
   no PII). The exact rows + ids are recorded in the execution record.

plus the post-apply verification (structural subset + demo reads as assigned
roles) per §4 condition 5, and the execution evidence record
(`docs/messages_apply_execution_2026-08-07.md`).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline probe (read-only):** confirm `message_threads` does
   not yet exist on the dev project, `matters` **does** exist with its four
   applied demo rows + `matters_select_assigned` (and `documents` +
   `documents_select_assigned` from the second un-deferral), and note the
   current `pg_policies` count (**7** today → **8** after apply) — the up
   sequence runs against the same baseline the rehearsal proved.
2. **Verify, don't guess (demo seed):** matter ids come from the **dev
   project's own applied `matters` rows**; the seed never uses rehearsal
   synthetic ids, never touches non-demo matters, never uses real PII or
   real account identities in `participants` (generic demo names only,
   D-MSG4), and every seeded row's `organization_id` equals its matter's
   org (D-MSR2).
3. **Rollback pairing standing by (rollback_plan §1/§5):**
   `06_message_threads.down.sql` (`drop table public.message_threads` — the
   policy dies with its table) + a targeted delete of the seeded demo rows
   (+ `git revert` of the policy commit per the RLS-gate review §6
   convention) is ready before step 1; **any** trigger condition (a matrix
   negative row starts passing, cross-tenant data visible, a demo row lands
   on a real matter/account, a non-generic participant name appears) =
   immediate revert, never fix-forward.
4. **Per-step verification:** after each of the three steps, probe the
   applied state (table exists → policy present → seed rows scoped
   correctly: right org, right matter, generic participants) with the
   observed output pasted verbatim into the execution record.
5. **Post-apply smoke (dev project):** the structural subset the rehearsal
   proved — table + RLS enabled + policy present + grants; then demo reads
   with role impersonation (`set local role authenticated` +
   `request.jwt.claims` via `supabase db query --linked`, the R1 pattern):
   the partner/attorney demo account (the **only** dev member, per the
   matters execution baseline) reads the threads on its assigned demo
   matters; the assigned demo clients read **0** because they hold no dev
   membership rows — the D-MSR2 membership guard firing live, recorded as
   an honest expectation (the matters/documents smoke precedent), never as
   a defect.
6. **No scope beyond the slice:** no other table/RPC/policy change, no
   body/individual-message storage, no write path, no email, no
   storage/realtime, no production, no service-role key, no real
   client/legal data.

## 5. What this approval does NOT authorize

- No other schema, policy, or RPC change beyond §3; **no write path** to
  message threads (the slice is read-only metadata; individual message
  rows/bodies and any delivery/storage path stay §14-deferred — D-MSG1,
  matrix §4 body row).
- No change to the Flutter client (`lib/`) — the env-gated `MessageGateway`
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
Signature is valid — the r1 rehearsal reported PASSED on 2026-08-07
(plan T4; evidence §4, criteria §2 all green).

- **Project Owner:** github.com/mostafasayed118 — **date: 2026-08-07**
  — **approval wording (recorded from the pair-programming session):**
  "Apply approved — messages read slice (06_message_threads + policy +
  demo seed referencing the applied demo matter ids), per this record
  §3–§5, with the §4 guardrails and rollback pairing."

> **Signed 2026-08-07.** The execution record
> (`docs/messages_apply_execution_2026-08-07.md`) captures the actual run;
> on success, plan T7 (client swap) follows (T6 — the dated matrix §4
> addendum for the "View a message thread (metadata)" row — is a separate
> commit).

## 7. Ledger

- Signed 2026-08-07: this record's status is ✅ APPLY APPROVED (dated); the
  plan's T5 row annotated.
- Executed 2026-08-07: the execution record
  (`docs/messages_apply_execution_2026-08-07.md`) is APPLIED — baseline
  probe → 06_message_threads → policy → demo seed → post-apply smoke all
  verified on the dev project; T6 (matrix addendum) and T7 (client swap)
  follow, and the roadmap §14/§13 + README/ledger lockstep is re-run on the
  merged tree (T8).
