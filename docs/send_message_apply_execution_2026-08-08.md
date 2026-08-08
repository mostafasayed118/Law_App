# LegalHub — Send-Message RPC Apply Execution Evidence (2026-08-08)

> **Record type:** Execution evidence for the audited `send_message` RPC
> slice (plan `docs/send_message_rpc_plan_2026-08-08.md` T5), the eighth
> §14 per-feature un-deferral. Mirrors the realtime-push apply-execution
> record (`docs/realtime_push_apply_execution_2026-08-08.md`) — the
> immediate precedent (the write half of the messaging path).
>
> **Status: APPLIED 2026-08-08 — up sequence complete and verified on the
> shared dev project** (`eutmvevpskerzpqmwplv`, `eu-central-1`): baseline
> probe → `supabase/rpc/send_message.sql` as ONE apply unit (function +
> EXECUTE grant + the D-SM3 revocation) → the **demo send via the RPC**
> (the first §8-audited live message write) → post-apply smoke all
> verified. Rollback pairing standing by (`rpc/_down.sql` drop + targeted
> demo-row/audit-row delete + `git revert` of the revocation block). The
> owner's dated approval is recorded in
> `docs/send_message_apply_approval_2026-08-08.md` §6 (**APPLY APPROVED
> 2026-08-08**). Nothing beyond the approval §3 scope was touched; the
> approval §5 exclusions hold.
>
> **One real finding recorded (§4, §5), not papered over:** the demo
> send's author is the partner account's **stored `profiles.display_name`
> — which on the dev project is the account's email address** (both dev
> demo accounts store their email as display_name, pre-existing since the
> P2 account creation). The RPC honored D-RT4 exactly (stored display
> name from profiles; the 'Demo client' fallback only when empty), so the
> email is the account's own pre-existing profile data, **not data the
> apply wrote**. This is an account-hygiene follow-up for the owner (§5),
> not a slice defect; no rollback was invoked (never fix-forward).

---

## 0. Runbook (executed 2026-08-08 with these commands)

```bash
# 1. Baseline probe (read-only) — see §1 for the observed output
# 2. Apply the audited RPC as ONE unit (approval §3.1 — function +
#    EXECUTE grant + the D-SM3 revocation)
supabase db query --linked --file supabase/rpc/send_message.sql
# 3. Demo send (approval §3.2) — role-impersonated RPC call as the partner
#    (set local role authenticated + request.jwt.claims sub), RETURNING id
# 4. Post-apply smoke (approval §4.5) — structural subset + audit-row
#    positive + delivery-gate reads
```

Rollback pairing standing by: `supabase/rpc/_down.sql` (drop
`send_message(uuid, text)` — the function + grants go with it) + a
targeted delete of the demo-sent row **and its audit row** (`delete from
public.messages where id = '1c031882-…'` + the matching
`public.audit_events` row) + `git revert` of the D-SM3 revocation block
(the `messages_insert_assigned` policy + INSERT grant re-add, the
gate-review §6 convention) — **never fix-forward**.

## 1. Baseline probe (read-only, before the up sequence)

| Check | Expected | Observed | Verdict |
|---|---|---|---|
| `send_message` function present? | **absent** | `0` (pg_proc count) | ✅ matches the approval §4.1 prediction |
| `messages` rows on dev | 11 (10 seeded + the realtime-push demo send `7cbf49e0-…`) | `11` | ✅ matches the approval §4.1 prediction |
| `pg_policies` (public) count | **10** → 9 after apply | `10` | ✅ matches the approval §4.1 prediction |
| Acquisition thread `5d148bca-…` assignment (the demo-send target) | partner assigned | `organization_id` = `ef43087b-adf4-4480-9bb2-28c26f46ec71` · `assigned_attorney_id` = `8fa94af0-7390-4f7a-988a-3965f7da04de` (the partner) · `assigned_client_id` = `9acfd3b4-96c6-4836-aaa7-defd7864cefb` | ✅ verify-don't-guess |
| Publication (`supabase_realtime`) | exactly `messages`, unchanged by this apply | `public · messages` only | ✅ untouched |
| `authenticated` INSERT grant on `messages` | **true** → false after apply | `true` / anon `false` | ✅ matches the approval §4.1 prediction |

