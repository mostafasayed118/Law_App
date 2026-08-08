# LegalHub — Audited Message Send (Send-Message) Completion Verification & Evidence Record (2026-08-08)

> **Record type:** Slice T8 close-out evidence (plan
> `docs/send_message_rpc_plan_2026-08-08.md`) — the **eighth §14
> per-feature un-deferral** (matters → documents → message_threads →
> storage → audit surfacing → individual messages/bodies → live delivery →
> **the audited send path**), records exactly what was **verified** about
> the audited `send_message` RPC path (server-side T1–T4 rehearsal-verified,
> T5 apply **owner-approved and EXECUTED 2026-08-08**
> (`docs/send_message_apply_execution_2026-08-08.md`); client swap
> `f874a57`, all on `feat/send-message-rpc`, no push) and exactly what is
> **still pending**,
> with no claim beyond what was actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-08 — the full gate green on the committed
> branch state (analyze clean, suite 1047 runtime / README 1044
> declaration, ledger PASS 115), and the T5 apply EXECUTED the same day
> (owner's dated §6 sign-off → policies 10→9, `authenticated` INSERT
> revoked, the demo send `1c031882-…` via the RPC with the §8 audit row
> observed).** This slice closed the realtime-push review-Q6
> follow-up: the app's message write path becomes a contract §8-audited
> RPC by construction. The dated close decision is recorded in §9,
> mirroring the P0C / P3.1–P3.5 / matters / documents / messages / storage
> / audit / realtime read / realtime push close format.

---

## 1. What this record covers

The audited message **send** path — the `send_message` RPC (D-SM1
in-function gate + `write_audit` §8 by construction + D-SM3 direct-INSERT
revocation) and the env-gated client swap (D-SM2: the seam calls the RPC
with no org pre-read + no client author; the gateway resolves the VO
through the shipped read) — delivered as plan T1–T8:

| Stage | Artifact | Commit |
|---|---|---|
| T1 — mechanism design review | `docs/send_message_gate_review_2026-08-08.md` (Q1–Q6 for a function, not a table: **function security** — `security definer` + pinned `search_path`, so the in-function gate IS the sole write authorization; D-SM1 = the exact `messages_insert_assigned` three-way org check re-asserted; Q3 = `write_audit('message:create','allowed',…)` §8 coverage closing the realtime-push review-Q6 gap; Q4 = org resolution moves into the function; Q6 = **D-SM3 revoke the direct INSERT grant + drop the policy**, with the 09-battery re-scope consequence named) | `7759181` |
| T2 — rehearsal-ready artifact (NOT applied) | `supabase/rpc/send_message.sql` + `rpc/_down.sql` entry — the gate → `write_audit` → INSERT → `returning id` unit, author from `profiles` (D-RT4); **live-validated on the rehearsal stack** (both assigned positives with the stored author, all five denies via the in-function RAISE, anon no grant, empty-body CHECK, backout round-trip drop/re-apply) | `60dae71` |
| T3 — battery + harness | NEW `supabase/tests/10_send_message_rls.sql` (10 checks: attorney + client send positives with the D-RT4 stored author, the §8 audit-row shape positive, the in-function deny rows ×5, empty-body CHECK through the RPC, the §8 negative) + the **09 battery re-scoped** (publication pins, privileged empty-body, extended delivery equivalence, **D-SM3 revocation pins 09.15/09.16**) + the `send_message.sql` D-SM3 revocation tail; harness: §1d RPC-EXECUTE 18→19, policy pin 11→10, selftest glob; static `--check` **337/0/0**, live battery **74/0/0**, selftest 6/6 | `b013ee5` |
| T4 — rehearsal r1 | **Genuinely executed** battery on the Docker-backed scratch stack (fresh-schema reset first — the `--apply` targets a fresh project): **`== summary: 74 passed, 0 warnings, 0 failures ==` / `RESULT: PASS`**, pins 11 tables / 11 RLS / **10 policies** / publication exactly messages / **19 EXECUTE RPCs** / authenticated INSERT revoked; evidence `docs/send_message_rehearsal_evidence_r1_2026-08-08.md` **PASSED** | `8df7e47` |
| T5 — dated apply gate | `docs/send_message_apply_approval_2026-08-08.md` **DRAFT** — preconditions (r1 PASSED `8df7e47`), the §3 apply plan (`send_message.sql` as ONE apply unit — function + EXECUTE grant + D-SM3 revocation; the demo send via the RPC as the assigned partner on the acquisition thread with the audit row observed), §4 guardrails (baseline probe policies 10→9 + INSERT-true→false + send_message-absent trigger conditions, rollback pairing), §5 exclusions | `a5db0af` |
| T6 — dated matrix addendum | the **"Send a message"** row's mechanism note → the audited RPC (D-SM1 gate, D-SM3 revocation recorded, policies 10→9 on apply; client/attorney SHIP now via the RPC, partner/`compliance_officer` stay ungranted, `platform_owner_admin` deny always); the §8 gap closes the realtime-push review-Q6 caveat | `ea74c63` |
| T7 — env-gated client swap | seam `sendMessage` → `send_message` RPC (D-SM2) + gateway re-read resolution + failure mapping + tests (fake untouched) | `f874a57` |
| T8 — lockstep + evidence + close | README count lockstep (1044 — see §7), roadmap §2 row + §14 eighth flip + §13 gate-table row + Phase 10/11/12 cross-refs, this record, dated close decision | this commit |

