# LegalHub — Realtime Apply Approval Decision Record (2026-08-08)

> **Record type:** The dated decision record that closes the apply-approval
> gate for the real-messages-rows (read) slice (plan
> `docs/realtime_real_data_plan_2026-08-08.md` T5), per the P2/P3 discipline
> (`docs/messages_apply_approval_2026-08-07.md` is the immediate precedent
> shape; `docs/documents_apply_approval_2026-08-07.md` and
> `docs/matters_apply_approval_2026-08-07.md` are the originals). This
> record, **once the r1 rehearsal is PASSED and this record is signed in
> §6**, is the owner's explicit authorization to apply the reviewed +
> rehearsed slice to the shared dev project, with the rollback pairing
> standing by.
>
> **Status: DRAFT — pending the owner's dated signature in §6.** The r1
> rehearsal is **PASSED 2026-08-08** (plan T4 — the first genuinely
> executed battery in the slice history: run locally on a Docker-backed
> scratch stack, `== summary: 70 passed, 0 warnings, 0 failures ==`, pins
> 11 tables / 11 RLS / 10 policies; evidence
> `docs/realtime_rehearsal_evidence_r1_2026-08-08.md`), so the apply gate
> is unblocked pending sign-off. On signature, this record authorizes the
> §3 up sequence against the shared dev project
> (`eutmvevpskerzpqmwplv`, `eu-central-1`) per the §4 execution conditions,
> with the rollback pairing standing by.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/realtime_real_data_plan_2026-08-08.md` (T5,
> D-RT8) · `docs/realtime_rls_gate_review_2026-08-08.md` (Q1–Q6, §6
> rollback) · `docs/realtime_rehearsal_evidence_r1_2026-08-08.md` (r1,
> PASSED `8204245`) · `docs/messages_apply_execution_2026-08-07.md` (the
> applied demo thread ids + demo accounts this seed references) ·
> `docs/rollback_plan.md` §1/§5 · `docs/permission_matrix.md` §4/§7 ·
> `supabase/README.md` · `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| §14 un-deferral gate (P0 closes + policy tests) | `docs/p0_closure_scope_2026-08-05.md` RATIFIED + `scripts/verify_policy_tests.sh` + the **matters + documents + messages precedents SHIPPED + applied** (the FK targets + assignment source) | ✅ Met — P0 RATIFIED 2026-08-05 · matters + documents + messages precedents SHIPPED + applied 2026-08-07 |
| RLS-gate design review | `docs/realtime_rls_gate_review_2026-08-08.md` (`790f6e7`) | ✅ Passed 2026-08-08 |
| Schema artifacts (rehearsal-ready) | `supabase/migrations/08_messages.sql` + `08_messages.down.sql` (`60198e2`) | ✅ Committed — NOT applied |
| Policy artifact | `supabase/policies/messages.sql` (`60198e2`) | ✅ Committed — NOT applied |
| Policy battery + harness | `supabase/tests/08_message_rls.sql`, `00_fixtures.sql`, `scripts/verify_policy_tests.sh` (`9f01870`, `f22e672`) | ✅ Committed; static `--check` PASS 333/0/0 |
| **Ephemeral rehearsal (r1)** | `docs/realtime_rehearsal_evidence_r1_2026-08-08.md` (`8204245`) | ✅ **PASSED 2026-08-08** — genuinely executed run (§4 evidence: 70/0/0) |
| **Apply approval (this record)** | this document | ⏳ **DRAFT — pending owner's dated sign-off (§6)** |
| Apply execution (dev project) | `docs/realtime_apply_execution_2026-08-08.md` | ⏳ pending approval + execution |

## 2. Gate criteria — what the r1 rehearsal must prove

Against the ephemeral project built from the committed files (r1, already
run, evidence `docs/realtime_rehearsal_evidence_r1_2026-08-08.md`), the
battery verified — mirroring the messages r1 five:

