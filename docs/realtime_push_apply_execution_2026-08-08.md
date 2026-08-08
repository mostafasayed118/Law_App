# LegalHub — Realtime Push Apply Execution Evidence (2026-08-08)

> **Record type:** Execution evidence for the realtime live-delivery (push)
> slice (plan `docs/realtime_push_real_data_plan_2026-08-08.md` T5), the
> seventh §14 per-feature un-deferral (matters → documents → message_threads
> → storage → audit surfacing → individual messages/bodies → live delivery).
> Mirrors the realtime-read apply-execution record
> (`docs/realtime_apply_execution_2026-08-08.md`) — the immediate precedent.
>
> **Status: APPLIED 2026-08-08 — up sequence complete and verified on the
> shared dev project** (`eutmvevpskerzpqmwplv`, `eu-central-1`): baseline
> probe → `09_realtime_push` → `policies/messages_insert` → the **demo send
> (the first live INSERT in the slice history, exercised through
> `messages_insert_assigned`)** → post-apply smoke all verified. Rollback
> pairing standing by (`09_realtime_push.down.sql` + targeted demo-row
> delete + `git revert` of the policy commit). The owner's dated approval
> is recorded in `docs/realtime_push_apply_approval_2026-08-08.md` §6
> (APPLY APPROVED 2026-08-08). Nothing beyond the approval §3 scope was
> touched; the approval §5 exclusions hold.
>
> **Run provenance:** this apply was executed via `supabase db query
> --linked` from the owner's linked machine (project ref
> `eutmvevpskerzpqmwplv`), the same channel the matters/documents/messages/
> realtime-read applies used; the observed output below is verbatim from
> the session.

---

## 0. Runbook (executed 2026-08-08 with these commands)

```bash
# 1. Baseline probe (read-only) — see §1 for the observed output
# 2. Apply the publication migration (approval §3.1)
supabase db query --linked --file supabase/migrations/09_realtime_push.sql
# 3. Apply the policy + grant (approval §3.2)
supabase db query --linked --file supabase/policies/messages_insert.sql
# 4. Demo send (approval §3.3) — role-impersonated INSERT as the partner
#    (set local role authenticated + request.jwt.claims sub), RETURNING id
# 5. Post-apply smoke (approval §4.5) — delivery-gate reads
```

Rollback pairing standing by: `09_realtime_push.down.sql`
(`alter publication supabase_realtime drop table messages;` — the
publication returns to its pre-apply state) + a targeted delete of the
demo-sent row (`delete from public.messages where id =
'7cbf49e0-…'`) + `git revert` of the policy commit (RLS-gate review §6
convention) — **never fix-forward**.

## 1. Baseline probe (read-only, before the up sequence)

