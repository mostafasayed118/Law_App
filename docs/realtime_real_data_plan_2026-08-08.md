# Plan: Realtime — Message Bodies + Individual Message Rows (the sixth §14 un-deferral) (2026-08-08)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> sixth slice under the roadmap §14 blanket-deferral, mirroring the
> **matters, documents, messages, storage** read slices (all four SHIPPED)
> and the **audit surfacing** client-only slice (fifth, SHIPPED 2026-08-08)
> — the same per-feature discipline applied to the last content-shaped
> deferred path: **individual message rows (bodies)** on a real `messages`
> table behind RLS, consummating the permission matrix §4 **"Read a
> document/message body"** row (line 143) for client/attorney for the first
> time. **Docs-only planning — zero dev-project effect**: nothing in this
> document applies anything to the dev Supabase project; every external step
> stays behind the owner's dated approval (INSTRUCTIONS.md §2.1/§5 hard
> gates).
>
> **Gate state (why this slice is now plannable — and why it wins the
> remaining reconciliation):** the §14 precondition chain ran green **five
> times** (P0 RATIFIED + policy battery shipped; matters/documents/messages
> read slices applied + client-swapped; audit surfacing closed the RPC
> surface 18-of-18). The remaining §14 list after the fifth flip is
> **realtime, billing, AI** — reconciled 2026-08-08:
> - **Realtime** (message bodies / individual `messages` rows / live
>   delivery) — the largest remaining content-shaped lift, and the **only
>   one with a shipped, applied dependency already in place**: the
>   `message_threads` table + `message_threads_select_assigned` policy are
>   **applied on the dev project** (messages slice T5) and battery-pinned,
>   so the `messages` table FKs to an applied table and inherits its gate.
>   **Picked.**
> - **Billing** — gated on D-09 (no live payment in MVP); external payment
>   provider decisions; not a read-metadata slice. Stays deferred.
> - **AI** — no matrix rows, no spec basis beyond the roadmap list; product
>   scope undefined. Stays deferred.
>
> **Scope honesty — what "realtime" means here:** the roadmap's realtime
> entry names **message bodies + individual message rows + live delivery**.
> This plan ships the **read path** (bodies + rows, RLS-scoped PostgREST) —
> the four-slice discipline, applied to the body row — and **flags live
> delivery (postgres_changes push) as a recorded follow-up** (D-RT6): live
> subscription is a *different authorization surface* (publication + channel
> auth + client reconnect/backfill lifecycle) that deserves its own
> mechanism review, exactly as the storage slice kept signed-URL/download UX
> and the audit slice kept the partner org-audit UI as follow-ups. The
> forward pin re-scopes to keep "live delivery absent" pinned.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Move the **individual-message read path** (bodies + rows, per thread) from
"structurally impossible" (D-MSG1 — the VO/type has no body field and the
matrix body row is deferred) to a real, org-scoped, **thread-scoped**
`messages` table read through PostgREST with RLS. "Done" = an active member
reads the individual messages of exactly the threads whose matter they are
assigned to (client or attorney); every other read — org-role-alone,
cross-org, unassigned, unauthenticated, `platform_owner_admin` — is denied
and policy-tested; the env-less demo and the whole test suite still run on
the fake. **The matrix §4 body row (line 143) gains its first client
surface** (client ✅ / attorney ✅ if assigned; partner / `compliance_officer`
"deny unless separately assigned" stay ungranted; `platform_owner_admin`
deny always). Thread **metadata** stays exactly as shipped (D-MSR slice);
the new surface is the per-thread **message list** (read-only, no composer,
no attachments, no edit/delete). **Live delivery is NOT in this slice**
(D-RT6 — flagged follow-up with its own mechanism review).

## 2. Gap (verified)