| # | Criterion | r1 evidence to capture | Verdict |
|---|---|---|---|
| 1 | `--apply` builds the slice cleanly (01…08, policies, RPCs) — `08_messages.sql` + `policies/messages.sql` applied on top of the already-applied `matters` + `documents` + `message_threads` tables | rehearsal §4 | ✅ **PASSED 2026-08-08** (37 files applied cleanly) |
| 2 | Structural pins hold on the applied posture | rehearsal §4: **11 tables / 11 RLS / 10 policies** / `messages` SELECT grant + anon absence / the `body` column present (the D-MSG1 consummation — **first content column**) but no attachment/read-receipt/`author_user_id` column (D-RT3/D-RT4) / the four prior slices' tables + policies still present | ✅ **PASSED 2026-08-08** |
| 3 | 00/01/02/03/04/05/06/07 regression batteries unaffected | rehearsal §4: fixtures + single-account bound + all seven prior batteries PASS (incl. the fixed 01.08 — see §6 finding 2) | ✅ **PASSED 2026-08-08** |
| 4 | `messages_select_assigned` enforces the matrix §4 contract | rehearsal §4: per-thread positives client-a 3 · attorney-a 6 · orphan 4 · org-role-alone 0 · **non-vacuous org-mismatch 0 (D-RT2 — the three-way org equality load-bearing)** · cross-org 0 · suspended 0 · owner 0 · anon denied | ✅ **PASSED 2026-08-08** |
| 5 | Mapping contract + teardown safety | rehearsal §4: `body` CHECK rejects empty · thread-delete cascades its messages (FK on delete cascade) · 08.12 mapping-consistency (live count = thread `message_count`) | ✅ **PASSED 2026-08-08** |

**Verdict (2026-08-08):** all five criteria **PASSED** on the genuinely
executed rehearsal run (evidence §4 — 70 passed / 0 warnings / 0
failures). The apply-approval gate is unblocked pending the owner's dated
signature in §6.

## 3. Decision (scope this record authorizes — once signed)

**APPLY APPROVED (on signature):** apply the reviewed + rehearsed realtime
slice to the shared dev project (`eutmvevpskerzpqmwplv`, `eu-central-1`) in
this order:

1. `supabase/migrations/08_messages.sql` — the `messages` table (the
   **D-MSG1 consummation**: `body text` with the non-empty CHECK — the
   first content column in the public schema; D-RT3), `organization_id`
   FK → `organizations` cascade (denormalized, mirrors threads/files),
   `thread_id` FK → the **applied** `message_threads` cascade,
   `author_display_name` (**stored display name — generic demo names only,
   D-RT4; never an identity claim, no real PII by convention**), `sent_at`
   default now(), org + thread indexes, the `(thread_id, sent_at)` fetch
   index, RLS enable, default-deny revoke, narrow `select` grant (Q5).
2. `supabase/policies/messages.sql` — `messages_select_assigned`
   (`is_active_member(organization_id)` AND exists through
   `message_threads t` **join** `matters m` with the **three-way org
   equality load-bearing** — `messages.organization_id = t.organization_id
   = m.organization_id` — AND assigned client/attorney = `auth.uid()`).
3. **Demo seed** — a small set of demo message rows referencing the
   **applied demo thread ids** on the dev project (resolved at apply time
   from the dev project's own `message_threads` rows — never guessed,
   never the rehearsal project's synthetic ids; the four applied demo
   thread ids recorded in
   `docs/messages_apply_execution_2026-08-07.md` §2.2 are
   `5d148bca-d784-4c21-81a1-1646c6754e2a` (acquisition review),
   `a8fd025e-d962-4573-9442-2d9f3a892376` (lease consultation),
   `d0904762-87dc-45ff-9480-845444511738` (procedural review),
   `4a8755b1-0260-4bcb-8544-9f019e658632` (family consultation)). Each
   seeded row carries `organization_id` = **its thread's org** (the D-RT2
   invariant applied at seed time), `author_display_name` = **generic demo
   names only** (D-RT4 — mirroring the thread participants; never the real
   account names/emails), `body` = **generic demo content** (no real
   client/legal copy, no PII), `sent_at` from the CHECK set. The exact rows
   + ids are recorded in the execution record.

