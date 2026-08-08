# LegalHub — Realtime Push (Live Delivery) Mechanism Design Review (2026-08-08)

> **Record type:** Mechanism design review for the realtime **live-delivery**
> (push) slice — the seventh roadmap §14 per-feature un-deferral
> (`postgres_changes` publication + Realtime RLS + the client subscription
> lifecycle), the **D-RT6 recorded follow-up** of the realtime read slice
> (sixth, SHIPPED 2026-08-08). Follows the `docs/p2_schema_rls_design.md`
> §8 Q1–Q6 pattern and the six shipped precedents (matters/documents/
> messages/storage server slices + audit surfacing + realtime read), but
> the questions are answered for a **mechanism, not a table**: publication
> membership, delivery authorization, the event source, and the client
> lifecycle. **Docs + rehearsal-ready artifacts only — NOT applied:**
> nothing here or in the paired `supabase/migrations/09_realtime_push*.sql`
> / `supabase/policies/messages_insert.sql` touches the dev project until
> the owner's dated apply-approval (INSTRUCTIONS.md §2.1/§5 hard gates).
>
> **Status: REVIEWED 2026-08-08 (decision-level).** Plan:
> `docs/realtime_push_real_data_plan_2026-08-08.md` (D-LV1…D-LV6 ratified
> by autonomy — recommended path, per the pair-programming grant).
> **Owner:** Project Owner (github.com/mostafasayed118). **Governed by:**
> `docs/permission_matrix.md` §6 (the "Realtime subscription for an
> org/matter the session no longer has access to → No events delivered"
> row — enforced here) · §7 (addendum discipline) · `docs/realtime_push_real_data_plan_2026-08-08.md` ·
> `docs/realtime_rls_gate_review_2026-08-08.md` (the read gate this
> delivery reuses) · `docs/rollback_plan.md` ·
> `docs/p0_closure_scope_2026-08-05.md` (D-P0C1(b) forward-pin discipline) ·
> Supabase Realtime docs (the mechanism basis: postgres_changes + Realtime
> RLS) · `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Precondition (roadmap §14 → this slice) | Status |
|---|---|
| P0 closes (D-02…D-10b) | ✅ **RATIFIED 2026-08-05** — `docs/p0_closure_scope_2026-08-05.md` |
| Policy tests exist | ✅ Shipped — `scripts/verify_policy_tests.sh` + the six prior slices' batteries |
| Signed matrix governs the grant (positive + negative) | ✅ `docs/permission_matrix.md` §6 — the realtime subscription row; §4 (the write row this slice adds) |
| Six server/client precedents (the discipline chain ran green six times) | ✅ **SHIPPED 2026-08-07/08** — matters/documents/messages/storage applied + audit + realtime read |
| Applied `messages` table + `messages_select_assigned` SELECT policy (the delivery gate + the event-source table) | ✅ Applied on the dev project (realtime read T5, `35cceb9`) + battery-pinned (10 tables / 10 RLS / 9 policies live; the harness forward pin asserts `pg_publication_tables` = 0 for `messages`) |
| Mechanism review (this record) | ✅ Answered 2026-08-08 (§3 Q1–Q6) |
| Rollback pairing | ✅ `supabase/migrations/09_realtime_push.down.sql` + git-revert policy pairing (§6) |
| Dated matrix addenda **before** the client surface ships | ⏳ T6 of the plan (after apply, before T7) |
| Dated apply-approval | ⏳ T5 — owner-gated; nothing applied until then |

**Conclusion:** the decision-level preconditions are satisfied (P0 + policy
tests + six shipped precedents + the delivery-gate table already applied)
and the artifacts are **rehearsal-ready but unapplied**. The first SQL
execution is the battery/rehearsal (T3/T4) — this session's Docker-backed
stack (the realtime read T4 precedent) makes that executable here; the
apply (T5) stays owner-gated.

## 2. Scope

**In scope (push, read-adjacent):** the `messages` table added to the
**`supabase_realtime` publication** (exactly `messages`, nothing else —
D-LV2), **Realtime RLS** as the delivery authorization (the **existing
`messages_select_assigned` SELECT policy is the delivery gate** — D-LV3),
the **minimal write source** (`messages_insert_assigned` INSERT policy +
`sendMessage(threadId, body)` + a thread-detail composer — D-LV1, the
event origin without which an INSERT channel delivers nothing), and the
client subscription lifecycle (per-thread channel + `thread_id=eq.…`
filter + reconnect + backfill via the shipped `fetchMessages` — D-LV4).
The matrix §6 "Realtime subscription for an org/matter the session no
longer has access to → No events delivered" row becomes **enforced +
battery-pinned**.

**Out of scope (flagged, not guessed):** **Broadcast/Presence** (the
`realtime.messages` authorization-table path — a different, scalability-
oriented mechanism not needed at this app's per-thread scale); message
**edit/delete/attachments/read-receipts** (insert-only write); the
partner/`compliance_officer` "deny unless separately assigned" oversight
rows (mechanism undefined — mirrors D-MSR5/D-STR6); billing (D-09); AI
(no scope); the apply-time demo send (T5, owner-approved, rollback paired).

## 3. Gate-review decisions (Q1–Q6, answered 2026-08-08)

1. **Q1 — Delivery mechanism: RESOLVED — `postgres_changes` on the
   `messages` table via the default `supabase_realtime` publication.** The
   migration records exactly `alter publication supabase_realtime add
   table messages;` (D-LV2) — the publication exists by default on
   Supabase projects; the forward pin asserts `pg_publication_tables`
   count = 0 for `messages` today and flips to **1, with nothing else**
   (D-LV5). The client subscribes
   `client.channel('thread:<id>').onPostgresChanges(event: insert,
   schema: 'public', table: 'messages', filter: 'thread_id=eq.<id>', …)`.
   **No `realtime.messages` authorization table is needed** — that is the
   Broadcast/Presence path; postgres_changes has its own authorization
   (Q2).
2. **Q2 — Delivery authorization: RESOLVED — Realtime RLS, the EXISTING
   `messages_select_assigned` SELECT policy IS the delivery gate.** Verified
   mechanism (Supabase Realtime RLS: postgres_changes adheres to the
   underlying table's RLS SELECT policies — the Aug 2024 Realtime
   authorization post: "Postgres Changes already adheres to RLS policies
   on the underlying table"): at delivery time the policy re-evaluates
   against the subscriber's JWT, so **publication membership is
   enablement, the RLS policy is authorization** — the read plan's D-RT6
   "different authorization surface" caution resolves to two pinned
   layers, not an unmodeled one. Consequence: the matrix §6 negative row
   becomes enforceable — a reader whose membership is suspended/removed,
   whose role changes, or who was never assigned **receives no events**,
   because the same gate that denies the SELECT denies the delivery. The
   battery pins this with a role-impersonated delivery-equivalence check.
   **Recorded residual (mirrors the read Q4):** the delivery gate is the
   policy as written at event time; a future policy edit changes delivery
   retroactively — which is the intended single-source-of-truth behavior,
   not a defect.
3. **Q3 — Event source (the honest gap): RESOLVED — the minimal send path
   (D-LV1).** `postgres_changes` INSERT delivers **new rows**; this repo
   has no message write path (the read slice shipped "no composer, no
   send/reply", D-RT5), so a channel with no write source is dead. The
   event origin is the **`messages_insert_assigned` INSERT policy** — the
   same gate shape as the read policy (`is_active_member(organization_id)`
   AND the exists through thread → matter with the three-way org equality
   AND assigned client/attorney; the non-empty `body` CHECK stays
   schema-level) — plus `sendMessage(String threadId, String body)` on the
   messaging seam and a composer on the thread-detail surface. **Insert-
   only**: no UPDATE/DELETE policy, no edit/delete/receipts/attachments
   (the write-path creep guard mirrors the read slice's body-less line).
   The channel filter `thread_id=eq.<id>` narrows delivery to the open
   thread; the INSERT policy re-verifies the gate server-side regardless.
4. **Q4 — Client lifecycle: RESOLVED — a NEW `MessageRealtimeApi` seam
   (D-LV4).** Provider types (`RealtimeChannel`) stay in one file (the
   seam discipline): `channel('thread:<id>')` + `onPostgresChanges` with
   the `thread_id=eq.…` filter, `onError`/`onSystemMessage` →
   re-subscribe (reconnect), and **initial backfill = the existing
   `fetchMessages` read** on subscribe (no second fetch mechanism). The
   `MessageThreadDetailCubit` owns the merged list and appends live INSERT
   rows, deduped by id. Env-less runs + ALL tests use a deterministic fake
   channel — the real reconnect/backfill path is the **configured-build
   verification** (honest pending, never claimed by unit tests).
5. **Q5 — Owner / oversight rows: RESOLVED.** The INSERT policy has **no
   owner carve-out** — `platform_owner_admin` "deny, always" holds as an
   operational invariant (owner accounts are never assigned on matters, so
   the thread→matter gate denies both send and receive); the battery pins
   the unassigned-owner deny. Partner/`compliance_officer` "deny unless
   separately assigned" stay ungranted for both the write and the
   delivery (the oversight mechanism is undefined — mirrors every prior
   Q4/Q5). Anon denied on both the INSERT grant (no grant) and delivery
   (no session).
6. **Q6 — Audit / observability: RESOLVED — the direct-INSERT path is NOT
   contract §8-audited, and that is recorded honestly.** The app's audited
   writes go through the org RPCs (which call `write_audit`); a policy-
   gated direct INSERT (this slice's demo send) is not RPC-audited — the
   same posture as the demo seeds in the six prior applies. **Flagged:**
   a future real-write slice should route sends through an audited
   `send_message` RPC (the D-MR4 roster seam + write_audit), and the
   live-delivery subscription itself is a client-side channel (no server
   audit row by design — the channel is a delivery pipe, not a state
   change). No new audit surface this slice.

## 4. Policy spec + deny rows (battery target)

**`messages_insert_assigned` (INSERT, `supabase/policies/messages_insert.sql`):**
```sql
create policy messages_insert_assigned on public.messages
  for insert
  with check (
    public.is_active_member(organization_id)
    and exists (
      select 1 from public.message_threads t
      join public.matters m on m.id = t.matter_id
        and m.organization_id = t.organization_id
      where t.id = messages.thread_id
        and messages.organization_id = t.organization_id
        and (m.assigned_client_id = auth.uid()
             or m.assigned_attorney_id = auth.uid())
    )
  );
