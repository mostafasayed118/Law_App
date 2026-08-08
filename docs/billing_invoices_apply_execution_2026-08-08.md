# LegalHub — Billing Invoices Apply Execution Evidence (2026-08-08)

> **Record type:** Execution evidence for the billing-invoices read slice
> (plan `docs/billing_invoices_real_data_plan_2026-08-08.md` T5) against
> the shared dev project (`eutmvevpskerzpqmwplv`, `eu-central-1`), under
> the dated apply-approval (`docs/billing_invoices_apply_approval_2026-08-08.md`,
> **APPLY APPROVED 2026-08-08**). Mirrors the matters/documents/messages/
> storage apply execution records (the §4-guardrail discipline).
>
> **Status: APPLIED 2026-08-08 — up sequence complete and verified on the
> shared dev project**: baseline probe → `10_billing_invoices` (the
> metadata-only table) → `policies/invoices` → demo seed (4 invoices on
> the applied demo matters) → post-apply smoke all verified. Rollback
> pairing standing by (`10_billing_invoices.down.sql` + targeted
> demo-row delete + `git revert` of the policy file). Nothing beyond the
> approval §3 scope was touched; the approval §5 exclusions hold (no
> write path, no payment integration, no tax machinery, no `lib/`
> change).

---

## 0. Runbook (executed 2026-08-08 with these commands)

```bash
# 1. Baseline probe (read-only) — see §1 for the observed output
# 2. Apply the schema migration (approval §3.1)
supabase db query --linked --file supabase/migrations/10_billing_invoices.sql
# 3. Apply the policy (approval §3.2)
supabase db query --linked --file supabase/policies/invoices.sql
# 4. Demo seed (approval §3.3) — 4 invoices on the applied demo matters,
#    org = the matter's org, generic numbers/amounts/copy (D-11)
# 5. Post-apply smoke (approval §4.5) — structural subset + role-impersonated
#    reads (partner 3 + family 0; clients 0/0; anon denied)
```

Rollback pairing standing by: `10_billing_invoices.down.sql` (`drop table
public.billing_invoices`) + a targeted delete of the seeded rows
(`delete from public.billing_invoices where id like 'b0000000-…%'`) +
`git revert` of the policy file (the RLS-gate review §6 convention) —
**never fix-forward**.

## 1. Baseline probe (read-only, before the up sequence)

| Check | Expected | Observed | Verdict |
|---|---|---|---|
| `public.billing_invoices` table | absent | `0` (information_schema) | ✅ |
| Applied demo matters resolve | the four ids, org `ef43087b-…` | all four present: `a6715e17-…` (acquisition review), `d155dc92-…` (lease consultation), `4f4a935f-…` (procedural review), `575391b6-…` (family consultation) — all org `ef43087b-adf4-4480-9bb2-28c26f46ec71` | ✅ verify-don't-guess |
| Public tables / RLS | 11 / 11 (pre-billing) | `11` tables / `11` RLS | ✅ (billing_invoices was the missing 12th) |
| Public policies | 10 current (→ 11) | `10` | ✅ (the storage apply took 9→10; this apply takes 10→11) |
| Storage-schema policies | 1 (unchanged) | `1` | ✅ |
| Publication (`supabase_realtime`) | exactly `messages`, untouched | `public · messages` only | ✅ |

Assignment map (the seed + smoke target): partner `8fa94af0-…` is the
assigned attorney on acquisition / lease / procedural (3 matters); the
family matter `575391b6-…` is **client-only** (`0c54d251-…`); the demo
clients hold no dev membership rows.

## 2. Up sequence (each step applied + verified)

### 2.1 `10_billing_invoices.sql` — the metadata-only table (D-BI1)

`supabase db query --linked --file supabase/migrations/10_billing_invoices.sql`
→ exit 0. Verified:

- **Table:** `public.billing_invoices` present with the exact D-BI1
  metadata-only column set — `id`, `organization_id`, `matter_id`,
  `invoice_number`, `amount_cents`, `currency`, `status`, `issued_at`,
  `due_at`, `description`. **No card/payment columns of any kind** — the
  D-11 PCI constraint is structural (raw PAN/CVV cannot live here). RLS
  enabled (`relrowsecurity = true`).

### 2.2 `policies/invoices.sql` — `invoices_select_assigned` (D-BI2)

`supabase db query --linked --file supabase/policies/invoices.sql` → exit
0. Verified: `invoices_select_assigned` (SELECT on `billing_invoices` —
`is_active_member(organization_id)` AND the `exists` on `matters` with
the **load-bearing org-mismatch clause** `m.organization_id =
billing_invoices.organization_id` AND the assigned client/attorney =
`auth.uid()` arms — the documents gate verbatim). **Public policies 10 →
11.**

### 2.3 Demo seed (approval §3.3) — 4 invoices

