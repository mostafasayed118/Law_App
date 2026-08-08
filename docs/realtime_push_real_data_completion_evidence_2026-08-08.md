# LegalHub — Realtime Live Delivery (Push) Completion Verification & Evidence Record (2026-08-08)

> **Record type:** Slice T8 close-out evidence (plan
> `docs/realtime_push_real_data_plan_2026-08-08.md`) — the **seventh §14
> per-feature un-deferral** (matters → documents → message_threads →
> storage → audit surfacing → individual messages/bodies → **live
> delivery**), records exactly what was **verified** about the realtime
> push path (server commits `af1715c` → `7efb32b`, client `6154fa3`, all
> on `main`, no push) and exactly what is **still pending**, with no claim
> beyond what was actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-08 — server applied + client surface complete,
> full gate green on `main` (analyze clean, suite 1045 runtime / README
> 1042 declaration, ledger PASS 115).** This slice closed the D-RT6
> follow-up from the realtime read slice: the `postgres_changes`
> publication + the INSERT policy + the first live INSERT on the dev
> project + the env-gated client subscription and composer. The dated
> close decision is recorded in §9, mirroring the P0C / P3.1–P3.5 /
> matters / documents / messages / storage / audit / realtime read close
> format.

---

## 1. What this record covers

The realtime **live-delivery (push)** path — `postgres_changes`
publication membership for `messages`, the `messages_insert_assigned`
INSERT policy (the D-LV1 write source), the first live INSERT, and the
env-gated client subscription + minimal composer — delivered as plan
T1–T8:

| Stage | Artifact | Commit |
|---|---|---|
| T1 — mechanism design review | `docs/realtime_push_gate_review_2026-08-08.md` (Q1–Q6 for a mechanism, not a table: **Realtime RLS = the existing `messages_select_assigned` SELECT policy IS the delivery gate**, D-LV2 exactly-`messages` publication, D-LV1 write source, D-LV4 client lifecycle, forward-pin re-scope 0→1) | `af1715c` |
| T2 — schema artifacts (NOT applied) | `supabase/migrations/09_realtime_push.sql` + `09_realtime_push.down.sql` + `supabase/policies/messages_insert.sql` — publication membership only + the INSERT grant + `messages_insert_assigned`; **live-validated** on the rehearsal stack (up/down/up round-trip 1→0→1, role-impersonated INSERTs) — two defects caught and fixed (no `IF NOT EXISTS` form for `CREATE PUBLICATION`; 08 granted SELECT only so the policy needed its own grant) | `f1d7903` |
| T3 — battery + harness | `supabase/tests/09_realtime_push.sql` (12 checks: publication pins 1 + nothing-else, assigned positive, five deny rows incl. suspended/owner/anon, empty-body CHECK, delivery-equivalence 09.11/09.12) + `verify_policy_tests.sh` re-scope (pins 10→11 policies; forward pin re-scoped to messages-in-publication **+ exactly-one-publication-row**); static `--check` **335/0/0**, selftest 6/6 | `6302bdc` |
| T4 — rehearsal r1 | **Genuinely executed** battery on the Docker-backed scratch stack: **`== summary: 72 passed, 0 warnings, 0 failures ==` / `RESULT: PASS`**, pins verified against the pre-existing applied state (publication 1, 11 policies, `messages_insert_assigned` present); evidence `docs/realtime_push_rehearsal_evidence_r1_2026-08-08.md` **PASSED** | `51532fd` |
| T5 — dated apply gate + execution | `docs/realtime_push_apply_approval_2026-08-08.md` **APPLY APPROVED 2026-08-08** (owner §6 signature) → apply executed: baseline probe (9 policies, publication 0, messages 10) → `09_realtime_push` (publication 0→1 exactly `public.messages`) → `policies/messages_insert` (9→10 policies, authenticated INSERT true / anon false) → **the demo send as the first live INSERT** `7cbf49e0-…` → post-apply smoke; evidence `docs/realtime_push_apply_execution_2026-08-08.md` **APPLIED** | `c96eff7` + `7efb32b` |
| T6 — dated matrix §4 + §6 addenda | the **"Send a message (insert)"** row (client/attorney SHIP behind `messages_insert_assigned`; partner/`compliance_officer` ungranted; `platform_owner_admin` deny always) + the §6 "Realtime subscription for an org/matter the session no longer has access to → No events delivered" row **→ enforced** (Realtime RLS = the existing SELECT policy, publication exactly messages) | `de25c6f` |
| T7 — env-gated client swap | NEW `SupabaseMessageRealtimeApi` seam + impl (per-thread `postgres_changes`, reconnect, close) + `sendMessage` on `MessageGateway`/fake + the thread-detail composer (insert-only D-LV1) + service_locator flip behind `env.isConfigured` + l10n ×3 + tests | `6154fa3` (amended from `a1a735e`) |
| T8 — lockstep + evidence + close | README count lockstep (1042 — see §7), roadmap §14 seventh flip + §13 gate-table row, this record, dated close decision | this commit |

