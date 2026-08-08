# LegalHub — Realtime Apply Execution Evidence (2026-08-08)

> **Record type:** Execution evidence for the real-messages-rows (read)
> slice (plan `docs/realtime_real_data_plan_2026-08-08.md` T5), the sixth
> §14 per-feature un-deferral (matters → documents → message_threads →
> storage → audit surfacing → individual messages/bodies). Mirrors the
> messages apply-execution record
> (`docs/messages_apply_execution_2026-08-07.md`) — the immediate
> precedent — and the matters/documents records.
>
> **Status: APPLIED 2026-08-08 — up sequence complete and verified on the
> shared dev project** (`eutmvevpskerzpqmwplv`, `eu-central-1`): baseline
> probe → `08_messages` → `policies/messages` → demo seed (10 messages
> referencing the applied demo thread ids) → post-apply smoke all
> verified. Rollback pairing standing by (`08_messages.down.sql` +
> targeted demo-row delete + `git revert` of the policy commit). The
> owner's dated approval is recorded in
> `docs/realtime_apply_approval_2026-08-08.md` §6 (APPLY APPROVED
> 2026-08-08). Nothing beyond the approval §3 scope was touched; the
> approval §5 exclusions hold.
>
> **Run provenance:** this apply was executed via `supabase db query
> --linked` from the owner's linked machine (project ref
> `eutmvevpskerzpqmwplv`), the same channel the matters/documents/messages
> applies used; the observed output below is verbatim from the session.

---

## 0. Runbook (executed 2026-08-08 with these commands)

```bash
# 1. Baseline probe (read-only) — see §1 for the observed output
# 2. Apply the table (approval §3.1)
supabase db query --linked --file supabase/migrations/08_messages.sql
# 3. Apply the policy (approval §3.2)
supabase db query --linked --file supabase/policies/messages.sql
# 4. Demo seed (approval §3.3) — 10 rows, org resolved per thread
# 5. Post-apply smoke (approval §4.5) — role-impersonated reads
```

Rollback pairing standing by: `08_messages.down.sql`
(`drop table public.messages;` — the policy dies with its table) + a
targeted delete of the seeded demo rows (`delete from public.messages
where thread_id in (the four applied demo thread ids)`) + `git revert`
of the policy commit (RLS-gate review §6 convention) — **never
fix-forward**.

## 1. Baseline probe (read-only, before the up sequence)

| Check | Expected | Observed | Verdict |
|---|---|---|---|
| `messages` table absent | 0 | `0` | ✅ baseline matches the rehearsal posture |
| `message_threads` present | 1 | `1` | ✅ |
| Four applied demo threads | the 4 recorded ids | all 4 present: acquisition `5d148bca-…` (count 1), lease `a8fd025e-…` (count 2), procedural `d0904762-…` (count 3), family `4a8755b1-…` (count 4) | ✅ verify-don't-guess |
| `matters` + `documents` present | 1 / 1 | `1` / `1` | ✅ (earlier un-deferrals intact) |
| `pg_policies` (public) count | 8 → 9 after apply | `8` | ✅ matches the approval §4.1 prediction |
| Policy inventory | 8 rows, no messages policy | `documents_select_assigned`, `invitations_select_partner`, `matters_select_assigned`, `memberships_select_org_roster`, `message_threads_select_assigned`, `organizations_select_active_member`, `profiles_select_own`, `profiles_update_own` | ✅ |
| Demo threads all in one org | org `ef43087b-…` | all four threads' `organization_id` = `ef43087b-adf4-4480-9bb2-28c26f46ec71` | ✅ |
| Dev membership baseline | 1 partner account | **2 memberships** — the SAME partner user `8fa94af0-7390-4f7a-988a-3965f7da04de`, active, in **two** orgs (`ef43087b-…` + `eb0b8cb8-…`) | ✅ honest update: the messages smoke's "only dev member" is one partner account with two org memberships |
| Demo matters' assignments | — | partner is **assigned_attorney** on acquisition `a6715e17-…`, lease `d155dc92-…`, procedural `4f4a935f-…`; **family `575391b6-…` has `assigned_attorney_id = NULL`** | ✅ this is what shapes the smoke below |

## 2. Up sequence (each step applied + verified)

| # | Step | Command | Result |
|---|---|---|---|
| 1 | `supabase/migrations/08_messages.sql` | `db query --linked --file` | ✅ applied cleanly (exit 0, no errors) — table created |
| 2 | `supabase/policies/messages.sql` | `db query --linked --file` | ✅ applied cleanly (exit 0) |
| 3 | Demo seed (10 rows) | INSERT…SELECT from `message_threads` | ✅ RETURNING captured (§2.2) |

### 2.1 Mid-apply verification (after steps 1–2)

| Check | Observed | Verdict |
|---|---|---|
| `messages` table + RLS | `relrowsecurity = true` | ✅ |
| Policy | `messages_select_assigned` (SELECT) present | ✅ |
| `pg_policies` count | `9` (8 → 9, the approval §4.1 prediction) | ✅ |
| `authenticated` SELECT on `messages` | `true` | ✅ |
| `anon` SELECT on `messages` | `false` (default-deny) | ✅ |
| Column shape | `id`, `organization_id`, `thread_id`, `author_display_name`, `body`, `sent_at`, `created_at`, `updated_at` (D-RT3, all `NOT NULL`) | ✅ |

