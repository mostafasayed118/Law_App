# Plan: Notification-Feed Producer Slice — real-event rows from the shipped write paths (2026-08-11)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> **notification-feed producer** — the D-N7 follow-up that stops the feed
> from rendering empty: real events from **already-shipped** surfaces are
> mapped into `notifications` rows server-side. **Docs-only planning — zero
> dev-project effect**: nothing here applies anything until the owner's
> dated apply-approval (INSTRUCTIONS.md §2.1/§5 hard gates). **Branch:
> `feat/notification-feed-producer`.**
>
> **Status: RATIFIED 2026-08-11 by the Project Owner (D-P1…D-P6 — §3
> decisions accepted as designed, including the minimal v1 event set, the
> fixed redacted summary map, and the deterministic battery-14 re-pin).
> The slice is un-blocked to start T1 (mechanism/RLS-gate review).** No
> code, no live-system effect; the dev-project apply still waits for the
> dated apply-approval (T5).
>
> **Gate state:** the feed surface is fully SHIPPED end-to-end (T1–T8 +
> walkthrough, `d923940` — 13 tables / 13 RLS / 12 public policies, the
> `NotificationGateway` client swap, suite 1303). The feed renders **empty
> pre-producer** by design (D-N7); this slice adds the producer. D-N7's
> exact contract: *"real events per shipped surface (matter updates,
> messages, invoice status, approvals) are decided slice-by-slice — never
> invented here."*
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Make the **shipped** notification-feed read surface **non-vacuous on the
dev project**: every real event through the two **audited write RPCs**
(`create_matter`, `send_message`) produces one redacted, org-scoped
`notifications` row automatically — so an active member's feed shows
"matter created" / "new message in thread" rows instead of always-empty.
"Done" = the RPCs' existing pinned behavior is **byte-identical** (battery
13/10 stay green), the produced rows obey the shipped D-N3/D-N4 redaction +
category contract, anon/non-member still cannot read (already pinned), and
the E2E walkthrough re-runs **non-vacuously**. No client change (the T8
feed already renders the rows); no new grant, no policy, no RPC-EXECUTE
change (the producer is a data-layer mechanism — the matter-write trigger
precedent).

## 2. Gap (verified)

| Claim | Verified fact |
|---|---|
| The feed is empty pre-producer | Dev project: `notifications` = 0 rows; E2E walkthrough (`docs/notification_feed_e2e_walkthrough_evidence_2026-08-11.md`) §8 lists "a future producer slice seeds rows and the same walkthrough re-runs non-vacuously" |
| Exactly two shipped audited write paths | `create_matter` (`supabase/rpc/create_matter.sql`, F-01, `matter:create`/allowed audit, org from param) and `send_message` (`supabase/rpc/send_message.sql`, D-SM3, **`message:create`**/allowed audit, org resolved from thread→matter) — both `security definer`, both §8-audited in the same transaction |
| No other server write source | invoices are read-only (D-11 no payment), approvals/tasks/alerts are fake-domain with no server surface — **no producer possible or honest** for them in v1 (D-N7: never invented) |
| Audit rows carry the feed's needs | `audit_events` has `action`, `outcome`, `organization_id`, `redacted_summary`, `server_timestamp` (`supabase/migrations/01_org_schema.sql:75`) — org + redacted posture + timestamp already present at the single write point |
| Batteries call the write RPCs before battery 14 | `13_matter_write_rls.sql` calls `create_matter` (successful creates) and `10_send_message_rls.sql` calls `send_message` — both run **before** `14_notification_rls.sql`, so a producer **shifts battery 14's absolute count pins** (14.01–14.03) — a harness re-pin is required (see §4/§6) |

## 3. Design decisions (**RATIFIED 2026-08-11 by the Project Owner** — the
mechanism review gates the artifacts against these, not the decisions
again)

