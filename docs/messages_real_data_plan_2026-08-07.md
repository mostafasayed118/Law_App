# Plan: Real Messages (Read) Data Path — the third §14 un-deferral (2026-08-07)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> third slice under the roadmap §14 blanket-deferral, mirroring the
> **matters** and **documents** read slices (plans
> `docs/matters_real_data_plan_2026-08-07.md` and
> `docs/documents_real_data_plan_2026-08-07.md`, both SHIPPED 2026-08-07) —
> the same per-feature discipline, applied to message **thread metadata**.
> **Docs-only planning — zero dev-project effect**: nothing in this document
> or its TASKS applies anything to the dev Supabase project; every external
> step stays behind the owner's dated approval (INSTRUCTIONS.md §2.1/§5 hard
> gates).
>
> **Gate state (why this slice is now plannable):** the §14 precondition is
> **met at the decision level and proven by precedent twice** — P0 closure
> RATIFIED (`docs/p0_closure_scope_2026-08-05.md`, D-P0C1…D-P0C5), the
> policy battery ships (`scripts/verify_policy_tests.sh`), and the matters
> **and** documents slices each ran the full chain green (rehearsal r1
> PASSED → signed apply → matrix addendum → env-gated client swap). The
> `matters` table is **applied on the dev project** and is this slice's FK
> target + assignment source of truth; the `documents` slice (second
> un-deferral) is the exact template this slice mirrors.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Move the **message-thread-metadata list read path** from the synthetic fake
to a real, org-scoped, **matter-scoped** `message_threads` table read
through PostgREST with RLS — **without changing the client `MessageThread`
VO or any presentation code** (the swap is seam-compatible and env-gated,
mirroring the matters/documents flips). "Done" = an active member reads
exactly the thread metadata of the matters they are assigned to (client or
attorney); every other read — org-role-alone, cross-org, unassigned,
unauthenticated, `platform_owner_admin` — is denied and policy-tested; the
env-less demo and the whole test suite still run on the fake. **Thread
metadata only: no message body, no preview, no attachment, no sender/message
pair column ever exists** (D-MSG1 line preserved in the real path); the
matrix's "Read a document/message body" row stays deferred.

## 2. Gap (verified)

- `MessageGateway` (Phase 9 slice 9.0) is fake-only:
  `FakeMessageGateway.syntheticThreads` serves five static non-PII thread
  rows; the real data path stays §14-deferred — and the matters/documents
  slices established the un-deferral discipline (§0).
- The client `MessageThread` VO (D-MSG1/D-MSG4): `id`, `title` (generic demo
  copy), `matterRef` (**a matter title string**, the title-keyed association
  the same `Document.matterRef` pattern uses), `participants` (a
  `List<String>` of generic demo roster names — **presentation-only, never
  an identity/availability claim**), `lastActivityAt`, `messageCount` (**a
  count, never content**). **No body, no preview, no attachments, no
  sender/message pair field** (D-MSG1 — enforced structurally).
- The **permission matrix §4 governs the read scope** and treats messages as
  **matter-scoped content** (line 143): client ✅ / attorney ✅ *if
  assigned*; partner ❌ / `compliance_officer` ❌ "deny unless separately
  assigned"; `platform_owner_admin` ❌ **deny, always**. Line 148: an org
  role without an explicit matter assignment cannot read a restricted matter
  **or its documents/messages** — true for every role.
- The **`matters` table is applied + policy-tested** on the dev project
  (`04_matters.sql` + `matters_select_assigned`): the message threads table
  FKs to it and inherits its assignment semantics — the message gate *is*
  the matter gate, scoped to the row's own matter (the documents
  `documents_select_assigned` pattern).
- The battery fixture set already seeds six matters with every assignment
  branch + six documents; the messages battery reuses the six matters, no
  new identity fixtures needed.
- The harness forward pin currently asserts `messages`/`files`/
  `matter_documents`/`matter_messages` absent (8 tables / 8 RLS / 7
  policies) — this slice ships `message_threads` and re-scopes the pin.

## 3. Design decisions (D-MSR1…D-MSR8 — ratified by autonomy this session)