### 2.2 Seeded demo rows (10 messages, org `ef43087b-…`, generic D-RT4 authors + bodies, no real PII)

Each thread got exactly its `message_count` rows (the mapping contract):
acquisition 1, lease 2, procedural 3, family 4. Authors alternate generic
`Demo attorney` / `Demo client`; bodies are `Demo message N — generic
demo content, no real client or legal data.`; `sent_at` staggered by N
hours. Seeded ids (RETURNING):

| message id | thread id | author |
|---|---|---|
| `193f535a-93e6-4456-af86-c1dddee6515f` | `5d148bca-…` (acquisition) | Demo attorney |
| `791a90a9-d8fd-4d0e-b80e-9bbb3725fa95` | `a8fd025e-…` (lease) | Demo attorney |
| `07964f30-ebb6-4e05-a07a-3dfd0b815de6` | `a8fd025e-…` (lease) | Demo client |
| `9367f074-d9ed-4162-8fac-904575388028` | `d0904762-…` (procedural) | Demo attorney |
| `bb4792f2-4591-4f85-8a70-4f55a5edcdc5` | `d0904762-…` (procedural) | Demo client |
| `e254421c-f152-448e-84ce-c7d65c37eec0` | `d0904762-…` (procedural) | Demo attorney |
| `8c006b32-5429-43a5-99c1-ad9b8f5c91e5` | `4a8755b1-…` (family) | Demo attorney |
| `f7cfd4ec-24ab-41ff-abab-4b3010c4dc88` | `4a8755b1-…` (family) | Demo client |
| `5419651f-f2f2-473d-811e-c474e61d0716` | `4a8755b1-…` (family) | Demo attorney |
| `a14a3c62-3de4-4374-950d-03a157a01083` | `4a8755b1-…` (family) | Demo client |

Post-seed probes: **org-mismatch rows = 0** (every message's
`organization_id` equals its thread's org — D-RT2 invariant held at seed
time); per-thread live counts match the `message_count` columns exactly
(1/2/3/4); **non-generic rows = 0** (no real PII: every author `Demo %`,
every body the generic demo pattern).

## 3. Post-apply smoke (role-impersonated reads, R1 pattern)

| Reader | Identity | Expected | Observed | Verdict |
|---|---|---|---|---|
| Partner (assigned attorney) | `sub=8fa94af0-7390-4f7a-988a-3965f7da04de` | reads its assigned threads' messages | **6** (acquisition 1 + lease 2 + procedural 3) | ✅ gate fires per-assignment |
| Partner — procedural thread | same | 3 | **3** | ✅ |
| Partner — cross-org | `organization_id = eb0b8cb8-…` (its second org, no threads) | 0 | **0** | ✅ |
| Stranger (no dev membership) | `sub=00000000-0000-0000-0000-0000000000ff` | 0 | **0** | ✅ |
| `body` CHECK (privileged, empty string) | — | CHECK violation, nothing written | `ERROR: 23514: new row for relation "messages" violates check constraint "messages_body_check"` — total stays **10** | ✅ |
| Final tally | — | 10 | **10** | ✅ |

> **Honest expectation note (\*):** the partner reads **6 of 10** — it is
> the assigned attorney on three of the four demo matters, while the
> **family** matter has `assigned_attorney_id = NULL`, so its 4 messages
> deny (and the family thread's participants are `{"Demo client"}` only —
> the `message_threads_select_assigned` gate also denies it for the
> partner). This is the D-RT2 assignment clause firing live — exactly the
> matrix contract ("an org role alone never grants; only the assigned
> client/attorney"), recorded as the designed behavior, never as a defect.
> A future assigned attorney/client for the family matter would read its
> messages without any change to this slice.

## 4. Trigger-condition sweep (rollback_plan §5)

| Trigger | Observed | Verdict |
|---|---|---|
| A matrix negative row starts passing | partner cross-org 0 · stranger 0 · org-mismatch rows 0 | ✅ none |
| Cross-tenant data visible | no message/thread outside org `ef43087b-…` readable | ✅ none |
| A demo row lands on a real thread/account | seed scoped to the four applied demo thread ids only | ✅ none |
| A non-generic author/body appears | non-generic rows = 0 | ✅ none |
| Policy inventory drift | 8 → 9, exactly the predicted set | ✅ none |

No trigger condition fired; **no rollback invoked** (never fix-forward).

## 5. Ledger / state

- **Applied 2026-08-08** (this record): `08_messages` + `policies/messages`
  + 10 demo message rows on the dev project; approval §6 signed (APPLY
  APPROVED).
- Plan T5 row flipped to DONE in the plan document; T6 (dated matrix §4
  addendum for the "Read a document/message body" row) and T7 (env-gated
  client `fetchMessages` swap) follow.
- The dev project's applied §14 posture is now matters + documents +
  message_threads + messages; **storage stays HELD owner-side** (r1 +
  apply pending the owner's Docker-host evidence) and **live delivery
  stays deferred** (D-RT6).
- Nothing pushed (this record is docs-only); the roadmap §14/§13 +
  README/ledger lockstep is part of T8 on the merged tree.
