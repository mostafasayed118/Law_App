# LegalHub — Audited Message-Send (`send_message`) Design Review (2026-08-08)

> **Record type:** Mechanism design review for the **audited message-send
> RPC** — the next slice after the seventh roadmap §14 per-feature
> un-deferral (realtime live delivery, SHIPPED `c229fcb`), and the
> **review-Q6 recorded follow-up** of the realtime-push slice: the app's
> message write path currently goes through a policy-gated direct INSERT
> that is **NOT contract §8-audited**, while every other write in the app
> routes through org RPCs that call `write_audit`. This review answers the
> `docs/p2_schema_rls_design.md` §8 Q1–Q6 pattern for a **function, not a
> table**: function security, the in-function authorization gate, the audit
> row, and the direct-INSERT fate (D-SM3). **Docs + rehearsal-ready
> artifacts only — NOT applied:** nothing here or in the paired
> `supabase/rpc/send_message.sql` / `_down.sql` touches the dev project
> until the owner's dated apply-approval (INSTRUCTIONS.md §2.1/§5 hard
> gates).
>
> **Status: REVIEWED 2026-08-08 (decision-level).** Plan:
> `docs/send_message_rpc_plan_2026-08-08.md` (D-SM1…D-SM3 ratified by
> autonomy — recommended path, per the pair-programming grant).
> **Owner:** Project Owner (github.com/mostafasayed118). **Governed by:**
> `docs/permission_matrix.md` §4 (the \"Send a message (insert)\" row —
> client/attorney SHIP behind `messages_insert_assigned`; the mechanism
> note this review amends to \"audited RPC\") · §7 (addendum discipline) ·
> `docs/send_message_rpc_plan_2026-08-08.md` ·
> `docs/realtime_push_gate_review_2026-08-08.md` (the write gate this RPC
> re-asserts in-function) · `docs/rollback_plan.md` ·
> `docs/p0_closure_scope_2026-08-05.md` (D-P0C1(b) forward-pin discipline) ·
> the audited-RPC seam precedent (`supabase/rpc/invite_member.sql` —
> `security definer` + `has_org_role` + `write_audit`) · `INSTRUCTIONS.md`
> §2.1/§3/§5.

---

## 1. Gate position

| Precondition (roadmap §14 → this slice) | Status |
|---|---|
| P0 closes (D-02…D-10b) | ✅ **RATIFIED 2026-08-05** — `docs/p0_closure_scope_2026-08-05.md` |
| Policy tests exist | ✅ Shipped — `scripts/verify_policy_tests.sh` + the seven prior slices' batteries |
| Signed matrix governs the grant (positive + negative) | ✅ `docs/permission_matrix.md` §4 — the \"Send a message (insert)\" row (SHIP behind `messages_insert_assigned`); this review's Q6 + T6 amend the mechanism note |
| Seven server/client precedents (the discipline chain ran green seven times) | ✅ **SHIPPED 2026-08-07/08** — matters/documents/messages/storage applied + audit + realtime read + realtime push |
| Applied `messages` table + `messages_insert_assigned` INSERT policy (the current, un-audited write path) | ✅ Applied on the dev project (realtime-push T5, `7efb32b` — policies 9→10, the first live INSERT `7cbf49e0-…`) + battery-pinned (11 tables / 11 RLS / 11 policies live; `pg_publication_tables` = exactly `messages`) |
| Mechanism review (this record) | ✅ Answered 2026-08-08 (§3 Q1–Q6) |
| Rollback pairing | ✅ `rpc/_down.sql` drop + git-revert policy/commit pairing (§6) |
| Dated matrix addendum **before** the client surface ships | ⏳ T6 of the plan (after apply, before T7) |
| Dated apply-approval | ⏳ T5 — owner-gated; nothing applied until then |

**Conclusion:** the decision-level preconditions are satisfied (P0 + policy
tests + seven shipped precedents + the applied `messages` table and INSERT
policy this RPC supersedes) and the artifact is **rehearsal-ready but
unapplied**. The first SQL execution is the battery/rehearsal (T3/T4) —
this session's Docker-backed stack (the realtime T4 precedent) makes that
executable here; the apply (T5) stays owner-gated.

## 2. Scope

**In scope (write-path consummation):** a NEW **`send_message` RPC** —
`security definer set search_path = public` (the `invite_member`
precedent), the **in-function gate** that re-asserts the exact
`messages_insert_assigned` authorization (`is_active_member(organization_id)`
AND the thread→matter exists with the three-way org equality AND assigned
client/attorney — **D-SM1**), a `write_audit('message:create', 'allowed',
…)` row (contract §8 coverage — the slice's whole point), the INSERT with
`returning id`, and the **client swap** where `sendMessage` routes through
the RPC (**D-SM2** — the impl's org-resolution pre-read moves into the
function, Q4). **D-SM3** — the direct-INSERT surface (grant + policy) is
revoked so the audited RPC becomes the **only** write path; the harness §1d
RPC-EXECUTE list moves **18 → 19 RPCs**.

**Out of scope (flagged, not guessed):** message **edit/delete/attachments/
read-receipts** (insert-only, unchanged); the composer UI shape and the
subscription (realtime-push T7, untouched); **Broadcast/Presence**; the
partner/`compliance_officer` \"deny unless separately assigned\" oversight
rows (mechanism undefined — mirrors every prior slice); billing (spec
D-09) and AI (no scope) — the §14 reconciliation keeps both deferred.

## 3. Gate-review decisions (Q1–Q6, answered 2026-08-08)

1. **Q1 — Function security: RESOLVED — `security definer` with a pinned
   `search_path = public`, the `invite_member` precedent.** The function is
   owned by the table owner and runs with definer privileges, so **RLS does
   NOT apply inside it** — the explicit in-function check (Q2) is therefore
   the **sole write authorization**, not an optional belt-and-braces. The
   `search_path` pin prevents schema-capture; pgcrypto/helper calls stay
   qualified where the rehearsal found it necessary (the R-1 pattern).
   Consequence: D-SM3 can safely revoke the direct-INSERT surface (Q6)
   because the RPC's gate is self-contained — the app never depends on the
   policy again.
2. **Q2 — In-function authorization (the load-bearing gate): RESOLVED —
   the exact `messages_insert_assigned` check, re-asserted inside the
   function (D-SM1).** The function takes `(p_thread_id uuid, p_body text)`
   and resolves **thread → matter → org under the same three-way org
   equality** the policy encodes: `public.is_active_member(organization_id)`
   AND `exists(select 1 from public.message_threads t join public.matters m
   on m.id = t.matter_id and m.organization_id = t.organization_id where
   t.id = p_thread_id and (m.assigned_client_id = auth.uid() or
   m.assigned_attorney_id = auth.uid()))`. The `body` non-empty CHECK stays
   schema-level (the D-RT3 mapping contract) — the function passes `p_body`
   through and the CHECK fires as before. **Why in-function rather than
   relying on the policy:** (a) `security definer` bypasses RLS (Q1), and
   (b) once D-SM3 lands the policy is gone — the function IS the gate, and
   the battery pins its deny rows by role-impersonated **EXECUTE** calls,
   not INSERTs. **Recorded residual (mirrors every prior Q4/Q5):** the gate
   is the function as written at call time; a future gate edit changes the
   write authorization retroactively — the intended single-source-of-truth
   behavior, not a defect.
3. **Q3 — Audit / observability: RESOLVED — every send writes a §8 audit
   row by construction.** The function calls `public.write_audit(
   'message:create', 'allowed', p_organization_id => v_org,
   p_resource_type => 'message', …)` — the `invite_member` seam — after the
   gate passes and before/with the INSERT, so a successful send is
   **always** audited (no direct-INSERT path remains, Q6). This closes the
   realtime-push review-Q6 gap exactly as recorded: \"a future real-write
   slice should route sends through an audited `send_message` RPC (the
   D-MR4 roster seam + write_audit)\". The live-delivery subscription stays
   un-audited by design (a delivery pipe, not a state change — recorded in
   the push review Q6). The battery pins the audit row (the D-P0C4
   redacted-observer pattern: the row appears with the generic actor
   reference; raw content never stored in the audit trail).
4. **Q4 — Org resolution moves into the function (client simplification,
   D-SM2): RESOLVED.** The current client impl performs an org-resolution
   pre-read before its direct INSERT (the `messages_insert_assigned` WITH
   CHECK prerequisite — realtime-push T7). With the RPC, the function
   resolves thread → org **under the gate itself**; an unreadable thread
   (no org / not assigned) is a **typed denial inside the function** before
   anything is written. The client drops the pre-read round trip: `sendMessage`
   parses the thread id to uuid at the impl boundary (the seam's existing
   VO-id → uuid mapping convention) and calls the RPC with
   `(thread_id, body)`. Failure mapping stays: RPC denial →
   `message_send_denied`, provider outage → `message_send_unavailable`,
   unexpected → `message_send_failed` (the realtime-push T7 kinds,
   unchanged in meaning — only the mechanism behind them changes).
5. **Q5 — Owner / oversight rows: RESOLVED.** The in-function gate has **no
   owner carve-out** — `platform_owner_admin` \"deny, always\" holds as an
   operational invariant (owner accounts are never assigned on matters, so
   the thread→matter gate denies; the battery pins the unassigned-owner
   EXECUTE denial). Partner/`compliance_officer` \"deny unless separately
   assigned\" stay ungranted (unchanged from the INSERT policy — the
   oversight mechanism is undefined, mirrors every prior Q4/Q5). Anon
   denied (no EXECUTE grant — the §1d pin asserts authenticated yes / anon
   no).
6. **Q6 — Direct-INSERT fate (D-SM3) + the 09-battery re-scope: RESOLVED —
   revoke the `authenticated` INSERT grant on `messages` and drop the
   `messages_insert_assigned` policy; the audited RPC becomes the only
   write path.** Rationale: defense in depth (a dormant policy is a
   maintenance trap), and the §8 story becomes \"every write is audited, by
   construction\" — no un-audited INSERT path can reappear without an
   explicit grant re-add. **Battery consequence (recorded for T3):** the
   09 battery's INSERT-policy group (`supabase/tests/09_realtime_push.sql`
   — ~10 role-impersonated `insert into public.messages` checks) **must be
   re-scoped in the same slice**, because the revocation denies those
   INSERTs at the privilege layer: the write-positive/deny rows move to
   role-impersonated `select public.send_message(…)` EXECUTE checks (the
   same five deny rows + the assigned positive + the audit-row positive),
   and the INSERT group becomes the **revocation pin** (authenticated
   INSERT false / policy gone). Policy count **11 → 10** in the same
   slice; the delivery-equivalence 09.11/09.12 checks are untouched (they
   read under the SELECT policy, which stands). The apply-time demo send
   (T5) shifts from an INSERT to an RPC call, with the audit row observed
   verbatim.