- **The body row is structurally impossible today (D-MSG1).** The
  `MessageThread` VO carries metadata only (`title`, `matterRef`,
  `participants`, `lastActivityAt`, `messageCount`) — "no message body, no
  preview, no attachment, no sender/message pair field anywhere on the
  type" — and the messaging presentation has **no thread-open affordance**
  (`MessageListScreen`/`MatterMessagesSection` render metadata rows only,
  D-MSG3). The matrix §4 line 143 "Read a document/message body" row is
  §14-deferred in every addendum to date (documents §4, messages §4,
  storage §4 — each explicitly "no body/content column exists").
- **The server-side dependency is applied + battery-pinned.** The
  `message_threads` table (id, organization_id, matter_id, title,
  participants text[], last_activity_at, message_count) + the
  `message_threads_select_assigned` policy are **applied on the dev project**
  (messages slice T5) and pinned in the harness (9 tables / 9 RLS /
  8 policies → now 10/10/9 after storage). `matters` is applied with the
  assignment columns the exists-subquery reads. **No new identity fixture
  work**: the battery's six matters + assigned client/attorney/suspended/
  orphan users already exist.
- **No `messages` table exists** — the harness forward pin asserts
  `messages` **absent** (`1f` baseline: `table_name = 'messages'` count =
  0) and the header comment reads "individual message rows/bodies still
  absent". This slice flips that pin to **present** and re-scopes it to
  **live delivery absent** (D-RT7).
- **The client messaging data layer is seam-ready.** `SupabaseMessageApi`
  (seam) + `SupabaseMessageApiImpl` (PostgREST, defensive catch) +
  `SupabaseMessageGateway` (guarded mapping, `providerUnavailable` mapped
  from the start) + `FakeMessageGateway` (deterministic non-PII threads)
  all shipped in the messages slice (T7 `7168f38`) — the seam extends
  cleanly with a `fetchMessages(threadId)` method (D-RT5), the fake gains
  deterministic per-thread message rows, and the DI flip is already in
  place.
- **No consumer pressure for live push yet** — the messaging surface has no
  thread-open affordance at all; the first consumer is the thread-detail
  read surface this slice builds (D-RT5), and live delivery only makes
  sense on top of that.

## 3. Design decisions (D-RT1…D-RT8 — recommended path, ratified by autonomy 2026-08-08 per the pair-programming grant; each is a one-line-reasoned choice, owner may amend)