## 2. Verified (actually run, 2026-08-08)

### 2.1 Final gate on the committed T7 state (`f874a57`; T8 is docs-only and re-swept the ledger)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` (whole repo, CI-exact) | **PASS — 0 changed** (300 files) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **1047 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 1044 in lockstep) |
| `scripts/verify_policy_tests.sh --check` (static battery) | **PASS 337/0/0** (the 10 battery + the re-scoped 09 landed at T3) |
| Live battery (rehearsal, genuinely executed) | **`== summary: 74 passed, 0 warnings, 0 failures ==` / `RESULT: PASS`** (T4, evidence `8df7e47`; selftest 6/6; pins 11/11/10/1/19) |

### 2.2 Server-side verification (rehearsal stack only — genuinely executed, NOT the dev project)

- **Artifact live-validated (T2, `60dae71`):** `send_message` applied to
  the scratch stack and exercised by role-impersonated calls — assigned
  attorney (partner-a, thread 1) sent id `1c098531-…`; assigned client
  (client-a) sent id `443461ce-…`; each send wrote the **§8 audit row**
  (`message:create/allowed`, actor, **resource_id = message id**, redacted
  summary `message sent`); the five denies (stranger / org-role-alone /
  cross-org / suspended / owner) all hit the **in-function RAISE**
  (`ERROR: permission denied`); anon has no grant; the empty body hit the
  `messages_body_check` CHECK with nothing written; the backout
  round-trip (drop → function + grants gone, re-apply → restored)
  verified. Demo + audit rows cleaned afterward.
- **Battery genuinely executed (T4, `8df7e47`):** the scratch `public`
  schema was reset first (43 objects cascaded — `--apply` targets a fresh
  project; the accumulated stack's create-table migrations reject on
  re-run), then the rehearsal ran from the committed files: `--apply` **40
  passed / 0 failures** (including the D-SM3-carrying `send_message.sql`
  as one apply unit), battery **74/0/0**, pins probed independently (11
  tables / 11 RLS / 10 policies / publication exactly messages / 19
  EXECUTE RPCs / authenticated INSERT **revoked**).
- **The T5 apply executed the same day** (owner's dated §6 sign-off →
  APPLY APPROVED → `docs/send_message_apply_execution_2026-08-08.md`
  **APPLIED**): `send_message` + the D-SM3 revocation live on the dev
  project — policies 10→9, `authenticated` INSERT revoked,
  `messages_insert_assigned` dropped, the demo send `1c031882-…` via
  the RPC with the **§8 audit row observed** (`message:create/allowed`,
  actor = the partner, resource id = the returned id, redacted `message
  sent`). The §8 gap the slice closes is closed there, exactly as the T6
  addendum records; one finding recorded (the author is the account's
  stored display name — an email — owner-side account hygiene, D-RT4
  honored; not a revert).

### 2.3 Test coverage added by the client swap (+2 declarations, suite 1042 → 1044 declaration; 1045 → 1047 runtime)

- `supabase_message_api_impl_test` (+1): the sendMessage group rewritten
  to the RPC — **the RPC-call pin** (function name + the named params
  `p_thread_id`/`p_body` and their values, with **no org pre-read** and
  **no author** — the D-SM2 point), the id-parse happy path, the
  **in-function denial** (`permission denied` → denied kind), unknown
  preserved with the message, non-Postgrest → providerUnavailable (raw
  throw from the injected caller), and the no-id loud failure
  (`send_message returned no id.`).
- `supabase_message_gateway_test` (+1): the sendMessage group rewritten to
  the re-read — **the VO maps from the re-read row, and the VO author is
  the server-derived stored author, NOT the passed `authorDisplayName`**
  (the D-SM2 honesty pin), plus the absent-on-re-read and malformed-row
  loud `message_send_failed` cases and the unchanged failure-kind mapping
  (denied / unavailable / unknown).
- `service_locator_test` (0): the `_FakeSupabaseMessageApi` seam signature
  updated to the new `Future<String> sendMessage` at compile level; the DI
  flip pins unchanged (gateway constructed with the seams behind
  `env.isConfigured`).

  Per-file sums: 1 + 1 + 0 = **2 declarations** — matching the ledger
  lockstep 1042 → 1044 (suite 1045 → 1047 runtime; equal deltas this
  slice, so the `blocTest<>` expansion convention nets zero spread).

