# LegalHub — Matters RLS-Gate Design Review (2026-08-07)

> **Record type:** RLS-gate design review for the real-matters (read) slice —
> the per-feature discipline required by the roadmap §14 un-deferral gate
> ("P0 closes + policy tests + matrix extension"), following the
> `docs/p2_schema_rls_design.md` §8 Q1–Q6 pattern (that record answered the
> identity/org questions on 2026-08-01; this record answers them for
> `matters`). **Docs + rehearsal-ready artifacts only — NOT applied:**
> nothing in this review or the paired `supabase/migrations/04_matters*.sql`
> / `supabase/policies/matters.sql` touches the dev project until the
> owner's dated apply-approval (INSTRUCTIONS.md §2.1/§5 hard gates; the
> Phase 3 R1 apply pattern).
>
> **Status: REVIEWED 2026-08-07 (decision-level).** Plan:
> `docs/matters_real_data_plan_2026-08-07.md` (D-MR1…D-MR8 ratified).
> **Owner:** Project Owner (github.com/mostafasayed118). **Governed by:**
> `docs/permission_matrix.md` §4/§6 (matter read rows) · §7 (addendum
> discipline) · `docs/p2_schema_rls_design.md` §8 pattern ·
> `docs/matters_real_data_plan_2026-08-07.md` · `docs/rollback_plan.md` ·
> `docs/p0_closure_scope_2026-08-05.md` (D-P0C1(a) deny-row discipline) ·
> `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Precondition (roadmap §14 → this slice) | Status |
|---|---|
| P0 closes (D-02…D-10b) | ✅ **RATIFIED 2026-08-05** — `docs/p0_closure_scope_2026-08-05.md` (D-P0C1…D-P0C5) |
| Policy tests exist | ✅ Shipped — `scripts/verify_policy_tests.sh` + `docs/p0c1_verification_evidence_2026-08-05.md` |
| Signed matrix governs the grant (positive + negative) | ✅ `docs/permission_matrix.md` §4 matter rows (§1 below) |
| RLS-gate review (this record) | ✅ Answered 2026-08-07 (§3 Q1–Q6) |
| Rollback pairing | ✅ `supabase/migrations/04_matters.down.sql` + git-revert policy pairing (§6) |
| Dated matrix addendum **before** the client surface ships | ⏳ T6 of the plan (after apply, before T7) |
| Dated apply-approval | ⏳ T5 — owner-gated; nothing applied until then |

**Conclusion:** the decision-level preconditions are satisfied; the schema
artifacts are **rehearsal-ready but unapplied**. The first SQL execution is
the battery/rehearsal (T3/T4) on a Postgres-capable environment — the local
machine has **no psql/Docker** (recorded constraint, same as D-45.1 Phase 1
and `docs/p0c1_verification_evidence_2026-08-05.md` §3), so this review
makes **no execution claim**.

## 2. Scope

**In scope (read path only):** a `public.matters` table (D-MR3 column
shape), one RLS SELECT policy (D-MR1 assignment + active-membership gate),
default-deny revokes + a narrow direct SELECT grant (Q5 discipline), and
the paired backout. The client swap (T7) is a separate, env-gated slice.

**Out of scope (flagged, not guessed):** matter mutations (no
INSERT/UPDATE/DELETE grant, no write RPC — a future reviewed slice);
partner/owner "oversight" reads (D-MR5 — mechanism undefined; not granted);
documents/messages real paths (each its own un-deferral); audit surfacing
(`read_org_audit`/`read_platform_audit` stay §14/P2-gated); storage/
realtime; seeding (apply-time, T5, owner-approved with cleanup).

## 3. Gate-review decisions (Q1–Q6, answered 2026-08-07)

1. **Q1 — Read mechanism: RESOLVED.** **Table + RLS SELECT policy via
   PostgREST** (`supabase.from('matters').select()`) — **no** SECURITY
   DEFINER RPC (D-MR2). Row-scoped reads are exactly RLS's job; the org
   RPCs exist for cross-table/definer needs, none of which apply here.
   The policy calls `public.is_active_member(organization_id)` — already
   EXECUTE-granted to `authenticated` (02_rls_functions R-4 grants), so no
   new function grant is introduced.
2. **Q2 — Assignment model: RESOLVED.** Rows carry
   `assigned_client_id` / `assigned_attorney_id` (FK `auth.users`, the
   `memberships.user_id` convention). The policy grants a row iff
   `is_active_member(organization_id)` **and**
   (`assigned_client_id = auth.uid() OR assigned_attorney_id = auth.uid()`).
   This enforces the matrix §4 contract verbatim: **an org role alone never
   grants matter access** (the "❌ deny for every role" row), and cross-org
   access is denied because membership is tested against the **matter's own
   org**.
3. **Q3 — Display-name resolution: RESOLVED.** Rows store **ids only**;
   the client resolves `assignedAttorneyName` via the shipped partner-scoped
   roster RPC (`list_org_members_metadata` → display names, the P3.3 seam).
   A profiles join in a plain select is **blocked by own-row profiles RLS**
   (D-T6) — no join, no profiles widening (D-MR4).
4. **Q4 — `platform_owner_admin` and oversight rows: RESOLVED.** The
   policy contains no owner carve-out: the assignment gate returns false
   for owner accounts (never assigned), so the matrix's "deny, always"
   row holds by construction and is pinned in the battery. Partner/owner
   "policy-approved oversight / policy-review scope" rows are **NOT
   granted** in this slice (D-MR5 — the oversight mechanism is undefined
   and deliberately deferred).
5. **Q5 — No direct table mutation: RESOLVED.** The only grant is
   `select` on `public.matters` to `authenticated` (mirrors
   `organizations`/`memberships` in 01_org_schema); no INSERT/UPDATE/
   DELETE grant, no write RPC. A future write slice is a separate
   reviewed design with its own matrix addendum.
6. **Q6 — Audit: RESOLVED.** Read-only slice: no new audit events, no
   `write_audit` call sites, no system-actor additions. (Matter **reads**
   are not audited in this slice — consistent with the existing contract
   where only privileged actions write audit rows; surfacing the audit
   RPCs is a separate §14 item.)

## 4. Policy + deny-rows spec (the battery contract, executed in T3)

Positive (each grants exactly one row):
- assigned **client** of the matter reads it (active member of the org);
- assigned **attorney** reads it (active member of the org);
- row-count pin: a client sees exactly their assigned set (no bleed).

Negative (deny rows, `03_platform_owner_boundary` style):
- active org member, **no assignment** → denied (org-role-alone row);
- **cross-org**: user assigned on an org-a matter, queried as org-b member
  → denied (membership is of the matter's own org);
- **suspended** membership in the matter's org → denied (the
  `is_active_member` status = 'active' rule);
- **unauthenticated** → denied;
- **`platform_owner_admin`** (owner account, unassigned) → denied, always
  (D-P0C1(a) deny-row extension);
- deleted-cascade sanity: dropping the org removes its matters (FK
  `on delete cascade`) — pinned in the battery fixture teardown.

## 5. Schema (rehearsal-ready — D-MR3)

`public.matters`: `id uuid pk default gen_random_uuid()` ·
`organization_id uuid not null fk organizations on delete cascade` ·
`title text not null` · `practice_area text not null` (client
`PracticeArea` enum-name: `corporate|civil|criminal|family`) ·
`status public.matter_status not null default 'open'` (new enum
`('open','active','closed')` — the client `MatterStatus` set) ·
`assigned_client_id uuid fk auth.users on delete set null` ·
`assigned_attorney_id uuid fk auth.users on delete set null` ·
`created_at timestamptz not null default now()` ·
`updated_at timestamptz not null default now()`.
Indexes: `(organization_id, status)`; partial `assigned_client_id` /
`assigned_attorney_id` (the two RLS lookup shapes). RLS enabled;
`revoke all … from anon, authenticated`; `grant select … to authenticated`
only (Q5).

## 6. Rollback pairing (never-fix-forward)

- `supabase/migrations/04_matters.down.sql` — `drop table public.matters;`
  `drop type public.matter_status;` (clean inverse, same directory).
- Policy backout: `git revert` of the policy commit (design §7 convention
  in `docs/rollback_plan.md`).
- Apply-time residue (T5): demo matter rows are inserted and removed in the
  same owner-approved step (cleanup discipline; one insert set, one drop).

## 7. Ledger

- Docs-only + rehearsal-ready SQL this session: **no `lib/`/`test/` change,
  no README-count change, no dev-project contact** — `verify_ledger.sh`
  unaffected; nothing pushed.
- The plan (T1–T8) tracks each subsequent gate; the battery (T3) and
  rehearsal (T4) are the first executions and will carry their own
  evidence records.