## 2. Verified (actually run, 2026-08-08)

### 2.1 Final gate on `main` (post-`6154fa3`, the last code commit; T8 is docs-only and re-swept the ledger)

| Check | Result |
|---|---|
| `bash scripts/verify_format.sh` (whole repo, CI-exact `dart format .`) | **PASS — 0 changed** (300 files) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **1045 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 1042 in lockstep) |
| `scripts/verify_policy_tests.sh --check` (static battery) | **PASS 335/0/0** (the 09 battery landed at T3) |
| Live battery (rehearsal, genuinely executed) | **`== summary: 72 passed, 0 warnings, 0 failures ==` / `RESULT: PASS`** (T4, evidence `51532fd`; selftest 6/6) |

### 2.2 Server-side verification (applied + verified on the dev project)

- **Baseline probe matched the approval record's predictions exactly**
  (`7efb32b`): **9 public policies** (→ 10), **publication 0 rows** (→ 1),
  `messages` table present with **10 demo rows**, all four demo threads in
  org `ef43087b-…`, and — verify-don't-guess — the acquisition thread's
  `assigned_attorney_id` = the partner `8fa94af0-…` (the demo-send
  target confirmed before anything was written).
- **`09_realtime_push` applied**: `pg_publication_tables` = **exactly
  `public.messages`, nothing else** (the D-LV2 invariant established, never
  assumed — the trigger condition in the approval record §4 was clean).
- **`policies/messages_insert` applied**: `messages_insert_assigned` live
  (WITH CHECK = the read gate applied as the write gate, D-LV1),
  `messages_select_assigned` intact, **pg_policies 9 → 10**,
  `authenticated` INSERT **true** / `anon` **false** (the grant half the
  T2 rehearsal finding required).
- **Demo send (D-LV6 — the first live INSERT in the slice history)**: a
  role-impersonated INSERT as the assigned partner on the acquisition
  thread, exercising `messages_insert_assigned` live: RETURNING id
  **`7cbf49e0-96da-4f12-8803-329f331d467a`**, org `ef43087b-…`, generic
  `Demo attorney` author + generic body — **0 org mismatches, 0 non-generic
  rows**.
- **Post-apply smoke (role-impersonated, R1 pattern):** the partner
  (assigned attorney, active member) reads the sent row: **1** — the
  delivery gate is the read gate (D-LV3), live; the **assigned client with
  no membership rows reads 0** — the D-RT2 membership guard firing live
  (recorded as designed, never as a defect); tally **10 → 11**.
- **Trigger-condition sweep clean; no rollback invoked** — the down-pairing
  (publication drop + demo-row delete + policy git-revert) stands by,
  unexercised. Dev project now: **11 tables / 11 RLS / 10 policies /
  publication exactly messages**.

### 2.3 Test coverage added by the client surface (+31 declarations, suite 1011 → 1042 declaration; 1014 → 1045 runtime)

