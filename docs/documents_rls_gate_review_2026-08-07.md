# LegalHub — Documents RLS-Gate Design Review (2026-08-07)

> **Record type:** RLS-gate design review for the real-documents (read)
> slice — the second roadmap §14 per-feature un-deferral, following the
> `docs/p2_schema_rls_design.md` §8 Q1–Q6 pattern and the **matters
> precedent** (`docs/matters_rls_gate_review_2026-08-07.md`, whose slice is
> SHIPPED — applied + client-swapped). **Docs + rehearsal-ready artifacts
> only — NOT applied:** nothing in this review or the paired
> `supabase/migrations/05_documents*.sql` / `supabase/policies/documents.sql`
> touches the dev project until the owner's dated apply-approval
> (INSTRUCTIONS.md §2.1/§5 hard gates; the matters apply pattern).
>
> **Status: REVIEWED 2026-08-07 (decision-level).** Plan:
> `docs/documents_real_data_plan_2026-08-07.md` (D-DR1…D-DR8 ratified).
> **Owner:** Project Owner (github.com/mostafasayed118). **Governed by:**
> `docs/permission_matrix.md` §4/§6 (document rows — matter-scoped content)
> · §7 (addendum discipline) · `docs/p2_schema_rls_design.md` §8 pattern ·
> `docs/documents_real_data_plan_2026-08-07.md` · `docs/matters_rls_gate_review_2026-08-07.md`
> (the assignment-gate precedent) · `docs/rollback_plan.md` ·
> `docs/p0_closure_scope_2026-08-05.md` (D-P0C1(a) deny-row discipline) ·
> `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Precondition (roadmap §14 → this slice) | Status |
|---|---|
| P0 closes (D-02…D-10b) | ✅ **RATIFIED 2026-08-05** — `docs/p0_closure_scope_2026-08-05.md` (D-P0C1…D-P0C5) |
| Policy tests exist | ✅ Shipped — `scripts/verify_policy_tests.sh` + `docs/p0c1_verification_evidence_2026-08-05.md` |
| Signed matrix governs the grant (positive + negative) | ✅ `docs/permission_matrix.md` §4 document rows (documents are **matter content** — line 143/148) |
| Matters precedent (the discipline chain ran green) | ✅ **SHIPPED 2026-08-07** — applied + battery r1 PASSED + matrix addendum + client swap |
| Applied `matters` table (this slice's FK target + assignment source) | ✅ Applied on the dev project (T5 of the matters plan, `0181cfa`) |
| RLS-gate review (this record) | ✅ Answered 2026-08-07 (§3 Q1–Q6) |
| Rollback pairing | ✅ `supabase/migrations/05_documents.down.sql` + git-revert policy pairing (§6) |
| Dated matrix addendum **before** the client surface ships | ⏳ T6 of the plan (after apply, before T7) |
| Dated apply-approval | ⏳ T5 — owner-gated; nothing applied until then |

**Conclusion:** the decision-level preconditions are satisfied (P0 + policy
tests + the matters precedent) and the schema artifacts are
**rehearsal-ready but unapplied**. The first SQL execution is the
battery/rehearsal (T3/T4) on a Postgres-capable environment — the
**established host is the owner's Docker machine** (matters r1 Path A
precedent: `supabase start` + `SUPABASE_TEST_DB_URL=…`; no psql/Docker on
this machine), so this review makes **no execution claim**.

## 2. Scope

**In scope (read path only):** a `public.documents` table (D-DR3 column
shape — **metadata only, no body/content/size/url columns**, D-V1), one
RLS SELECT policy (D-DR1/D-DR2 — org + matter-scoped assignment gate),
default-deny revokes + a narrow direct SELECT grant (Q5 discipline), and
the paired backout. The client swap (T7) is a separate, env-gated slice.

**Out of scope (flagged, not guessed):** document **bodies** (no column —
the matrix body row stays §14-deferred, D-V1 holds); document
mutation/upload/delete (no INSERT/UPDATE/DELETE grant, no write RPC — a
future reviewed slice); partner/`compliance_officer` "deny unless
separately assigned" oversight reads (D-DR5 — mechanism undefined; not
granted); messages real path (its own un-deferral); storage / realtime /
e-signature; audit surfacing (`read_org_audit`/`read_platform_audit` stay
§14/P2-gated); seeding (apply-time, T5, owner-approved with cleanup).

## 3. Gate-review decisions (Q1–Q6, answered 2026-08-07)

1. **Q1 — Read mechanism: RESOLVED.** **Table + RLS SELECT policy via
   PostgREST** (`supabase.from('documents').select()`) — **no** SECURITY
   DEFINER RPC (D-DR2). Row-scoped reads are exactly RLS's job; the org
   RPCs exist for cross-table/definer needs, none of which apply here.
   The policy calls `public.is_active_member(organization_id)` — already
   EXECUTE-granted to `authenticated` (02_rls_functions R-4 grants), so
   **no new function grant is introduced**.
2. **Q2 — Assignment model: RESOLVED.** Documents are **matter content**
   (matrix §4 line 148 — "a restricted matter **or its documents/
   messages**"): a row grants iff `is_active_member(organization_id)` **and**
   the reader is assigned (client or attorney) **on the document's matter**,
   via a **plain `exists` subquery on the applied `matters` table**:
   `m.id = documents.matter_id AND m.organization_id = documents.organization_id
   AND (m.assigned_client_id = auth.uid() OR m.assigned_attorney_id = auth.uid())`.
   Two properties make this the same gate as matters, by construction:
   (a) the assignment columns live on the matters row itself, so the
   exists yields the matter gate **regardless of whether matters RLS
   re-applies inside the policy expression** (defense-in-depth either
   way — RLS does apply at the subquery scan for `authenticated`, and the
   raw predicate is identical); (b) the **`m.organization_id =
   documents.organization_id` clause is load-bearing** — the org gate must
   come from the matter's **authoritative** org, never the document's
   denormalized column, so **a document is never readable when its matter
   is not** (the FK alone cannot enforce org consistency; the battery pins
   the org-mismatch deny row).
3. **Q3 — matterRef (title) resolution: RESOLVED.** Rows store
   `matter_id` (ids only); the client `Document.matterRef` is **title-keyed
   by design** (D-W2). The gateway resolves the title via the **embedded
   `matters(title)` select** (PostgREST embed, the exact pattern
   `SupabaseOrgApi.listMyMemberships` ships with `organizations(name)`),
   falling back to the raw matter id (plan §9-style, honest — never a
   fabricated title). The embed resolves because the documents policy
   guarantees the reader passes the matter gate (the same gate the embed's
   RLS applies) — no profiles join, no cross-seam leak.
4. **Q4 — `platform_owner_admin` and oversight rows: RESOLVED.** The
   policy contains **no owner carve-out** — the matrix's "deny, always"
   row holds as an **operational invariant, not a policy guarantee**:
   owner accounts are never assigned on matters, so the matter gate denies
   them; the battery pins the unassigned-owner deny row. **Recorded
   residual (mirrors the matters Q4):** if an owner account were ever
   assigned on a matter, this policy WOULD grant its documents — enforcing
   the categorical deny would require an `is_platform_owner()` exclusion
   (and its EXECUTE grant to `authenticated`, widening the PostgREST
   surface both reviews avoided); deferred with the oversight mechanism
   (D-DR5). Partner/`compliance_officer` "deny unless separately assigned"
   cells are **NOT granted** in this slice.
5. **Q5 — No direct table mutation; metadata only: RESOLVED.** The only
   grant is `select` on `public.documents` to `authenticated` (mirrors
   `matters`/`organizations`/`memberships`); no INSERT/UPDATE/DELETE grant,
   no write RPC. The table carries **no body/content/size/url columns**
   (D-V1) — the metadata-only line is structural, so the vault can never
   render document content even in the real path. A future write/body
   slice is a separate reviewed design with its own matrix addendum.
6. **Q6 — Audit: RESOLVED.** Read-only slice: no new audit events, no
   `write_audit` call sites, no system-actor additions. Document **reads**
   are not audited (consistent with matters); surfacing the audit RPCs
   stays a separate §14 item.

## 4. Policy + deny-rows spec (the battery contract, executed in T3)

Positive (each grants exactly the document set of the assigned matters):
- **assigned client** (client-a on matters 1,2) reads their documents → 2;
- **assigned attorney** (partner-a on matters 1,2,3) reads theirs → 3;
- **orphan** (assigned client on matter 4) reads theirs → 1;
- row-count pins prove no blanket-org bleed (same count shape as the
  matters battery 2/3/1).

Negative (deny rows, `03_platform_owner_boundary` style):
- active org member, **no matter assignment** → denied (org-role-alone);
- **org-mismatch (D-DR2 invariant):** a document whose `organization_id`
  ≠ its matter's org denies for **every** role (the load-bearing clause);
- **cross-org**: partner-b assigned on an org-a matter, member of org-b
  only → denied (`is_active_member` of the document's org fails);
- **suspended** membership in the document's org → denied;
- **unauthenticated** → denied;
- **`platform_owner_admin`** (owner account, unassigned) → denied, always
  (D-P0C1(a) deny-row extension; Q4 residual noted in-file);
- `document_type` **CHECK** row: an insert with an unmapped value
  (`'tax'`) fails the CHECK — the schema is the mapping contract;
- deleted-cascade sanity: dropping the matter removes its documents (FK
  `on delete cascade`) — pinned in the battery fixture teardown.

## 5. Schema (rehearsal-ready — D-DR3)

`public.documents`: `id uuid pk default gen_random_uuid()` ·
`organization_id uuid not null fk organizations on delete cascade`
(denormalized, mirrors matters — the policy's membership check reads it,
but the **matter's org is authoritative**, Q2) · `matter_id uuid not null
fk matters on delete cascade` (the assignment source of truth + FK target
for the embed) · `title text not null` (never PII by convention, D-V4) ·
`document_type text not null` with a `CHECK` against the client
`DocumentType` set (`contract|brief|evidence|correspondence`) — the schema
is the mapping contract, so no write path can insert a value the client
cannot map · `created_at timestamptz not null default now()` ·
`updated_at timestamptz not null default now()`. Indexes:
`(organization_id)`; `(matter_id)` (the FK join + battery lookup shape).
RLS enabled; `revoke all … from anon, authenticated`; `grant select … to
authenticated` only (Q5). **No body/content/size/url columns** (D-V1).

## 6. Rollback pairing (never-fix-forward)

- `supabase/migrations/05_documents.down.sql` — `drop table public.documents;`
  (clean inverse; the inline `document_type` CHECK dies with the table —
  unlike 04, no type object to drop).
- Policy backout: `git revert` of the policy commit (design §7 convention
  in `docs/rollback_plan.md`).
- Apply-time residue (T5): demo document rows are inserted and removed in
  the same owner-approved step (cleanup discipline; one insert set, one
  drop).

## 7. Ledger

- Docs-only + rehearsal-ready SQL this session: **no `lib/`/`test/` change,
  no README-count change, no dev-project contact** — `verify_ledger.sh`
  unaffected; nothing pushed.
- The plan (T1–T8) tracks each subsequent gate; the battery (T3) and
  rehearsal (T4) are the first executions and will carry their own
  evidence records.
