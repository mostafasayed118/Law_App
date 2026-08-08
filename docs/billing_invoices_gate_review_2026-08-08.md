# LegalHub — Billing Invoices RLS-Gate Design Review (2026-08-08)

> **Record type:** RLS-gate design review for the real-billing-invoices
> (read-metadata) slice — the **ninth** roadmap §14 per-feature
> un-deferral, following the `docs/p2_schema_rls_design.md` §8 Q1–Q6
> pattern and the **seven read-slice precedents**
> (`docs/matters_rls_gate_review_2026-08-07.md` +
> `docs/documents_rls_gate_review_2026-08-07.md` +
> `docs/messages_rls_gate_review_2026-08-07.md` +
> `docs/storage_rls_gate_review_2026-08-08.md` +
> `docs/realtime_rls_gate_review_2026-08-08.md` +
> `docs/realtime_push_gate_review_2026-08-08.md` +
> `docs/send_message_gate_review_2026-08-08.md`, all SHIPPED —
> applied + client-swapped). **Docs + rehearsal-ready artifacts only — NOT
> applied:** nothing in this review or the paired
> `supabase/migrations/10_billing_invoices*.sql` /
> `supabase/policies/invoices.sql` touches the dev project until the
> owner's dated apply-approval (INSTRUCTIONS.md §2.1/§5 hard gates; the
> matters/documents/messages/storage apply pattern).
>
> **Status: REVIEWED 2026-08-08 (decision-level).** Plan:
> `docs/billing_invoices_real_data_plan_2026-08-08.md` (D-BI1…D-BI6
> ratified by autonomy — recommended path, per the pair-programming grant;
> plan committed `a395678` on `main`, this review on
> `feat/billing-invoices-read`). **Owner:** Project Owner
> (github.com/mostafasayed118). **Governed by:**
> `docs/d11_billing_payments_decision_2026-08-08.md` (D-11 DECIDED —
> Paymob provider, **no live payment in MVP** — fake-gateway pattern,
> PCI via hosted tokenization, tax out of scope; D-04 residency
> confirmed) · `docs/permission_matrix.md` §4 (the documents row — the
> cell split this slice extends to invoices) · §7 (addendum discipline) ·
> `docs/p2_schema_rls_design.md` §8 pattern (Q4 billing deferral,
> consummated here) · `docs/billing_invoices_real_data_plan_2026-08-08.md`
> · `docs/documents_rls_gate_review_2026-08-07.md` (the exists-subquery
> precedent this gate mirrors verbatim) · `docs/rollback_plan.md` ·
> `docs/p0_closure_scope_2026-08-05.md` (D-P0C1(a) deny-row discipline) ·
> `INSTRUCTIONS.md` §2.1/§3/§5 (incl. §4.4 — tax rules never hardcoded).

---

## 1. Gate position