- `supabase_message_realtime_api_impl_test` (NEW, +5): the seam's
  lifecycle via an injected binder — the **`thread_id=eq.…` filter pin**,
  INSERT-row forwarding, **channel-error reconnect + recovery signal**
  (re-entry guarded), close teardown.
- `supabase_message_api_impl_test` (+5): `sendMessage` — the **org
  resolution under the same RLS gate** before inserting (unreadable org =
  typed denial), the insert payload (thread id, org, author display name,
  body), denial / unknown PostgrestException → failure kinds.
- `supabase_message_gateway_test` (+8): `sendMessage` mapping +
  failure kinds; `watchMessages` event mapping — INSERT → `MessageLiveAppended`,
  reconnect → `MessageLiveReconnected`, **malformed rows dropped cleanly**
  (never mislabeled as a reconnect).
- `message_gateway_test` (fake, +4): deterministic per-thread **send
  append** (thread-scoped), instance-scoped live stream, **never-emitting
  stream** in env-less runs (the fake-channel pin).
- `message_thread_detail_cubit_test` (+6): **live-append + dedupe-by-id**;
  **reconnect → re-backfill via the shipped `fetchMessages`** (fetchCalls
  pinned); send success (append after clearing in-flight); **send failure**
  (error surfaced, draft kept); close → unsubscribe.
- `message_thread_detail_screen_test` (+3): the composer — send flow
  (draft → tap send → row appears), **empty-disable** (no send while empty
  or in flight), inline send error + retry; **no edit/delete affordances**
  (the insert-only D-LV1 posture).
- Re-scoped, not added: `router_test` detail pin (the read-only posture →
  the composer posture), `service_locator_test` DI pins (gateway constructed
  with both seams behind `env.isConfigured`), and the 4 `MessageGateway`
  test stubs (matter-details, list-screen ×2, search) updated to the new
  seam at compile level.

  Per-file sums: 5 + 5 + 8 + 4 (data) + 6 + 3 (presentation) =
  **31 declarations** — matching the ledger lockstep 1011 → 1042 (suite
  1014 → 1045 runtime; equal deltas this slice, so the `blocTest<>`
  expansion convention nets zero spread).

## 3. Pending (honestly NOT run — do not read as verified)

- **No live configured-build subscription round-trip on a device/emulator**
  — all client verification is the typed/fake test suite + DI pins (the
  D-45.1 Phase 2 convention; needs `.env`, git-ignored). The real
  websocket channel, the real reconnect path, and real delivered events
  are inert until a configured build exists; the impl's unit tests pin
  filter/lifecycle via an injected binder, never a live channel (honest
  D-LV4 limit, recorded in the T4 evidence too).
- **Insert-only** — no edit / delete / attachments / receipts on messages
  (D-LV1); the composer is the minimal send path.
- **The direct-INSERT path is not §8-audited** (review Q6 from the
  mechanism review) — same posture as the six prior applies' demo seeds;
  a future audited `send_message` RPC is a recorded follow-up.
- **No Broadcast / Presence** — the `realtime.messages` authorization
  table is not used; `postgres_changes` + Realtime RLS covers the slice.
- **No push** — `main` is ahead of `origin`; push awaits owner approval.

## 4. Acceptance-criteria status (plan §7/T8 done-when)