- **D-P1 — the producer is an audit-mirror trigger, not an RPC edit.** A
  new `AFTER INSERT` trigger on `audit_events` maps the two audited actions
  into `notifications`. Rationale: (a) **zero modification to the shipped
  RPCs** — the F-01 and send-message review surfaces stay closed and their
  batteries stay byte-identical green; (b) **one producer point** — the
  feed becomes a filtered projection of the audit log ("the feed says what
  the audit says"), so any future audited RPC auto-produces by adding one
  action-map entry; (c) the audit row already carries
  `organization_id` + `server_timestamp` + the redacted-summary posture.
- **D-P2 — the v1 event set is exactly `{matter:create, message:create}`**
  (the two audited write actions, with `outcome = 'allowed'`). Invoice
  status, approvals, appointment reminders, and system maintenance have **no
  server write source in v1** (D-11 no-payment; fake-domain queues; no
  scheduler) — per D-N7 they are **not invented**; the fake/fixture rows
  keep the other categories visible in env-less runs, and the map extends
  per future slice.
- **D-P3 — redaction + category mapping (the D-N3/D-N4 contract, kept
  structural):** produced rows carry a **fixed redacted summary** (the
  feed's `Demo notification — …` copy convention), never the matter title
  or message body: `matter:create` → `type 'matter_created'` / summary
  `'Demo notification — matter created'`; `message:create` → `type
  'message_received'` / summary `'Demo notification — new message in
  thread'`. Category = `activity` for both — the honest v1 set (the
  `appointment`/`system` categories stay fixture/fake-only until a real
  source exists, D-N7). `is_read` stays `false` (D-N6 — the feed never
  mutates).
- **D-P4 — the mirror is trigger-only, EXECUTE-never-granted.** The
  trigger function runs as the table owner (RLS bypassed for the owner —
  the same footing as the battery's postgres-role fixture inserts), so the
  `notifications` write needs **no new grant and no new policy** — the
  member-facing surface remains strictly read-only (matrix §4 row
  unchanged). EXECUTE is revoked from `public`/`anon`/`authenticated` —
  clients cannot invoke the mirror (the `write_audit` deny precedent); the
  harness RPC-EXECUTE pin stays **20** and gains a deny-pin for the new
  function.
- **D-P5 — the trigger is a data-layer mechanism, not a policy.** Like the
  F-01 `refuse_platform_owner_assignment` trigger
  (`migrations/11_matter_write.sql`, recorded "trigger is not a policy" in
  `docs/current_applied_surface_2026-08-08.md` §1a): the applied-surface
  counts stay **13 tables / 13 RLS / 12 public policies**; the producer is
  recorded as a §1c-style mechanism note, and the matrix "View
  notifications (metadata)" row keeps **member SHIP read-only, no write
  cells** (the write is a server mechanism, not a client grant).
- **D-P6 — the harness re-pins battery 14's absolute counts.** Because
  batteries 10/13's successful RPC calls produce rows **before** battery 14
  runs, 14.01–14.03's `count = 4/4/1` pins shift by a deterministic number
  (fixed battery order + fixed RPC calls). The slice re-derives those pins
  during T3 and the r1 rehearsal confirms the exact new counts — never a
  relative fudge, an exact re-derivation.

## 4. Artifact sketch (rehearsal-ready when approved)

- **`supabase/migrations/15_notification_producer.sql`** — the trigger
  function `mirror_feed_notification()` (`security definer`,
  `set search_path = public`, returns trigger) + `create trigger
  notifications_from_audit after insert on public.audit_events for each
  row execute function …`; function body: the D-P2 action filter, the D-P3
  fixed map, `insert into public.notifications (organization_id, category,
  type, summary, server_timestamp, is_read)`. `revoke execute … from
  public, anon, authenticated` on the function.
- **`supabase/migrations/15_notification_producer.down.sql`** — drop the
  trigger then the function (the rollback-pairing contract, review Q6
  verbatim style).
- **Battery additions** — a new `supabase/tests/15_notification_producer.sql`
  (keeps the producer concern separate; harness grows to batteries 01–15)
  with **delta-based** checks (count before → RPC call → count after +1),
  each a named `POLICY-BATTERY FAIL` block (≥10 blocks, the sweep
  threshold): create → row with org/category/type/summary pinned; send →
  row; a **denied** create produces no row; the mirror function EXECUTE is
  denied for `authenticated`; the produced summary never contains the
  matter title / message body (redaction pin); anon still denied reading
  produced rows; org scoping of produced rows (member of the event's org
  only).
- **Battery-14 re-pin** — 14.01/14.02/14.03 absolute counts re-derived
  after 10/13's producer rows (deterministic; exact numbers verified by r1).

## 5. Client slice

**None.** The T8 feed surface (gateway + screen + entry + l10n) already
renders whatever the org-gate returns — produced rows appear on the next
`load()`. This slice is **server-only**: artifacts + battery + harness +
rehearsal + apply + re-verification. The only client-adjacent step is the
**T8 re-verification** (§6 step 8): the configured-build walkthrough re-runs
**non-vacuously** — an in-transaction `create_matter` as the partner shows
the produced feed row live, then `ROLLBACK` (zero residue, the 2026-08-09
transactional-demo discipline).

## 6. Gate sequence (the T1–T8 shape, adapted for a server-only mechanism)

1. **This plan ratified + owner authorization** (the producer is a NEW
   server-side write mechanism — the gate; D-N7 explicitly leaves row
   sources to be "decided slice-by-slice") — **MET 2026-08-11** (D-P1…D-P6
   ratified); the slice starts at **T1**
2. **T1 mechanism/RLS-gate review** — dated review note: the trigger
   design (D-P1), the action map (D-P2/D-P3), org resolution from the
   audit row, the battery-14 re-pin (D-P6), and the "not a policy" framing
   (D-P5)
3. **T2 artifacts** — `15_notification_producer.sql` (+ `.down`),
   rehearsal-ready
4. **T3 battery + harness wiring** — `15_notification_producer.sql` +
   battery-14 re-pin + mirror deny-pin; static `--check` green (selftest
   stays 6/6)
5. **T4 ephemeral rehearsal r1** — genuinely executed on the scratch
   stack: batteries 13/10 (RPCs **unchanged**) + the re-pinned 14 + the new
   15 all green; dated evidence
6. **T5 dated apply-approval (owner) → T6 apply to the dev project** —
   per-step output captured; **only the new migration** (no RPC file
   touched)
7. **T7 addenda** — applied-surface §1c-style mechanism note (counts
   unchanged 13/13/12/20 RPC) + a matrix §4 read-only-stays note (the
   producer is a server mechanism, not a grant)
8. **T8 feed re-verification** — in-transaction live demo (partner
   `create_matter` → produced feed row in-txn → `ROLLBACK`, zero residue)
   + the E2E walkthrough re-run **non-vacuously**, dated evidence appended

## 7. Acceptance criteria (testable)

1. A successful `create_matter` produces exactly one `notifications` row
   with the event's org, `activity`, `matter_created`, the fixed redacted
   summary — and the matter title never appears in it.
2. A successful `send_message` produces exactly one row
   (`activity`/`message_received`, redacted) for the thread's org.
3. A **denied** RPC call (owner-assignment refusal, non-member sender)
   produces **no** row.
4. Battery 13/10 pass **unchanged** (the shipped RPCs' pinned behavior is
   untouched — the producer is additive), battery 14's re-pinned absolute
   counts hold, battery 15's delta checks hold, harness `--check` + selftest
   green.
5. `authenticated` cannot EXECUTE the mirror function (deny-pin); the
   member-facing feed surface stays read-only (no INSERT/UPDATE/DELETE
   grant or policy — matrix §4 unchanged).
6. Anon/non-member/cross-org still cannot read produced rows (existing
   14.04–14.07 pins hold live).
7. The E2E walkthrough re-runs non-vacuously: the partner's live
   in-transaction create shows the feed row, rolled back with zero residue.

## 8. Risks & open questions (owner)

- **Event set (D-P2):** v1 = exactly the two audited write actions.
  Invoice-status events stay out (no write path — D-11 no payment);
  approval/task events stay out (fake-domain, no server surface). The
  `appointment`/`system` categories remain fixture/fake-only until a real
  source exists. Confirm this minimal honest set.
- **Summary copy (D-P3):** the fixed `Demo notification — …` map
  (recommended — the fixture/fake convention) vs the audit
  `redacted_summary` verbatim (`'matter created'` / `'message sent'`).
  Recommendation: the fixed map, so the feed copy stays uniform.
- **Battery-14 re-pin (D-P6):** the absolute pins shift by the count of
  successful RPC calls in batteries 10/13 (deterministic — 13.01's create
  + any other successful creates; 10.01/10.02's sends). The r1 rehearsal
  pins the exact new numbers; no guess.
- **Audit-mirror coupling:** the feed inherits the audit taxonomy
  (`matter:create`/`message:create`). If a future slice renames an audit
  action, the mirror map must follow — recorded as the D-P1 trade-off,
  accepted.
- **Rollback:** `15_notification_producer.down.sql` (drop trigger +
  function) + the git-revert pairing; produced rows are data (rolled back
  with the migration's down only if dropped — the pairing contract).

## 9. Ledger

- DRAFTED 2026-08-11 (docs-only; feed surface SHIPPED at `d923940`, suite
  1303).
- **RATIFIED 2026-08-11 by the Project Owner** — §3 D-P1…D-P6 accepted as
  designed; the §8 open questions resolved in the plan's recommended
  direction (minimal v1 event set, fixed redacted summary map, battery-14
  re-pin). No code, no live-system effect, nothing applied. Step 1 MET —
  the slice starts at **T1 (mechanism/RLS-gate review)**; the dev-project
  apply waits for the dated apply-approval (T5) and the matrix/applied
  addenda (T7).