All trigger conditions clean at the baseline; no STOP condition fired.

## 2. Up sequence (each step applied + verified)

### 2.1 `supabase/rpc/send_message.sql` — the audited write path (ONE apply unit)

`supabase db query --linked --file supabase/rpc/send_message.sql` → exit 0
(DDL statements return no rows; verified immediately after):

- **Function live:** `send_message(uuid, text)` present with
  `prosecdef = true` and the pinned `search_path = public` (D-SM1 —
  RLS does not apply inside a definer function, so the in-function gate
  is the sole write authorization).
- **Grants:** `authenticated` EXECUTE **true** / `anon` **false**.
- **D-SM3 revocation live:** `authenticated` INSERT on `messages`
  **true → false** / `anon` false · `messages_insert_assigned` **gone**
  (pg_policies count for the name = 0) · **`pg_policies` 10 → 9**.
- **Publication unchanged:** `pg_publication_tables` still exactly
  `public.messages`.

The audited RPC is now the **only** message write path on the dev
project — every send is §8-audited by construction.

### 2.2 Demo send (the first §8-audited live message write)

Role-impersonated RPC call as the assigned partner on the acquisition
demo thread (`set local role authenticated` + `request.jwt.claims` sub =
`8fa94af0-7390-4f7a-988a-3965f7da04de`), generic demo body (no real
client/legal copy):

```
┌──────────────────────────────────────┐
│ sent_message_id                      │
├──────────────────────────────────────┤
│ 1c031882-b054-4c54-ab07-c6b70f25b8f2 │
└──────────────────────────────────────┘
```

