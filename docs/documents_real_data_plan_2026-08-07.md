# Plan: Real Documents (Read) Data Path — the second §14 un-deferral (2026-08-07)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> second slice under the roadmap §14 blanket-deferral, mirroring the
> **matters read slice** (plan `docs/matters_real_data_plan_2026-08-07.md`,
> SHIPPED 2026-08-07) — the same per-feature discipline, applied to
> document **metadata**. **Docs-only planning — zero dev-project effect**:
> nothing in this document or its TASKS applies anything to the dev
> Supabase project; every external step stays behind the owner's dated
> approval (INSTRUCTIONS.md §2.1/§5 hard gates).
>
> **Gate state (why this slice is now plannable):** the §14 precondition
> is **met at the decision level and proven by precedent** — P0 closure
> RATIFIED (`docs/p0_closure_scope_2026-08-05.md`, D-P0C1…D-P0C5), the
> policy battery ships (`scripts/verify_policy_tests.sh`), and the
> matters slice ran the full chain green (rehearsal r1 PASSED → signed
> apply → matrix addendum → env-gated client swap). The `matters` table
> is now **applied on the dev project** and is the documents table's FK
> target and assignment source of truth.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Move the **document-metadata list read path** from the synthetic fake to a
real, org-scoped, **matter-scoped** `documents` table read through
PostgREST with RLS — **without changing the client `Document` VO or any
presentation code** (the swap is seam-compatible and env-gated, mirroring
the matters flip). "Done" = an active member reads exactly the document
metadata of the matters they are assigned to (client or attorney); every
other read — org-role-alone, cross-org, unassigned, unauthenticated,
`platform_owner_admin` — is denied and policy-tested; the env-less demo and
the whole test suite still run on the fake. **Metadata only: no document
body/content/size/URL column ever exists** (D-V1 line preserved in the real
path); the matrix's "Read a document/message body" row stays deferred.

## 2. Gap (verified)

- `DocumentGateway` (Phase 8 slice 8.0, `22d63e5`) is fake-only:
  `FakeDocumentGateway.syntheticDocuments` serves five static non-PII
  metadata rows; the real data path stays §14-deferred — and the matters
  slice established the un-deferral discipline (§0).
- The client `Document` VO (D-V4): `id`, `title`, `matterRef` (**a matter
  title string**, D-W2 — the title-keyed association the reverse
  cross-link resolves via `matter_title_resolver.dart`), `type`
  (`DocumentType` enum), `createdAt`. **No body, no content, no size, no
  download URL, no e-signature field** (D-V1).
- The **permission matrix §4 governs the read scope** and treats documents
  as **matter-scoped content** (line 143): client ✅ / attorney ✅ *if
  assigned*; partner ❌ / `compliance_officer` ❌ "deny unless separately
  assigned"; `platform_owner_admin` ❌ **deny, always**. Line 148: an org
  role without an explicit matter assignment cannot read a restricted
  matter **or its documents/messages** — true for every role. Line 152:
  `platform_owner_admin` reading any matter/document/message content is
  denied **at the RLS layer**, not hidden in the UI.
- The **`matters` table is applied + policy-tested** on the dev project
  (`04_matters.sql` + `matters_select_assigned`, battery r1 PASSED): the
  documents table FKs to it and inherits its assignment semantics — the
  document gate *is* the matter gate, scoped to the row's own matter.
- The battery fixture set already seeds six matters with every assignment
  branch (client-a, partner-a, orphan, cross-org partner-b, suspended-a) —
  the documents battery reuses them, no new identity fixtures needed.

## 3. Design decisions (D-DR1…D-DR8 — ratified by autonomy this session)

