# LegalHub — Notification Producer Slice: Apply Execution Evidence (2026-08-11)

> **Record type:** execution evidence for the notification **producer**
> slice (`supabase/migrations/15_notification_producer.sql`), per
> `docs/notification_feed_producer_apply_approval_2026-08-11.md` §3/§4.
> Mirrors the notification-feed apply-execution record
> (`docs/notification_feed_apply_execution_2026-08-11.md`) — the immediate
> precedent.
>
> **Status: APPLIED 2026-08-11 — up sequence complete and verified on the
> shared dev project** (`eutmvevpskerzpqmwplv`, `eu-central-1`): baseline
> probe → `15_notification_producer.sql` → post-apply structural + live
> smoke all verified. Rollback pairing standing by
> (`15_notification_producer.down.sql` — drop trigger + function — plus
> the git-revert policy pairing), **unexercised** (no trigger condition
> fired; never fix-forward). The owner's dated approval is recorded in
> `docs/notification_feed_producer_apply_approval_2026-08-11.md` §6
> (**APPLY APPROVED 2026-08-11**, signed in-session when the owner
> directed the apply execution). Nothing beyond the approval §3 scope was
> touched; the approval §5 exclusions hold.
>
> **No findings.** The apply surfaced nothing: the producer is a single
> server-side function + trigger (D-P5 — a data-layer mechanism, not a
> policy; counts unchanged 13/13/12/20 RPC), the mirror is EXECUTE-revoked
> from client roles (D-P4), and the live smoke ran inside a transaction
> and rolled back — the dev feed gains **no** permanent rows from the
> apply itself (D-N7 producer start: the feed fills only with real event
> traffic after this apply).

---

## 0. Runbook (executed 2026-08-11 with these commands)

```bash
# 1. Baseline probe (read-only) — §1
supabase db query --linked "<probe SQL>"   # via the Management API, login role
# 2. Apply the single migration (approval §3.1)
supabase db query --linked --file supabase/migrations/15_notification_producer.sql
# 3. Post-apply structural + live smoke (approval §4.4/§4.5)
```

Note: the local `supabase` CLI link had to be refreshed first
(`supabase link --project-ref eutmvevpskerzpqmwplv` → "Finished supabase
link.") — the link state did not survive the host restart; no schema
effect, purely the CLI connection metadata.

Rollback pairing standing by: `15_notification_producer.down.sql` (drop
trigger + function) + `git revert` of the artifact commit —
**never fix-forward**.

## 1. Baseline probe (read-only, before the up sequence)

| Check | Expected | Observed | Verdict |
|---|---|---|---|
| `mirror_audit_to_notifications` function present? | **absent** | `0` | ✅ |
| trigger `audit_events_mirror_notifications` present? | **absent** | `0` | ✅ |
| tables with RLS | **13** (unchanged by this apply) | `13` | ✅ |
| `pg_policies` (public) count | **12** (unchanged — the producer is not a policy) | `12` | ✅ |
| `pg_policies` (storage) count | **1** | `1` | ✅ |
| publication (`supabase_realtime`) | exactly `messages` | `1` | ✅ |
| `matter-files` bucket | present | `1` | ✅ |
| RPC-EXECUTE (canonical 20-list) | **20** (unchanged — no new RPC) | `20` (the 23 visible EXECUTE-granted = 20 RPCs + `rls_auto_enable` platform fn + the 2 R-4 helpers `is_active_member`/`has_org_role`) | ✅ |
| `audit_events` rows (the mirror source) | present, untouched | `15` | ✅ |

All trigger conditions clean at the baseline; no STOP condition fired.

## 2. Up sequence (the single migration, applied + verified)

### 2.1 `supabase/migrations/15_notification_producer.sql`

`supabase db query --linked --file …/15_notification_producer.sql` → exit 0.
Verified immediately after (per-step, approval §4.4):

```
┌───────────┬────────────┬───────────┬───────────┬────────┬─────┬──────────────┬──────────────────┬───────────┐
│ mirror_fn │ mirror_trg │ auth_exec │ anon_exec │ tables │ rls │ pub_policies │ storage_policies │ pub_total │
├───────────┼────────────┼───────────┼───────────┼────────┼─────┼──────────────┼──────────────────┼───────────┤
│ 1         │ 1          │ false     │ false     │ 13     │ 13  │ 12           │ 1                │ 1         │
└───────────┴────────────┴───────────┴───────────┴────────┴─────┴──────────────┴──────────────────┴───────────┘
```

Exactly the D-P4/D-P5 contract: the function + trigger are present, the
function is **EXECUTE-revoked from both `authenticated` and `anon`**
(trigger-invoked only), and the applied counts are **unchanged**
(13/13/12+1, publication exactly `messages`) — "the trigger is not a
policy", the F-01 11_matter_write precedent.

## 3. Post-apply smoke (dev project)

### 3.1 Structural subset (live)

13 tables / 13 RLS / 12 public + 1 storage policies / publication exactly
`public.messages` (count 1) / bucket intact / RPC-EXECUTE stays **20** —
the §2.1 table, verbatim. Matches the r1-rehearsed pins exactly.

### 3.2 Live positive — the audit-mirror path, in-transaction (approval §4.5)

Impersonating the dev project's own active member (the demo partner
`8fa94af0-7390-4f7a-988a-3965f7da04de`, active member of the demo org
`ef43087b-adf4-4480-9bb2-28c26f46ec71` — the only dev member, so the
create uses attorney = the partner, client = null, the F2-D5 posture),
inside `begin; … rollback;`:

```
┌──────────┬────────────────┬────────────────────────────────────┬──────────────────────────────────────┐
│ category │ type           │ summary                            │ organization_id                      │
├──────────┼────────────────┼────────────────────────────────────┼──────────────────────────────────────┤
│ activity │ matter_updated │ Demo notification — matter created │ ef43087b-adf4-4480-9bb2-28c26f46ec71 │
└──────────┴────────────────┴────────────────────────────────────┴──────────────────────────────────────┘
```

The **audit-mirror producer is live on the dev project**: the partner's
`create_matter` → `matter:create`/`allowed` audit row → the AFTER INSERT
trigger → exactly one org-scoped notification row with the **fixed D-P3
summary** (`Demo notification — matter created` — the probe title "must
never leak" appears nowhere), category `activity`, type `matter_updated`,
read back **through `notifications_select_org` under RLS** (the exact path
the feed gateway takes) — all in the same transaction.

### 3.3 Residue (post-ROLLBACK, approval §4.5)

```
┌─────────────┬──────────────────┬──────────────┬─────────────┐
│ notif_total │ producer_residue │ matter_total │ audit_total │
├─────────────┼──────────────────┼──────────────┼─────────────┤
│ 0           │ 0                │ 6            │ 15          │
└─────────────┴──────────────────┴──────────────┴─────────────┘
```

**Zero residue** — D-P6 atomicity live: the feed is back to 0 (the dev
feed gains no permanent rows from the apply itself; it fills only with
real event traffic), the produced row is gone, and `audit_events` is back
to its 15 baseline (the smoke's audit row rolled back with the event).

### 3.4 Live negative — anon read denied (unchanged gate)

`set role anon; select count(*) from public.notifications;` →

```
ERROR:  42501: permission denied for table notifications
HINT:  Grant the required privileges to the current role with:
GRANT SELECT ON public.notifications TO anon;
```

Denied at the privilege layer — the feed's read gate is unchanged by the
producer (the mirror writes as the trigger, never as a client path).

## 4. Verification summary

| Approval §4 condition | Result |
|---|---|
| 1. Pre-up baseline probe | ✅ function/trigger absent · 13/13/12+1 · publication exactly `messages` · bucket · RPC-EXECUTE 20 · audit 15 — all clean |
| 2. Dev-project-own rows in the smoke | ✅ the smoke uses `8fa94af0-…` (dev partner) + `ef43087b-…` (dev org) — no rehearsal synthetic ids; the live positive runs in-txn and rolls back, so the dev feed gains no permanent rows |
| 3. Rollback pairing standing by | ✅ `15_notification_producer.down.sql` + git-revert pairing ready; **unexercised** (no trigger condition fired) |
| 4. Per-step verification | ✅ observed output captured after the apply (§2.1) — function/trigger present, EXECUTE denied to both client roles, counts unchanged |
| 5. Post-apply smoke | ✅ 13/13/12+1 + publication unchanged + RPC-EXECUTE 20 + live positive (in-txn partner create → produced org feed row visible via RLS → rollback → zero residue) + live negative (anon denied, 42501) |
| 6. No scope beyond the slice | ✅ only the one §3 file applied; no table/RPC/policy/publication/storage/data change |

## 5. Findings

**None.** The apply surfaced no pre-existing issue: the producer is a new
server-side mechanism that changes no table, policy, RPC, or data; the
smoke rolled back with zero residue. No rollback invoked.

## 6. Next steps (per the producer slice plan gate sequence)

- **T7:** dated addenda — the applied-surface **§1c-style mechanism note**
  (counts **unchanged** 13 tables / 13 RLS / 12 public + 1 storage / 20
  RPC-EXECUTE; trigger-not-a-policy, D-P5) + the matrix §4 **read-only-
  stays** note (the producer is a server mechanism, not a grant — the
  member SHIP read-only row is unchanged).
- **T8:** the **non-vacuous feed re-verification** — the E2E walkthrough
  re-runs with an in-transaction partner `create_matter` → produced feed
  row live → `ROLLBACK` → zero residue (the §3.2 shape above, already
  exercised live), dated evidence appended; the client feed then renders
  real event traffic instead of the empty arm.
- The battery remains ephemeral-only by design; the dev project's applied
  posture matches the r1-rehearsed state (13/13/12+1, RPC 20) plus the
  producer mechanism.