| Check | Expected | Observed | Verdict |
|---|---|---|---|
| `pg_policies` (public) count | 9 → 10 after apply | `9` | ✅ matches the approval §4.1 prediction |
| `pg_publication_tables` (`supabase_realtime`) | 0 → 1 after apply (messages only) | `0` | ✅ matches the approval §4.1 prediction (empty publication baseline) |
| `messages` table present (read slice) | 1 | `1` | ✅ (06 un-deferral intact) |
| Messages seeded on dev | 10 | `10` | ✅ (the read slice's demo seed intact) |
| Four applied demo threads | the 4 recorded ids | all 4 present: acquisition `5d148bca-…` (count 1), lease `a8fd025e-…` (count 2), procedural `d0904762-…` (count 3), family `4a8755b1-…` (count 4) | ✅ verify-don't-guess |
| Demo threads all in one org | org `ef43087b-…` | all four threads' `organization_id` = `ef43087b-adf4-4480-9bb2-28c26f46ec71` | ✅ |
| Acquisition thread assignment (the demo-send target) | partner assigned | `assigned_attorney_id` = `8fa94af0-7390-4f7a-988a-3965f7da04de` (the partner) · `assigned_client_id` = `9acfd3b4-96c6-4836-aaa7-defd7864cefb` | ✅ verify-don't-guess — the partner IS the assigned attorney |
| Dev membership baseline | 1 partner account | **2 memberships** — the same partner user `8fa94af0-…`, active, in two orgs (`ef43087b-…` + `eb0b8cb8-…`); the assigned demo **clients hold no membership rows** | ✅ shapes the smoke below |

## 2. Up sequence (each step applied + verified)

### 2.1 `09_realtime_push.sql` — publication membership (D-LV2)

`supabase db query --linked --file supabase/migrations/09_realtime_push.sql`
→ exit 0. Verified:

```
┌────────────┬───────────┐
│ schemaname │ tablename │
├────────────┼───────────┤
│ public     │ messages  │
└────────────┴───────────┘
```

`pg_publication_tables` = **exactly `public.messages` — nothing else**
(the D-LV2 invariant + D-P0C1(b) teeth, live). No new table/columns/RLS.

### 2.2 `policies/messages_insert.sql` — the write surface (D-LV1)

`supabase db query --linked --file supabase/policies/messages_insert.sql`
→ exit 0. Verified: `messages_insert_assigned` present (INSERT, WITH CHECK
= `is_active_member(organization_id)` AND exists through
`message_threads t` join `matters m` with the three-way org equality AND
assigned client/attorney — the read gate applied to the write) ·
`messages_select_assigned` (SELECT) intact · **`pg_policies` 9 → 10** ·
`authenticated` INSERT grant **true** / `anon` **false** (the privilege-
layer half; a policy without a grant never fires — the T2 finding).

### 2.3 Demo send (D-LV6 — the first live INSERT)

Role-impersonated INSERT as the assigned partner on the acquisition demo
thread (`set local role authenticated` + `request.jwt.claims` sub =
`8fa94af0-…`), org `ef43087b-…`, generic author/body (D-RT4):

```
┌──────────────────────────────────────┬───────────────────────────────┐
│ id                                   │ sent_at                       │
├──────────────────────────────────────┼───────────────────────────────┤
│ 7cbf49e0-96da-4f12-8803-329f331d467a │ 2026-08-08 13:06:27.217747+00 │
└──────────────────────────────────────┴───────────────────────────────┘
```

The row persisted through `messages_insert_assigned` — **the INSERT policy
positive, live on the dev project**. Row scope verified (right org, right
thread, generic author + body — no org mismatch, no PII):

| Field | Value |
|---|---|
| `organization_id` | `ef43087b-adf4-4480-9bb2-28c26f46ec71` (= the thread's org, D-RT2) |
| `thread_id` | `5d148bca-d784-4c21-81a1-1646c6754e2a` (acquisition demo thread) |
| `author_display_name` | `Demo attorney` (generic, D-RT4) |
| `body` | `Demo message — live-delivery test send.` (generic, no real PII) |

## 3. Post-apply smoke (role-impersonated reads, R1 pattern)

| Reader | Identity | Expected | Observed | Verdict |
|---|---|---|---|---|
| Partner (assigned attorney, active member) | `sub=8fa94af0-7390-4f7a-988a-3965f7da04de` | reads the sent row (delivered-row positive) | **1** | ✅ the delivery gate = the read gate (D-LV3), live |
| Assigned client (NO membership rows) | `sub=9acfd3b4-96c6-4836-aaa7-defd7864cefb` | 0 — the D-RT2 membership guard | **0** | ✅ membership guard firing live — recorded as an honest expectation, never a defect (the realtime-read smoke precedent) |
| Publication inventory | exactly `public.messages` | `public · messages` only | ✅ nothing else | ✅ D-LV2 |
| Final tally | 10 → 11 | **11** | ✅ | ✅ |

> **Honest expectation note (\\*):** the demo **clients** are assigned on
> the demo matters but hold **no dev membership rows** — `is_active_member`
> is false for them, so they read 0. This is the D-RT2 membership guard
> firing live (the same posture recorded in the realtime-read smoke),
> never a defect: an active membership for those accounts would grant them
> their assigned threads without any change to this slice. No live
> websocket delivery is claimed in the smoke — that is the env-gated
> client slice (D-LV4, plan T7).

## 4. Trigger-condition sweep (rollback_plan §5)

| Trigger | Observed | Verdict |
|---|---|---|
| A matrix negative row starts passing | anon INSERT false · assigned client (no membership) reads 0 · no RLS violation bypass | ✅ none |
| Cross-tenant data visible | the sent row + all reads scoped to org `ef43087b-…` | ✅ none |
| A demo row lands on a real thread/account | the send targets the acquisition **demo** thread only, generic author/body | ✅ none |
| A non-generic author/body appears | non-generic rows = 0 | ✅ none |
| Publication drifts beyond the slice | `pg_publication_tables` = exactly `public.messages` | ✅ none |
| Policy inventory drift | 9 → 10, exactly the predicted set (`messages_insert_assigned` added) | ✅ none |

No trigger condition fired; **no rollback invoked** (never fix-forward).
The rollback pairing (`09_realtime_push.down.sql` + the demo-row delete +
the policy git-revert) stands by, unexercised.

## 5. Ledger / state

- **Applied 2026-08-08:** `09_realtime_push` (publication, exactly
  messages) + `policies/messages_insert` (grant + `messages_insert_assigned`)
  + the demo send (`7cbf49e0-…`). Dev project now: **10 tables / 10 RLS /
  10 policies / publication exactly messages (1)** — the approval's exact
  predictions (tables 10: `files` landed later with the storage apply).
- **Plan T5 row:** flipped DONE (the dated approval §6 + this execution
  record close the apply gate).
- **Pending:** T6 — the dated matrix §4 write-row + §6 delivery-row
  addenda (committed **before** the client surface ships) → T7 — the
  env-gated client swap (subscription + composer, D-LV1/D-LV4) → T8 —
  lockstep + close (roadmap §14 seventh flip, README/ledger sweep).
- Committed as `docs(realtime-push)`; nothing pushed; worktree clean
  except the pre-existing storage skeletons.