| Criterion | Status | Evidence |
|---|---|---|
| Mechanism review answers the D-RT6 authorization question (publication ≠ RLS) | **VERIFIED** | `af1715c`: Realtime RLS = the existing `messages_select_assigned` SELECT policy IS the delivery gate; publication membership = enablement only |
| Server slice rehearsed (battery green on the committed files, live-validated artifacts) + applied on the dev project with rollback pairing | **VERIFIED** | T2 live round-trip (`f1d7903`); T4 genuinely executed 72/0/0 (`51532fd`); T5 applied + smoke (`7efb32b`); rollback pairing standing by, not invoked |
| Dated matrix addenda (write row + §6 delivery row) precede the client surface | **VERIFIED** | `de25c6f` (T6) < `6154fa3` (T7) |
| Env-gated subscription + composer swap (fake in env-less runs + ALL tests); shipped `MessageThread`/`Message` VOs untouched | **VERIFIED** | DI pins; fake never-emitting stream + deterministic send; suite green on the fake |
| Per-thread subscription + reconnect + backfill via the shipped `fetchMessages` (never a second fetch mechanism) | **VERIFIED** | realtime impl filter pin + reconnect test; cubit re-backfill fetchCalls pin |
| Insert-only: no edit/delete; no §8 audit on the direct path | **VERIFIED** | widget assertions (single-field composer, no edit/delete affordances); gateway surface (insert only); review Q6 recorded |
| README count lockstep; roadmap §14 seventh flip + §13 row; ledger PASS on the committed state | **VERIFIED** | §2.1; README 1042; §6; this commit |
| Full gate on the client slice; ledger PASS | **VERIFIED** | §2.1; PASS 115 |

## 5. Exact commands (as run — reproducible)

```bash
# T2 — live artifact validation (rehearsal stack; see the r1 record §3)
#     up/down/up round-trip + role-impersonated INSERT checks, via the
#     psql shim into the Docker container (see docs/realtime_push_rehearsal_evidence_r1_2026-08-08.md)
# T4 — rehearsal (scratch Docker stack + psql shim)
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_policy_tests.sh --apply
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_policy_tests.sh          # -> 72/0/0, RESULT: PASS
bash scripts/verify_policy_tests.sh --selftest  # -> 6/6 (harness drift detection)
# T5 — apply on the dev project (owner approved, `7efb32b`)
supabase db query --linked --file supabase/migrations/09_realtime_push.sql
supabase db query --linked --file supabase/policies/messages_insert.sql
# demo send + smoke — see docs/realtime_push_apply_execution_2026-08-08.md §0/§3
# T7 — client gate
bash scripts/verify_format.sh                  # whole-repo, CI-exact
flutter analyze
flutter test                                   # 1045 passed
bash scripts/verify_ledger.sh                  # PASS 115
```

## 6. Ledger impact

README test count **1011 → 1042** across the slice in lockstep with the
ledger's declaration count (suite 1014 → 1045 runtime; equal +31 deltas
this slice). **One drift was caught and fixed before T8:** the first T7
commit (`a1a735e`) pinned README at **1037** — the final ledger sweep on
those exact bytes showed the ledger's git-grep declaration count at
**1042**, so the commit's "ledger PASS" claim was false for its content.
The README was corrected (both markers + the coverage description, which
still described the read slice) and the commit **amended** (`a1a735e` →
`6154fa3`, local-only, nothing pushed) so the record is truthful. Final
state `scripts/verify_ledger.sh` **PASS 115/0/0**. The docs all sweep
green with the resolved commit refs.

## 7. Review findings — resolved (not papered over)

- **T2 live validation (the rehearsal stack caught real defects):** two
  findings surfaced by actually running the artifacts and were fixed in
  the same commit (`f1d7903`):
  1. **`CREATE PUBLICATION` has no `IF NOT EXISTS` form** — the first
     draft's bare guard was a syntax error; fixed with a `do`-block guard.
  2. **08 granted SELECT only, so the INSERT policy could never fire** —
     the rehearsal proved the partner INSERT was permission-denied at the
     privilege layer; the INSERT grant was added (write surface = grant +
     policy, recorded in the file comment).
- **T3 battery genuinely executed (not just statically checked):** the
  full battery ran live on the Docker rehearsal stack against the
  pre-existing applied state — **72/0/0**, the new pins (publication 1,
  policies 11, exactly-messages) matched the live state, static `--check`
  335/0/0, selftest 6/6 (`6302bdc`).
