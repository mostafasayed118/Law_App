# Plan: §14 Reconciliation (billing/AI) + Next Slice — Audited Message Send (2026-08-08)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS). Part A is
> the **§14 reconciliation** of the two remaining deferred paths — **billing**
> and **AI** — after the realtime live-delivery slice closed (roadmap §14,
> seventh un-deferral, `c229fcb`). Part B is the plan for the **recommended
> next plannable slice**: the **audited `send_message` RPC** — the review-Q6
> follow-up recorded by the realtime-push slice (the write path's contract §8
> audit gap). **Docs-only planning — zero dev-project effect**: nothing in
> this document applies anything to the dev Supabase project; every external
> step stays behind the owner's dated approval (INSTRUCTIONS.md §2.1/§5 hard
> gates).
>
> **Reconciliation verdict (verified 2026-08-08):** the roadmap's remaining
> **billing, AI** is accurate and neither path is currently plannable as a
> T1–T8 slice — **billing is blocked on the OPEN spec D-09** (payment
> provider / tax / PCI scope; owner + finance; also D-04 residency + PCI
> scope, and "no live payment in MVP"), and **AI has no scope at all**
> (blocked on OPEN D-07/D-08, legal review; no matrix rows, no RPC, no table,
> bootstrap spec's not-in-scope list). One **cross-document D-09 collision**
> is flagged (A.1): `docs/legalhub_specification.md` D-09 = Payment provider
> (open) vs `docs/p0_decision_capture.md` D-09 = Role semantics (decided
> 2026-07-31) — the billing deferral cites the **spec's** D-09.
>
> **Why the audited `send_message` RPC is the next slice (the §14
> reconciliation's recommendation):** with seven of nine §14 paths SHIPPED,
> the deferred list is exhausted of plannable items, so the best
> value/risk slice is the highest-value **recorded follow-up on a shipped
> path** — message sends are the only write path in the app not covered by
> contract §8 audit (realtime-push Q6 + matrix §4 write-row addendum + T8
> evidence §3 all flag it). It reuses the now seven-times-proven T1–T8
> server pipeline, the audited-RPC seam (`invite_member` precedent:
> `security definer` + `has_org_role` gate + `write_audit`), and the
> harness §1d RPC-EXECUTE pin list (18→19 RPCs). The client-only
> alternative — a partner-facing org-audit screen (audit evidence D-AUD1
> follow-up) — is recorded as the fallback; it is lower value and can slot
> in between server slices with near-zero risk.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## Part A — §14 reconciliation (verified 2026-08-08)

### A.1 Billing — STAYS DEFERRED (blocked on open owner-side decisions)

**Verified state (2026-08-08):**

| Claim | Verified fact | Source |
|---|---|---|
| Billing is the only remaining §14 server-side path | matters, documents, messages, storage, audit, realtime (read + push) all SHIPPED; roadmap §13/§14 tails say "billing, AI" | roadmap §13 row, §14 tail |
| Payment is gated on D-09 | Phase 5 (consultation booking) is client-only, "no live payment" | roadmap §5 line 315; spec §4 MVP list |
| D-09 = payment provider / tax / PCI scope, **open** | Owner + finance; gate "Before billing/payment spec"; impacts "Billing, booking payment" | `docs/legalhub_specification.md` D-09 |
| Billing also gated on D-04 + PCI | "Billing / payments \| D-09, D-04 (residency), PCI scope" | `docs/legalhub_specification.md` §13 |
| No billing data model exists | "No data models for matters/documents/messages/billing"; `billing_invoices` screen "Maybe \| Defer real payment (D-09)" | `docs/legalhub_bootstrap_specification.md`; spec §13 |
| No billing RPC / matrix rows | repo scan: zero billing/payment rows in `docs/permission_matrix.md`, zero billing RPCs in `supabase/rpc/` | verified 2026-08-08 |

**⚠ D-09 collision (flagged):** `docs/legalhub_specification.md` D-09 =
Payment provider / tax / PCI scope (**open**); `docs/p0_decision_capture.md`
D-09 = Role semantics (**DECIDED 2026-08-07-31**). The billing deferral and
the roadmap Phase-5 line ("payment is gated on D-09") cite the **spec's**
D-09. The realtime-push T8 evidence §8's "billing (D-09)" inherits the
ambiguity. **Recommendation:** future billing references say "spec D-09
(payment provider / tax / PCI)" to disambiguate; the p0 capture's D-09
(role semantics) is closed and unrelated.

**Verdict:** NOT plannable as a T1–T8 slice. The §14 gate ("per feature,
same P2 discipline") presupposes a table + RLS + battery + matrix rows;
billing has none, and the gate to creating any is the **owner's dated
closing of spec D-09 (+ D-04)** — an external payment/PCI/tax decision
(owner + finance per the spec), not a planning decision. A
billing-invoices **read-metadata** slice (invoice rows + RLS + client
surface, mirroring the six read slices) becomes plannable **only after**
that closes. Recorded as owner-blocked, not forgotten.

### A.2 AI — STAYS DEFERRED (no scope)

**Verified state (2026-08-08):**

| Claim | Verified fact | Source |
|---|---|---|
| AI items are explicitly deferred | "Research AI assistant / citation manager / statutory browser / legal draft workspace (D-07/D-08)" in the Deferred list | `docs/legalhub_specification.md` §4 |
| Gated on open legal-review decisions | D-07 (research data source/license/freshness, open, legal review), D-08 (AI usage policy, open, legal review) | `docs/legalhub_specification.md` D-07/D-08 |
| Not in scope at all | bootstrap spec's not-in-scope list includes the research AI assistant / citation manager / statutory browser / draft workspace | `docs/legalhub_bootstrap_specification.md` |
| No matrix rows / RPC / table / spec basis | repo scan: zero AI rows in `docs/permission_matrix.md`, zero AI RPCs/tables, roadmap lists "AI" with no scope | verified 2026-08-08 |

**Verdict:** NOT plannable — there is nothing to un-defer. AI has no
scope beyond the roadmap list's word. Un-block condition: product scope
definition + closed D-07/D-08 (owner + legal), at which point a
research-read slice could be planned under the same discipline. The
roadmap's "AI (no scope)" characterization (T8 evidence §8) is accurate
and stays.

### A.3 Reconciliation verdict

- The §14 deferred list is now **exhausted of plannable items**: 7 of 9
  paths un-deferred and SHIPPED; **billing and AI both stay deferred
  behind open owner-side decisions** (spec D-09 + D-04; D-07/D-08), each
  with a concrete un-block gate recorded above.
- **Next slice (this plan):** the audited `send_message` RPC — the
  write-path §8-audit gap recorded by the realtime-push slice. Chosen by
  autonomy (best value/risk among the remaining recorded follow-ups:
  server-side closure of the last governance gap on a shipped path vs the
  client-only partner-audit alternative).
- **Roadmap impact (when the next slice ships):** §2 unwired-RPC inventory
  count moves **18-of-18 → 19-of-19** (the harness §1d RPC-EXECUTE list
  gains `send_message(uuid, text)`); the §13 gate-table row's "billing/AI
  stay deferred" tail is unchanged until either un-blocks.

---

## Part B — SPEC_KIT PLAN: audited message-send RPC (Template 2)

### B.1 Goal

Route every message send through an **audited `send_message` RPC** so the
write path carries contract §8 audit coverage like the org RPCs do —
closing the realtime-push review-Q6 gap. The RPC re-applies the exact
`messages_insert_assigned` gate **inside the function** (D-SM1), writes an
audit row via `public.write_audit` (the `invite_member` seam), inserts the
message row, and the client `sendMessage` swaps from the direct INSERT to
the RPC (D-SM2). The direct-INSERT surface (grant + policy) is revoked so
the audited RPC becomes the **only** write path (D-SM3). No schema change
(the `messages` table + `body` CHECK + thread FK from the realtime slice
stand); no change to the read path, the subscription, or the composer UI
shape.

### B.2 Layers touched

- **Server (rehearsal-ready, apply-gated):** `supabase/rpc/send_message.sql`
  + `_down.sql` entry + harness §1d RPC-EXECUTE pin.
- **Presentation:** none (the composer's send flow keeps its shape; the
  failure kinds' meaning is unchanged).
- **Domain:** none (`MessageGateway.sendMessage` signature unchanged).
- **Data:** `supabase_message_api.dart` + impl + gateway — `sendMessage`
  swaps the insert caller for an RPC caller (new `MessageRpcCaller`
  typedef mirroring `DocumentTableCaller`), failure mapping for
  RPC-denial / unavailable / unknown.

### B.3 New/changed files

| File | Layer | Responsibility |
|------|-------|-----------------|
| `supabase/rpc/send_message.sql` (new) | server | audited send: role gate (D-SM1) → `write_audit` → INSERT; `security definer set search_path = public` (the `invite_member` pattern) |
| `supabase/rpc/_down.sql` (edit) | server | backout pairing (drop function) |
| `scripts/verify_policy_tests.sh` (edit) | harness | §1d RPC-EXECUTE list gains `send_message(uuid, text)`; battery file list + `--apply` order + any structural pins |
| `supabase/tests/10_send_message_rls.sql` (new) | server | battery: EXECUTE grant pins (authenticated yes / anon no), the in-function gate's deny rows, the audit row written, the body CHECK, the direct-INSERT revocation pin (D-SM3) |
| `docs/send_message_gate_review_2026-08-08.md` (new, T1) | docs | Q1–Q6 design review |
| `docs/send_message_apply_approval_2026-08-08.md` + execution + rehearsal evidence (new, T4/T5) | docs | the dated-gate records |
| `docs/permission_matrix.md` (edit, T6) | docs | §4 "Send a message" row mechanism note: audited RPC (was direct INSERT, §8 gap recorded) |
| `lib/data/messaging/supabase_message_api.dart` + impl + gateway (edit, T7) | data | `sendMessage` → RPC caller; failure kinds |
| tests (edit/new, T7) | test | impl RPC-call pin, gateway mapping, DI pins; fake unchanged |

### B.4 State shape (Cubit/State)

**Unchanged** — `MessageThreadDetailState` (Loading/Loaded/Empty/Error +
`sending`/`sendError` from the realtime-push T7) keeps its exact shape.
The send flow's failure kinds (`message_send_denied` / `_unavailable` /
`_failed`) keep their meaning; only the *mechanism* behind them changes
(RPC denial vs INSERT RLS denial). No new state variant.

### B.5 Data flow

User taps Send → `MessageThreadDetailCubit.send` (in-flight guard, draft
kept) → `MessageGateway.sendMessage(threadId, body)` → (configured)
`SupabaseMessageGateway` → `SupabaseMessageApi.sendMessage` → **RPC call
(`send_message`, with the thread-id/org resolution moved into the
function)** → RPC: role gate → `write_audit('message:create', 'allowed',
…)` → INSERT → returns the row id → gateway maps → cubit appends +
clears in-flight. The **org-resolution hop the current impl performs
client-side (the `messages_insert_assigned` WITH CHECK prerequisite) moves
into the RPC** — the client no longer needs to read the thread's org
before sending (the function resolves it under the same gate). Env-less
runs + tests keep the fake (unchanged behavior, deterministic append).

### B.6 Dependencies

None. The RPC uses `public.has_org_role` / membership helpers and
`public.write_audit` — all shipped and battery-pinned. No new package.

### B.7 Testing strategy

- **Battery (T3):** EXECUTE grant pins (authenticated yes, anon no); the
  in-function gate's deny rows (org-role-alone / cross-org / suspended /
  owner — same five rows as 09, re-asserted **inside the function**);
  the audit row written (an `audit_events` row with the `message:create`
  action appears — the D-P0C4 redacted-observer pattern); the `body`
  CHECK; the **D-SM3 pin** (direct INSERT now denied — the revoked grant).
- **Client (T7):** impl `sendMessage` RPC-call pin (function name + args,
  no org pre-read), RPC-denial / unavailable / unknown failure mapping,
  gateway mapping, DI pins, fake unchanged (send append still green), the
  cubit/screen send tests from realtime-push T7 re-run untouched.

### B.8 Risks / open questions (decisions ratified by autonomy, one line each)

- **D-SM1 — in-function gate mechanism:** `security definer` with an
  explicit `messages_select_assigned`-equivalent check inside the function
  (the `invite_member` precedent; the same three-way org equality the
  policy encodes, asserted server-side so the RPC is the gate even if the
  policy drifts). *Recommended: security definer + explicit check; the
  battery pins the deny rows inside the function.*
- **D-SM2 — client swap:** `sendMessage` routes through the RPC behind
  `env.isConfigured`; the fake keeps the direct-append behavior so
  env-less runs and tests are untouched. *Recommended: swap now, in the
  same slice as the RPC ships (T7).*
- **D-SM3 — direct-INSERT fate:** after the RPC ships, revoke the
  `authenticated` INSERT grant on `messages` and drop the
  `messages_insert_assigned` policy (replaced by the RPC's in-function
  gate), so **all** writes go through the audited path — the battery pins
  authenticated INSERT false. *Recommended: revoke + drop (defense in
  depth; the §8 story becomes "every write is audited, by construction").*
  The demo-send smoke in the apply record shifts to an RPC call.
- **Residual:** the RPC is a new 19th RPC — the §13 "18-of-18 wired"
  claim moves to 19-of-19 in T8's lockstep; the realtime read/push
  batteries' forward pins are untouched (the messages INSERT surface is
  pinned, not the publication).

---

## Part C — TASKS (Template 3)

Branch: `feat/send-message-rpc`

- [x] **1. Mechanism design review** — touches: `docs/send_message_gate_review_2026-08-08.md`
  (Q1–Q6: function security D-SM1, the in-function gate = the three-way
  org equality, the `write_audit('message:create', …)` row, the D-SM3
  direct-INSERT revocation + why, org resolution moving into the function,
  rollback = `_down.sql` + policy re-add) — done when: review committed,
  decisions D-SM1..D-SM3 ratified, ledger sweep green. — **DONE (this
  commit, 2026-08-08):** Q1–Q6 answered — D-SM1 ratified (security
  definer + explicit in-function gate; RLS does not apply inside the
  function, so the check IS the sole write authorization), D-SM2 ratified
  (client RPC swap; the org-resolution pre-read moves into the function),
  D-SM3 ratified (revoke the direct-INSERT grant + drop
  `messages_insert_assigned`; the RPC becomes the only write path — with
  the **09-battery re-scope consequence recorded in Q6**: the ~10
  role-impersonated INSERT checks move to EXECUTE checks + the revocation
  pin, policies 11→10 in the same slice); the audit row (Q3), owner/anon
  denies (Q5), §4 function sketch + deny rows, §5 harness re-scope (§1d
  18→19), §6 rollback pairing (`_down.sql` + git-revert policy re-add).
  Ledger sweep green.
- [x] **2. Rehearsal-ready artifacts (NOT applied)** — touches:
  `supabase/rpc/send_message.sql` + `_down.sql` entry (the `invite_member`
  pattern: `security definer set search_path = public`, `has_org_role`/
  assignment gate, `write_audit`, INSERT, RETURNING id) — done when:
  artifacts committed, static review clean, nothing applied. — **DONE (this
  commit, 2026-08-08):** `supabase/rpc/send_message.sql` (D-SM1 in-function
  gate → profiles display name with the client-parity 'Demo client'
  fallback → INSERT RETURNING id → `write_audit('message:create',
  'allowed', …, p_resource_id, redacted summary)` → return; revoke
  public/anon + grant authenticated) + the `_down.sql` drop entry —
  **live-validated on the rehearsal stack**: apply → 9 role-impersonated
  checks all as designed (assigned attorney + assigned client send with
  the audit row observed — actor, resource id, redacted summary;
  stranger / org-role-alone / cross-org / suspended / owner denied by the
  in-function RAISE; anon denied at the grant; empty body →
  `messages_body_check` with nothing written) → drop round-trip
  (function + grants gone, re-apply restores) → demo rows + audit rows
  cleaned. NOT applied to the dev project.
- [x] **3. Battery + harness** — touches: `supabase/tests/10_send_message_rls.sql`
  (EXECUTE grant pins, in-function deny rows ×5, audit-row positive, body
  CHECK, direct-INSERT-revoked pin) + `scripts/verify_policy_tests.sh`
  edits (file list, run loop, `--apply` order, §1d RPC-EXECUTE gains
  `send_message(uuid, text)` 18→19) — done when: static `--check` green,
  selftest green. — **DONE (this commit, 2026-08-08):** NEW
  `supabase/tests/10_send_message_rls.sql` (10 named checks: attorney +
  client send positives with the D-RT4 stored author from profiles, the §8
  audit-row shape positive, the in-function deny rows (org-role-alone /
  cross-org / suspended / owner / anon), the empty-body CHECK through the
  RPC, and the §8 negative — a denied send writes no audit row) + the
  **09 re-scope** (the INSERT-policy group moved to the 10 battery; 09 now
  pins publication membership + the privileged empty-body CHECK + the
  extended delivery equivalence (attorney + client positives, suspended /
  cross-org / owner / stranger negatives) + the **D-SM3 revocation pins**
  (09.15 privilege-layer deny, 09.16 policy gone)) + the
  **send_message.sql D-SM3 revocation tail** (revoke INSERT grant + drop
  `messages_insert_assigned` — the coherent --apply unit) + harness edits
  (§1d RPC-EXECUTE **18→19** with `send_message(uuid, text)`; policy pin
  **11→10**; file list + run loop + UUID scan + FAIL-marker loop gain 10;
  selftest glob gains 10; header/apply comments). **Verified, not
  claimed:** static `--check` **337/0/0** · live battery on the rehearsal
  stack **74/0/0** (10 green, 09 re-scoped green, pins 11 tables / 11 RLS /
  10 policies / publication exactly messages / 19 EXECUTE RPCs) · selftest
  **6/6**. NOT applied to the dev project.
- [ ] **4. Ephemeral rehearsal (r-series)** — touches: Docker-stack
  `verify_policy_tests.sh --apply` + battery (the established genuinely-
  executed precedent) + `docs/send_message_rehearsal_evidence_r1_2026-08-08.md`
  — done when: r1 PASSED, evidence recorded.
- [ ] **5. Dated apply-approval → apply** — touches: dev project (RPC +
  the D-SM3 revocation), `docs/send_message_apply_approval_2026-08-08.md`
  + execution record — done when: owner's dated sign-off, apply executed
  with the demo-send smoke shifted to an RPC call (audit row observed),
  rollback pairing standing by. **Owner-gated.**
- [ ] **6. Dated matrix addendum** — touches: `docs/permission_matrix.md`
  §4 "Send a message" row mechanism note (audited RPC replaces the direct
  INSERT; the §8 gap closes; D-SM3 revocation recorded) — done when:
  addendum committed **before** the client surface ships, ledger green.
- [ ] **7. Client swap (env-gated)** — touches: `supabase_message_api` +
  impl + gateway `sendMessage` → RPC caller (D-SM2), failure mapping,
  fake untouched, tests (impl RPC-call pin incl. **no org pre-read**,
  denial/unavailable/unknown mapping, DI pins, fake determinism re-run)
  — done when: format clean · analyze clean · suite green · ledger PASS.
- [ ] **8. Lockstep + evidence + close** — touches: README test count,
  roadmap §2 18-of-18 → 19-of-19 + §13 row, completion evidence
  `docs/send_message_real_data_completion_evidence_2026-08-08.md`, dated
  close decision — done when: all docs sweep green, full gate re-run,
  close decision recorded.
