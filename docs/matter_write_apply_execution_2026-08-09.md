# LegalHub — F-01 Step 2 Matter-Write Apply Execution Evidence (2026-08-09)

> **Record type:** execution evidence for the F-01 step 2 matter-write slice
> (`supabase/rpc/create_matter.sql` + `supabase/migrations/11_matter_write.sql`),
> per `docs/matter_write_apply_approval_2026-08-09.md` §3/§4. Mirrors the
> send-message apply-execution record (`docs/send_message_apply_execution_2026-08-08.md`)
> — the immediate precedent (an RPC with a §8-audited live write).
>
> **Status: APPLIED 2026-08-09 — up sequence complete and verified on the
> shared dev project** (`eutmvevpskerzpqmwplv`, `eu-central-1`): baseline
> probe → `create_matter.sql` → `11_matter_write.sql` → the **demo create
> via the RPC** (the first §8-audited live matter write) → post-apply smoke
> all verified. Rollback pairing standing by (`11_matter_write.down.sql` +
> the `rpc/_down.sql` drop + `git revert`), **unexercised**. The owner's
> dated approval is recorded in `docs/matter_write_apply_approval_2026-08-09.md`
> §6 (**APPLY APPROVED 2026-08-09**, signed in-session when the owner
> directed the apply execution). Nothing beyond the approval §3 scope was
> touched; the approval §5 exclusions hold.
>
> **One real finding recorded (§5), not papered over:** the apply surfaced
> that the dev project's **`platform_config.owner_user_id` IS the account
> id historically recorded as the acquisition demo matter's "client"**
> (`9acfd3b4-…`) — so the pre-existing demo matter `a6715e17-…`
> ("Demo matter — acquisition review", seeded 2026-08-07 by the matters
> apply) has the **platform owner id as its `assigned_client_id`** — the
> exact Q4 residual state F-01 forbids, present in the dev demo data since
> before the F-01 work. **Contained, not a live disclosure** (verified: the
> owner reads 0 matters — the `matters_select_assigned` policy's
> `is_active_member` arm blocks it, since the owner holds no memberships).
> This is pre-existing demo data the apply surfaced, **not a defect of this
> slice**; the slice's guarantee (no NEW owner assignment through any path)
> is now live and proven. No rollback was invoked (never fix-forward); the
> data remediation is an owner-side follow-up (§5).

---

## 0. Runbook (executed 2026-08-09 with these commands)

```bash
# 1. Baseline probe (read-only) — §1
# 2. Apply the RPC (approval §3.1)
supabase db query --linked --file supabase/rpc/create_matter.sql
# 3. Apply the trigger migration (approval §3.2)
supabase db query --linked --file supabase/migrations/11_matter_write.sql
# 4. Demo create (approval §3.3) — role-impersonated RPC call as the
#    partner (set local role authenticated + request.jwt.claims sub),
#    RETURNING id — persisted
# 5. Post-apply smoke + negative probes (approval §4.5)
```

Rollback pairing standing by: `11_matter_write.down.sql` (drop trigger +
function) + the `rpc/_down.sql` drop for `create_matter` + `git revert` of
the artifact commit — **never fix-forward**.

## 1. Baseline probe (read-only, before the up sequence)

| Check | Expected | Observed | Verdict |
|---|---|---|---|
| `create_matter` function present? | **absent** | `0` | ✅ |
| `refuse_platform_owner_assignment` present? | **absent** | `0` | ✅ |
| trigger `matters_refuse_owner_assignment` present? | **absent** | `0` | ✅ |
| `matters` table present | yes | `1` | ✅ |
| `pg_policies` (public) count | **11** (unchanged by this apply) | `11` | ✅ |
| tables with RLS | **12** | `12` | ✅ |
| publication (`supabase_realtime`) | exactly `messages` | `1` | ✅ |
| `matter-files` bucket | present | `1` | ✅ |
| `platform_config` rows (D-P0C3) | exactly 1 | `1` | ✅ |
| demo org `ef43087b-…` | resolves | `1` | ✅ |
| demo partner `8fa94af0-…` active member of the demo org | **yes** (the only dev member) | `1` | ✅ |
| demo client memberships | **0** (F-09 posture) | `0` | ✅ |
| demo matters in the demo org | 4 | `4` | ✅ |