- **T5 apply smoke (live finding, recorded honestly):** the assigned client
  with no membership rows reads 0 on the sent demo row — the D-RT2
  membership guard firing live, recorded as the honest expectation in the
  approval record, never as a defect.
- **T7 ledger (count accuracy — the slice's sharpest finding):** the final
  ledger sweep on the committed T7 state caught the README pin **1037 ≠
  1042** (the ledger's ground-truth declaration count on the exact
  committed bytes). Fixed and **amended into the commit** so the gate
  claim is true of what ships; the lesson recorded: run the ledger on the
  exact bytes that get committed, not on an intermediate state.
- **D-LV3 honesty:** 09.11/09.12 prove the **RLS delivery proxy** (the
  role-impersonated read under `messages_select_assigned` — the gate
  Realtime RLS applies); a real websocket round-trip is explicitly not
  claimed by any unit test and stays the configured-build verification
  (T7's realtime impl tests pin filter/lifecycle via an injected binder,
  never a live channel).

## 8. Owner attention needed

- **Push approval:** `main` is ahead of `origin`; the slice's commits
  (`af1715c` T1, `f1d7903` T2, `6302bdc` T3, `51532fd` T4, `c96eff7` +
  `7efb32b` T5, `de25c6f` T6, `6154fa3` T7, this T8) await your push
  approval.
- **Configured-build verification (D-LV4):** the real websocket
  round-trip, reconnect, and live delivered events need a configured build
  (`.env`, git-ignored) — the D-45.1 convention; the owner-side live E2E
  checklist from `docs/p3_plan_complete_2026-08-05.md` should gain a
  realtime item.
- **Recorded write-path follow-ups:** an **audited `send_message` RPC**
  (review Q6 — the direct-INSERT path is not §8-audited), and message
  edit/delete/attachments/receipts (all out of D-LV1 scope).
- **Remaining §14 deferred paths:** billing (spec D-09 — payment
  provider/tax/PCI, open; not the decided p0 D-09 role semantics) and AI
  (no scope) — the deferred list now narrows to those two; each keeps the
  same per-feature discipline (reconciled 2026-08-08 in
  `docs/send_message_rpc_plan_2026-08-08.md`).

## 9. Dated close decision

**Realtime live-delivery (push) slice — CLOSED 2026-08-08.** T1–T7 met
their gates: the mechanism design review answered the D-RT6 authorization
question (Supabase Realtime RLS makes the **existing `messages_select_assigned`
SELECT policy the delivery gate**; publication membership = enablement
only, exactly `messages`); the `09_realtime_push` artifacts + INSERT
policy shipped and were **live-validated on the rehearsal stack** (two
real defects caught and fixed); the battery + harness re-scoped the
forward pin to messages-in-publication + exactly-one-publication-row
(static `--check` 335/0/0) and the **rehearsal battery was genuinely
executed green (72/0/0)**; the owner's dated approval was signed and the
**apply executed on the dev project** (publication 0→1 exactly
`public.messages`, policies 9→10, the **first live INSERT**
`7cbf49e0-…` through `messages_insert_assigned`, smoke verified with the
membership-guard negative recorded as designed); the dated matrix §4
write-row + §6 delivery-row addenda consummated the "Send a message" and
"Realtime subscription → No events delivered" rows before the client
surface; and the env-gated swap shipped — NEW `SupabaseMessageRealtimeApi`
(per-thread `postgres_changes` + reconnect + backfill via the shipped
`fetchMessages`), `sendMessage` on the gateway/fake, and the insert-only
thread-detail composer — with the full gate green on `main` (format PASS ·
analyze clean · suite 1045 runtime / README 1042 · ledger PASS 115, the
README 1037→1042 drift caught by the final sweep and amended into the
commit). The §14 realtime row flips to per-feature SHIPPED (seventh
un-deferral — read + live delivery both closed). **Nothing pushed**;
billing (D-09) and AI stay deferred each behind their own future
per-feature un-deferral.