## 3. Pending (honestly NOT run — do not read as verified)

- **No live configured-build send round-trip on a device/emulator** — all
  client verification is the typed/fake test suite + DI pins (the D-45.1
  Phase 2 convention; needs `.env`, git-ignored). The real RPC call and
  the real §8 audit row on the dev project are only observable after the
  apply + a configured build.
- **Insert-only** — no edit / delete / attachments / receipts (unchanged
  from D-LV1); the composer is the minimal send path.
- **No push** — `feat/send-message-rpc` is ahead of `origin`; push awaits
  owner approval.

## 4. Acceptance-criteria status (plan §7/T8 done-when)

| Criterion | Status | Evidence |
|---|---|---|
| Mechanism review answers the write-path authorization question (RLS does not apply inside a definer function → the in-function gate IS the sole authorization) | **VERIFIED** | `7759181`: Q1/Q2 — `security definer` + pinned `search_path` + the exact `messages_insert_assigned` three-way org check re-asserted (D-SM1) |
| Rehearsal-ready artifact live-validated on the rehearsal stack (positives, denies, anon, CHECK, backout) | **VERIFIED** | `60dae71`: 9 role-impersonated checks genuinely executed (both positives + the audit row, five denies, anon, empty-body, drop/re-apply) |
| Battery pins the RPC write path + the D-SM3 revocation; harness RPC-EXECUTE 18→19, policies 11→10 | **VERIFIED** | `b013ee5`: 10 battery (10 checks) + 09 re-scope (09.15/09.16 revocation pins); static `--check` 337/0/0; live 74/0/0 |
| Rehearsal r1 genuinely executed green with the pins verified | **VERIFIED** | `8df7e47`: 74/0/0, RESULT: PASS, pins 11/11/10/1/19, selftest 6/6 |
| Dated matrix addendum (mechanism note → audited RPC, D-SM3 recorded) precedes the client surface | **VERIFIED** | `ea74c63` (T6) < `f874a57` (T7) |
| Env-gated client swap (seam → RPC with no org pre-read + no client author; gateway resolves the VO via the shipped read; fake untouched) | **VERIFIED** | `f874a57`: impl RPC-call pin, gateway re-read mapping (VO author from the server row), DI pins; fake unchanged; suite green |
| README count lockstep; roadmap §2 row + §14 eighth flip + §13 row; ledger PASS on the committed state | **VERIFIED** | §2.1; README 1044; §6; this commit |
| Full gate on the client slice; ledger PASS | **VERIFIED** | §2.1; PASS 115 |

## 5. Exact commands (as run — reproducible)

```bash
# T2 — live artifact validation (rehearsal stack; see the r1 record §3)
#     role-impersonated send checks + audit-row probes + backout round-trip,
#     via the psql shim into the Docker container
# T3 — static + live battery (scratch Docker stack + psql shim)
bash scripts/verify_policy_tests.sh --check          # -> 337/0/0
bash scripts/verify_policy_tests.sh --selftest       # -> 6/6
# T4 — rehearsal (fresh-schema reset, then the genuine cycle)
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_policy_tests.sh --apply        # -> 40/0/0
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_policy_tests.sh                # -> 74/0/0, RESULT: PASS
# T5 — apply on the dev project (OWNER-GATED, HELD — not run)
# T7 — client gate
dart format --output=none --set-exit-if-changed .    # whole-repo, CI-exact
flutter analyze                                      # No issues found
flutter test                                         # 1047 passed
bash scripts/verify_ledger.sh                        # PASS 115
```

## 6. Ledger impact

README test count **1042 → 1044** across the slice in lockstep with the
ledger's declaration count (suite 1045 → 1047 runtime; equal +2 deltas
this slice). The ledger's README-count check (both the `Tests (N total)`
marker and the `**N tests**` marker) caught the drift on the uncommitted
T7 state before the commit — the count was updated in the same commit
(`f874a57`) so the gate claim is true of what ships. Final state
`scripts/verify_ledger.sh` **PASS 115/0/0**. The docs all sweep green
with the resolved commit refs.

## 7. Review findings — resolved (not papered over)

- **T1 design review named a real consequence the plan implied but had
  not:** dropping `messages_insert_assigned` (D-SM3) breaks the 09
  battery's ~10 role-impersonated INSERT-policy checks — they had to
  re-scope to EXECUTE checks + the revocation pin in the same slice
  (09.15 privilege-layer deny, 09.16 policy gone), policies 11→10. The
  review recorded this before any artifact existed (`7759181`).
- **T2 live validation proved the author source and the gate behavior on
  real rows:** the stored author came from `profiles` ("Partner A" —
  D-RT4), the audit row carried the actor + message resource id + redacted
  summary, and all five deny roles hit the in-function RAISE — none of
  which the battery could claim without a live run (`60dae71`).
