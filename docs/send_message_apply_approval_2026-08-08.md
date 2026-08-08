# LegalHub — Send-Message RPC Apply Approval Decision Record (2026-08-08)

> **Record type:** The dated decision record that closes the apply-approval
> gate for the **audited `send_message` RPC** slice (plan
> `docs/send_message_rpc_plan_2026-08-08.md` T5), per the P2/P3 discipline
> (`docs/realtime_push_apply_approval_2026-08-08.md` is the immediate
> precedent shape — the write half of the messaging path; the
> matters/documents/messages/realtime records are the originals). This
> record, **once the r1 rehearsal is PASSED and this record is signed in
> §6**, is the owner's explicit authorization to apply the reviewed +
> rehearsed slice to the shared dev project, with the rollback pairing
> standing by.
>
> **Status: APPLY APPROVED 2026-08-08 — the owner's dated sign-off is
> recorded in §6.** The ephemeral rehearsal r1
> (`docs/send_message_rehearsal_evidence_r1_2026-08-08.md`) reported
> **PASSED 2026-08-08** (plan T4 — genuinely executed battery, 74/0/0; §4
> evidence), and the T2 artifact was validated live on the rehearsal host
> (apply → 9 role-impersonated checks as designed → drop round-trip → the
> D-SM3 revocation state verified). Nothing beyond the §3 scope; the §5
> exclusions hold.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/send_message_rpc_plan_2026-08-08.md` (T5,
> D-SM1..D-SM3) · `docs/send_message_gate_review_2026-08-08.md` (Q1–Q6,
> §6 rollback) · `docs/send_message_rehearsal_evidence_r1_2026-08-08.md`
> (r1, PASSED `8df7e47`) · `docs/realtime_push_apply_execution_2026-08-08.md`
> (the applied demo thread + the dev partner account this demo send
> references) · `docs/rollback_plan.md` §1/§5 · `docs/permission_matrix.md`
> §4/§7 · `supabase/README.md` · `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| §14 un-deferral gate (P0 closes + policy tests) | `docs/p0_closure_scope_2026-08-05.md` RATIFIED + `scripts/verify_policy_tests.sh` + the **seven prior per-feature slices SHIPPED** (messages table + policies + publication live) | ✅ Met — P0 RATIFIED 2026-08-05 · matters/documents/messages/storage/audit/realtime-read/realtime-push SHIPPED; realtime-push applied 2026-08-08 (11 tables / 11 RLS / 10 policies / publication exactly messages live) |
| Mechanism design review | `docs/send_message_gate_review_2026-08-08.md` (`7759181`) | ✅ Reviewed 2026-08-08 (Q1–Q6, D-SM1..D-SM3 ratified) |
| RPC artifact (rehearsal-ready) | `supabase/rpc/send_message.sql` + `_down.sql` entry (`60dae71`) | ✅ Committed — NOT applied; live-validated on the rehearsal host |
| Battery + harness | `supabase/tests/10_send_message_rls.sql` + the 09 re-scope + `scripts/verify_policy_tests.sh` (`b013ee5`) | ✅ Committed; static `--check` PASS 337/0/0 · selftest 6/6 |
| **Ephemeral rehearsal (r1)** | `docs/send_message_rehearsal_evidence_r1_2026-08-08.md` (`8df7e47`) | ✅ **PASSED 2026-08-08** — genuinely executed run (§4 evidence: 74/0/0) |
| **Apply approval (this record)** | this document | ⏳ **DRAFT** — awaiting the owner's dated sign-off (§6) |
| Apply execution (dev project) | `docs/send_message_apply_execution_2026-08-08.md` | ⏳ pending execution (this record authorizes it) |

## 2. Gate criteria — what the r1 rehearsal must prove

Against the ephemeral project built from the committed files (r1, already
run, evidence `docs/send_message_rehearsal_evidence_r1_2026-08-08.md`),
the battery verified:

| # | Criterion | r1 evidence to capture | Verdict |
|---|---|---|---|
| 1 | The slice builds cleanly — `send_message.sql` applies (function + EXECUTE grant + **the D-SM3 revocation** as one unit) on top of the applied messaging surface | `--apply` **40 passed / 0 failures** (incl. `apply send_message.sql`) + the T2 live round-trip | ✅ **PASSED 2026-08-08** (genuinely executed) |
| 2 | Structural pins hold on the applied posture | rehearsal §4: **11 tables / 11 RLS / 10 policies** (11→10 — the D-SM3 `messages_insert_assigned` drop) / `send_message` EXECUTE present, anon absent / **authenticated INSERT on `messages` revoked** / publication unchanged (exactly `messages`, 1 + total 1) / §1d **19 RPCs** | ✅ **PASSED 2026-08-08** |
| 3 | 00/01/02/03/04/05/06/07/08/09 regression batteries unaffected (09 re-scoped: publication + delivery + D-SM3 revocation pins) | rehearsal §4: fixtures + single-account bound + all prior batteries PASS | ✅ **PASSED 2026-08-08** |
| 4 | `send_message` enforces the matrix §4 write contract **inside the function** (D-SM1) | rehearsal §4 (10 battery): assigned attorney + client positives persist with the D-RT4 stored author from profiles · org-role-alone / cross-org / suspended / owner / anon each denied (the in-function gate) · empty-body CHECK (10.09) | ✅ **PASSED 2026-08-08** |
| 5 | Contract §8 audit — every successful send writes the redacted audit row; denied sends write none | rehearsal §4 (10.03/10.10): `message:create/allowed` rows with actor + resource id + redacted summary 'message sent'; exactly the two positive sends' rows remain after all denies | ✅ **PASSED 2026-08-08** |

**Verdict (2026-08-08):** all five criteria **PASSED** on the genuinely
executed rehearsal run (evidence §4 — 74 passed / 0 warnings / 0
failures). The apply-approval gate is unblocked pending the owner's dated
signature in §6.

## 3. Decision (scope this record authorizes — once signed)

**APPLY APPROVED (on signature):** apply the reviewed + rehearsed
send-message slice to the shared dev project (`eutmvevpskerzpqmwplv`,
`eu-central-1`) in this order:

