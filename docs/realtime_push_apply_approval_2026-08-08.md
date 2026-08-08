# LegalHub — Realtime Push Apply Approval Decision Record (2026-08-08)

> **Record type:** The dated decision record that closes the apply-approval
> gate for the realtime live-delivery (push) slice (plan
> `docs/realtime_push_real_data_plan_2026-08-08.md` T5), per the P2/P3
> discipline (`docs/realtime_apply_approval_2026-08-08.md` is the immediate
> precedent shape — the read half of this same slice; the
> matters/documents/messages records are the originals). This record,
> **once the r1 rehearsal is PASSED and this record is signed in §6**, is
> the owner's explicit authorization to apply the reviewed + rehearsed
> slice to the shared dev project, with the rollback pairing standing by.
>
> **Status: APPLY APPROVED (2026-08-08).** The owner's dated sign-off in §6
> authorizes the §3 up sequence against the shared dev project
> (`eutmvevpskerzpqmwplv`, `eu-central-1`) per the §4 execution conditions,
> with the rollback pairing standing by. The ephemeral rehearsal r1
> (`docs/realtime_push_rehearsal_evidence_r1_2026-08-08.md`) reported
> **PASSED 2026-08-08** (plan T4 — genuinely executed battery, 72/0/0; §4
> evidence), and the T2 artifacts were validated live on the rehearsal host
> (up/down/up publication round-trip + role-impersonated INSERT tests).
> Nothing beyond the §3 scope; the §5 exclusions hold.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/realtime_push_real_data_plan_2026-08-08.md` (T5,
> D-LV1/D-LV2/D-LV6) · `docs/realtime_push_gate_review_2026-08-08.md`
> (Q1–Q6, §6 rollback) · `docs/realtime_push_rehearsal_evidence_r1_2026-08-08.md`
> (r1, PASSED `51532fd`) · `docs/realtime_apply_execution_2026-08-08.md`
> (the applied demo thread ids + the dev partner account this demo send
> references) · `docs/rollback_plan.md` §1/§5 · `docs/permission_matrix.md`
> §4/§6/§7 · `supabase/README.md` · `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| §14 un-deferral gate (P0 closes + policy tests) | `docs/p0_closure_scope_2026-08-05.md` RATIFIED + `scripts/verify_policy_tests.sh` + the **six prior per-feature slices SHIPPED + applied** (the messages table + policy this slice extends already live) | ✅ Met — P0 RATIFIED 2026-08-05 · matters/documents/messages/storage/audit/realtime-read SHIPPED; realtime-read applied 2026-08-08 (10 tables / 10 RLS / 9 policies live) |
| Mechanism design review | `docs/realtime_push_gate_review_2026-08-08.md` (`af1715c`) | ✅ Passed 2026-08-08 |
| Schema artifact (rehearsal-ready) | `supabase/migrations/09_realtime_push.sql` + `09_realtime_push.down.sql` (`f1d7903`) | ✅ Committed — NOT applied |
| Policy artifact | `supabase/policies/messages_insert.sql` (`f1d7903`) | ✅ Committed — NOT applied |
| Policy battery + harness | `supabase/tests/09_realtime_push.sql`, `00_fixtures.sql`, `scripts/verify_policy_tests.sh` (`6302bdc`) | ✅ Committed; static `--check` PASS 335/0/0 · selftest 6/6 |
| **Ephemeral rehearsal (r1)** | `docs/realtime_push_rehearsal_evidence_r1_2026-08-08.md` (`51532fd`) | ✅ **PASSED 2026-08-08** — genuinely executed run (§4 evidence: 72/0/0) |
| **Apply approval (this record)** | this document | ✅ **APPROVED 2026-08-08** (owner's dated sign-off, §6) |
| Apply execution (dev project) | `docs/realtime_push_apply_execution_2026-08-08.md` | ⏳ pending execution (this record authorizes it) |

## 2. Gate criteria — what the r1 rehearsal must prove

Against the ephemeral project built from the committed files (r1, already
run, evidence `docs/realtime_push_rehearsal_evidence_r1_2026-08-08.md`),
the battery verified — mirroring the read-slice five:

| # | Criterion | r1 evidence to capture | Verdict |
|---|---|---|---|
| 1 | The slice builds cleanly — `09_realtime_push.sql` applies (publication membership) and `policies/messages_insert.sql` applies (grant + policy) on top of the already-applied `messages` table | T2 live round-trip (publication for messages **1 → 0 → 1**, exactly one table, nothing else) + T3 battery | ✅ **PASSED 2026-08-08** (genuinely executed) |
| 2 | Structural pins hold on the applied posture | rehearsal §4: **11 tables / 11 RLS / 11 policies** (10→11 — the INSERT policy) / `messages` SELECT **+ INSERT** grants present, anon absent / forward pin re-scoped: **live delivery PRESENT** (`pg_publication_tables` for messages = 1) **+ exactly one publication row** | ✅ **PASSED 2026-08-08** |
| 3 | 00/01/02/03/04/05/06/07/08 regression batteries unaffected | rehearsal §4: fixtures + single-account bound + all prior batteries PASS (incl. the fixed 01.08) | ✅ **PASSED 2026-08-08** |
| 4 | `messages_insert_assigned` enforces the matrix §4 write contract | rehearsal §4: assigned attorney + client positives persist (rolled back) · org-role-alone / cross-org / suspended / owner / anon each denied (live RLS-violation catch) · empty-body CHECK (09.10) | ✅ **PASSED 2026-08-08** |
| 5 | Delivery equivalence — the matrix §6 row | rehearsal §4: after an insert, the assigned reader sees the delivered row (09.11), suspended / cross-org / owner see 0 (09.12) — the read gate IS the delivery gate. **Honest limit:** the RLS proxy, not a live websocket round-trip (that is T7, D-LV4) | ✅ **PASSED 2026-08-08** |

**Verdict (2026-08-08):** all five criteria **PASSED** on the genuinely
executed rehearsal run (evidence §4 — 72 passed / 0 warnings / 0
failures). The apply-approval gate is unblocked pending the owner's dated
signature in §6.

## 3. Decision (scope this record authorizes — once signed)

**APPLY APPROVED (on signature):** apply the reviewed + rehearsed
realtime-push slice to the shared dev project (`eutmvevpskerzpqmwplv`,
`eu-central-1`) in this order:

1. `supabase/migrations/09_realtime_push.sql` — **publication membership
   only** (D-LV2): add the `messages` table to the `supabase_realtime`
   publication (the publication exists by default; the guarded
   `do`-block create is a no-op on a project that has it). No new table,
   no new columns, no RLS change. This is the **enablement** layer —
   delivery authorization is Realtime RLS (the already-applied
   `messages_select_assigned` SELECT policy, D-LV3).
2. `supabase/policies/messages_insert.sql` — the **write surface** (D-LV1):
   `grant insert on public.messages to authenticated;` (08 granted SELECT
   only — the live finding that a policy without a grant never fires)
   + `messages_insert_assigned` — `is_active_member(organization_id)` AND
   an exists through `message_threads t` **join** `matters m` with the
   **three-way org equality load-bearing** (`messages.organization_id =
   t.organization_id = m.organization_id`) AND assigned client/attorney =
   `auth.uid()`. Insert-only — no UPDATE/DELETE policy (no edit/delete/
   attachments/read-receipts).
3. **Demo send (D-LV6 — the first live INSERT in the slice history):** one
   message row inserted **as the assigned partner**, exercising
   `messages_insert_assigned` live: `set local role authenticated` +
   `request.jwt.claims` sub = the dev partner account
   `8fa94af0-7390-4f7a-988a-3965f7da04de` (active, the only dev member,
   per the realtime-read execution record), on the **acquisition-review
   demo thread** `5d148bca-d784-4c21-81a1-1646c6754e2a` (the applied demo
   thread where the partner is the assigned attorney — count 1), with
   `organization_id` = its thread's org `ef43087b-adf4-4480-9bb2-28c26f46ec71`
   (the D-RT2 invariant), `author_display_name` = **generic demo name**
   (`Demo attorney`), `body` = **generic demo content** (no real PII, no
   real client/legal copy). The observed INSERT output + the resulting row
   id are recorded verbatim in the execution record.

plus the post-apply verification (structural subset + the delivery-gate
read as the assigned partner) per §4 condition 5, and the execution
evidence record (`docs/realtime_push_apply_execution_2026-08-08.md`).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline probe (read-only):** confirm the dev project's live
   state before the up sequence — the `messages` table **exists** (the read
   slice applied it) with its 10 demo rows, the four applied demo threads
   (`5d148bca-…` / `a8fd025e-…` / `d0904762-…` / `4a8755b1-…`, org
   `ef43087b-…`), the current `pg_policies` count (**9** today per the
   realtime-read execution record → **10** after step 2), and the current
   `pg_publication_tables` state for `supabase_realtime` (**expected 0** —
   messages not yet published; the hosted project ships an empty
   `supabase_realtime` by default). **Trigger condition:** if the
   publication already holds rows (any table, incl. messages), STOP and
   record — the D-LV2 exactly-messages invariant must be established by
   this apply, never assumed. The up sequence runs against the same
   baseline the rehearsal proved.
2. **Verify, don't guess (demo send):** the target thread id comes from the
   **dev project's own applied `message_threads` rows** (verify the
   acquisition thread's org + the partner's assignment before inserting —
   never guessed, never the rehearsal project's synthetic ids); the send
   uses generic demo author/body (D-RT4, no real PII); the inserted row's
   `organization_id` equals its thread's org (D-RT2).
3. **Rollback pairing standing by (rollback_plan §1/§5):**
   `09_realtime_push.down.sql` (drop the `messages` membership — the
   publication returns to its pre-apply state) + a targeted delete of the
   demo-sent row + `git revert` of the policy commit (per the gate-review
   §6 convention) is ready before step 1; **any** trigger condition (a
   matrix negative row starts passing, cross-tenant data visible, the demo
   row lands on a real thread/account, a non-generic author/body appears,
   the publication gains anything beyond `messages`) = immediate revert,
   never fix-forward.
4. **Per-step verification:** after each of the three steps, probe the
   applied state (publication membership exactly `messages` → grant +
   policy present → the demo row scoped correctly: right org, right thread,
   generic author + body) with the observed output pasted verbatim into the
   execution record.
5. **Post-apply smoke (dev project):** the structural subset the rehearsal
   proved — `pg_publication_tables` for `supabase_realtime` = **1** (messages
   only) · `pg_policies` = **10** · `messages_insert_assigned` present ·
   `authenticated` INSERT grant true, anon false; then the **delivery-gate
   read** with role impersonation (the R1 pattern via `supabase db query
   --linked`): the partner (`sub=8fa94af0-…`) reads the demo-sent row on
   its assigned acquisition thread (the delivered-row positive); the
   demo **clients** read 0 because they hold no dev membership rows — the
   D-RT2 membership guard firing live, recorded as an honest expectation
   (the realtime-read smoke precedent), never as a defect. No live
   websocket delivery is claimed in the smoke (that is the env-gated client
   slice, T7).
6. **No scope beyond the slice:** no other table/RPC/policy change, no
   other table added to the publication, no message edit/delete/
   attachments/read-receipts, no Broadcast/Presence channels, no storage/
   realtime changes, no production, no service-role key, no real
   client/legal data.

## 5. What this approval does NOT authorize

- No other schema, policy, RPC, or publication change beyond §3; **no
  message edit/delete/attachments/read-receipts** (insert-only write path,
  D-LV1); **Broadcast/Presence stays out of scope**; **billing (D-09) and
  AI stay §14-deferred**.
- No change to the Flutter client (`lib/`) — the env-gated subscription +
  composer swap is plan **T7** (D-LV1/D-LV4), a separate slice with its own
  gate.
- No battery run against the dev project (the harness hard-refuses the dev
  ref; the battery is ephemeral-only by design).
- No push, no production deployment, no service-role credentials, no real
  data beyond the demo send of §3.
- The actual apply **execution** is a separate execution slice with its own
  evidence record; this record authorizes the apply decision only.

## 6. Owner sign-off

By signing below, the Project Owner authorizes the §3 apply against the
shared dev project (`eutmvevpskerzpqmwplv`), subject to the §4 execution
conditions and the §5 exclusions, with the rollback pairing standing by.
Signature is valid — the r1 rehearsal reported PASSED on 2026-08-08 (plan
T4; evidence §4, criteria §2 all green — genuinely executed, 72/0/0).

- **Project Owner:** github.com/mostafasayed118 — **date: 2026-08-08**
  — **approval wording (recorded from the pair-programming session):**
  "Apply approved — realtime live-delivery slice (09_realtime_push +
  policies/messages_insert + the demo send as the assigned partner on the
  acquisition demo thread), per this record §3–§5, with the §4 guardrails
  and rollback pairing."

> **Signed 2026-08-08.** The execution record
> (`docs/realtime_push_apply_execution_2026-08-08.md`) captures the actual
> run; on success, T6 (the dated matrix §4 write-row + §6 delivery-row
> addenda) precedes T7 (client swap) per the plan.

## 7. Ledger

- Signed 2026-08-08: this record's status is ✅ APPLY APPROVED (dated);
  the plan's T5 row annotated.
- Pending: owner's dated sign-off (§6) → apply execution
  (`docs/realtime_push_apply_execution_2026-08-08.md`) captures the actual
  run per §4; on success, T6 (matrix addenda) and T7 (client swap) follow,
  and the roadmap §14/§13 + README/ledger lockstep is re-run on the merged
  tree (T8).
