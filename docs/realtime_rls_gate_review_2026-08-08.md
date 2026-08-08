# LegalHub — Realtime RLS-Gate Design Review (2026-08-08)

> **Record type:** RLS-gate design review for the realtime read slice —
> the sixth roadmap §14 per-feature un-deferral (individual **message
> rows/bodies**), following the `docs/p2_schema_rls_design.md` §8 Q1–Q6
> pattern and the **matters, documents, messages, storage precedents**
> (`docs/{matters,documents,messages}_rls_gate_review_2026-08-07.md` +
> `docs/storage_rls_gate_review_2026-08-08.md`, all five slices SHIPPED —
> applied + client-swapped; audit surfacing closed the RPC surface
> 18-of-18). **Docs + rehearsal-ready artifacts only — NOT applied:**
> nothing in this review or the paired
> `supabase/migrations/08_messages*.sql` / `supabase/policies/messages.sql`
> touches the dev project until the owner's dated apply-approval
> (INSTRUCTIONS.md §2.1/§5 hard gates; the four-slice apply pattern).
>
> **Status: REVIEWED 2026-08-08 (decision-level).** Plan:
> `docs/realtime_real_data_plan_2026-08-08.md` (D-RT1…D-RT8 ratified by
> autonomy — recommended path, per the pair-programming grant).
> **Owner:** Project Owner (github.com/mostafasayed118). **Governed by:**
> `docs/permission_matrix.md` §4/§6 (the "Read a document/message body"
> row — line 143 — consummated here for client/attorney) · §7 (addendum
> discipline) · `docs/p2_schema_rls_design.md` §8 pattern ·
> `docs/realtime_real_data_plan_2026-08-08.md` ·
> `docs/messages_rls_gate_review_2026-08-07.md` (the thread-gate
> precedent this slice extends one hop) · `docs/rollback_plan.md` ·
> `docs/p0_closure_scope_2026-08-05.md` (D-P0C1(a) deny-row discipline) ·
> `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Precondition (roadmap §14 → this slice) | Status |
|---|---|
| P0 closes (D-02…D-10b) | ✅ **RATIFIED 2026-08-05** — `docs/p0_closure_scope_2026-08-05.md` (D-P0C1…D-P0C5) |
| Policy tests exist | ✅ Shipped — `scripts/verify_policy_tests.sh` + `docs/p0c1_verification_evidence_2026-08-05.md` |
| Signed matrix governs the grant (positive + negative) | ✅ `docs/permission_matrix.md` §4 line 143 ("Read a document/message body") — the row this slice gives its first client surface; §6 |
| Four server-heavy precedents (the discipline chain ran green four times) | ✅ **SHIPPED 2026-08-07/08** — matters/documents/messages/storage applied + battery r1 PASSED + matrix addenda + client swaps |
| Applied `message_threads` + `matters` tables (this slice's FK target + assignment source) | ✅ Applied on the dev project (messages slice T5; matters slice T5) + battery-pinned (10 tables / 10 RLS / 9 policies live) |
| RLS-gate review (this record) | ✅ Answered 2026-08-08 (§3 Q1–Q6) |
| Rollback pairing | ✅ `supabase/migrations/08_messages.down.sql` + git-revert policy pairing (§6) |
| Dated matrix addendum **before** the client surface ships | ⏳ T6 of the plan (after apply, before T7) |
| Dated apply-approval | ⏳ T5 — owner-gated; nothing applied until then |

**Conclusion:** the decision-level preconditions are satisfied (P0 + policy
tests + four shipped server precedents + both FK targets applied) and the
schema artifacts are **rehearsal-ready but unapplied**. The first SQL
execution is the battery/rehearsal (T3/T4) on a Postgres-capable
environment — the **established host is the owner's Docker machine**
(`supabase start`; the four-slice r1 Path A precedent), so this review
makes **no execution claim**.

## 2. Scope

**In scope (read path only):** a `public.messages` table (D-RT3 column
shape — individual message rows: thread FK + org + `author_display_name` +
**`body`** + `sent_at`; **the first content column in the public schema**),
one RLS SELECT policy (`messages_select_assigned` — the thread gate
extended one hop: the reader must pass the thread's own
`message_threads_select_assigned` gate, plus the **three-way org equality**
D-RT2), default-deny revokes + a narrow direct SELECT grant (Q5
discipline), and the paired backout. The client swap (T7) is a separate,
env-gated slice that builds the **first thread-detail read surface** (the
matrix body row's first client surface — D-RT5).

**Out of scope (flagged, not guessed):** **live delivery / realtime push**
(D-RT6 — postgres_changes publication + channel auth + client
reconnect/backfill is a *different authorization surface* and gets its own
mechanism review; the forward pin re-scopes to keep live delivery absent);
message **send/reply/compose** (no INSERT/UPDATE/DELETE grant, no write RPC
— a future reviewed write slice); attachments / read receipts / edit
history (no columns); partner/`compliance_officer` "deny unless separately
assigned" oversight reads (D-RT non-decision — mechanism undefined;
mirrors D-MSR5/D-STR6); billing (D-09); AI (no scope); seeding
(apply-time, T5, owner-approved with cleanup).

## 3. Gate-review decisions (Q1–Q6, answered 2026-08-08)

1. **Q1 — Read mechanism: RESOLVED.** **Table + RLS SELECT policy via
   PostgREST** (`supabase.from('messages').select(...).eq('thread_id', id)`)
   — **no** SECURITY DEFINER RPC (D-RT2). Row-scoped reads are exactly
   RLS's job; the policy calls `public.is_active_member(organization_id)`
   — already EXECUTE-granted to `authenticated` (02_rls_functions R-4
   grants), so **no new function grant is introduced**. The read is
   **per-thread** (the `.eq('thread_id', …)` filter), matching the client
   thread-detail surface (D-RT5); the RLS policy re-verifies the gate
   server-side regardless of the filter.
2. **Q2 — Assignment model: RESOLVED.** Individual messages are **matter
   content** (matrix §4 line 143/148 — "a restricted matter **or its
   documents/messages**"), and this slice extends the **messages thread
   gate one hop**: a row grants iff `is_active_member(messages.organization_id)`
   **and** an exists-subquery passes on the **row's thread** → **the
   thread's matter**: `exists (select 1 from message_threads t join matters
   m on m.id = t.matter_id and m.organization_id = t.organization_id where
   t.id = messages.thread_id and messages.organization_id =
   t.organization_id and (m.assigned_client_id = auth.uid() OR
   m.assigned_attorney_id = auth.uid()))`. **The three-way org equality is
   load-bearing** — `messages.organization_id = t.organization_id =
   m.organization_id` — so the org gate comes from the matter's
   **authoritative** org, never a denormalized column, and **a message is
   never readable when its thread (or matter) is not** (the battery pins
   the non-vacuous org-mismatch deny row). Defense-in-depth: the assignment
   columns live on the matters row itself, so the exists yields the matter
   gate regardless of whether matters RLS re-applies inside the policy
   expression (the messages-review Q2 property, inherited).
3. **Q3 — matterRef / title resolution: RESOLVED — none needed.** The
   message read needs **no embed**: the thread title is already
   client-side (the thread list loads first; the detail route receives the
   thread's id + title from the tapped row). The `Message` VO carries the
   row's own `author_display_name` + `body` + `sent_at`; every cast is
   guarded at the gateway (the documents/messages T7 baseline — malformed
   rows → typed `FormatException`, never a raw `TypeError`). **No embed,
   no fallback fabrication.**
4. **Q4 — `platform_owner_admin` and oversight rows: RESOLVED.** The
   policy contains **no owner carve-out** — the matrix's "deny, always"
   row holds as an **operational invariant, not a policy guarantee**:
   owner accounts are never assigned on matters, so the thread→matter gate
   denies them; the battery pins the unassigned-owner deny row. **Recorded
   residual (mirrors the matters/documents/messages/storage Q4):** if an
   owner account were ever assigned on a matter, this policy WOULD grant
   that thread's messages — enforcing the categorical deny would require an
   `is_platform_owner()` exclusion (and its EXECUTE grant to
   `authenticated`, widening the PostgREST surface the prior reviews
   avoided); deferred with the oversight mechanism. Partner/
   `compliance_officer` "deny unless separately assigned" cells are **NOT
   granted** in this slice.
5. **Q5 — No direct table mutation; the D-MSG1 reversal is deliberate and
   scoped: RESOLVED.** The only grant is `select` on `public.messages` to
   `authenticated` (mirrors all four prior slices); no INSERT/UPDATE/DELETE
   grant, no write RPC. **This slice ships the first content column**
   (`body text` with `check (body <> '')` — the schema-as-mapping-contract
   pattern) and the first thread-open affordance — the **deliberate,
   reviewed consummation of the D-MSG1 body-less line for the real read
   path only**: the shipped `MessageThread` VO and the messaging list stay
   body-less (the list renders metadata rows exactly as today), no write
   path exists (so no content can be inserted except the owner-approved
   demo seed at apply time), and the matrix body row's partner/owner cells
   stay ungranted. A future write slice is a separate reviewed design with
   its own matrix addendum.
6. **Q6 — Audit: RESOLVED.** Read-only slice: no new audit events, no
   `write_audit` call sites, no system-actor additions. Message reads are
   not audited (consistent with matters/documents/messages/files); the
   audit RPCs' surface is already shipped (audit surfacing, fifth
   un-deferral) and unchanged.

## 4. Policy + deny-rows spec (the battery contract, executed in T3)

Positive (each grants exactly the message set of the reader's **threads** —
proving no blanket-thread bleed; the fixture seeds each thread with a
message count EQUAL to its `message_count` column — thread-1: 1 … thread-6:
6, total 21 — so the seeded reality matches the metadata the client renders
and the 08.12 mapping-consistency pin holds):
- **assigned client** (client-a on matters 1,2 → their 2 threads) reads the
  messages of those threads (1 + 2 = **3**);
- **assigned attorney** (partner-a on matters 1,2,3 → 3 threads) reads
  theirs (1 + 2 + 3 = **6**);
- **orphan** (assigned client on matter 4 → 1 thread) reads theirs (**4**);
- row-count pins prove the read is thread-scoped, not org-wide (the
  per-thread count discipline, pinned dynamically by 08.12).

Negative (deny rows, `03_platform_owner_boundary` style):
- active org member, **no matter assignment** → denied (org-role-alone);
- **org-mismatch (D-RT2 invariant, non-vacuous):** a message row whose
  `organization_id` ≠ its thread's org (which equals its matter's org)
  denies for **every** role — the reader is an active member of the row's
  org AND assigned on the temp (different-org) matter, so **only the
  three-way-org clause denies** (the documents/messages T3 lesson,
  pre-empted);
- **cross-org**: partner-b assigned on an org-a matter, member of org-b
  only → denied (`is_active_member` of the message's org fails);
- **suspended** membership in the message's org → denied (the
  `is_active_member` arm);
- **unauthenticated** → denied;
- **`platform_owner_admin`** (owner account, unassigned) → denied, always
  (D-P0C1(a) deny-row extension; Q4 residual noted in-file);
- `body` **CHECK** row: an insert with an empty body (`''`) fails the CHECK
  — the schema is the mapping contract (the `size_bytes >= 0` /
  `message_count >= 0` pattern applied to content);
- deleted-cascade sanity: dropping the **thread** removes its messages (FK
  `on delete cascade`) — pinned in the battery fixture teardown (the
  thread-delete cascade, one hop past the matter-delete cascades of 04–07).

## 5. Schema (rehearsal-ready — D-RT3)

`public.messages`: `id uuid pk default gen_random_uuid()` ·
`organization_id uuid not null fk organizations on delete cascade`
(denormalized, mirrors threads/files — the policy's membership check reads
it, but the **matter's org is authoritative**, Q2) · `thread_id uuid not
null fk message_threads on delete cascade` (the thread gate's anchor —
drops cascade the thread's messages) · `author_display_name text not null`
(stored display name, D-RT4 — generic demo names by convention; **no
`author_user_id` column**, identity binding is the future write slice's
job via the matters D-MR4 roster seam) · `body text not null` with a
`check (body <> '')` — the schema-as-mapping-contract decision; the first
content column, deliberately scoped (Q5) · `sent_at timestamptz not null
default now()` · `created_at timestamptz not null default now()` ·
`updated_at timestamptz not null default now()`. Indexes: `(thread_id,
sent_at)` (the fetch shape: one thread's messages in order), `(organization_id)`.
RLS enabled; `revoke all … from anon, authenticated`; `grant select … to
authenticated` only (Q5). **No attachments, no read receipts, no edit
history, no `author_user_id`** (D-RT3/D-RT4).

## 6. Rollback pairing (never-fix-forward)

- `supabase/migrations/08_messages.down.sql` — `drop table public.messages;`
  (clean inverse; the inline `body` CHECK dies with the table, like 05/06/07
  — no type object to drop).
- Policy backout: `git revert` of the policy commit (design §7 convention
  in `docs/rollback_plan.md`).
- Apply-time residue (T5): demo message rows are inserted and removed in
  the same owner-approved step (cleanup discipline; one insert set, one
  delete set — referencing the **applied** demo thread ids, resolved at
  apply time).

## 7. Ledger

- Docs-only + rehearsal-ready SQL this session: **no `lib/`/`test/` change,
  no README-count change, no dev-project contact** — `verify_ledger.sh`
  unaffected; nothing pushed.
- The plan (T1–T8) tracks each subsequent gate; the battery (T3) and
  rehearsal (T4) are the first executions and will carry their own
  evidence records. The forward pin flips at T3 (messages PRESENT) and
  re-scopes to live delivery ABSENT (D-RT7).
