# Plan: Realtime — Live Delivery (postgres_changes Push) (the seventh §14 un-deferral) (2026-08-08)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> seventh slice under the roadmap §14 blanket-deferral, mirroring the
> **matters, documents, messages, storage** read slices (SHIPPED) + the
> **audit surfacing** client-only slice (fifth) + the **realtime read**
> slice (sixth, SHIPPED 2026-08-08) — the same per-feature discipline
> applied to the **push half** of the roadmap's realtime entry: live
> delivery of `messages` rows via **`postgres_changes`** (publication
> membership + Realtime RLS + the client subscription lifecycle incl.
> reconnect + backfill), the slice the sixth un-deferral's **D-RT6**
> explicitly recorded as its natural next step ("gets its own mechanism
> review + dated approval"). **Docs-only planning — zero dev-project
> effect**: nothing in this document applies anything to the dev Supabase
> project; every external step stays behind the owner's dated approval
> (INSTRUCTIONS.md §2.1/§5 hard gates).
>
> **Gate state (why this slice is now plannable):** the §14 precondition
> chain ran green **six times** (P0 RATIFIED + policy battery shipped;
> matters/documents/messages/storage server slices applied + client-swapped;
> audit surfacing closed the RPC surface 18-of-18; realtime read closed the
> body row). The remaining §14 list after the sixth flip is **billing, AI**
> — reconciled 2026-08-08:
> - **Live delivery (postgres_changes push)** — the D-RT6 recorded
>   follow-up; its dependency (`messages` table + `messages_select_assigned`
>   SELECT policy) is **applied on the dev project** (realtime read T5) and
>   battery-pinned. **Picked.**
> - **Billing** — gated on D-09 (no live payment in MVP); external payment
>   provider decisions; not a metadata slice. Stays deferred.
> - **AI** — no matrix rows, no spec basis; product scope undefined. Stays
>   deferred.
>
> **Scope honesty — what live delivery means here, and the one scope
> question this plan answers up front:** postgres_changes with the INSERT
> event delivers **new rows** — and this repo has **no message write path**
> (the read slice explicitly shipped "no composer, no send/reply", D-RT5).
> A subscription channel with no write source delivers nothing, so the push
> slice is only meaningful **paired with the minimal INSERT source**: the
> `messages_insert_assigned` write policy + `sendMessage(threadId, body)`
> on the messaging seam + a composer on the thread-detail surface — the
> read slice's recorded follow-up, consummated here as the event source
> (**D-LV1** below; the owner may amend). Everything else about the write
> path (edit/delete/receipts/attachments) stays out of scope.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Move **live message delivery** from "structurally absent" (the harness
forward pin asserts `pg_publication_tables` = 0 for `messages`; the client
has no subscription surface) to a real, RLS-gated `postgres_changes`
channel: when a **new** message row is written to a thread the reader is
assigned to (client or attorney, active member), the reader's open
thread-detail surface **receives it live** (appended to the loaded list);
a reader with no access to the thread/matter **receives nothing** (the
matrix §6 "Realtime subscription for an org/matter the session no longer
has access to → No events delivered" row, now enforced + battery-tested).
"Done" = the `messages` table is the **only** table in the
`supabase_realtime` publication; delivery is gated by the **existing**
`messages_select_assigned` policy via **Realtime RLS** (no new
authorization surface — verified mechanism, §3 D-LV3); the client
subscribes per-thread with a `thread_id=eq.…` filter, reconnects on
disconnect, and backfills via the existing `fetchMessages` read; the
minimal **send** path (D-LV1) is the event source; env-less runs + the
whole test suite still run on the fake. The forward pin re-scopes from
"live delivery absent" to "messages in the publication, nothing else"
(D-LV5 — D-P0C1(b) keeps its teeth: no accidental table exposure via
realtime).

## 2. Gap (verified)

- **The harness pins live delivery absent.** `scripts/verify_policy_tests.sh`
  §1f: `expect_eq "live delivery STILL absent (messages in no publication)"
  "$(run_sql "select count(*) from pg_publication_tables where schemaname =
  'public' and tablename = 'messages';")" "0"` — and the header comment
  reads "live delivery still absent" (re-scoped at realtime-read T3). This
  slice flips that pin to **present** and re-scopes it (D-LV5).
- **No client subscription surface exists.** `SupabaseMessageApi`
  (seam/impl/gateway/fake) carries `fetchMessageThreads` + `fetchMessages`
  only; `supabase_flutter` is already a dependency (the table seam binds
  `Supabase.instance.client`), so the Realtime client (`client.channel(...)`
  `.onPostgresChanges(...)`) needs a NEW seam — provider types stay in one
  file (the established seam discipline), and env-less runs/tests keep a
  deterministic fake.
- **No write path — the honest event-source gap.** The read slice shipped
  "no composer, no send/reply" (D-RT5) and recorded the write path as a
  follow-up; a `postgres_changes` INSERT channel without an INSERT source
  is a dead channel. This plan pairs the subscription with the **minimal
  send** (D-LV1) as the event source — the write path consummated **only**
  to the extent live delivery needs it (insert-only, same gate, no edit/
  delete/attachments/receipts).
- **The mechanism is verified, not guessed.** Supabase's **Realtime RLS**
  makes `postgres_changes` adhere to the underlying table's RLS SELECT
  policies (Supabase docs + Aug 2024 blog: "Postgres Changes already
  adheres to RLS policies on the underlying table"): the **existing
  `messages_select_assigned` policy IS the delivery gate**, and the
  per-thread `thread_id=eq.…` filter narrows delivery to the open thread.
  The D-RT6 read-plan caution ("realtime RLS on publications ≠ table
  SELECT RLS") resolves to: publication membership is the *enablement*,
  Realtime RLS is the *authorization*, and both are battery-pinnable. The
  `realtime.messages` authorization table is the **Broadcast/Presence**
  path — not needed for postgres_changes.
- **The §6 matrix row exists but is unenforced.** `docs/permission_matrix.md`
  §6: "Realtime subscription for an org/matter the session no longer has
  access to → No events delivered" — recorded as a contract row, never
  battery-tested (no publication existed). This slice makes it enforceable
  and pins it.
- **No consumer pressure beyond the shipped read surface** — the
  thread-detail screen (realtime read T7) is the subscription consumer; the
  composer (D-LV1) is its natural complement.

## 3. Design decisions (D-LV1…D-LV6 — recommended path, ratified by autonomy 2026-08-08 per the pair-programming grant; each is a one-line-reasoned choice, owner may amend)

| # | Decision | Recommendation | Why / alternative |
|---|---|---|---|
| D-LV1 | **Write source (the scope question)** | **Minimal send path as the event source**: `messages_insert_assigned` INSERT policy (same gate as the read policy: active member of the row's org AND exists through thread → matter with the three-way org equality AND assigned client/attorney; the `body` non-empty CHECK stays schema-level) + `sendMessage(String threadId, String body)` on the messaging seam + a composer on the thread-detail screen. **Insert-only** — no edit/delete/attachments/read-receipts. The read slice's recorded "no composer" follow-up, consummated here because a push slice without a write source delivers nothing | The honest event-source gap (§2); alternative (subscription only, no send) would ship a channel that can never fire — untestable and meaningless |
| D-LV2 | **Publication scope** | **Exactly `messages` in the `supabase_realtime` publication, nothing else** — `alter publication supabase_realtime add table messages;` (the publication exists by default on Supabase projects; the migration records the delta). The harness pins `pg_publication_tables` = **1** (messages only) | The forward pin keeps D-P0C1(b) teeth — no accidental table exposure via realtime; adding any other table would trip the pin |
| D-LV3 | **Delivery authorization** | **Realtime RLS — the existing `messages_select_assigned` SELECT policy IS the delivery gate.** No new policy for delivery; the §6 "Realtime subscription for an org/matter the session no longer has access to → No events delivered" row becomes enforced + battery-tested (role-impersonated: a suspended/removed/cross-org reader's channel delivers nothing). The per-thread `thread_id=eq.…` filter narrows the channel | Verified mechanism (Supabase Realtime RLS: postgres_changes adheres to the underlying table's SELECT policies); resolves D-RT6's surface caution — publication membership is enablement, Realtime RLS is authorization, both pinned |
| D-LV4 | **Client subscription lifecycle** | **NEW `MessageRealtimeApi` seam** (channel + `postgres_changes` subscription, `thread_id=eq.<id>` filter; `onError`/`onSystemMessage` → reconnect; **initial backfill = the existing `fetchMessages` read** on subscribe) + `MessageThreadDetailCubit` appends live INSERT rows to the loaded list (dedupe by id). Provider types (RealtimeChannel) stay in one file; env-less runs/tests use a deterministic fake channel | The seam discipline (provider types never cross the boundary); backfill via the shipped read avoids a second fetch mechanism; the cubit owns the merged list |
| D-LV5 | **Battery + forward pin** | New `supabase/tests/09_realtime_push.sql` (publication-membership pin: messages in `supabase_realtime`, count 1, nothing else; the INSERT-policy deny rows — org-role-alone / cross-org / suspended / owner / anon denied, empty body rejected by the CHECK; the assigned-write positive; the §6 delivery-gate negative) + harness edits (file list, run loop, `--apply` order gains `09_realtime_push.sql`, pins **10→11 policies** — the INSERT policy — and the **forward pin re-scopes**: `pg_publication_tables` for messages 0→1, re-scoped to pin "messages present + exactly one publication row") | Tables/RLS stay 11/11 (no new table); policies 10→11; the forward pin's teeth move from "live delivery absent" to "nothing else in the publication" |
| D-LV6 | **Seeding + smoke** | The apply step (owner-approved) sends one demo message as the assigned partner (the INSERT policy positive, live) and records the observed event delivery; rollback pairing = `09_realtime_push.down.sql` (`alter publication supabase_realtime drop table messages;`) + the policy commit git-revert + the demo row delete | Mirrors the six prior applies; the demo send is the first live INSERT in the slice history — recorded verbatim, rollback standing by, never fix-forward |

**Non-decisions (flagged, not guessed):** **Broadcast/Presence** (the
scalability path with the `realtime.messages` authorization table — out of
scope; postgres_changes is simpler and RLS-adherent, and this app's
per-thread scale is small); message **edit/delete/attachments/read-receipts**
(insert-only write path); the partner/`compliance_officer` "deny unless
separately assigned" oversight rows (mechanism undefined — mirrors
D-MR5/D-DR5/D-MSR5/D-STR6); **billing** (D-09) and **AI** (no scope) stay
deferred.

## 4. Layers touched

- **Server (rehearsal → apply, gated):** `supabase/migrations/09_realtime_push.sql`
  (+ `09_realtime_push.down.sql`), `supabase/policies/messages_insert.sql`,
  `supabase/tests/09_realtime_push.sql`, `scripts/verify_policy_tests.sh`
  (battery file list + run loop + `--apply` order + policy pin 10→11 +
  forward-pin re-scope to messages-in-publication + exactly-one-publication-row).
- **Matrix (§7 discipline):** `docs/permission_matrix.md` — a dated §4
  addendum for the **write** row (client/attorney send SHIP behind
  `messages_insert_assigned`; partner/`compliance_officer` "deny unless
  separately assigned" stay ungranted; `platform_owner_admin` deny always)
  + a dated §6 addendum flipping the **"Realtime subscription for an
  org/matter the session no longer has access to → No events delivered"**
  row to enforced (Realtime RLS = the existing SELECT policy; battery-pinned).
- **Client (env-gated swap, D-LV4):** `lib/data/messaging/supabase_message_realtime_api.dart`
  (NEW seam) + `supabase_message_realtime_api_impl.dart` + a
  `MessageRealtimeGateway` (or the seam folds into the existing gateway —
  T7 decides the minimal surface), `sendMessage` on `MessageGateway`/fake,
  `MessageThreadDetailCubit` subscription wiring (live append + reconnect +
  backfill), the thread-detail **composer** (D-LV1), `lib/app/service_locator.dart`
  DI flip behind `env.isConfigured`, 3 `.arb` + generated l10n.
- **Docs (per-slice):** design review, rehearsal + apply-approval/execution
  records, completion evidence, roadmap §14 seventh flip + §13 gate-table
  row, plan task rows.

## 5. Risks + mitigations

- **Live INSERT with no real users:** the only dev member is the partner
  demo account; live delivery is demonstrated by the apply-time demo send
  (D-LV6) and the battery's role-impersonated checks — never claimed beyond
  what is actually observed (INSTRUCTIONS.md §1.3 #5).
- **Realtime RLS version drift:** older hosts/CLI stacks may not enforce
  Realtime RLS the same way. Mitigation: the rehearsal battery runs against
  the real Docker stack (the read slice T4 precedent — now executable in
  this session); the §6 negative row is pinned role-impersonated, so a
  non-enforcing host would trip the pin loudly at rehearsal, never silently
  at apply.
- **Channel lifecycle flakiness in tests:** the cubit's live-append logic is
  tested with a deterministic fake channel (no real sockets in the suite);
  the real reconnect/backfill path is the T7 configured-build verification
  (honest pending, not claimed by unit tests).
- **Write-path creep:** the insert-only line (no edit/delete/attachments/
  receipts) is enforced structurally (no UPDATE/DELETE policy, no columns)
  exactly like the read slice's body-less line.
- **Rollback:** `09_realtime_push.down.sql` drops the publication
  membership (the INSERT policy dies with its table only if the table
  drops; otherwise the policy commit git-reverts) — standing by, never
  fix-forward.

## 6. Rehearsal plan (T4 — ephemeral-only, r-series)

The read slice's T4 established that this session can execute the battery
(Docker-backed `supabase start` scratch stack + psql shim). The live-
delivery rehearsal runs the same loop on the committed files:
`SUPABASE_TEST_DB_URL=… scripts/verify_policy_tests.sh --apply` (now
gaining `09_realtime_push.sql` + `messages_insert.sql`), then the full
battery (pins: 11 tables / 11 RLS / **11 policies**, messages-in-publication
count **1**, nothing else; the 09 checks incl. the §6 delivery-gate
negative). Results recorded in
`docs/realtime_push_rehearsal_evidence_r1_2026-08-08.md`, flipped PASSED —
nothing applied.

## 7. Apply gate (T5) + rollback

Owner's dated sign-off on `docs/realtime_push_apply_approval_2026-08-08.md`
(the r1 PASSED + §4 guardrails precedent) → apply to the dev project:
baseline probe (publication empty, policies 10) → `09_realtime_push.sql`
→ `policies/messages_insert.sql` → **one demo send** as the assigned
partner (D-LV6, the first live INSERT — observed output verbatim in
`docs/realtime_push_apply_execution_2026-08-08.md`) → post-apply smoke
(publication count 1, INSERT policy present, the §6 negative holds).
Rollback pairing standing by; no fix-forward.

# Tasks: Realtime — Live Delivery (postgres_changes Push)

Branch: `feat/realtime-push` (server-heavy T1–T6 — the four-slice branch
discipline; T7–T8 build on the merged base). Each task is independently
committable with the stated verification; the apply gate (T5) is the only
owner-gated step. T2–T4 are server artifacts — **no dev-project change
until T5**.

- [x] **1. Mechanism design review** — touches: this document + a
  `docs/realtime_push_gate_review_2026-08-08.md` (§8-style Q1–Q6 for live
  delivery: the publication + Realtime RLS mechanism, D-LV3 delivery gate =
  the existing SELECT policy, the D-LV1 write source, the D-LV4 client
  lifecycle, rollback, the forward-pin re-scope to
  messages-present + exactly-one-publication-row) — done when: docs
  committed, ledger sweep green (no dev-project contact). — **DONE (this
  commit, 2026-08-08)** — the review answers Q1–Q6 for the mechanism: Q1
  postgres_changes via the default supabase_realtime publication (exactly
  messages, D-LV2); Q2 Realtime RLS — the existing messages_select_assigned
  policy IS the delivery gate (verified mechanism; the D-RT6 surface
  caution resolves to publication=enablement + RLS=authorization, both
  pinned; the §6 negative row becomes enforceable); Q3 the D-LV1 minimal
  send path as the honest event source (insert-only, same gate); Q4 the
  MessageRealtimeApi seam + backfill via fetchMessages (real reconnect is
  configured-build pending, never claimed); Q5 no owner carve-out, the
  oversight rows stay ungranted; Q6 the direct-INSERT path is not
  contract §8-audited — recorded honestly, a future audited send RPC
  flagged. §4 pins the INSERT policy + deny rows (org-role-alone,
  cross-org, suspended, owner, anon, empty-body CHECK, the assigned
  positive, the delivery-equivalence negative); §5 the 09 migration
  (publication membership only, no new table) + the forward-pin re-scope
  (pg_publication_tables messages 0→1, policies 10→11); §6 rollback
  pairing; ledger PASS 115, no dev-project contact.
- [x] **2. Schema artifacts (rehearsal-ready, NOT applied)** — touches:
  `supabase/migrations/09_realtime_push.sql` (+ `09_realtime_push.down.sql`),
  `supabase/policies/messages_insert.sql` — done when: the migration adds
  exactly `messages` to `supabase_realtime` (D-LV2), the down is the clean
  inverse (`drop table` membership), the INSERT policy mirrors the read
  gate (D-LV1), committed. — **DONE (this commit, 2026-08-08)** —
  09_realtime_push.sql (publication membership only — the guard-create is
  a `do`-block because CREATE PUBLICATION has no IF NOT EXISTS form, a
  syntax error the live rehearsal caught and fixed; D-LV2 exactly-messages)
  + a clean idempotent `_down.sql` (membership drop guarded by a
  `pg_publication_tables` check) + policies/messages_insert.sql
  (`messages_insert_assigned`, D-LV1 — the read gate applied as WITH
  CHECK; **the INSERT grant added after a live finding: 08 granted SELECT
  only, so a policy without the grant never fires**). **Verified live on
  the rehearsal Docker stack** (not just statically): up/down/up
  round-trip (membership exactly `messages`, 1→0→1); the INSERT policy
  gates live — assigned attorney-a INSERT allowed (INSERT 0 1), stranger
  INSERT denied (new row violates row-level security policy), org-role-
  alone INSERT denied (org-a member, unassigned on the matter). Battery
  static `--check` 333/0/0 (09 not yet listed — T3) + ledger PASS 115;
  NOT applied to the dev project.
- [x] **3. Policy battery** — touches: `supabase/tests/09_realtime_push.sql`
  + `scripts/verify_policy_tests.sh` (file list, run loop, `--apply` order
  gains `09_realtime_push.sql`, policy pin **10→11**, forward pin re-scoped
  to **messages in the publication count 1 + nothing else**) + the §6
  delivery-gate negative as a role-impersonated check — done when: battery
  green against a Postgres (the read slice's executable-T4 precedent),
  committed with the static `--check` green. — **DONE (this commit,
  2026-08-08)** — `supabase/tests/09_realtime_push.sql` (12 checks: the
  publication-membership pins 09.01/09.02 — messages in `supabase_realtime`
  count 1 + the publication holds nothing else, D-LV2/D-P0C1(b) teeth; the
  INSERT positives 09.03/09.04 — assigned attorney/client on thread 1
  persist, rolled back; the INSERT deny rows 09.05–09.09 — org-role-alone /
  cross-org / suspended / owner / anon, each a live RLS-violation catch;
  09.10 the empty-body CHECK; 09.11/09.12 the delivery-equivalence pair —
  the assigned reader sees the delivered row, suspended/cross-org/owner see
  0, the §6 matrix row enforced) + harness edits (file list, run loop,
  `--apply` order gains `09_realtime_push.sql`, policy pin **10→11**,
  forward pin re-scoped **0→1** to messages-in-publication count 1 +
  exactly-one-publication-row, selftest fixture glob 0[1-8]→0[1-9], header
  + apply comments). **Verified live on the rehearsal host 2026-08-08: full
  battery 72 passed / 0 warnings / 0 failures (09 green), static `--check`
  335/0/0, selftest 6/6.**
- [ ] **4. Ephemeral rehearsal (r-series)** — touches: evidence record
  `docs/realtime_push_rehearsal_evidence_r1_2026-08-08.md` — done when: the
  loop (migrate → policy → battery → read-as-roles → the §6 negative)
  passes on throwaway infra with zero dev-project contact (this session's
  Docker precedent).
- [ ] **5. Dated apply-approval → apply** — touches: dev project
  (publication + INSERT policy + demo send), `docs/realtime_push_apply_approval_2026-08-08.md`
  + `docs/realtime_push_apply_execution_2026-08-08.md` — done when: the
  owner's dated approval exists, apply executed with the down-pairing +
  cleanup (the first live INSERT observed verbatim), rollback standing by.
- [ ] **6. Matrix addenda (dated)** — touches: `docs/permission_matrix.md`
  §4 (the write row: client/attorney send SHIP behind
  `messages_insert_assigned`; partner/`compliance_officer` ungranted;
  `platform_owner_admin` deny always) + §6 (the "Realtime subscription for
  an org/matter the session no longer has access to → No events delivered"
  row → **enforced**, Realtime RLS = the existing SELECT policy,
  battery-pinned) — done when: addenda committed **before** the client
  surface ships, ledger sweep green.
- [ ] **7. Client swap (env-gated, NEW subscription + composer)** — touches:
  `lib/data/messaging/supabase_message_realtime_api.dart` (NEW seam) +
  impl + gateway (`sendMessage` + subscribe), `fake_message_gateway.dart`
  (deterministic send + a fake channel), `message_thread_detail_cubit.dart`
  (live-append + reconnect + backfill via `fetchMessages`), the thread-detail
  composer (D-LV1), `lib/app/service_locator.dart` (env flip), 3 `.arb` +
  generated l10n, tests (seam/impl columns + filter pin, gateway mapping +
  failure, cubit live-append/dedupe/reconnect, widget composer, DI pins) —
  done when: format clean · analyze clean · suite green (fake unchanged) ·
  ledger PASS.
- [ ] **8. Lockstep + evidence + close** — touches: README test count,
  roadmap §14 seventh per-feature flip + §13 gate-table row (the deferred
  list narrows to **billing/AI**), completion evidence
  `docs/realtime_push_real_data_completion_evidence_2026-08-08.md`, dated
  close decision — done when: all docs sweep green, full gate re-run on the
  committed state, close decision recorded.