## 4. Function spec + deny rows (battery target)

**`supabase/rpc/send_message.sql` (sketch — the T2 artifact):**
```sql
create or replace function public.send_message(
  p_thread_id uuid,
  p_body      text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_org uuid;
begin
  -- gate: is_active_member + thread->matter three-way org equality + assigned
  select t.organization_id into v_org
    from public.message_threads t
    join public.matters m on m.id = t.matter_id
      and m.organization_id = t.organization_id
   where t.id = p_thread_id
     and public.is_active_member(t.organization_id)
     and (m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid());
  if v_org is null then
    raise exception 'permission denied';
  end if;
  perform public.write_audit('message:create', 'allowed',
    p_organization_id => v_org,
    p_resource_type   => 'message');
  return (insert into public.messages
            (organization_id, thread_id, author_display_name, body)
          values (v_org, p_thread_id,
                  coalesce(nullif(auth.jwt() ->> 'display_name', ''), 'Demo user'),
                  p_body)
          returning id);
end $$;
-- grant execute on function public.send_message(uuid, text) to authenticated;
```
Deny rows the battery pins (`supabase/tests/10_send_message_rls.sql`),
each by role-impersonated **EXECUTE**:
- **org-role-alone send** (member, no matter assignment) → `permission
  denied`;
- **cross-org send** (assigned on an org-a matter, org-b member only) →
  denied;