- **T4 rehearsal ran from a genuinely fresh schema, not the accumulated
  stack:** the first `--apply` on the accumulated scratch stack rejected
  (the migrations create tables without `IF NOT EXISTS`; `--apply`
  targets a fresh project). Per never-fix-forward, the scratch `public`
  schema was reset first (43 objects cascaded, rebuilt from the committed
  files; `auth`/`storage` untouched), then the rehearsal ran clean —
  40/0/0 apply, 74/0/0 battery, pins verified (`8df7e47`).
- **T5 honest hold → executed:** the apply-approval record shipped
  **DRAFT** (never claimed applied), the §14 flip note and §2 row carried
  the explicit HELD marker so no reader could mistake the rehearsal state
  for the applied state; the owner's dated §6 sign-off then closed the
  gate and the apply executed the same day
  (`docs/send_message_apply_execution_2026-08-08.md` — policies 10→9,
  INSERT revoked, demo send `1c031882-…` with the §8 audit row
  observed), with one finding recorded and **resolved the same day**:
  the author was the account's stored display name (an email — D-RT4
  honored, not a revert); generic demo display names were set on the two
  dev profiles (`Demo Partner` / `Demo Client`, verified via the RPC's
  exact author SELECT) — see the execution record §5.
- **T7 ledger catch (count accuracy):** the final ledger sweep on the
  uncommitted T7 state caught the README count at 1042 while the ledger's
  git-grep declaration count on the tree was 1044 — the README was updated
  **in the same commit** (`f874a57`) so the committed bytes match the gate
  claim (the realtime-push T7 lesson applied: run the ledger on the exact
  bytes that get committed).

## 8. Owner attention needed

- **Sign the T5 apply-approval (§6 of
  `docs/send_message_apply_approval_2026-08-08.md`) to execute the server
  apply** — `send_message` + the D-SM3 revocation (policies 10→9, §8
  audit by construction, the demo send via the RPC with the audit row
  observed). Until then the dev project's write path stays the direct
  INSERT and the env-gated client flip is inert in configured builds.
- **Push approval:** `feat/send-message-rpc` is ahead of `origin`; the
  slice's commits (`7759181` T1, `60dae71` T2, `b013ee5` T3, `8df7e47`
  T4, `a5db0af` T5-DRAFT, `ea74c63` T6, `f874a57` T7, this T8) await
  your push approval.
- **Configured-build verification (D-SM2):** the real RPC round-trip
  (and the §8 audit row on the dev project) needs the apply + a
  configured build (`.env`, git-ignored) — the D-45.1 convention.
- **Remaining §14 deferred paths:** billing (spec D-09 — payment
  provider/tax/PCI, open; not the decided p0 D-09 role semantics) and AI
  (no scope) — the deferred list now narrows to those two; each keeps the
  same per-feature discipline (reconciled 2026-08-08 in
  `docs/send_message_rpc_plan_2026-08-08.md`).

## 9. Dated close decision

**Audited message send (send-message) slice — CLOSED 2026-08-08 (client
surface).** T1–T4, T6–T7 met their gates: the mechanism design review
answered the write-path authorization question (`security definer` means
RLS does not apply inside the function, so the D-SM1 in-function gate IS
the sole write authorization) and designed the §8-audited RPC closing the
realtime-push review-Q6 gap; the `send_message` artifact was
**live-validated on the rehearsal stack** (positives, all five denies,
anon, empty-body CHECK, backout round-trip); the battery + harness pinned
the RPC write path and the D-SM3 revocation (static `--check` 337/0/0,
live 74/0/0, §1d RPC-EXECUTE 18→19, policies 11→10) and the **rehearsal
battery was genuinely executed green from a fresh schema**; the dated
matrix §4 addendum moved the "Send a message" row's mechanism note to the
audited RPC before the client surface; and the env-gated swap shipped —
the seam calls `send_message` with no org pre-read + no client author
(D-SM2), the gateway resolves the [Message] VO through the shipped read,
fake untouched — with the full gate green on the committed state (format
PASS · analyze clean · suite 1047 runtime / README 1044 · ledger PASS
115, the README 1042→1044 drift caught by the final sweep and fixed in
the same commit). **The T5 server apply executed the same day** (owner's
dated §6 sign-off → APPLY APPROVED →
`docs/send_message_apply_execution_2026-08-08.md` **APPLIED**: policies
10→9, INSERT revoked, the demo send `1c031882-…` via the RPC with the
§8 audit row observed) — the §8 gap is closed on the dev project and the
§14 send-message row flips to per-feature SHIPPED with the write path
now the audited RPC. **Nothing pushed**;
billing (D-09) and AI stay deferred each behind their own future
per-feature un-deferral.