1. **`supabase/rpc/send_message.sql` — the audited write path (one apply
   unit):** `create or replace function public.send_message(uuid, text)`
   — `security definer set search_path = public` (D-SM1) with the
   **in-function gate** (the exact `messages_insert_assigned`
   authorization re-asserted: `is_active_member` AND the thread→matter
   three-way org equality AND assigned client/attorney), the author
   display name read from `profiles` (the D-RT4 stored-name source; the
   client-parity 'Demo client' fallback), the INSERT `returning id`, and
   `write_audit('message:create', 'allowed', …, p_resource_id, 'message
   sent')` (contract §8 — the slice's whole point); `revoke … from
   public, anon; grant execute … to authenticated;` — **plus the D-SM3
   revocation**: `revoke insert on public.messages from authenticated;`
   + `drop policy if exists messages_insert_assigned on public.messages;`
   so the audited RPC becomes the **only** message write path. No new
   table, no new columns, no RLS change to the read path, no publication
   change.
2. **Demo send (the first §8-audited live message write):** one
   `send_message` call **as the assigned partner**, exercising the
   audited path live: `set local role authenticated` +
   `request.jwt.claims` sub = the dev partner account
   `8fa94af0-7390-4f7a-988a-3965f7da04de` (active, the assigned attorney
   per the realtime-push execution record), on the **acquisition-review
   demo thread** `5d148bca-d784-4c21-81a1-1646c6754e2a` (count 1), with
   a **generic demo body** (no real PII, no real client/legal copy). The
   RPC returns the new message id; the **audit row** (`message:create`,
   actor = the partner, resource id = the returned id, redacted summary
   'message sent') is observed verbatim — §8 coverage live on the dev
   project for the first time.

plus the post-apply verification (structural subset + the audit-row
positive + the delivery-gate read as the assigned partner) per §4
condition 5, and the execution evidence record
(`docs/send_message_apply_execution_2026-08-08.md`).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline probe (read-only):** confirm the dev project's live
   state before the up sequence — `send_message` **absent**, the
   `messages` table with its **11 demo rows** (10 seeded + the
   realtime-push demo send `7cbf49e0-…`), the acquisition thread
   `5d148bca-…` with `assigned_attorney_id` = the partner
   `8fa94af0-…` (verify-don't-guess), the current `pg_policies` count
   (**10** today per the realtime-push execution record → **9** after
   step 1), the publication state (**exactly `messages`, count 1** —
   untouched by this apply), and the current `authenticated` INSERT grant
   on `messages` (**true** today → **false** after step 1). **Trigger
   condition:** if `send_message` already exists, the INSERT grant is
   already revoked, the policy is already gone, or the policy count is
   not 10, STOP and record — the D-SM3 transition must be established by
   this apply, never assumed.
2. **Verify, don't guess (demo send):** the target thread id comes from
   the **dev project's own applied `message_threads` rows** (verify the
   acquisition thread's org + the partner's assignment before the call —
   never guessed, never the rehearsal project's synthetic ids); the body
   is generic demo content (D-RT4, no real PII); the audit row's
   `resource_id` equals the RPC's returned id.
3. **Rollback pairing standing by (rollback_plan §1/§5):**
   `supabase/rpc/_down.sql` (drop `send_message(uuid, text)` — the
   function + grants go with it) + **git revert** of the D-SM3 revocation
   block (the `messages_insert_assigned` policy + INSERT grant re-add,
   per the gate-review §6 convention) + a targeted delete of the
   demo-sent row **and its audit row** is ready before step 1; **any**
   trigger condition (a matrix negative row starts passing, cross-tenant
   data visible, the demo row lands on a real thread/account, a
   non-generic author/body appears, the audit row is missing or carries
   content) = immediate revert, never fix-forward.
4. **Per-step verification:** after each of the two steps, probe the
   applied state (`send_message` present with `prosecdef` + EXECUTE
   grant, anon denied → INSERT revoked, policy gone → the demo row scoped
   correctly: right org, right thread, generic author/body + the audit
   row shape) with the observed output pasted verbatim into the execution
   record.
5. **Post-apply smoke (dev project):** the structural subset the rehearsal
   proved — `pg_policies` = **9** (10→9, the D-SM3 drop) ·
   `send_message(uuid, text)` EXECUTE true / anon false ·
   `authenticated` INSERT on `messages` **false** · `messages_insert_assigned`
   absent · the publication still **exactly `messages` (1 + total 1)**;
   then the **audit-row positive** (a `message:create/allowed` row with
   actor = the partner, `resource_id` = the returned id, redacted summary
   'message sent' — read via `supabase db query --linked` as the
   privileged role, never a raw client SELECT on `audit_events`, D-P0C4)
   and the **delivery-gate read** with role impersonation (the R1
   pattern): the partner reads the demo-sent row on its assigned
   acquisition thread (the delivered-row positive). The assigned demo
   **client** (`9acfd3b4-…`) reads 0 because it holds no dev membership
   rows — the D-RT2 membership guard firing live, recorded as an honest
   expectation (the realtime-push smoke precedent), never as a defect.
6. **No scope beyond the slice:** no other table/RPC/policy/function
   change, no publication change, no message edit/delete/attachments/
   read-receipts, no storage/realtime changes, no production, no
   service-role key, no real client/legal data.

## 5. What this approval does NOT authorize

- No other schema, policy, RPC, or function change beyond §3; **no
  message edit/delete/attachments/read-receipts** (insert-only write
  path); **Broadcast/Presence stays out of scope**; **billing (spec D-09)
  and AI stay §14-deferred**.
- No change to the Flutter client (`lib/`) — the env-gated
  `sendMessage` → RPC swap is plan **T7** (D-SM2), a separate slice with
  its own gate.
- No battery run against the dev project (the harness hard-refuses the
  dev ref; the battery is ephemeral-only by design).
- No push, no production deployment, no service-role credentials, no real
  data beyond the demo send of §3.
- The actual apply **execution** is a separate execution slice with its
  own evidence record; this record authorizes the apply decision only.

## 6. Owner sign-off

By signing below, the Project Owner authorizes the §3 apply against the
shared dev project (`eutmvevpskerzpqmwplv`), subject to the §4 execution
conditions and the §5 exclusions, with the rollback pairing standing by.
Signature is valid — the r1 rehearsal reported PASSED on 2026-08-08 (plan
T4; evidence §4, criteria §2 all green — genuinely executed, 74/0/0).

- **Project Owner:** github.com/mostafasayed118 — **date: 2026-08-08**
  — **approval wording:** "Apply approved — audited send_message RPC
  slice (send_message.sql with the D-SM3 revocation + the demo send via
  the RPC as the assigned partner on the acquisition demo thread), per
  this record §3–§5, with the §4 guardrails and rollback pairing."
  — **signature:** ✍️ Signed 2026-08-08 by the Project Owner
  (github.com/mostafasayed118), authorizing the §3 apply against
  `eutmvevpskerzpqmwplv` subject to the §4 execution conditions.

> **APPLY APPROVED 2026-08-08.** The execution record
> (`docs/send_message_apply_execution_2026-08-08.md`) captures the actual
> run; on success, T6 (the dated matrix §4 mechanism-note addendum)
> precedes T7 (client swap) per the plan — both already committed in this
> slice, and the §14 row flipped with the HELD caveat now resolvable.

## 7. Ledger

- DRAFT 2026-08-08: this record's status was ⏳ DRAFT — awaiting the
  owner's dated sign-off (§6); the plan's T5 row annotated.
- APPLY APPROVED 2026-08-08: the owner's dated sign-off recorded in §6;
  the apply execution (`docs/send_message_apply_execution_2026-08-08.md`)
  captures the actual run per §4; T6 (matrix addendum) and T7 (client
  swap) were already committed ahead of the sign-off, and the roadmap
  §13/§2 HELD caveats resolve once the execution record lands.