The row persisted through the **audited path**: the in-function gate
passed (the partner is an active member of the thread's org AND the
assigned attorney on the thread's matter), the INSERT ran inside the
definer function, and the §8 audit row was written in the same implicit
transaction. Row scope verified:

| Field | Value | Verdict |
|---|---|---|
| `organization_id` | `ef43087b-adf4-4480-9bb2-28c26f46ec71` (= the thread's org, D-RT2) | ✅ |
| `thread_id` | `5d148bca-d784-4c21-81a1-1646c6754e2a` (acquisition demo thread) | ✅ the approval §3.2 target |
| `author_display_name` | the partner's **stored `profiles.display_name`** — the account's email address (D-RT4 honored) | ⚠️ **finding — see §4/§5** |
| `body` | `Demo message — audited send_message RPC test send (generic, no real data).` | ✅ generic |

**§8 audit row (observed verbatim via the linked CLI as the privileged
role — never a raw client SELECT on `audit_events`, D-P0C4):**

| Field | Value |
|---|---|
| `action` / `outcome` | `message:create` / `allowed` |
| `actor_user_id` | `8fa94af0-7390-4f7a-988a-3965f7da04de` (the partner) |
| `resource_type` / `resource_id` | `message` / `1c031882-b054-4c54-ab07-c6b70f25b8f2` (**= the RPC's returned id**) |
| `redacted_summary` | `message sent` (never the body) |

The **§8 audit gap is closed live on the dev project** — the slice's
whole point, verified.

## 3. Post-apply smoke (role-impersonated reads, R1 pattern)

| Reader | Identity | Expected | Observed | Verdict |
|---|---|---|---|---|
| Partner (assigned attorney, active member) | `sub=8fa94af0-7390-4f7a-988a-3965f7da04de` | reads the demo-sent row (delivery-gate positive) | **1** | ✅ the delivery gate = the read gate, live |
| Assigned client (NO membership rows) | `sub=9acfd3b4-96c6-4836-aaa7-defd7864cefb` | 0 — the D-RT2 membership guard | **0** | ✅ membership guard firing live — recorded as an honest expectation, never a defect (the realtime-push smoke precedent) |
| Structural subset | — | policies 9 · EXECUTE true/anon false · INSERT false · policy gone · publication exactly messages | all as expected (§2.1) | ✅ |
| Final tally | 11 → 12 | **12** | ✅ | ✅ |

> **Honest expectation note (\*):** the demo **clients** are assigned on
> the demo matters but hold **no dev membership rows** — `is_active_member`
> is false for them, so they read 0. This is the D-RT2 membership guard
> firing live (the same posture recorded in the realtime-push smoke),
> never a defect.

## 4. Trigger-condition sweep (rollback_plan §5)

| Trigger | Observed | Verdict |
|---|---|---|
| A matrix negative row starts passing | anon INSERT false · anon EXECUTE false · assigned client (no membership) reads 0 · INSERT revoked at the privilege layer | ✅ none |
| Cross-tenant data visible | the sent row + all reads scoped to org `ef43087b-…`, thread `5d148bca-…` | ✅ none |
| A demo row lands on a real thread/account | the send targets the acquisition **demo** thread, as the partner account the approval §3.2 names | ✅ none |
| A **non-generic author/body appears** | body generic ✅; **author = the partner's stored display name — the account's email — see the finding below** | ⚠️ **finding — not a slice defect; no revert** |
| The audit row is missing or carries content | `message:create/allowed`, actor, resource id = returned id, redacted `message sent` | ✅ none |
| Policy inventory drift | 10 → 9, exactly the predicted set (`messages_insert_assigned` dropped) | ✅ none |

**The one finding (recorded, not papered over):** the demo send's author
is the partner account's stored `profiles.display_name`, which on the dev
project is the account's **email address** — both dev demo accounts'
profiles store their email as display_name (pre-existing since the P2
account creation; the realtime-push demo send looked generic only because
its INSERT passed `'Demo attorney'` explicitly). The RPC implemented
D-RT4 exactly as rehearsed (stored display name from profiles; the
`'Demo client'` fallback only when empty) — the rehearsal battery pinned
'Partner A' because the rehearsal fixtures' profiles store generic names,
while the dev accounts' profiles store emails. The email is the account's
own pre-existing profile data, not data this apply wrote; the RPC is
correct. **No rollback was invoked** (never fix-forward) — the fix is an
account-hygiene update outside this slice's scope (§4.6/§5), flagged for
the owner (§5).

No other trigger condition fired; **no rollback invoked**. The rollback
pairing (`rpc/_down.sql` drop + the demo-row/audit-row delete + the
revocation git-revert) stands by, unexercised.

## 5. Ledger / state / owner attention

- **Applied 2026-08-08:** `send_message(uuid, text)` (security definer,
  in-function gate, §8 audit by construction) + the EXECUTE grant
  (authenticated, anon denied) + **D-SM3 revocation** (INSERT revoked,
  `messages_insert_assigned` dropped) + the demo send
  (`1c031882-b054-4c54-ab07-c6b70f25b8f2`). Dev project now: **11 tables
  / 11 RLS / 9 policies / publication exactly messages (1) / 19 EXECUTE
  RPCs** — the approval's exact predictions, with the message tally 12.
- **Plan T5 row:** flipped DONE (the dated approval §6 + this execution
  record close the apply gate; the §14/§13/§2 HELD markers resolve).
- **⚠ Owner-side follow-up (account hygiene, pre-existing, out of scope
  here):** the two dev demo accounts' `profiles.display_name` store their
  email addresses, so any D-RT4-derived author on the dev project is the
  account's email. Setting generic demo display names on those two
  profiles (an account-data update, owner-approved) would make future
  D-RT4 authors generic — the client impl's `'Demo client'` fallback
  never fires because the stored names are non-empty.
- **Configured-build verification (D-SM2):** the env-gated client swap
  (plan T7, committed `f874a57`) now has its server prerequisite live —
  a configured build's send will call the audited RPC and observe the §8
  audit row.
- Committed as `docs(send-rpc)`; nothing pushed; worktree clean except
  the pre-existing owner-side skeletons.