| # | Decision | Recommendation | Why / alternative |
|---|---|---|---|
| D-DR1 | **Read scope, slice 2** | **Matter-scoped metadata only**: a document row is readable iff the reader is an active member of the document's org **AND** assigned (client or attorney) on the document's `matter_id` (matrix §4 line 143/148 — documents are matter content; an org role alone never grants, cross-org denied, `platform_owner_admin` deny always) | Partner/owner "deny unless separately assigned" cells need a defined oversight mechanism (future D-DR, mirror D-MR5); the body row stays deferred (no body column) |
| D-DR2 | **Read mechanism** | **Table + RLS SELECT policy via PostgREST** (`supabase.from('documents').select()`); **no** SECURITY DEFINER RPC. The policy's matter gate is a **plain `exists` subquery on `matters`** — `m.id = documents.matter_id AND m.organization_id = documents.organization_id AND (m.assigned_client_id = auth.uid() OR m.assigned_attorney_id = auth.uid())` — which reuses the applied table, **no new function surface** (the `is_platform_owner`-style exclusion was rejected in the matters review Q4 for exactly this reason). **The `m.organization_id = documents.organization_id` clause is load-bearing**: the org gate must come from the **matter's authoritative org**, not the document's denormalized column, so a document is never readable when its matter is not (matrix §4 line 148 — "restricted matter **or its documents/messages**"; the FK alone cannot enforce org consistency) | Row-scoped reads are RLS's job; the exists reads the matters row's own assignment + org columns, so it yields the matter gate regardless of whether matters RLS re-applies inside the policy (defense-in-depth either way); the battery pins the org-mismatch deny row |
| D-DR3 | **Column shape** | `documents`: `id uuid pk default gen_random_uuid()`, `organization_id uuid not null fk organizations on delete cascade` (denormalized, mirrors matters — the policy's membership check reads it directly), `matter_id uuid not null fk matters on delete cascade` (the assignment source of truth), `title text not null`, `document_type text not null` with a `CHECK` against the client `DocumentType` set (`contract|brief|evidence|correspondence` — the schema-is-the-mapping-contract decision from matters `practice_area`), `created_at timestamptz default now()`, `updated_at timestamptz default now()`. **No body/content/size/url columns** (D-V1). | 1:1 with the client metadata VO; the CHECK makes the enum mapping a schema contract; the cascade ties document lifecycle to its matter |
| D-DR4 | **matterRef resolution** | Rows store `matter_id` (ids only); the gateway resolves the VO's title-keyed `matterRef` via the **embedded `matters(title)` select** (PostgREST embed, RLS-applied — the reader is assigned on the matter by the documents policy, so the embed resolves; the same embed pattern `SupabaseOrgApi.listMyMemberships` already uses). Fallback: the raw matter id (plan §9-style, honest — never a fabricated title) | The VO is title-keyed by design (D-W2); embedding `matters(title)` is one round-trip and RLS-safe; a profiles-style join is not needed (titles live on the applied matters table, readable under the same gate) |
| D-DR5 | **Partner/owner oversight** | **Not in slice 2** — the "deny unless separately assigned" mechanism is undefined; the RLS stays purely assignment-based (mirror D-MR5) | Matrix cells stay ungranted; a future D-DR defines the oversight row (which would then also propagate to matters, via the shared exists gate) |
| D-DR6 | **Policy-test battery** | New `supabase/tests/05_document_rls.sql` + the harness's explicit file list / run loop / UUID scan / FAIL scan gain the new file; **structural pins re-scope**: 7 tables → **8** (adds `documents`), 6 policies → **7** (adds `documents_select_assigned`), plus the documents SELECT grant + anon absence rows | The matters T3 convention (the harness is a fixed list; a new battery is inert until listed) |
| D-DR7 | **Client swap** | `lib/data/documents/supabase_document_api.dart` + `supabase_document_api_impl.dart` + `supabase_document_gateway.dart` implementing `DocumentGateway` behind `env.isConfigured` (service_locator flip, matters pattern); row→VO mapping (type mapping incl. loud drift, matterRef embed + fallback, guarded casts) + typed failure mapping; **VO and presentation untouched** | Env-less runs and ALL tests keep the fake; the real path is inert until a configured build + applied schema exist |
| D-DR8 | **Seeding + residue** | Demo document rows referencing the **applied demo matter ids** (dev project's own ids resolved at apply time) are part of the **apply step** (owner-approved), paired with the rollback (`_down.sql` drop) and cleanup discipline | No seed at commit time; no real client PII anywhere; document titles are generic demo copy (D-V4) |

**Non-decisions (flagged, not guessed):** document **bodies** (no column, no
storage surface — the matrix body row stays deferred; D-V1 holds); partner
/`compliance_officer` oversight rows (D-DR5 follow-up); document
mutation/upload/delete actions (read-only, D-V1 discipline); messages real
path (a **separate** §14 un-deferral with the same discipline); storage /
realtime / e-signature (stays deferred); audit wiring for document reads
(stays §14/P2-gated).

## 4. Layers touched

- **Server (rehearsal → apply, gated):** `supabase/migrations/05_documents.sql`
  (+ `05_documents.down.sql`), `supabase/policies/documents.sql`,
  `supabase/tests/05_document_rls.sql`, `scripts/verify_policy_tests.sh`
  (battery list + structural pins re-scoped 7→8 tables / 6→7 policies).
  The `matters` table is already applied — `05_documents` is additive on
  top of it (FK target), no change to existing migrations/policies/RPCs.
- **Client (env-gated):** `lib/data/documents/supabase_document_api.dart`,
  `supabase_document_api_impl.dart`, `supabase_document_gateway.dart` (new
  data dir, mirrors `lib/data/matters`), `lib/app/service_locator.dart`
  (flip). `lib/features/documents/**` presentation and the `Document` /
  `DocumentGateway` domain types are **untouched**.
- **Docs:** dated matrix §4 addendum (adds the "View a document
  (metadata)" row; keeps the body row deferred), roadmap §14 second
  per-feature flip, README lockstep, completion evidence.

## 5. State shape / data flow

- **State shape unchanged:** `DocumentCubit`/`DocumentState` read
  `DocumentGateway.fetchDocuments()` exactly as today; the fake remains the
  env-less/test implementation.
- **Data flow (configured build):**
  `vault list screen → DocumentCubit → DocumentGateway (Supabase impl) →
  PostgREST from('documents').select('id, title, document_type, created_at,
  matters(title)') (RLS-scoped, D-DR1/D-DR4) → row → Document VO
  (matterRef from the embedded title, fallback id)`. One embed hop, the
  same pattern `SupabaseOrgApi.listMyMemberships` already ships — no new
  surface.

## 6. Dependencies

- **Server:** the **applied `matters` table** (D-DR2's exists subquery +
  D-DR3's FK) — the documents slice is additive on the matters slice, no
  new primitives beyond stock Postgres/PostgREST.
- **Client:** none new — `supabase_flutter` is already the only backend
  SDK, confined to `lib/data/`; the gateway uses the existing client.
- **Infra (rehearsal/apply):** Postgres to run the battery — the
  **established host is the owner's Docker machine** (matters r1 Path A
  precedent: `supabase start` + `SUPABASE_TEST_DB_URL=…`), so the
  rehearsal is owner-side but no longer an unknown.

## 7. Testing strategy

- **SQL battery** (`05_document_rls.sql`, via `verify_policy_tests.sh`):
  assigned-client sees the documents of its matters; assigned-attorney
  sees theirs; row-count pins (client 2 / attorney 3 / orphan 1 — same
  count shape as the matters battery, proving no blanket-org bleed);
  org-role-alone denied; cross-org denied (partner-b on an org-a matter's
  documents); suspended denied; `platform_owner_admin` denied always;
  unauthenticated denied; `document_type` CHECK rejects an unmapped value;
  **org-mismatch deny row** (a document whose `organization_id` ≠ its
  matter's org denies for every role — the D-DR2 invariant);
  matter-delete cascade removes its documents.
- **Dart unit:** `SupabaseDocumentGateway` row→VO mapping (type mapping
  incl. unknown-value loud failure), matterRef embed resolution + id
  fallback, failure mapping (provider error → typed `AppError`,
  redaction-safe — no row content in errors), malformed-row guards (no raw
  `TypeError`s across the boundary — the matters T7 review fix as
  baseline).
- **DI pins:** `service_locator_test` — env-less → `FakeDocumentGateway`,
  configured → `SupabaseDocumentGateway`.
- **Widget/cubit:** unchanged (fake stays); the existing vault suite is the
  regression net proving the swap is seam-compatible.
- **Not claimed:** no live dev-project read until the apply step; the
  battery + rehearsal evidence are the standing server claims.

## 8. Acceptance criteria

- [ ] A document (metadata) is readable iff the reader is an active member
      of its org **and** assigned (client or attorney) on its matter (RLS
      + battery, matrix §4 line 143/148).
- [ ] Org-role-alone, cross-org, unassigned, unauthenticated, and
      `platform_owner_admin` reads are denied (battery, 03-style deny rows;
      the owner row holds as the operational invariant — never assigned).
- [ ] Battery green via `verify_policy_tests.sh`; rehearsal r-series passed
      with evidence before any apply (owner's Docker host, matters r1
      precedent).
- [ ] Apply executed only under the owner's dated apply-approval, with
      `_down.sql` rollback pairing and demo-row cleanup discipline (demo
      document ids reference the **applied** demo matter ids, resolved at
      apply time).
- [ ] Client swap is env-gated; env-less runs and the full Flutter suite
      are unchanged (fake); `Document` VO and presentation untouched.
- [ ] Dated matrix addendum (§7) precedes the client surface shipping;
      roadmap §14 gains the second per-feature flip; README count in
      lockstep; ledger PASS.
- [ ] Full gate on every client slice: format clean · analyze clean ·
      suite green · ledger PASS — nothing pushed.

## 9. Risks / open questions

- **Policy/matters coupling (D-DR2):** the documents policy's exists
  subquery inherits any future change to `matters` (e.g. a partner
  oversight row would also open documents on those matters). Recorded as
  **intended** — documents should track matter access — and pinned by the
  battery (deny rows assert the current posture).
- **Org-mismatch invariant (D-DR2 review hardening):** the document's
  denormalized `organization_id` is never authoritative — the exists
  matches the matter's own org, so a document is readable only when its
  matter is. The org-mismatch deny row pins it; the future write slice
  must keep the column consistent (defense-in-depth, never trust the
  writer).
- **Embed reliability (D-DR4):** the embedded `matters(title)` resolves
  because the documents policy guarantees the matter gate; a null embed
  falls back to the raw matter id (flagged in the client tests; never a
  fabricated title). A client who can see a document but not its title
  would show the id — honest, and impossible under the current policy
  (same gate).
- **Infra:** rehearsal/apply are owner-side (matters r1 Path A precedent) —
  no psql/Docker on this machine; the first battery execution is T3/T4 on
  the owner's host or CI.
- **Scope:** slice 2 swaps only the document-metadata read path; bodies,
  storage, realtime, and the messages real path each stay deferred.
- **No email, no rate-limit exposure** in this slice (no GoTrue trigger).

---

# Tasks: Real Documents (Read) Data Path

Branch: `feat/documents-real-read`

Each task is independently committable with the stated verification; the
apply gate (T5) is the only owner-gated step. T2–T4 are server artifacts —
**no dev-project change until T5**.

- [ ] **1. Scope note + RLS-gate design addendum** — touches: this document
  + a `documents` §8-style review (`docs/documents_rls_gate_review_2026-08-07.md`,
  the Q1–Q6 pattern answered for documents: matter-scoped assignment
  model, the exists-subquery policy, negative cases, rollback pairing,
  seed plan) — done when: docs committed, ledger sweep green (no
  dev-project contact).
- [ ] **2. Schema artifacts (rehearsal-ready, NOT applied)** — touches:
  `supabase/migrations/05_documents.sql` (+ `05_documents.down.sql`),
  `supabase/policies/documents.sql` — done when: DDL matches
  D-DR1/D-DR3 (matter FK + org column + `document_type` CHECK, metadata
  only), `_down.sql` is a clean inverse, committed.
- [ ] **3. Policy battery** — touches: `supabase/tests/05_document_rls.sql`
  (new document fixture rows referencing the six fixture matters go in
  `supabase/tests/00_fixtures.sql`, the matters precedent) +
  `scripts/verify_policy_tests.sh` — **four sites**: battery file list,
  run loop, UUID cross-ref scan, FAIL-marker scan — **plus the `--apply`
  order gains `05_documents.sql`** (pre-empting the matters T3 blocking
  finding: a harness-built project must apply 05 before the structural
  pins run) and the structural pins re-scope (7→8 tables / 6→7 policies +
  documents grant/anon rows) — done when: battery runs green against a
  Postgres (owner's Docker host or CI) with the §4 deny rows incl. the
  org-mismatch row; committed.
- [ ] **4. Ephemeral rehearsal (r-series)** — touches: evidence record
  `docs/documents_rehearsal_evidence_r1_<date>.md` — done when: the loop
  (migrate → policy → battery → read-as-roles) passes on throwaway infra
  with zero dev-project contact; **owner-side / CI runner** (matters r1
  Path A precedent).
- [ ] **5. Dated apply-approval → apply** — touches: dev project
  (migrations + policies + demo seed), `docs/documents_apply_approval_<date>.md`
  + `docs/documents_apply_execution_<date>.md` — done when: the owner's
  dated approval exists, apply executed with `_down.sql` pairing + cleanup
  discipline (demo ids reference the applied demo matter ids), observed
  output recorded verbatim.
- [ ] **6. Matrix addendum (dated)** — touches: `docs/permission_matrix.md`
  §4 — adds the **"View a document (metadata)"** row (client/attorney
  cells SHIP behind `documents_select_assigned`; partner/
  `compliance_officer` "deny unless separately assigned" cells stay
  ungranted; `platform_owner_admin` deny always) and records the **body
  row keeps its §14 deferral** (no body column, D-V1) — done when:
  addendum committed **before** the client surface ships, ledger sweep
  green.
- [ ] **7. Client swap (env-gated)** — touches:
  `lib/data/documents/supabase_document_api.dart` +
  `supabase_document_api_impl.dart` + `supabase_document_gateway.dart`,
  `lib/app/service_locator.dart`, tests (mapping, matterRef embed +
  fallback, failure mapping, DI pins) — done when: format clean · analyze
  clean · suite green (fake unchanged) · ledger PASS; VO/presentation
  untouched.
- [ ] **8. Lockstep + evidence + close** — touches: README test count,
  roadmap §14 second per-feature flip + gate-table row, completion
  evidence `docs/documents_real_data_completion_evidence_<date>.md`,
  dated close decision — done when: all docs sweep green, full gate re-run
  on the committed state, close decision recorded.