```
Deny rows the battery pins (`supabase/tests/09_realtime_push.sql`):
- **org-role-alone insert** (member, no matter assignment) → denied;
- **cross-org insert** (assigned on an org-a matter, org-b member only) →
  denied;
- **suspended membership** in the message's org → denied (the
  `is_active_member` arm);
- **`platform_owner_admin` insert** → denied, always (never assigned);
- **anon insert** → denied (no grant);
- **empty `body`** → CHECK violation (schema-level, not policy);
- positive: the **assigned attorney/client** inserts on their thread →
  allowed;
- **delivery equivalence (the §6 row):** after the insert, a role-
  impersonated read with the SAME gate returns the row for the assigned
  reader and 0 for the suspended/cross-org/owner reader — the delivery
  gate is the read gate (Q2).

## 5. Migration (rehearsal-ready — NOT applied)

**`supabase/migrations/09_realtime_push.sql`:** `alter publication
supabase_realtime add table messages;` — exactly one membership (D-LV2);
no new table, no new columns, no RLS change (the SELECT policy ships in
08; the INSERT policy lives in `supabase/policies/messages_insert.sql`).
**`supabase/migrations/09_realtime_push.down.sql`:** `alter publication
supabase_realtime drop table messages;` — the clean inverse.
**Forward-pin re-scope (D-LV5):** the harness §1f pin flips from
`pg_publication_tables … messages = 0` to **`= 1` with nothing else**
(the pin's teeth move from "live delivery absent" to "no accidental table
exposure via realtime" — D-P0C1(b) discipline); the policy pin re-scopes
10 → **11** (the INSERT policy).

## 6. Rollback pairing (never-fix-forward)

- `supabase/migrations/09_realtime_push.down.sql` — drop the publication
  membership (clean inverse; the INSERT policy is table-scoped and stays,
  so the policy commit git-reverts separately).
- Policy backout: `git revert` of the `messages_insert.sql` commit (design
  §7 convention in `docs/rollback_plan.md`).
- Apply-time residue (T5): the demo send is inserted and removed in the
  same owner-approved step (one insert, one delete — referencing the
  **applied** demo thread ids, resolved at apply time); the live-delivery
  observation is recorded verbatim with the rollback standing by.

## 7. Ledger

- Docs-only + rehearsal-ready SQL this session: **no `lib/`/`test/` change,
  no README-count change, no dev-project contact** — `verify_ledger.sh`
  unaffected; nothing pushed.
- The plan (T1–T8) tracks each subsequent gate; the battery (T3) and
  rehearsal (T4) are the first executions and will carry their own
  evidence records. The forward pin flips at T3 (messages in the
  publication, count 1, nothing else) — D-LV5.