| Precondition (roadmap §14 → this slice) | Status |
|---|---|
| P0 closes (D-02…D-10b) | ✅ **RATIFIED 2026-08-05** — `docs/p0_closure_scope_2026-08-05.md` (D-P0C1…D-P0C5) |
| Policy tests exist | ✅ Shipped — `scripts/verify_policy_tests.sh` + `docs/p0c1_verification_evidence_2026-08-05.md` |
| Signed matrix governs the grant (positive + negative) | ✅ `docs/permission_matrix.md` §4 document rows (invoices are **matter content** — the documents row's "a restricted matter **or its documents/messages**" reading, extended to invoices) + §7 addendum discipline |
| **D-11 billing decision** (the previous un-block blocker) | ✅ **DECIDED 2026-08-08** — `docs/d11_billing_payments_decision_2026-08-08.md`: Paymob for any future real integration · **no live payment in MVP** (fake-gateway pattern) · PCI via Paymob-hosted tokenization (raw PAN/CVV never touches our servers/logs/audit → SAQ-A-like target, **no PCI claim for the demo**) · tax out of scope · D-04 residency confirmed |
| Seven read-slice precedents (the discipline chain ran green seven times) | ✅ **SHIPPED 2026-08-07/08** — matters / documents / message_threads / storage / audit / realtime read / realtime push (+ the audited send path, the eighth) — all applied + battery r1 PASSED + matrix addenda + client swaps |
| Applied `matters` table (this slice's FK target + assignment source) | ✅ Applied on the dev project (matters T5 — execution evidence `docs/matters_apply_execution_2026-08-07.md`); the four demo matters (`a6715e17-…` acquisition · `d155dc92-…` lease · `4f4a935f-…` procedural · `575391b6-…` family, org `ef43087b-adf4-4480-9bb2-28c26f46ec71`) are the demo-seed FK targets |
| No billing data model / RPC / matrix rows exist (the §14 gap) | ✅ Verified gap — zero billing rows in `docs/permission_matrix.md`, zero billing RPCs in `supabase/rpc/`, zero billing tables (plan §2) — this review's schema is the first |
| Harness state (the pins this slice re-scopes) | ✅ 11 tables / 11 RLS / 10 public + 1 storage policies / publication exactly `public.messages` / 19 EXECUTE RPCs / batteries 01–10 — verified 2026-08-08 (send-message T3/T4) |
| RLS-gate review (this record) | ✅ Answered 2026-08-08 (§3 Q1–Q6) |
| Rollback pairing | ✅ `supabase/migrations/10_billing_invoices.down.sql` + git-revert policy pairing (§6) |
| Dated matrix addendum **before** the client surface ships | ⏳ T6 of the plan (after apply, before T7) |
| Dated apply-approval | ⏳ T5 — owner-gated; nothing applied until then |

**Conclusion:** the decision-level preconditions are satisfied (P0 +
policy tests + seven shipped precedents + **D-11 DECIDED** + the applied
`matters` FK target) and the schema artifacts are **rehearsal-ready but
unapplied**. The first SQL execution is the battery/rehearsal (T3/T4) on
a Postgres-capable environment — the **established host is the owner's
Docker machine** (`supabase start`; the storage/realtime/send-message r1
Path A precedent), so this review makes **no execution claim**.

## 2. Scope

**In scope (read-metadata path only):** a `public.billing_invoices`
metadata table (D-BI1 column shape — **invoice metadata only, no
card/payment columns of any kind**, the D-11 PCI constraint made
structural: the table cannot even *hold* raw PAN/CVV), one RLS SELECT
policy on it (`invoices_select_assigned` — the **documents
exists-subquery pattern verbatim**, org-mismatch clause load-bearing),
default-deny revokes + a narrow direct SELECT grant (Q5 discipline), and
the paired backout. The client swap (T7) is a separate, env-gated slice
that **builds** the first billing client surface (D-BI5 — `Invoice` VO +
`BillingGateway.fetchInvoices()` + a matter-invoices section, the storage
D-STR7 precedent).

**Out of scope (flagged, not guessed):** any **write path** (no
INSERT/UPDATE/DELETE grant, no write RPC — D-11 "no live payment in
MVP" holds: the fake gateway is the product posture, not a stopgap);
**payment integration of any kind** (no Paymob SDK/iframe/redirect in
this slice — a separate, future, owner-approved integration spec per
D-11); **tax/VAT calculation or lifecycle machinery** (D-11 — the
`status` CHECK is deliberately minimal `('issued','paid')`, INSTRUCTIONS
§4.4 — tax rules never hardcoded); a **firm-wide invoices view for
partners** (partner/`compliance_officer` "deny unless separately
assigned" cells stay ungranted — recorded follow-up, the documents
precedent); **AI** (the last §14 path, owner-blocked on D-07/D-08 + no
scope); seeding (apply-time, T5, owner-approved with cleanup).

## 3. Gate-review decisions (Q1–Q6, answered 2026-08-08)

1. **Q1 — Read mechanism: RESOLVED.** **Single-layer, PostgREST, no
   SECURITY DEFINER RPC.** Invoices are **pure metadata — no bytes**, so
   there is no storage layer (the storage slice's two-layer answer is
   not needed). `public.billing_invoices` + `invoices_select_assigned`
   via `supabase.from('billing_invoices').select()` through the documents
   seam (`DocumentTableCaller` pattern — the provider binding is the only
   file that touches provider types). The policy calls
   `public.is_active_member(organization_id)` — already EXECUTE-granted
   to `authenticated` (02_rls_functions R-4 grants); **no new function
   grant is introduced** (the matters/documents/messages convention).
2. **Q2 — Assignment model: RESOLVED.** Invoices are **matter content**
   (matrix §4 documents row — "a restricted matter **or its
   documents/messages**" — extended to invoices; D-BI3). A row grants iff
   `is_active_member(organization_id)` **and** the reader is assigned
   (client or attorney) **on the invoice's matter**, via the documents
   exists-subquery pattern **verbatim**:
   `exists (select 1 from matters m where m.id = invoices.matter_id AND
   m.organization_id = invoices.organization_id AND
   (m.assigned_client_id = auth.uid() OR m.assigned_attorney_id =
   auth.uid()))`. **The `m.organization_id`-vs-row org equality is
   load-bearing** — the org gate comes from the matter's **authoritative**
   org, so an invoice is never readable when its matter is not (the
   org-mismatch battery rows pin it, non-vacuously). **The
   active-membership arm is load-bearing** — a suspended-but-still-
   assigned user must be denied exactly as on documents (the fixture
   matter 6 assigns `suspended-a`, pinning it).
3. **Q3 — matterRef (title) resolution: RESOLVED.** Rows store
   `matter_id` (ids only); the client `Invoice.matterRef` is
   **title-keyed by design** (D-BI5). The gateway resolves the title via
   the **embedded `matters(title)` select** (the documents D-DR4 / D-MSR4
   pattern exactly), falling back to the raw matter id (honest — never a
   fabricated title). The embed resolves because the policy guarantees
   the reader passes the matter gate.
4. **Q4 — `platform_owner_admin` and oversight rows: RESOLVED.** The
   policy contains **no owner carve-out** — the matrix's "deny, always"
   row holds as an **operational invariant, not a policy guarantee**:
   owner accounts are never assigned on matters, so the gate denies them;
   the battery pins the unassigned-owner deny row. **Recorded residual
   (mirrors the matters/documents/messages/storage Q4):** if an owner
   account were ever assigned on a matter, the policy WOULD grant its
   invoices — enforcing the categorical deny would require an
   `is_platform_owner()` exclusion (and its EXECUTE grant to
   `authenticated`, widening the PostgREST surface the prior reviews
   avoided); deferred with the oversight mechanism.
   Partner/`compliance_officer` "deny unless separately assigned" cells
   are **NOT granted** in this slice.
5. **Q5 — No direct table mutation; metadata only: RESOLVED.** The only
   grant is `select` on `public.billing_invoices` to `authenticated`
   (mirrors matters/documents/messages/files); no INSERT/UPDATE/DELETE
   grant, no write RPC — **D-11's no-live-payment posture is structural,
   not aspirational**. The table carries **no card/payment columns of any
   kind** — no `card_token`, no `payment_method`, no `billing_address`,
   no amount-payer identity beyond the assigned matter: the D-11 PCI
   constraint (raw PAN/CVV never touches our servers, logs, or audit) is
   **enforced by schema** — the table cannot even represent payment data.
   The `amount_cents >= 0` + `status in ('issued','paid')` CHECKs are the
   mapping contract (no write path can insert a value the client cannot
   render; no tax/lifecycle machinery per D-11). The new client surface
   is **metadata-only** (D-BI5) with **no pay affordance** — the billing
   surface can never initiate a charge in this slice. A future real
   Paymob integration is a separate, owner-approved spec (D-11).
6. **Q6 — Audit: RESOLVED.** Read-only slice: no new audit events, no
   `write_audit` call sites, no system-actor additions. Invoice
   **metadata reads are not audited** (consistent with
   matters/documents/messages/files); surfacing the audit RPCs stays a
   separate shipped §14 item (audit surfacing SHIPPED 2026-08-08).

## 4. Policy + deny-rows spec (the battery contract, executed in T3)

Positive (each grants exactly the invoice set of the assigned matters,
one invoice per fixture matter — the documents 2/3/1 count shape):
- **assigned client** (client-a on matters 1,2) reads their invoices → 2;
- **assigned attorney** (partner-a on matters 1,2,3) reads theirs → 3;
- **orphan** (assigned client on matter 4) reads theirs → 1;
- row-count pins prove no blanket-org bleed (same count shape as the
  matters/documents/messages 2/3/1 batteries).

Negative (deny rows, `03_platform_owner_boundary` style):
- active org member, **no matter assignment** → denied (org-role-alone);
- **org-mismatch (D-BI2 invariant):** an invoice row whose
  `organization_id` ≠ its matter's org denies — for **every** role; the
  fixture must be **non-vacuous** — the reader is an active member of the
  row's org AND assigned on the temp (different-org) matter, so only the
  clause denies (the documents T3 lesson, pre-empted);
- **cross-org**: partner-b assigned on an org-a matter, member of org-b
  only → denied (`is_active_member` of the invoice's org fails);
- **suspended** membership in the invoice's org → denied — the
  load-bearing `is_active_member` arm (fixture matter 6 assigns
  `suspended-a`);
- **unauthenticated** → denied;
- **`platform_owner_admin`** (owner account, unassigned) → denied, always
  (D-P0C1(a) deny-row extension; Q4 residual noted in-file);
- **`amount_cents` CHECK row:** an insert with a negative amount (`-1`)
  fails the CHECK — the schema is the mapping contract;
- **`status` CHECK row:** an insert with a status outside
  `('issued','paid')` (e.g. `'overdue'`) fails the CHECK — deliberately
  minimal per D-11 (no tax/lifecycle machinery);
- deleted-cascade sanity: dropping the matter removes its invoice rows
  (FK `on delete cascade`).

## 5. Schema (rehearsal-ready — D-BI1)

`public.billing_invoices`: `id uuid pk default gen_random_uuid()` ·
`organization_id uuid not null fk organizations on delete cascade`
(denormalized, mirrors matters/documents/message_threads — the policy's
membership check reads it, but the **matter's org is authoritative**, Q2)
· `matter_id uuid not null fk matters on delete cascade` (the assignment
source of truth + FK target for the embed) · `invoice_number text not
null` (generic — `INV-2026-0001` style; never PII by convention) ·
`amount_cents bigint not null default 0` with a
`check (amount_cents >= 0)` — the schema is the mapping contract ·
`currency text not null default 'EGP'` (the D-11 demo posture; no FX
machinery) · `status text not null default 'issued'` with a
`check (status in ('issued','paid'))` — **deliberately minimal** (D-11:
no tax/VAT/lifecycle machinery, INSTRUCTIONS §4.4) · `issued_at
timestamptz not null default now()` · `due_at timestamptz not null` ·
`description text not null default ''` (generic demo copy, never PII).
**No card/payment columns of any kind** (D-11 PCI — structural, Q5).
Indexes: `(organization_id)`; `(matter_id)` (the FK join + battery lookup
shape). RLS enabled; `revoke all … from anon, authenticated`; `grant
select … to authenticated` only (Q5).

## 6. Rollback pairing (never-fix-forward)

- `supabase/migrations/10_billing_invoices.down.sql` — `drop table
  public.billing_invoices;` (clean inverse; the inline CHECKs die with
  the table, like 04/05/06, no type object to drop).
- Policy backout: `git revert` of the policy commits (design §7
  convention in `docs/rollback_plan.md`).
- Apply-time residue (T5): demo invoice rows are inserted and removed in
  the same owner-approved step (cleanup discipline; one insert set, one
  delete set).

## 7. Ledger

- Docs-only + rehearsal-ready SQL this session: **no `lib/`/`test/`
  change, no README-count change, no dev-project contact** —
  `verify_ledger.sh` unaffected; nothing pushed.
- The plan (T1–T8) tracks each subsequent gate; the battery (T3) and
  rehearsal (T4) are the first executions and will carry their own
  evidence records.
- **Harness re-scope (D-BI6, executed at T3):** `BATTERY_FILES` gains
  `11_invoice_rls.sql`; the `--apply` order gains `10_billing_invoices.sql`;
  pins **tables 11→12 / RLS 11→12 / public policies 10→11** (12 minus the
  D-SM3 `messages_insert_assigned` drop — the 1e wording updates);
  the 1f forward-pin comment gains the **ninth** un-deferral
  (`billing_invoices` present + `invoices_select_assigned`); UUID + FAIL
  scans and the header comment update with it; selftest glob catches the
  new battery file.