| # | Decision | Recommendation | Why / alternative |
|---|---|---|---|
| D-RT1 | **Read scope** | **Thread-scoped individual message rows (bodies)**: a row is readable iff the reader is an active member of the row's org **AND** assigned (client or attorney) on the **thread's** matter — the exists-subquery gate through `message_threads` → `matters` (the `messages_select_assigned` policy). Matrix line 143 body row consummated for client/attorney; partner/`compliance_officer` "deny unless separately assigned" stay ungranted; `platform_owner_admin` deny always (operational invariant) | Messages are matter content (line 148 — "a restricted matter **or its documents/messages**"); the body row's long deferral ends for the assigned reader only |
| D-RT2 | **Read mechanism** | **Table + RLS SELECT policy via PostgREST** (`supabase.from('messages').select()` filtered by `thread_id`); **no** SECURITY DEFINER RPC. The policy is the thread gate **plus the row's own org**: `exists (select 1 from message_threads t join matters m on m.id = t.matter_id and m.organization_id = t.organization_id where t.id = messages.thread_id and messages.organization_id = t.organization_id and public.is_active_member(messages.organization_id) and (m.assigned_client_id = auth.uid() or m.assigned_attorney_id = auth.uid()))` — **the three-way org equality (`messages.organization_id = t.organization_id = m.organization_id`) is load-bearing** (the org gate comes from the matter's authoritative org), mirroring the messages/files org-mismatch clauses | Row-scoped reads are RLS's job; no new function surface (`is_active_member` already R-4 granted); the battery pins the org-mismatch deny row |
| D-RT3 | **Column shape** | `messages`: `id uuid pk default gen_random_uuid()`, `organization_id uuid not null fk organizations on delete cascade` (denormalized, mirrors threads/files), `thread_id uuid not null fk message_threads on delete cascade` (the thread gate's anchor), `author_display_name text not null`, `body text not null` with `check (body <> '')` (schema-as-mapping-contract — no empty body the client cannot render), `sent_at timestamptz not null default now()`, `created_at`/`updated_at`. **No attachments, no read receipts, no edit history, no author_user_id column** (D-RT4). Indexes: `(thread_id, sent_at)` (the fetch shape), `(organization_id)`. | Faithful to the thread gate; the CHECK mirrors `size_bytes >= 0` / `message_count >= 0`; the body column is the D-MSG1 consummation — the first content column in the repo's public schema |
| D-RT4 | **Author identity** | **`author_display_name text` (stored display name), NO `author_user_id` column.** The demo seed carries generic demo names only (D-MSR3 participants convention — no real PII denormalized by this slice); the client renders the stored name. A future write/real-identity slice binds real users via the matters D-MR4 roster seam (flagged §9) | Mirrors the ratified participants-as-names decision (D-MSR3) exactly — no identity surface this slice; the demo seed's "Demo client" cannot be a user id |
| D-RT5 | **Client swap** | **Extend the shipped messaging seam** (`SupabaseMessageApi`/impl/gateway/fake gain `fetchMessages(String threadId)`) + a **NEW `Message` VO** (id, authorDisplayName, body, sentAt — **the body field is the D-MSG1 consummation, scoped to the real read path**) + a **NEW thread-detail read surface** (the first thread-open affordance: tap a thread row → read-only message list, gated by the same capability check that renders the messaging entry; no composer, no send/reply). Presentation otherwise untouched; env-less runs + ALL tests keep the fake | Consumer-attached, never a shelved headless layer (D-B7 lesson); the storage slice's NEW-surface precedent (D-STR7); the thread-detail route mirrors the matter-details route pattern |
| D-RT6 | **Live delivery** | **NOT in this slice.** `postgres_changes`/Supabase Realtime push (publication membership, channel authorization, client subscription lifecycle incl. reconnect + backfill) is a **different authorization surface** (realtime RLS on publications ≠ table SELECT RLS) and gets its own mechanism review + dated approval. The read path ships first; the forward pin re-scopes to keep **live delivery absent** pinned (D-RT7) | The four-slice discipline is read-first per feature; bundling a live channel + reconnect/backfill into this slice would double its risk surface; the "realtime" name's read half is consummated here, its push half recorded as the natural next slice |
| D-RT7 | **Battery + forward pin** | New `supabase/tests/08_message_rls.sql` + harness edits (file list, run loop, `--apply` order gains `08_messages.sql`, structural pins 10→11 tables / 9→10 policies, UUID + FAIL scans). **The forward pin flips: `messages` now PRESENT (1)** and re-scopes to pin **live delivery absent** (no `messages` row in the `supabase_realtime` publication / no channel grant — an executable `pg_publication_tables` query), keeping D-P0C1(b)'s teeth honest (the deferred item is now the push half, not the table) | The storage T3 convention (fixed list; inert until listed); the pin must keep meaning after the last content table ships |
| D-RT8 | **Seeding + residue** | Demo message rows referencing the **applied demo thread ids** (dev project's own thread ids resolved at apply time) are part of the **apply step** (owner-approved), paired with rollback (`08_messages.down.sql` drop) + cleanup discipline; author names generic demo names (D-RT4) | No seed at commit time; no real client PII anywhere (the thread participants precedent) |

**Non-decisions (flagged, not guessed):** **live delivery / realtime push**
(D-RT6 follow-up — the next natural slice); message **send/reply/compose**
(write path, read-only slice); attachments / read receipts / edit history
(no columns, no surface); partner/`compliance_officer` "deny unless
separately assigned" oversight rows (mechanism undefined — mirrors
D-MSR5/D-STR6); **billing** (D-09) and **AI** (no scope) stay deferred.

## 4. Layers touched

- **Server (rehearsal → apply, gated):** `supabase/migrations/08_messages.sql`
  (+ `08_messages.down.sql`), `supabase/policies/messages.sql`,
  `supabase/tests/08_message_rls.sql`, `scripts/verify_policy_tests.sh`
  (battery file list + run loop + `--apply` order + structural pins
  10→11 tables / 9→10 policies + forward pin flip to present + live-
  delivery-absent re-scope + header/D-P0C1(b) comments). Additive on the
  **applied** `message_threads` table (FK target) — no change to existing
  migrations/policies/RPCs.
- **Client (env-gated):** `lib/data/messaging/supabase_message_api.dart`
  (seam gains `fetchMessages(String threadId)`),
  `supabase_message_api_impl.dart` (the `messages` SELECT with the
  `thread_id` filter + columns pin), `supabase_message_gateway.dart`
  (row→`Message` VO mapping, guarded casts + failure mapping on the
  existing `Result`/`AppError` boundary), `fake_message_gateway.dart`
  (deterministic non-PII per-thread message rows, D-RT8), a NEW
  `lib/features/messaging/domain/message.dart` (`Message` VO),
  `lib/features/messaging/presentation/message_thread_detail_screen.dart`
  (NEW thread-detail read surface) + the list row gains the thread-open
  affordance, `lib/app/router.dart` (the thread-detail route),
  `lib/app/service_locator.dart` (no registration change — the existing
  flip rides; the new methods extend the registered seam), 3 `.arb` +
  generated l10n (thread-detail title, empty, error ×3 locales).
- **Docs:** dated matrix §4 addendum (the "Read a document/message body"
  row — client/attorney SHIP behind `messages_select_assigned`; partner/
  compliance stay ungranted; owner deny always), roadmap §14 sixth
  per-feature flip + §13 gate-table row, README lockstep, completion
  evidence.
- **Not touched:** any other feature's VO or presentation; the `messages`
  **write** path; existing migrations/policies/RPCs.

## 5. State shape / data flow

- **State shape:** `MessageCubit`/`MessageState` stay as shipped for the
  thread list; the new thread-detail surface gets a **feature-scoped cubit**
  (the matter-sections pattern: self-provided `BlocProvider`, post-frame
  load, inline empty/error+retry states) — a new `MessageThreadDetailCubit`
  + state over `ViewState<List<Message>>`, mirroring the audit section's
  section-local fetch on the existing seam.
- **Data flow (configured build):**
  `thread list row (tap) → thread-detail route → MessageThreadDetailCubit →
  MessageGateway (Supabase impl) → PostgREST
  from('messages').select('id, author_display_name, body, sent_at')
  .eq('thread_id', id) (RLS-scoped by messages_select_assigned) → rows →
  Message VO list`. One round-trip per thread, no new surface beyond the
  detail route; the server re-scopes each read to the thread's matter gate.

## 6. Dependencies

- **Server:** the **applied `message_threads` table** (D-RT2's exists anchor
  + D-RT3's FK) and the applied `matters` table (the assignment columns) —
  both battery-pinned; no new primitives beyond stock Postgres/PostgREST.
- **Client:** none new — `supabase_flutter` is already the only backend SDK,
  confined to `lib/data/`; the gateway extends the shipped messaging seam.
- **Infra (rehearsal/apply):** Postgres to run the battery — the
  **established host is the owner's Docker machine** (`supabase start`;
  matters/documents/messages r1 Path A + storage T4 precedent), so the
  rehearsal is owner-side but no longer an unknown.

## 7. Testing strategy

- **SQL battery** (`08_message_rls.sql`, via `verify_policy_tests.sh`):
  assigned-client reads the messages of its threads; assigned-attorney reads
  theirs; row-count pins (the 2/3/1 count shape per thread, proving no
  blanket-thread bleed); org-role-alone denied; cross-org denied (member of
  the org, assigned on another org's matter); suspended denied (the
  `is_active_member` arm); `platform_owner_admin` denied always;
  unauthenticated denied; **non-vacuous org-mismatch deny row** (a message
  row whose `organization_id` ≠ its thread's org — the reader is an active
  member of the row's org AND assigned on the temp matter, so only the
  three-way-org clause denies); `body` non-empty CHECK row; thread-delete
  cascade removes its messages. Structural pins: 11 tables / 10 policies /
  `messages` present / live delivery absent (`pg_publication_tables` has no
  `messages` row).
- **Dart unit:** `SupabaseMessageGateway` row→`Message` VO mapping (body,
  author_display_name, sent_at parse, guarded casts — malformed rows →
  typed FormatException, never a raw TypeError; the documents/messages T7
  baseline), failure mapping incl. `denied` → `message_read_denied` and
  `providerUnavailable` (tested from the start — the messages T7 lesson);
  `SupabaseMessageApiImpl` columns pin (`id, author_display_name, body,
  sent_at` + the `.eq('thread_id', …)` filter); fake determinism/non-PII
  (fixed per-thread counts, generic author names).
- **Cubit/widget:** thread-detail cubit emissions (loading → loaded/empty/
  error+retry, in-flight guard); the thread-detail screen renders the
  message list, empty copy, denied state (never empty-success), error-retry;
  the list row's thread-open affordance is capability-gated; l10n ×3 pins.
- **DI pins:** `service_locator_test` — env-less → fake (now exposing the
  per-thread messages), configured → `SupabaseMessageGateway` (exposes
  `fetchMessages`).
- **Not claimed:** no live dev-project read until the apply step; no
  realtime push (D-RT6 follow-up); the battery + rehearsal evidence are the
  standing server claims.

## 8. Acceptance criteria

- [ ] An individual message (body + row) is readable iff the reader is an
      active member of its org **and** assigned (client or attorney) on its
      thread's matter (RLS + battery; matrix §4 line 143 body row).
- [ ] Org-role-alone, cross-org, unassigned, org-mismatch, unauthenticated,
      and `platform_owner_admin` reads are denied (battery deny rows; the
      owner row holds as the operational invariant — never assigned).
- [ ] Battery green via `verify_policy_tests.sh`; rehearsal r-series passed
      with evidence before any apply (owner's Docker host, the four-slice
      r1 precedent).
- [ ] Apply executed only under the owner's dated apply-approval, with
      `08_messages.down.sql` rollback pairing + demo-row cleanup discipline
      (demo message ids reference the **applied** demo thread ids).
- [ ] Client swap is env-gated; env-less runs and the full Flutter suite
      are unchanged (fake); the shipped thread-metadata VO/presentation is
      untouched (the new `Message` VO + thread-detail surface are additive).
- [ ] Dated matrix §4 addendum (§7) precedes the client surface shipping;
      roadmap §14 gains the sixth per-feature flip; README count in
      lockstep; ledger PASS.
- [ ] Full gate on every client slice: format clean · analyze clean ·
      suite green · ledger PASS — nothing pushed.

## 9. Risks / open questions

- **D-MSG1 reversal is deliberate and scoped.** The body field on the NEW
  `Message` VO (and the new thread-detail surface) consummates the body-less
  line **for the real read path only** — the shipped `MessageThread` VO and
  the messaging list stay body-less, and no write path exists. The matrix
  body row's partner/owner cells stay ungranted; the addendum records the
  reversal honestly.
- **Policy/thread coupling (D-RT2):** the `messages` policy inherits any
  future change to `message_threads`/`matters` (e.g. a partner oversight row
  would also open message rows on those threads). Recorded as **intended** —
  messages should track thread access — and pinned by the battery.
- **Org-mismatch invariant (D-RT2):** the three-way org equality
  (`messages.organization_id = thread.organization_id = matter.organization_id`)
  is load-bearing; the non-vacuous deny row pins it; the future write slice
  must keep the column consistent.
- **Author identity (D-RT4):** stored display names, no user-id column —
  the matters D-MR4 roster seam is the future write slice's binding path;
  recorded as the key open follow-up (mirrors D-MSR3).
- **Realtime push (D-RT6):** live delivery needs a separate mechanism
  review (publication + channel auth + reconnect/backfill). The forward pin
  re-scopes to keep it pinned absent so the deferral stays honest.
- **Embed reliability:** none — the message read needs no title embed (the
  thread title is already client-side); the `sent_at`/body mapping guards
  every cast.
- **Infra:** rehearsal/apply are owner-side (the four-slice Path A
  precedent) — no psql/Docker on this machine; the first battery execution
  is T3/T4 on the owner's host or CI.
- **Scope:** this slice swaps only the individual-message read path;
  send/reply, attachments, live delivery, billing, and AI each stay
  deferred.
- **No email, no rate-limit exposure** in this slice (no GoTrue trigger).

---

# Tasks: Realtime — Message Bodies + Individual Message Rows

Branch: `feat/realtime-real-read` (server-heavy T1–T6 — the four-slice
branch discipline; T7–T8 build on the merged base).

Each task is independently committable with the stated verification; the
apply gate (T5) is the only owner-gated step. T2–T4 are server artifacts —
**no dev-project change until T5**.

- [x] **1. Scope note + RLS-gate design addendum** — touches: this document
  + a `messages` §8-style review (`docs/realtime_rls_gate_review_2026-08-08.md`,
  the Q1–Q6 pattern answered for individual messages: the thread-scoped
  assignment model, the three-way-org exists policy (D-RT2), the body
  column + CHECK (D-RT3), author-as-display-name (D-RT4), the live-delivery
  follow-up (D-RT6), negative cases incl. the non-vacuous org-mismatch row,
  rollback pairing, seed plan) — done when: docs committed, ledger sweep
  green (no dev-project contact). — **DONE (this commit)** — the review
  answers Q1–Q6 for the thread-scoped one-hop gate (D-RT2 three-way org
  equality load-bearing; Q3 no embed needed — the thread title is already
  client-side; Q5 records the deliberate D-MSG1 reversal scoped to the real
  read path), the 2/3/1-per-thread positive pins + deny rows incl. the
  non-vacuous org-mismatch and the `body` CHECK, the schema (D-RT3) with
  the `(thread_id, sent_at)` index, rollback pairing (08 down + git-revert),
  and the T3 forward-pin flip note (messages PRESENT → live delivery
  ABSENT).
- [x] **2. Schema artifacts (rehearsal-ready, NOT applied)** — touches:
  `supabase/migrations/08_messages.sql` (+ `08_messages.down.sql`),
  `supabase/policies/messages.sql` — done when: DDL matches D-RT1/D-RT3
  (thread FK + org column + `author_display_name` + `body` with the non-empty
  CHECK + `sent_at`, metadata + body only, no attachments/read-receipts/
  user-id columns), `_down.sql` is a clean inverse, committed. — **DONE
  (this commit)** — 08_messages.sql (D-RT3 column shape + the
  `(thread_id, sent_at)` fetch index + RLS + default-deny revokes + the
  narrow authenticated SELECT grant, Q5) + a clean `_down.sql` inverse
  (drop table; the body CHECK dies with it) + policies/messages.sql
  (messages_select_assigned — the thread gate extended one hop with the
  three-way org equality load-bearing, D-RT2; no owner carve-out Q4);
  NOT applied at commit; battery `--check` 331/0/0 + ledger PASS 115 on
  the tree.
- [x] **3. Policy battery** — touches: `supabase/tests/08_message_rls.sql`
  (new message fixture rows referencing the six fixture threads in
  `supabase/tests/00_fixtures.sql`, the documents/messages precedent) +
  `scripts/verify_policy_tests.sh` — the established sites: battery file
  list, run loop, UUID cross-ref scan, FAIL-marker scan — **plus the
  `--apply` order gains `08_messages.sql`**, the structural pins re-scope
  (10→11 tables / 9→10 policies + `messages` grant/anon rows + **the
  forward pin flips to `messages` PRESENT and re-scopes to live delivery
  absent** via a `pg_publication_tables` query), **and the harness header +
  D-P0C1(b) forward-pin comments** ("individual message rows/bodies still
  absent" → "messages shipped as the sixth un-deferral; live delivery still
  absent") **plus the `00_fixtures.sql` reset-ordering + sanity pin**
  (`delete from public.messages;` before `message_threads`; message-count
  pin) — done when: battery runs green against a Postgres (owner's Docker
  host or CI) with the §4 deny rows incl. the non-vacuous org-mismatch row;
  committed with the static `--check` green. — **DONE (this commit)** —
  08_message_rls.sql (12 checks: client-a 3 / partner-a 6 / orphan 4
  positives, org-role-alone / non-vacuous org-mismatch / cross-org /
  suspended / owner / anon denies, the body CHECK, the thread-delete
  cascade, and the message-count mapping-consistency pin 08.12); fixtures
  seed 21 messages matching the six threads' message_count columns (1–6,
  the mapping contract); harness gains 08 in the file list / run loop /
  UUID scan / FAIL-marker loop, `--apply` order gains 08_messages.sql,
  pins re-scope 10→11 tables / 9→10 policies + messages grant/anon rows,
  the forward pin flips to messages-present + live-delivery-absent
  (`pg_publication_tables` = 0), and supabase/README.md gains the 08 row;
  static `--check` **333/0/0** + selftest **6/6** + ledger **PASS 115**.
- [ ] **4. Ephemeral rehearsal (r-series)** — touches: evidence record
  `docs/realtime_rehearsal_evidence_r1_<date>.md` — done when: the loop
  (migrate → policy → battery → read-as-roles) passes on throwaway infra
  with zero dev-project contact; **owner-side / CI runner** (the four-slice
  r1 Path A precedent).
- [ ] **5. Dated apply-approval → apply** — touches: dev project
  (migrations + policies + demo seed), `docs/realtime_apply_approval_<date>.md`
  + `docs/realtime_apply_execution_<date>.md` — done when: the owner's
  dated approval exists, apply executed with `_down.sql` pairing + cleanup
  discipline (demo message ids reference the applied demo thread ids),
  observed output recorded verbatim.
- [ ] **6. Matrix addendum (dated)** — touches: `docs/permission_matrix.md`
  §4 — the **"Read a document/message body"** row gains its dated addendum
  (client/attorney cells SHIP behind `messages_select_assigned` — the
  body row's first client surface; partner/`compliance_officer` "deny
  unless separately assigned" cells stay ungranted; `platform_owner_admin`
  deny always) and records the D-MSG1 reversal scoped to the real read
  path + live delivery staying deferred — done when: addendum committed
  **before** the client surface ships, ledger sweep green.
- [ ] **7. Client swap (env-gated, NEW thread-detail surface)** — touches:
  `lib/data/messaging/supabase_message_api.dart` +
  `supabase_message_api_impl.dart` + `supabase_message_gateway.dart`
  (`fetchMessages(String threadId)`), `lib/features/messaging/domain/message.dart`
  (NEW `Message` VO), `fake_message_gateway.dart` (deterministic per-thread
  non-PII message rows), `lib/features/messaging/presentation/message_thread_detail_screen.dart`
  (NEW) + the list row's thread-open affordance + `lib/app/router.dart`,
  3 `.arb` + generated l10n, tests (mapping incl. body/author/sent_at,
  impl columns + `.eq('thread_id')` pin, failure mapping incl.
  `providerUnavailable` from the start, fake determinism, cubit/widget,
  DI pins) — done when: format clean · analyze clean · suite green (fake
  unchanged) · ledger PASS; shipped thread VO/presentation untouched.
- [ ] **8. Lockstep + evidence + close** — touches: README test count,
  roadmap §14 sixth per-feature flip + §13 gate-table row, completion
  evidence `docs/realtime_real_data_completion_evidence_<date>.md`, dated
  close decision — done when: all docs sweep green, full gate re-run on the
  committed state, close decision recorded.