plus the post-apply verification (structural subset + demo reads as assigned
roles) per §4 condition 5, and the execution evidence record
(`docs/realtime_apply_execution_2026-08-08.md`).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline probe (read-only):** confirm `messages` does not yet
   exist on the dev project, `message_threads` **does** exist with its four
   applied demo rows + `message_threads_select_assigned` (and `matters` +
   `documents` from the earlier un-deferrals), and note the current
   `pg_policies` count (**8** today per the messages execution record →
   **9** after apply; the storage slice remains HELD/unapplied owner-side,
   so the pinned 11/11/10 posture describes the full committed battery, not
   the dev project — the baseline probe re-establishes the exact number) —
   the up sequence runs against the same baseline the rehearsal proved.
2. **Verify, don't guess (demo seed):** thread ids come from the **dev
   project's own applied `message_threads` rows**; the seed never uses
   rehearsal synthetic ids, never touches non-demo threads, never uses real
   PII or real account identities in `author_display_name` or `body`
   (generic demo content only, D-RT4), and every seeded row's
   `organization_id` equals its thread's org (D-RT2).
3. **Rollback pairing standing by (rollback_plan §1/§5):**
   `08_messages.down.sql` (`drop table public.messages` — the policy dies
   with its table) + a targeted delete of the seeded demo rows (+ `git
   revert` of the policy commit per the RLS-gate review §6 convention) is
   ready before step 1; **any** trigger condition (a matrix negative row
   starts passing, cross-tenant data visible, a demo row lands on a real
   thread/account, a non-generic author/body appears) = immediate revert,
   never fix-forward.
4. **Per-step verification:** after each of the three steps, probe the
   applied state (table exists → policy present → seed rows scoped
   correctly: right org, right thread, generic author + body) with the
   observed output pasted verbatim into the execution record.
5. **Post-apply smoke (dev project):** the structural subset the rehearsal
   proved — table + RLS enabled + policy present + grants; then demo reads
   with role impersonation (`set local role authenticated` +
   `request.jwt.claims` via `supabase db query --linked`, the R1 pattern):
   the partner/attorney demo account (the **only** dev member, per the
   matters execution baseline) reads the messages on its assigned demo
   threads; the assigned demo clients read **0** because they hold no dev
   membership rows — the D-RT2 membership guard firing live, recorded as an
   honest expectation (the matters/documents/messages smoke precedent),
   never as a defect.
6. **No scope beyond the slice:** no other table/RPC/policy change, no
   write path (no send/reply/composer), no attachments/read-receipts, no
   live delivery (postgres_changes stays deferred — D-RT6), no
   storage/realtime, no production, no service-role key, no real
   client/legal data.

## 5. What this approval does NOT authorize

- No other schema, policy, or RPC change beyond §3; **no write path** to
  messages (the slice is read-only rows + bodies; **live delivery stays
  §14-deferred — D-RT6, matrix §4 body row**).
- No change to the Flutter client (`lib/`) — the env-gated `MessageGateway`
  `fetchMessages` swap is plan **T7**, a separate slice with its own gate.
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
Signature is valid — the r1 rehearsal reported PASSED on 2026-08-08 (plan
T4; evidence §4, criteria §2 all green — genuinely executed, 70/0/0).

- **Project Owner:** github.com/mostafasayed118 — **date: ______** —
  **approval wording (recorded from the pair-programming session):**
  "Apply approved — realtime read slice (08_messages + policies/messages +
  demo seed referencing the applied demo thread ids), per this record
  §3–§5, with the §4 guardrails and rollback pairing."

> **Pending signature.** On sign-off, the execution record
> (`docs/realtime_apply_execution_2026-08-08.md`) captures the actual run;
> on success, T6 (the dated matrix §4 addendum for the "Read a
> document/message body" row) precedes T7 (client swap) per the plan.

## 7. Ledger

- DRAFT 2026-08-08: r1 rehearsal PASSED (plan T4, evidence `8204245`);
  this record opened with the gate table showing the apply-approval row ⏳.
- Pending: owner's dated sign-off (§6) → flip status to ✅ APPLY APPROVED
  (dated) → execute per §4 → record execution evidence → T6 matrix addendum
  → T7 client swap → T8 lockstep + close (roadmap §14/§13 + README/ledger
  re-swept on the merged tree).