All trigger conditions clean at the baseline; no STOP condition fired.

## 2. Up sequence (each step applied + verified)

### 2.1 `supabase/rpc/create_matter.sql` — the first matter-write surface

`supabase db query --linked --file supabase/rpc/create_matter.sql` → exit 0.
Verified immediately after:

| Check | Observed | Verdict |
|---|---|---|
| `create_matter(uuid, text, text, uuid, uuid)` present | `1` | ✅ |
| `authenticated` EXECUTE | `true` | ✅ |
| `anon` EXECUTE | `false` | ✅ (default-deny preserved) |

### 2.2 `supabase/migrations/11_matter_write.sql` — the categorical trigger

`supabase db query --linked --file supabase/migrations/11_matter_write.sql`
→ exit 0 (the file's `begin; … commit;` wrapper ran cleanly). Verified:

| Check | Observed | Verdict |
|---|---|---|
| `refuse_platform_owner_assignment()` present | `1` | ✅ |
| `authenticated` EXECUTE on the trigger function | `false` (trigger-invoked only, F2-D3) | ✅ |
| trigger `matters_refuse_owner_assignment` on `matters` | `1` | ✅ |
| `pg_policies` (public) | `11` — **unchanged** (the trigger is not a policy arm; no R-4 probe widening) | ✅ |
| tables with RLS | `12` | ✅ |

### 2.3 Demo create (the first §8-audited live matter write)

Role-impersonated RPC call as the demo partner (`set local role
authenticated` + `request.jwt.claims` sub = `8fa94af0-…`), generic demo
title, `practice_area = 'corporate'`, assigned attorney = the partner,
client = null (F2-D5 — the partner is the only dev member):

```
┌──────────────────────────────────────┐
│ created_matter_id                    │
├──────────────────────────────────────┤
│ d28f1f05-f95f-46ea-9b15-767f15778c01 │
└──────────────────────────────────────┘
```

The row persisted through the audited path: F2-D1 passed (the partner is an
active member of the demo org), the INSERT ran inside the definer function
under the categorical trigger, and the §8 audit row was written in the same
implicit transaction.

**§8 audit row (observed verbatim via the linked CLI as the privileged role
— never a raw client SELECT on `audit_events`, D-P0C4):**

| Field | Value |
|---|---|
| `action` / `outcome` | `matter:create` / `allowed` |
| `actor_user_id` | `8fa94af0…` (the partner) |
| `resource_type` / `resource_id` | `matter` / `d28f1f05-f95f-46ea-9b15-767f15778c01` (**= the RPC's returned id**) |
| `redacted_summary` | `matter created` (never the title) |

The **§8 matter-create audit path is live on the dev project** — the
slice's whole point, verified.

## 3. Negative probes (live, all inside `begin; … rollback;`)

| Probe | Expectation | Observed | Verdict |
|---|---|---|---|
| F2-D2 — `create_matter` with the platform-owner id (`platform_config.owner_user_id`, read in-block, masked) as assigned client | refused — `platform owner cannot be assigned to a matter` | the exact refusal message | ✅ |
| F2-D4 — `create_matter` with a non-member account id (the demo-client account) as assigned client | refused — `assigned client must be an active member of the organization` | the exact guard message | ✅ |
| anon — `create_matter` under `set local role anon` | `insufficient_privilege` (no EXECUTE grant) | privilege-layer denial | ✅ |

## 4. Post-apply smoke (role-impersonated reads, R1 pattern)

| Reader | Identity | Expected | Observed | Verdict |
|---|---|---|---|---|
| Partner (assigned attorney, active member) | `sub=8fa94af0-…` | reads the demo matter `d28f1f05-…` | **1** | ✅ RLS read-back live |
| Platform owner | `sub=9acfd3b4-…` | reads 0 — the membership arm (owner holds no memberships) | **0** | ✅ contained (see §5) |
| Structural subset | — | fn + trigger + grants + policies 11 + RLS 12 (§2) | all as observed | ✅ |

## 5. The finding (recorded, not papered over)

**Pre-existing dev demo data violates the F-01 never-assigned invariant —
now surfaced by the apply.** The dev project's
`platform_config.owner_user_id` **equals the account id historically
recorded as the acquisition demo matter's "client"** (`9acfd3b4-…`). The
pre-existing demo matter **`a6715e17-…` "Demo matter — acquisition review"**
(seeded by the matters apply, 2026-08-07; `assigned_client_id = 9acfd3b4-…`,
`assigned_attorney_id = 8fa94af0-…`) therefore has the **platform owner id
in an assignment column** — the exact state the F-01 register described as
"if an owner account were ever assigned, this policy WOULD grant" — and
battery 12's invariant is false in the dev demo data (the battery itself is
ephemeral-only, so it never ran here).

**Why it is contained (verified, not assumed):** the
`matters_select_assigned` policy requires `is_active_member(organization_id)`
AND the assignment — the owner holds **0** memberships, so impersonating the
owner returns **0 visible matters**. No live disclosure; the owner account
cannot read the matter.

**Why this is not a slice defect:** the trigger and RPC are exactly as
rehearsed; the guarantee they enforce (no NEW owner assignment through any
path) is now live and proven (§2.3, §3). The trigger does not retroactively
rewrite pre-existing rows — by design (narrow, F2-D3). The owner-assigned
row predates the F-01 work and the apply.

**Remediation (owner-side, separate approved slice — the send-message
display-name precedent):** re-assign `a6715e17-…`'s `assigned_client_id`
from the owner id to the real demo-client account (`0c54d251-…`) so the
dev demo data satisfies the F-01 invariant, and note the owner-account
hygiene (the same account was historically seeded as a demo "client"). This
is a data change outside this approval's §3 scope — **not applied here; no
rollback invoked** (never fix-forward).

## 6. Trigger-condition sweep (rollback_plan §5)

| Trigger | Observed | Verdict |
|---|---|---|
| A matrix negative row starts passing | owner-refusal, member-guard, anon denial all fire live (§3) | ✅ none |
| Cross-tenant data visible | demo create scoped to org `ef43087b-…`, partner-assigned; owner reads 0 | ✅ none |
| A demo row lands on a real matter/account | the demo create is a new matter (`d28f1f05-…`), generic title, no real data | ✅ none |
| An owner assignment succeeds through any path | refused at the RPC (F2-D2) and pinned at the trigger (rehearsal 13.04/13.14) | ✅ none |
| Policy inventory drift | `pg_policies` 11 → 11 (unchanged — the trigger is not a policy) | ✅ none |
| The §8 audit row missing or carrying content | `matter:create/allowed`, actor, resource id = returned id, redacted `matter created` | ✅ none |

**The one finding (§5) is pre-existing demo data the apply surfaced — not a
trigger-condition violation; no rollback invoked.** The rollback pairing
stands by, unexercised.

## 7. Ledger / state / owner attention

- **Applied 2026-08-09:** `create_matter(uuid, text, text, uuid, uuid)`
  (security definer, F2-D1/D2/D4 gates, §8 audit by construction; EXECUTE
  granted authenticated, denied anon) + the categorical
  `refuse_platform_owner_assignment` trigger on `matters` (EXECUTE-revoked).
  Dev project now: **12 tables / 12 RLS / 11 public policies / 20
  RPC-EXECUTE** (19 → 20) + the trigger — the approval §4.1 predictions,
  with the matter tally 5 (4 pre-existing + `d28f1f05-…`).
- **§8 matter-create audit live** — the F-01 step 2 guarantee is enforced
  on the shared dev project; the demo smoke row `d28f1f05-…` persists (the
  send-message demo-send precedent).
- **⚠ Owner-side follow-up (§5 finding) — RESOLVED 2026-08-09:** the
  acquisition demo matter's client was re-assigned off the owner id onto
  the demo-client account with a machine audit row
  (`docs/f12_data_remediation_2026-08-09.md`); the F-01 invariant now
  holds in the dev demo data (owner id in 0 assignment columns).
- **Remaining gate steps:** dated matrix §4 addendum (matter-write row) +
  applied-surface record addendum (RPC-EXECUTE 19 → 20, trigger) + the
  env-gated client swap (separate slice).
- Nothing pushed; the slice commit `f2e88cc` precedes this execution;
  worktree state per `git status`.