- **suspended membership** in the thread's org → denied (the
  `is_active_member` arm);
- **`platform_owner_admin` send** → denied, always (never assigned);
- **anon execute** → denied (no grant);
- **empty `body`** → CHECK violation (schema-level);
- positive: the **assigned attorney/client** sends on their thread → the
  returned id + a **`message:create` audit row** exists (the §8 positive);
- **revocation pin:** `insert into public.messages` as an assigned fixture
  role → denied at the privilege layer (D-SM3), and
  `messages_insert_assigned` no longer exists in `pg_policies` (policies
  11 → 10).

## 5. Artifacts (rehearsal-ready — NOT applied)

**`supabase/rpc/send_message.sql`** — the §4 sketch (gate → audit →
INSERT → RETURNING) + the `authenticated` EXECUTE grant (anon none).
**`supabase/rpc/_down.sql`** — the backout entry (drop function +
revoke), the P2 `_down.sql` convention.
**Harness re-scope:** `scripts/verify_policy_tests.sh` §1d RPC-EXECUTE
list gains **`send_message(uuid, text)`** (18 → 19); the battery file list
+ `--apply` order gain `10_send_message_rls.sql`; the **09 battery's
INSERT group is re-scoped to EXECUTE + the revocation pin (Q6)**; the
policy pin re-scopes **11 → 10**; the §1f forward pin is untouched (the
publication membership stays exactly `messages` — the write-surface change
is policy/function-level, never the publication).

## 6. Rollback pairing (never-fix-forward)

- `supabase/rpc/_down.sql` — drop `send_message` + revoke the EXECUTE
  grant (clean inverse).
- Policy/grant backout: `git revert` of the D-SM3 revocation commit (the
  `messages_insert_assigned` policy + INSERT grant re-add), the design §7
  convention in `docs/rollback_plan.md`.
- Apply-time residue (T5): the demo send becomes an RPC call — one send,
  one audit row, one cleanup delete in the same owner-approved step
  (referencing the **applied** demo thread ids, resolved at apply time);
  the audit row's presence is observed verbatim with the rollback standing
  by.

## 7. Ledger

- Docs + rehearsal-ready SQL this session: **no `lib/`/`test/` change, no
  README-count change, no dev-project contact** — `verify_ledger.sh`
  unaffected; nothing pushed.
- The plan (T1–T8) tracks each subsequent gate; the battery (T3) and
  rehearsal (T4) are the first executions and will carry their own evidence
  records. The policy pin re-scopes at T3 (11 → 10, D-SM3) and the §1d
  RPC-EXECUTE list moves 18 → 19 — the roadmap §13 \"18-of-18 wired\" claim
  follows in T8's lockstep.