Fixed demo ids (`b0000000-…-0001..0004`), the applied demo matter ids,
org `ef43087b-…` on every row (the **matter's own org**), **generic
invoice numbers / synthetic EGP amounts / generic demo copy only**
(D-11 — no real charges, no PII, no card data):

| Invoice id | Matter | Number | Amount | Status |
|---|---|---|---|---|
| `b0000000-…-0001` | `a6715e17-…` (acquisition) | INV-2026-0001 | 125000 | issued |
| `b0000000-…-0002` | `d155dc92-…` (lease) | INV-2026-0002 | 87500 | paid |
| `b0000000-…-0003` | `4f4a935f-…` (procedural) | INV-2026-0003 | 62000 | issued |
| `b0000000-…-0004` | `575391b6-…` (family) | INV-2026-0004 | 45000 | issued |

Verified per guardrail §4.4: **4 invoices** seeded; every row's
`organization_id` **equals its matter's org** (the D-BI2 invariant —
`org_matches_matter = true` on all four).

## 3. Post-apply smoke (role-impersonated reads, R1 pattern)

`set local role authenticated` + `request.jwt.claims` sub — the RLS gate
on the live dev project:

| Reader | Identity | Expected | Observed | Verdict |
|---|---|---|---|---|
| Partner (assigned attorney, the **only** dev member) | `sub=8fa94af0-7390-4f7a-988a-3965f7da04de` | reads the invoices on its 3 assigned matters | **3** — `INV-2026-0001/0002/0003` | ✅ positive — assigned attorney sees exactly its set |
| Partner — family matter (client-only) | same | 0 (not assigned) | invoice `INV-2026-0004` **absent** from the partner's read set | ✅ the assignment gate, live |
| Assigned client (NO membership rows) | `sub=0c54d251-6b23-4d59-b6a4-7b0f74c9d123` (family) | 0 — the D-BI2 membership guard | **0** | ✅ membership guard firing live — recorded as an honest expectation, never a defect (the matters/documents/messages/storage smoke precedent) |
| Assigned client (NO membership rows) | `sub=9acfd3b4-96c6-4836-aaa7-defd7864cefb` (acquisition) | 0 — same | **0** | ✅ same |
| Anon | `role=anon` | denied | `permission denied for table billing_invoices` (42501 — no grant, default-deny) | ✅ anon denied |

> **Honest expectation note (\\*):** the demo **clients** are assigned on
> the demo matters but hold **no dev membership rows** — `is_active_member`
> is false for them, so they read 0. This is the D-BI2 membership guard
> firing live (the same posture recorded in the matters/documents/
> messages/storage smokes), never a defect.

**Final structural subset (all verified):** **12 tables / 12 RLS**
(billing_invoices added; every public table RLS-enabled) · **public
policies 11** (10→11) · **storage policies 1** (unchanged) · publication
**exactly `public.messages`** (untouched) · invoices 4.

## 4. Trigger-condition sweep (rollback_plan §5)

| Trigger | Observed | Verdict |
|---|---|---|
| A matrix negative row starts passing | anon denied (no grant) · assigned clients (no membership) read 0/0 · partner does NOT read the client-only family invoice | ✅ none |
| Cross-tenant data visible | all rows + reads scoped to org `ef43087b-…`, the four applied demo matters | ✅ none |
| A demo row lands on a real matter/account | the seed targets the applied **demo** matters only, generic numbers/copy | ✅ none |
| A non-generic invoice number/amount/description appears | all four numbers/amounts/descriptions generic (D-11 synthetic, no PII, no card data) | ✅ none |
| Policy inventory drift | public 10→11, exactly the predicted set (`invoices_select_assigned`) | ✅ none |

No trigger condition fired; **no rollback invoked** (never fix-forward).
The rollback pairing (`10_billing_invoices.down.sql` + the targeted
demo-row delete + the policy git-revert) stands by, unexercised.

## 5. Ledger / state / owner attention

- **Applied 2026-08-08:** `10_billing_invoices` (metadata-only table) +
  `policies/invoices` + the demo seed (4 invoices on the applied demo
  matters). Dev project now: **12 tables / 12 RLS / 11 public policies +
  1 storage policy / publication exactly messages / 4 demo invoices** —
  the approval's scope, with the baseline-count delta recorded (§0: the
  approval's "10 public policies" matched the actual pre-apply state;
  this apply moved it 10→11).
- **Plan T5 row:** flipped DONE (the dated approval §6 + this execution
  record close the apply gate; the roadmap §14 billing SHIPPED flip lands
  at T8 with the client swap).
- **No write path / no payment integration** (D-11): the slice is
  read-only metadata; invoice creation, Paymob, and tax machinery are
  future, owner-approved slices. **No `lib/` change** — the env-gated
  `BillingGateway` swap is plan T7.
- **Configured-build verification (D-BI5):** the future env-gated client
  swap will read these seeded rows under the same RLS gates.
- Committed as `docs(billing)`; nothing pushed; worktree clean except the
  pre-existing owner-side `SPEC_KIT.md`.
