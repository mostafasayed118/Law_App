# LegalHub — Notification-Feed Producer: Mechanism/RLS-Gate Review (2026-08-11)

> **Record type:** mechanism/RLS-gate design review (the T1 gate) for the
> **notification-feed producer slice** — the D-N7 follow-up that maps real
> events from the shipped write paths into `notifications` rows
> server-side, per the ratified plan
> `docs/notification_feed_producer_slice_plan_2026-08-11.md` (D-P1…D-P6
> **RATIFIED 2026-08-11**). Follows the
> `docs/p2_schema_rls_design.md` §8 Q1–Q6 pattern and the feed read-slice
> review precedent (`docs/notification_feed_gate_review_2026-08-11.md`).
> **Docs + rehearsal-ready artifacts only — NOT applied:** nothing here
> touches the dev project until the owner's dated apply-approval
> (INSTRUCTIONS.md §2.1/§5 hard gates).
>
> **Status: REVIEWED 2026-08-11 (decision-level).** Plan:
> `docs/notification_feed_producer_slice_plan_2026-08-11.md` (step 1 MET —
> D-P1…D-P6 ratified; un-blocked to T1). Feed surface: SHIPPED end-to-end
> (`d923940` — T1–T8 + walkthrough; the producer is the D-N7 follow-up).
> The artifacts (`15_notification_producer.sql` + `.down` + battery 15)
> are **the next pipeline step (T2/T3)** — this review gates their shape.
> **Owner:** Project Owner (github.com/mostafasayed118). **Governed by:**
> the ratified producer plan (D-P1…D-P6) · the ratified feed scope note
> (D-N1…D-N7) · `docs/permission_matrix.md` §4/§7 (the "View notifications
> (metadata)" row stays read-only member SHIP — the producer is a server
> mechanism, not a client grant) · the matter-write trigger precedent
> (`docs/matter_write_slice_review_2026-08-09.md` R-1/R-2 — "trigger is
> not a policy") · `docs/rollback_plan.md` · `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Precondition (plan → this slice) | Status |
|---|---|
| Producer plan ratified (the gate) | ✅ **RATIFIED 2026-08-11** — `docs/notification_feed_producer_slice_plan_2026-08-11.md` (D-P1…D-P6); step 1 MET |
| Feed read surface shipped (the producer's target) | ✅ **SHIPPED end-to-end** — T1–T8 + E2E walkthrough (`d923940`; 13 tables / 13 RLS / 12 public policies / `NotificationGateway` swap, suite 1303) |
| Shipped write paths pinned (the producer's sources) | ✅ `create_matter` (F-01, battery 13) + `send_message` (D-SM3, battery 10) — both `security definer`, both §8-audited in-transaction (`matter:create` / **`message:create`**, org carried on the audit row) |
| Harness baseline (the pins this slice touches) | ✅ 13 tables / 13 RLS / 12 public policies / 20 EXECUTE RPCs / batteries 01–14 (verified 2026-08-11) |
| Mechanism/RLS-gate review (this record) | ✅ Answered 2026-08-11 (§3 Q1–Q6) |
| Rehearsal-ready artifacts (T2) | ⏳ Next step — this review's shape (§3) is the artifact contract |
| Rollback pairing | ⏳ `supabase/migrations/15_notification_producer.down.sql` (drop trigger + function) + git-revert policy pairing |
| Dated apply-approval | ⏳ T5 — owner-gated; nothing applied until then |

**Conclusion:** the decision-level preconditions are satisfied (plan
RATIFIED, feed shipped, the two write RPCs battery-pinned, the harness
baseline known). The mechanism shape below is the **artifact contract**;
no execution claim is made — the first SQL execution is the
battery/rehearsal (T3/T4) on a Postgres-capable environment (the
established owner's-host precedent).

## 2. Scope

**In scope (server-only producer):** an `AFTER INSERT` trigger on
`audit_events` mapping the two shipped audited actions (`matter:create`,
`message:create`, `outcome = 'allowed'`) into redacted, org-scoped
`notifications` rows; the harness re-pin of battery 14's absolute counts;
a new producer battery (15) with delta + atomicity + redaction + deny
checks. **Explicitly out:** any modification to the shipped RPCs (D-P1),
any new grant/policy (D-P4/D-P5), any client-EXECUTE surface (RPC-EXECUTE
stays 20), invoice/approval/appointment/system events (D-P2 — no server
write source in v1, never invented per D-N7), any read-flag or delivery
behavior (D-N2/D-N6).

## 3. Q1–Q6 (the p2_schema_rls_design §8 pattern, mechanism-adapted)

### Q1 — Is the audit-mirror trigger the right mechanism? (D-P1)

**Yes.** The producer is an `AFTER INSERT FOR EACH ROW` trigger on
`audit_events` (the single point every audited event already passes),
filtering `action IN ('matter:create','message:create') AND outcome =
'allowed'` and inserting the mapped `notifications` row. Verified
properties:

- **Zero modification to the shipped RPCs** — `create_matter` and
  `send_message` keep their F-01/D-SM3-pinned bodies; batteries 13/10
  pass **unchanged** (the producer is purely additive).
- **No recursion** — `notifications` has no trigger; the mirror insert
  cannot re-fire.
- **Security posture** — the trigger function is `security definer` with
  `set search_path = public` (the house function posture) and runs as the
  table owner, so the `notifications` insert needs **no new grant and no
  new policy** (owner bypasses RLS — the same footing as the battery's
  postgres-role fixture inserts).
- **Future surfaces** — any later audited RPC auto-produces by extending
  the action map (one CASE arm), the D-P1 trade-off (the feed inherits
  the audit taxonomy) accepted and recorded.

### Q2 — Is the action map + redaction honest? (D-P2/D-P3)

**Yes.** The v1 event set is exactly the **two shipped audited write
actions** — verified against the RPC sources: `create_matter` audits
`'matter:create'`/`'allowed'` with `organization_id` from the param
(`supabase/rpc/create_matter.sql`), and `send_message` audits
**`'message:create'`**/`'allowed'` with the org resolved from
thread→matter (`supabase/rpc/send_message.sql:66-72`). The map is fixed
and redacted (the D-N3 contract made structural):

| Audit action | category | type (D-N3 set) | summary (fixed, redacted) |
|---|---|---|---|
| `matter:create` | `activity` | `matter_created` | `Demo notification — matter created` |
| `message:create` | `activity` | `message_received` | `Demo notification — new message in thread` |

The matter title and message body **never** enter the summary (battery-15
redaction pin). Invoice/approval/appointment/system have **no server
write source in v1** (D-11 no-payment; fake-domain queues; no scheduler)
— per D-N7 they are not invented; the fixture/fake rows keep those
categories visible in env-less runs, and the map extends per future
slice.

### Q3 — Org resolution + atomicity (the feed's org-gate feeds, live)

**Org resolution is the audit row's, not a re-derivation.** The mirror
reads `NEW.organization_id` — both RPCs already write it (the create's
param; the send's thread-resolved org), so no join is needed and
identity-level events (`organization_id IS NULL`, e.g. platform actions)
are skipped by the filter. The produced row then flows through the
shipped `notifications_select_org` gate unchanged (active member of the
row's org; `platform_owner_admin` deny-always — the existing battery 14
pins hold on produced rows too).

**Atomicity:** the mirror insert lives in the same transaction as the
audit row — a rolled-back event (e.g. battery 13.01's in-txn create)
produces a feed row that **vanishes with the rollback** (pinned by
battery 15's in-txn check), and a mirror-insert failure rolls the event
back (the `write_audit` load-bearing precedent — "a write_audit failure
rolls the create back"). Realistically inert (the audit row's org is
already valid, the category CHECK admits the map's fixed values) — the
strict atomicity is the decision.

### Q4 — Privilege posture: no new grant, no new policy, no RPC

**Clean.** The mirror function is **trigger-only**: EXECUTE revoked from
`public`, `anon`, `authenticated` (the `write_audit` deny precedent) —
clients cannot invoke it; the harness RPC-EXECUTE pin stays **20** and
gains a deny-pin for the new function. The member-facing surface remains
**strictly read-only**: no INSERT/UPDATE/DELETE grant or policy on
`notifications`; the matrix "View notifications (metadata)" row is
**unchanged** (member SHIP, no write cells — the producer is a server
mechanism, not a client grant, exactly like the F-01
`refuse_platform_owner_assignment` trigger, which was recorded "trigger
is not a policy" in the applied-surface §1a). Applied-surface counts
stay **13 tables / 13 RLS / 12 public policies / 20 RPC-EXECUTE**.

### Q5 — Battery-14 re-pin: deterministic, exact (D-P6)

**Verified by source inspection — the re-pin is exactly computable:**

- Batteries 10 and 13 are the **only** RPC callers (all other batteries
  write the two audit actions nowhere — verified by grep).
- Battery 13's successful creates (13.01, 13.16) are inside
  `begin … rollback` — **rolled back**, zero persistent producer rows;
  13.02/13.03/13.06 etc. are denied (raise before `write_audit`) — zero.
- Battery 10's two **positive sends (10.01, 10.02) commit** (CHECK 10.10:
  "exactly the two positive sends' audit rows exist") — with the
  producer, exactly **2 persistent org-a notification rows** exist when
  battery 14 runs.
- Battery 14's fixture baseline: 4 org-a + 1 org-b seeded rows.

**Re-pin (exact):** 14.01 org-a partner **4 → 6**; 14.02 org-a client
**4 → 6**; 14.03 org-b partner **1 (unchanged)**. The r1 rehearsal
confirms these exact numbers — never a relative fudge.

The new **battery 15** uses **delta-based** assertions (count before →
RPC call → count after +1) so its own checks are order-robust, plus: the
in-txn atomicity pin (row appears in-txn, vanishes on rollback), the
mirror EXECUTE-deny pin for `authenticated`, the redaction pin (produced
summary never contains the matter title / message body), a denied create
produces no row, and anon still denied reading produced rows.

### Q6 — Harness/apply/rollback contract (T3/T4/T5/T7)

- **Artifacts:** `supabase/migrations/15_notification_producer.sql` (the
  trigger function + `create trigger notifications_from_audit after
  insert on public.audit_events` + the EXECUTE revoke) and
  `15_notification_producer.down.sql` (drop trigger, then function — the
  review-Q6 verbatim style).
- **Harness:** batteries 01–15 (battery 15 wired into the list +
  FAIL-marker sweep + fixture cross-ref); battery 14 re-pinned (4→6/4→6/1);
  the mirror function added to the EXECUTE-deny set; structural pins
  unchanged (13/13/12 — the trigger is not a policy); static `--check`
  green + selftest 6/6.
- **Apply:** **only the new migration** — no RPC file touched; batteries
  13/10 must pass unchanged in the r1 rehearsal as the no-regression
  proof.
- **Rollback pairing:** `15_notification_producer.down.sql` (drop trigger
  + function) + the git-revert policy pairing, standing by, unexercised
  unless a trigger condition fires.
- **Addenda (T7):** applied-surface §1c-style mechanism note (counts
  unchanged — trigger is not a policy) + a matrix §4 read-only-stays note
  (the producer is a server mechanism, not a grant).
- **T8 re-verification:** in-transaction live demo (partner
  `create_matter` → produced feed row in-txn → `ROLLBACK`, zero residue)
  + the E2E walkthrough re-runs **non-vacuously**, dated evidence
  appended.

## 4. Verdict

**Mechanism approved at the decision level.** The audit-mirror trigger
(D-P1) with the exact v1 action map (D-P2/D-P3), org resolution from the
audit row (Q3), the trigger-only EXECUTE-denied posture (Q4), and the
**exact** battery-14 re-pin 4→6/4→6/1 (Q5) form the artifact contract for
`15_notification_producer.sql` (+ `.down`) and battery 15 (Q6). The
shipped RPCs are untouched by construction — the no-regression proof is
batteries 13/10 passing unchanged in the r1 rehearsal. Next pipeline
step: draft the T2 artifacts against this contract.

## 5. Ledger

- REVIEWED 2026-08-11 (decision-level) — plan RATIFIED (`cdd7ab4`), feed
  shipped (`d923940`), re-pin derived by source inspection, no execution
  claim. Only working-tree change: this record. Ledger sweep PASS.
- Remaining gates: T2 artifacts → T3 battery + harness (static `--check`)
  → T4 r1 (genuinely executed) → T5 dated apply-approval (owner) → T6 dev
  apply → T7 addenda → T8 non-vacuous re-verification.