| # | Decision | Recommendation | Why / alternative |
|---|---|---|---|
| D-MSR1 | **Read scope, slice 3** | **Matter-scoped thread metadata only**: a thread row is readable iff the reader is an active member of the thread's org **AND** assigned (client or attorney) on the thread's `matter_id` (matrix §4 line 143/148 — messages are matter content; an org role alone never grants, cross-org denied, `platform_owner_admin` deny always) | Partner/owner "deny unless separately assigned" cells need a defined oversight mechanism (mirror D-MR5/D-DR5); the body row stays deferred (no body column) |
| D-MSR2 | **Read mechanism** | **Table + RLS SELECT policy via PostgREST** (`supabase.from('message_threads').select()`); **no** SECURITY DEFINER RPC. The policy's matter gate is a **plain `exists` subquery on `matters`** — `m.id = message_threads.matter_id AND m.organization_id = message_threads.organization_id AND (m.assigned_client_id = auth.uid() OR m.assigned_attorney_id = auth.uid())` (the documents D-DR2 pattern verbatim, applied to the new table). **The `m.organization_id = message_threads.organization_id` clause is load-bearing** — the org gate must come from the matter's **authoritative** org, never the thread's denormalized column, so a thread is never readable when its matter is not (matrix line 148) | Row-scoped reads are RLS's job; no new function surface (`is_active_member` already R-4 granted); the battery pins the org-mismatch deny row |
| D-MSR3 | **Column shape + participants** | `message_threads`: `id uuid pk default gen_random_uuid()`, `organization_id uuid not null fk organizations on delete cascade`, `matter_id uuid not null fk matters on delete cascade`, `title text not null`, **`participants text[] not null default '{}'`** (generic demo display names, D-MSG4 — never real PII by convention), `last_activity_at timestamptz not null default now()`, `message_count integer not null default 0` with a `check (message_count >= 0)` (the schema-is-the-mapping-contract decision; the VO requires a count), `created_at`/`updated_at`. **No body/preview/attachment/sender columns** (D-MSG1). | **Participants as stored display names (text[]) is the ratified recommendation** — the VO is display-name-keyed by design (D-MSG4, presentation-only) and the demo seed carries only generic names, so **no real PII is denormalized by this slice's demo seed** (the column permits names by design; a future write slice controls what it writes); `'Demo client'` (a neutral placeholder, not a user) cannot be represented as a user id, so the matters D-MR4 roster-resolution pattern does not apply here; a future write/real-identity slice is a separate reviewed design (flagged in §9) |
| D-MSR4 | **matterRef resolution** | Rows store `matter_id` (ids only); the gateway resolves the VO's title-keyed `matterRef` via the **embedded `matters(title)` select** (PostgREST embed, RLS-applied — the documents D-DR4 pattern exactly; the reader passes the matter gate by the policy, so the embed resolves). Fallback: the raw matter id (honest — never a fabricated title) | The VO is title-keyed by design (D-W2); one round-trip, RLS-safe, no new surface |
| D-MSR5 | **Partner/owner oversight** | **Not in slice 3** — the "deny unless separately assigned" mechanism is undefined; the RLS stays purely assignment-based (mirror D-MR5/D-DR5) | Matrix cells stay ungranted; a future D-DR defines the oversight row (which would then also propagate to matters/documents/messages via the shared exists gate) |
| D-MSR6 | **Policy-test battery** | New `supabase/tests/06_message_rls.sql` + the harness's explicit file list / run loop / UUID scan / FAIL scan gain the new file; **structural pins re-scope**: 8 tables → **9** (adds `message_threads`), 7 policies → **8** (adds `message_threads_select_assigned`), plus the threads SELECT grant + anon absence rows; **the forward pin narrows** to `('messages','files')` still absent — individual message rows (bodies) and file storage stay deferred; the never-built `matter_documents`/`matter_messages` join-table names are dropped from the pin (documents/message_threads are first-class tables) | The documents T3 convention (the harness is a fixed list; a new battery is inert until listed) |
| D-MSR7 | **Client swap** | `lib/data/messaging/supabase_message_api.dart` + `supabase_message_api_impl.dart` + `supabase_message_gateway.dart` implementing `MessageGateway` behind `env.isConfigured` (service_locator flip, matters/documents pattern); row→VO mapping (participants text[] → `List<String>`, message_count int, last_activity_at parse, matterRef embed + fallback, guarded casts) + typed failure mapping; **VO and presentation untouched** | Env-less runs and ALL tests keep the fake; the real path is inert until a configured build + applied schema exist |
| D-MSR8 | **Seeding + residue** | Demo thread rows referencing the **applied demo matter ids** (dev project's own ids resolved at apply time) are part of the **apply step** (owner-approved), paired with the rollback (`_down.sql` drop) and cleanup discipline; participants are generic demo names (D-MSG4) | No seed at commit time; no real client PII anywhere |

**Non-decisions (flagged, not guessed):** message **bodies** (no column, no
storage surface — the matrix body row stays deferred; D-MSG1 holds);
individual message rows + realtime delivery (a future slice); partner /
`compliance_officer` oversight rows (D-MSR5 follow-up); message
send/reply/attachment actions (read-only, D-MSG1 discipline); file storage
(stays deferred); audit wiring for message reads (stays §14/P2-gated).

## 4. Layers touched

- **Server (rehearsal → apply, gated):** `supabase/migrations/06_message_threads.sql`
  (+ `06_message_threads.down.sql`), `supabase/policies/message_threads.sql`,
  `supabase/tests/06_message_rls.sql`, `scripts/verify_policy_tests.sh`
  (battery list + structural pins re-scoped 8→9 tables / 7→8 policies +
  forward pin narrowed to `('messages','files')`). The `matters` table is
  already applied — `06` is additive on top of it (FK target), no change to
  existing migrations/policies/RPCs.
- **Client (env-gated):** `lib/data/messaging/supabase_message_api.dart`,
  `supabase_message_api_impl.dart`, `supabase_message_gateway.dart` (new
  data dir, mirrors `lib/data/documents`), `lib/app/service_locator.dart`
  (flip). `lib/features/messaging/**` presentation and the `MessageThread` /
  `MessageGateway` domain types are **untouched**.
- **Docs:** dated matrix §4 addendum (adds the "View a message thread
  (metadata)" row; keeps the body row deferred), roadmap §14 third
  per-feature flip, README lockstep, completion evidence.

## 5. State shape / data flow

- **State shape unchanged:** `MessageCubit`/`MessageState` read
  `MessageGateway.fetchThreads()` exactly as today; the fake remains the
  env-less/test implementation.
- **Data flow (configured build):**
  `messaging list screen → MessageCubit → MessageGateway (Supabase impl) →
  PostgREST from('message_threads').select('id, matter_id, title,
  participants, last_activity_at, message_count, matters(title)')
  (RLS-scoped, D-MSR1/D-MSR4) → row → MessageThread VO (matterRef from the
  embedded title, fallback id)`. One embed hop, the documents pattern — no
  new surface.

## 6. Dependencies

- **Server:** the **applied `matters` table** (D-MSR2's exists subquery +
  D-MSR3's FK) — additive on the matters slice, no new primitives beyond
  stock Postgres/PostgREST. The applied `documents` table is untouched.
- **Client:** none new — `supabase_flutter` is already the only backend SDK,
  confined to `lib/data/`; the gateway uses the existing client.
- **Infra (rehearsal/apply):** Postgres to run the battery — the
  **established host is the owner's Docker machine** (matters/documents r1
  Path A precedent), so the rehearsal is owner-side but no longer an
  unknown.

## 7. Testing strategy

- **SQL battery** (`06_message_rls.sql`, via `verify_policy_tests.sh`):
  assigned-client sees the threads of its matters; assigned-attorney sees
  theirs; row-count pins (client 2 / attorney 3 / orphan 1 — the
  matters/documents count shape, proving no blanket-org bleed); org-role-
  alone denied; cross-org denied; suspended denied; `platform_owner_admin`
  denied always; unauthenticated denied; **org-mismatch deny row** (a thread
  whose `organization_id` ≠ its matter's org denies for every role — the
  D-MSR2 invariant); `message_count` CHECK rejects a negative value;
  matter-delete cascade removes its threads.
- **Dart unit:** `SupabaseMessageGateway` row→VO mapping (participants
  text[] → `List<String>`, message_count int, last_activity_at parse,
  matterRef embed resolution + id fallback, failure mapping, malformed-row
  guards — the documents T7 fixes as baseline: no raw `TypeError`s across
  the boundary, `providerUnavailable` mapping pinned).
- **DI pins:** `service_locator_test` — env-less → `FakeMessageGateway`,
  configured → `SupabaseMessageGateway`.
- **Widget/cubit:** unchanged (fake stays); the existing messaging suite is
  the regression net proving the swap is seam-compatible.
- **Not claimed:** no live dev-project read until the apply step; the
  battery + rehearsal evidence are the standing server claims.

## 8. Acceptance criteria

- [x] A message thread (metadata) is readable iff the reader is an active
      member of its org **and** assigned (client or attorney) on its matter
      (RLS + battery, matrix §4 line 143/148).
- [x] Org-role-alone, cross-org, unassigned, unauthenticated, and
      `platform_owner_admin` reads are denied (battery, 03-style deny rows;
      the owner row holds as the operational invariant — never assigned).
- [x] Battery green via `verify_policy_tests.sh`; rehearsal r-series passed
      with evidence before any apply (owner's Docker host, matters/documents
      r1 precedent).
- [x] Apply executed only under the owner's dated apply-approval, with
      `_down.sql` rollback pairing and demo-row cleanup discipline (demo
      thread ids reference the **applied** demo matter ids, resolved at
      apply time).
- [x] Client swap is env-gated; env-less runs and the full Flutter suite
      are unchanged (fake); `MessageThread` VO and presentation untouched.
- [x] Dated matrix addendum (§7) precedes the client surface shipping;
      roadmap §14 gains the third per-feature flip; README count in
      lockstep; ledger PASS.
- [x] Full gate on every client slice: format clean · analyze clean ·
      suite green · ledger PASS — nothing pushed.

## 9. Risks / open questions

- **Policy/matters coupling (D-MSR2):** the threads policy's exists subquery
  inherits any future change to `matters` (e.g. a partner oversight row
  would also open message threads on those matters). Recorded as **intended**
  — messages should track matter access — and pinned by the battery.
- **Org-mismatch invariant (D-MSR2):** the thread's denormalized
  `organization_id` is never authoritative — the exists matches the matter's
  own org, so a thread is readable only when its matter is. The org-mismatch
  deny row pins it; the future write slice must keep the column consistent.
- **Participants as stored names (D-MSR3):** the ratified recommendation
  stores generic demo display names; a future real-identity/write slice
  needing live names must revisit (the matters D-MR4 roster seam is the
  available pattern). Recorded as the key open follow-up.
- **Embed reliability (D-MSR4):** the embedded `matters(title)` resolves
  because the policy guarantees the matter gate; a null embed falls back to
  the raw matter id (flagged in the client tests; never a fabricated title).
- **Infra:** rehearsal/apply are owner-side (matters/documents r1 Path A
  precedent) — no psql/Docker on this machine; the first battery execution
  is T3/T4 on the owner's host or CI.
- **Scope:** slice 3 swaps only the message-thread-metadata read path;
  bodies, individual messages, storage, realtime, and the messages write
  path each stay deferred.
- **No email, no rate-limit exposure** in this slice (no GoTrue trigger).

---

# Tasks: Real Messages (Read) Data Path

Branch: `feat/messages-real-read`

Each task is independently committable with the stated verification; the
apply gate (T5) is the only owner-gated step. T2–T4 are server artifacts —
**no dev-project change until T5**.

- [x] **1. Scope note + RLS-gate design addendum** — touches: this document
  + a `messages` §8-style review (`docs/messages_rls_gate_review_2026-08-07.md`,
  the Q1–Q6 pattern answered for messages: matter-scoped assignment model,
  the exists-subquery policy, the participants-as-names decision (D-MSR3),
  negative cases, rollback pairing, seed plan) — done when: docs committed,
  ledger sweep green (no dev-project contact). — **DONE `443f42e`** (+ the
  org-mismatch non-vacuity nit `ab41c83`).
- [x] **2. Schema artifacts (rehearsal-ready, NOT applied)** — touches:
  `supabase/migrations/06_message_threads.sql` (+ `06_message_threads.down.sql`),
  `supabase/policies/message_threads.sql` — done when: DDL matches
  D-MSR1/D-MSR3 (matter FK + org column + `participants text[]` +
  `message_count` CHECK, metadata only, no body column), `_down.sql` is a
  clean inverse, committed. — **DONE `5a506ca`** (NOT applied at commit;
  applied later under the T5 approval).
- [x] **3. Policy battery** — touches: `supabase/tests/06_message_rls.sql`
  (new thread fixture rows referencing the six fixture matters go in
  `supabase/tests/00_fixtures.sql`, the documents precedent) +
  `scripts/verify_policy_tests.sh` — **four sites**: battery file list, run
  loop, UUID cross-ref scan, FAIL-marker scan — **plus the `--apply` order
  gains `06_message_threads.sql`** (the documents T3 pre-emption as
  baseline), the structural pins re-scope (8→9 tables / 7→8 policies +
  threads grant/anon rows + forward pin narrowed to `('messages','files')`),
  **and the harness header + D-P0C1(b) forward-pin comments** ("all eight" →
  "all nine"; "messages/files still absent" → "individual messages/files
  still absent; first three un-deferrals") **plus the `00_fixtures.sql`
  reset-ordering + sanity pin** (`delete from public.message_threads;`
  before `matters`; 6-thread pin) — the documents T3 sites as baseline —
  done when: battery runs green against a Postgres (owner's Docker host or
  CI) with the §4 deny rows incl. the org-mismatch row; committed. —
  **DONE `0ed14c7`** (+ README-battery + quoted-participants nits
  `4905697`); static `--check` **37/0/0**; the live battery ran green in T4
  (r1 PASSED).
- [x] **4. Ephemeral rehearsal (r-series)** — touches: evidence record
  `docs/messages_rehearsal_evidence_r1_<date>.md` — done when: the loop
  (migrate → policy → battery → read-as-roles) passes on throwaway infra
  with zero dev-project contact; **owner-side / CI runner** (matters/
  documents r1 Path A precedent). — **DONE `a37c6dc`** — r1 **PASSED
  2026-08-07** (owner's Path A Docker run; 9 tables / 9 RLS / 8 policies
  live pins; 06 battery 11 checks green).
- [x] **5. Dated apply-approval → apply** — touches: dev project
  (migrations + policies + demo seed), `docs/messages_apply_approval_<date>.md`
  + `docs/messages_apply_execution_<date>.md` — done when: the owner's
  dated approval exists, apply executed with `_down.sql` pairing + cleanup
  discipline (demo thread ids reference the applied demo matter ids),
  observed output recorded verbatim. — **2026-08-07 status:** approval
  **APPLY APPROVED** (`docs/messages_apply_approval_2026-08-07.md` §6,
  owner's dated sign-off); execution **APPLIED 2026-08-07** (evidence
  `docs/messages_apply_execution_2026-08-07.md` — baseline probe →
  06_message_threads → policy → demo seed → post-apply smoke all verified;
  rollback pairing standing by).
- [x] **6. Matrix addendum (dated)** — touches: `docs/permission_matrix.md`
  §4 — adds the **"View a message thread (metadata)"** row (client/attorney
  cells SHIP behind `message_threads_select_assigned`; partner/
  `compliance_officer` "deny unless separately assigned" cells stay
  ungranted; `platform_owner_admin` deny always) and records the **body row
  keeps its §14 deferral** (no body column, D-MSG1) — done when: addendum
  committed **before** the client surface ships, ledger sweep green. —
  **DONE `d5ac001`** (before T7's client swap).
- [x] **7. Client swap (env-gated)** — touches:
  `lib/data/messaging/supabase_message_api.dart` +
  `supabase_message_api_impl.dart` + `supabase_message_gateway.dart`,
  `lib/app/service_locator.dart`, tests (mapping incl. participants text[]
  and message_count, matterRef embed + fallback, failure mapping incl.
  `providerUnavailable`, DI pins) — done when: format clean · analyze clean
  · suite green (fake unchanged) · ledger PASS; VO/presentation untouched.
  — **DONE `7168f38`** (+24 tests; the `providerUnavailable` mapping was
  tested from the start — the documents T7 lesson pre-built).
- [x] **8. Lockstep + evidence + close** — touches: README test count,
  roadmap §14 third per-feature flip + gate-table row, completion evidence
  `docs/messages_real_data_completion_evidence_<date>.md`, dated close
  decision — done when: all docs sweep green, full gate re-run on the
  committed state, close decision recorded. — **DONE this commit** (README
  918; roadmap §14 third flip + §13 row; evidence record; dated close
  decision).
