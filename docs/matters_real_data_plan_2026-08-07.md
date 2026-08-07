# Plan: Real Matters (Read) Data Path — the first §14 un-deferral (2026-08-07)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> first slice under the roadmap §14 blanket-deferral, per the reconciliation
> of 2026-08-07 (single consolidated `main` @ `8c3125b`, suite 857, README
> 854, ledger PASS 171). **Docs-only planning — zero dev-project effect**:
> nothing in this document or its TASKS applies anything to the dev Supabase
> project; every external step stays behind the owner's dated approval
> (INSTRUCTIONS.md §2.1/§5 hard gates).
>
> **Gate state (why this slice is now plannable):** the §14 precondition
> "P0 closes (D-02…D-10b) + policy tests exist" is **met at the decision
> level** — `docs/p0_closure_scope_2026-08-05.md` is RATIFIED (D-P0C1…D-P0C5)
> and the policy battery ships (`scripts/verify_policy_tests.sh` + `docs/p0c1_verification_evidence_2026-08-05.md`).
> What remains is the per-feature P3 discipline, all executed below in
> order: RLS-gate design → policy battery → rehearsal → **dated apply
> approval** → apply with rollback → dated matrix addendum → client swap.

---

## 1. Goal

Move the **matter list/details read path** from the synthetic fake to a
real, org- and assignment-scoped `matters` table read through PostgREST
with RLS — **without changing the client `Matter` VO or any presentation
code** (the swap is seam-compatible and env-gated, mirroring the org/auth
flips). "Done" = an active member reads exactly the matters they are
assigned to (client or attorney); every other read — org-role-alone,
cross-org, unauthenticated, `platform_owner_admin` — is denied and
policy-tested; the env-less demo and the whole test suite still run on the
fake.

## 2. Gap (verified)

- `MatterGateway` (Phase 7 slice 7.1, `5740594`) is fake-only:
  `FakeMatterGateway.syntheticMatters` serves five static non-PII rows; the
  real data path stays §14-deferred (roadmap §14, matrix §4/§6) — and the
  reconciliation confirmed the §14 decision-level gate has now lifted (§0).
- The **permission matrix §4 is the governing contract for the read scope**
  and is stricter than org-scoping:
  - "View a matter" → client ✅ **if assigned as the client on it**; attorney
    ✅ **if assigned to it**; partner ✅ "org policy-approved oversight only,
    not blanket"; owner ✅ "policy-review scope only"; `platform_owner_admin`
    ❌ **deny, always**.
  - "An org role alone (no matter assignment)" → ❌ **deny for every role**.
  - Cross-org access denied; `platform_owner_admin` never reads matter content.
- Client `Matter` VO (D-M4): `id`, `title`, `practiceArea` (enum),
  `status` (open/active/closed), `assignedAttorneyName` (display name),
  `createdAt`. No client names, no real-looking case numbers.
- The `profiles` table is **own-row-only** (D-T6) — a plain PostgREST select
  cannot join display names; the shipped roster RPC
  (`list_org_members_metadata`, Phase 3 R1) returns them under the in-body
  guard and is the established name-resolution seam (P3.3 roster).

## 3. Design decisions (D-MR1…D-MR8 — ratified by autonomy this session)

| # | Decision | Recommendation | Why / alternative |
|---|---|---|---|
| D-MR1 | **Read scope, slice 1** | **Assignment-scoped only**: a row is readable iff `assigned_client_id = auth.uid() OR assigned_attorney_id = auth.uid()` **AND** the reader is an active member of the matter's `organization_id` (defense-in-depth; satisfies "org role alone never grants" + "cross-org denied") | Partner/owner "oversight/policy-review" rows need a defined oversight mechanism (future D-MR); `platform_owner_admin` stays ❌ always (matrix §4, D-P0C1(a) deny-row) |
| D-MR2 | **Read mechanism** | **Table + RLS SELECT policy via PostgREST** (`supabase.from('matters').select()`); **no** SECURITY DEFINER RPC | Row-scoped reads are exactly RLS's job; an RPC adds moving parts for no benefit here (the org RPCs exist for cross-table/definer needs) |
| D-MR3 | **Column shape** | `matters`: `id uuid pk default gen_random_uuid()`, `organization_id uuid not null fk organizations`, `title text not null`, `practice_area text not null` (enum-name string), `status text not null check (status in ('open','active','closed'))`, `assigned_client_id uuid fk profiles`, `assigned_attorney_id uuid fk profiles`, `created_at timestamptz default now()`, `updated_at timestamptz` | 1:1 with the client VO; status/practice-area strings map to the client enums |
| D-MR4 | **Display-name resolution** | The gateway stores **ids**; the client resolves `assignedAttorneyName` via the shipped roster RPC (`OrganizationGateway` → `listOrgMembers` display names), the P3.3 seam | A profiles join is blocked by own-row RLS (D-T6); the roster RPC already returns display names under the in-body guard |
| D-MR5 | **Partner/owner oversight** | **Not in slice 1** — the "policy-approved oversight" / "policy-review scope" mechanism is undefined; leaving it out keeps the RLS purely assignment-based and defensible | Matrix rows stay "policy-review scope only" (not granted); a future D-MR defines the oversight row |
| D-MR6 | **Policy-test battery** | New `supabase/tests/04_matter_rls.sql` + the harness's **explicit file list** in `scripts/verify_policy_tests.sh` (lines ~73–76) gains the new file; battery follows the 03 deny-row style (D-P0C1(a)) | The harness is a fixed list — a new battery file is inert until listed; the static fixture cross-ref check (line ~97) also covers it |
| D-MR7 | **Client swap** | `lib/data/matters/supabase_matter_gateway.dart` implementing `MatterGateway` behind `env.isConfigured` (service_locator flip, org-pattern lines ~185–198); row→VO mapping + typed failure mapping; **VO and presentation untouched** | Env-less runs and ALL tests keep the fake; the real path is inert until a configured build + applied schema exist |
| D-MR8 | **Seeding + residue** | Demo matter rows referencing the dev demo-account profile ids are part of the **apply step** (owner-approved), paired with the rollback (`_down.sql` drop) and cleanup discipline | No seed at commit time (commit = rehearsal-ready artifacts only); no real client PII anywhere |

**Non-decisions (flagged, not guessed):** partner/owner oversight mechanism
(D-MR5 follow-up); matter mutation/write actions (out of scope — read-only,
D-M1 discipline); documents/messages real paths (each is a **separate** §14
un-deferral with the same discipline); audit wiring for matter reads (the
`read_org_audit`/`read_platform_audit` RPCs already exist; surfacing stays
§14/P2-gated).

## 4. Layers touched

- **Server (rehearsal → apply, gated):** `supabase/migrations/04_matters.sql`
  (+ `04_matters.down.sql`), `supabase/policies/matters.sql`,
  `supabase/tests/04_matter_rls.sql`, `scripts/verify_policy_tests.sh`
  (battery list). No change to existing migrations/policies/RPCs.
- **Client (env-gated):** `lib/data/matters/supabase_matter_gateway.dart`
  (new data dir, mirrors `lib/data/orgs`), `lib/app/service_locator.dart`
  (flip), the row→VO mapping (may live in the gateway or a small
  `matter_row_mapper.dart`). `lib/features/matters/**` presentation and the
  `Matter`/`MatterGateway` domain types are **untouched**.
- **Docs:** dated matrix addendum (§7 discipline), roadmap §14 per-feature
  flip, README lockstep, completion evidence.

## 5. State shape / data flow

- **State shape unchanged:** `MatterCubit`/`MatterState` read
  `MatterGateway.fetchMatters()` exactly as today; the fake remains the
  env-less/test implementation.
- **Data flow (configured build):**
  `matter list screen → MatterCubit → MatterGateway (Supabase impl) →
  PostgREST from('matters').select() (RLS-scoped, D-MR1) → row → Matter VO;
  name hop: gateway → OrganizationGateway.listMembers (roster RPC, D-MR4)
  → display-name map → assignedAttorneyName`.
  One break from the pure hop chain, by design: the display-name resolution
  is a second seam call (roster RPC) — the same hop the P3.3 roster already
  makes, so it is not new surface.

## 6. Dependencies

- **Server:** none new — stock Postgres/PostgREST/Supabase primitives
  (`gen_random_uuid`, RLS policies, `auth.uid()`).
- **Client:** none new — `supabase_flutter` is already the only backend SDK,
  confined to `lib/data/`; the gateway uses the existing client + the
  existing org roster RPC seam.
- **Infra (rehearsal/apply):** Postgres to run the battery + a
  Docker-capable environment for the ephemeral rehearsal — **infra-blocked
  on this machine today** (same constraint recorded in D-45.1 Phase 1 and
  `docs/p0c1_verification_evidence_2026-08-05.md` §3); rehearsal may run on
  a CI runner or the owner's machine.

## 7. Testing strategy

- **SQL battery** (`04_matter_rls.sql`, run via `verify_policy_tests.sh`):
  assigned-client sees the matter; assigned-attorney sees it;
  org-member-unassigned denied; org-role-alone denied; cross-org denied;
  `platform_owner_admin` denied always (deny-row extension);
  unauthenticated denied; row-count pin (client sees exactly their assigned
  set); fixture UUIDs resolve in `00_fixtures.sql`.
- **Dart unit:** `SupabaseMatterGateway` row→VO mapping (status/practice-area
  enum mapping incl. unknown-value handling), failure mapping (provider
  error → typed `AppError`, redaction-safe context — no row content in
  errors), roster-RPC name resolution + fallback.
- **DI pins:** `service_locator_test` — env-less → `FakeMatterGateway`,
  configured → `SupabaseMatterGateway`.
- **Widget/cubit:** unchanged (fake stays); existing matter suite is the
  regression net proving the swap is seam-compatible.
- **Not claimed:** no live dev-project read until the apply step; the
  battery + rehearsal evidence are the standing server claims (P2/P3
  "never claim until verified" discipline).

## 8. Acceptance criteria

- [x] A matter is readable iff the reader is its assigned client **or**
      assigned attorney **and** an active member of its org (RLS + battery).
      — battery `04_matter_rls.sql` checks 04.01–04.03 (assigned
      positives); r1 PASSED.
- [x] Org-role-alone, cross-org, unauthenticated, and
      `platform_owner_admin` reads are denied (battery, 03-style deny rows).
      — checks 04.04–04.08 (negatives) + the owner residual recorded.
- [x] Battery green via `verify_policy_tests.sh`; rehearsal r-series passed
      with evidence before any apply. — r1 PASSED (Path A, owner's host).
- [x] Apply executed only under the owner's dated apply-approval, with
      `_down.sql` rollback pairing and demo-row cleanup discipline. — §6
      signed; execution evidence `matters_apply_execution` records the run.
- [x] Client swap is env-gated; env-less runs and the full Flutter suite
      are unchanged (fake); `Matter` VO and presentation untouched. — DI
      flip pinned in `service_locator_test`; suite green on the fake.
- [x] Dated matrix addendum (§7) precedes the client surface shipping;
      roadmap §14 row flips to per-feature; README count in lockstep;
      ledger PASS. — matrix addendum `3dbf623`; this commit flips §14.
- [x] Full gate on every client slice: format clean · analyze clean ·
      suite green · ledger PASS — nothing pushed. — re-run at T8 (evidence
      §2.1); nothing pushed.

## 9. Risks / open questions

- **Infra-blocked rehearsal/apply** (no Docker/psql on this machine) —
  Phase 1 rehearsal is owner-side/CI-runner, D-45.1-style; Option C-style
  fallback (recorded residual) only if the window is long.
- **Partner/owner oversight rows** are deliberately not granted (D-MR5) —
  an open design question for the next matter slice (what "org
  policy-approved oversight" means mechanically).
- **Name-resolution fallback:** if the roster RPC is unavailable in a given
  configured build, `assignedAttorneyName` falls back to the id — flag in
  the client tests; never leaks profiles beyond the existing seam.
- **Scope:** slice 1 swaps only the matter read path; the workspace
  sections, unified search, and document/message surfaces keep reading the
  fakes (each real path is its own un-deferral).
- **No email, no rate-limit exposure** in this slice (no GoTrue trigger).

---

# Tasks: Real Matters (Read) Data Path

Branch: `feat/matters-real-read`

Each task is independently committable with the stated verification; the
apply gate (T5) is the only owner-gated step. T2–T4 are server artifacts —
**no dev-project change until T5**.

- [ ] **1. Scope note + RLS-gate design addendum** — touches: this document
  + a `matters` §8-style review (the `p2_schema_rls_design.md` Q1–Q6
  pattern answered for matters: assignment model, policy shape, negative
  cases, rollback pairing, seed plan) — done when: docs committed, ledger
  sweep green (no dev-project contact).
- [ ] **2. Schema artifacts (rehearsal-ready, NOT applied)** —
  touches: `supabase/migrations/04_matters.sql` (+ `04_matters.down.sql`),
  `supabase/policies/matters.sql` — done when: DDL matches D-MR1/D-MR3,
  `_down.sql` is a clean inverse, committed.
- [ ] **3. Policy battery** — touches: `supabase/tests/04_matter_rls.sql`
  + `scripts/verify_policy_tests.sh` (battery list + fixture cross-ref) —
  done when: battery runs green against a Postgres (local or CI) with the
  deny rows of §8; committed.
- [ ] **4. Ephemeral rehearsal (r-series)** — touches: evidence record
  `docs/matters_rehearsal_evidence_r1_<date>.md` — done when: the loop
  (migrate → policy → battery → read-as-roles) passes on throwaway infra
  with zero dev-project contact; **infra-blocked on this machine — owner
  side / CI runner** (D-45.1 Phase 1 constraint).
- [ ] **5. Dated apply-approval → apply** — touches: dev project
  (migrations + policies + demo seed), `docs/matters_apply_approval_<date>.md`
  + `docs/matters_apply_execution_<date>.md` — done when: the owner's
  dated approval exists, apply executed with `_down.sql` pairing + cleanup
  discipline, observed output recorded verbatim (P2/P3 pattern).
- [ ] **6. Matrix addendum (dated)** — touches: `docs/permission_matrix.md`
  §4/§6 rows for the matter read (assigned-only grant; deny rows) per §7
  discipline — done when: addendum committed **before** the client surface
  ships, ledger sweep green.
- [x] **7. Client swap (env-gated)** — touches:
  `lib/data/matters/supabase_matter_gateway.dart` (+ mapper), `lib/app/service_locator.dart`,
  tests (mapping, failure mapping, name resolution, DI pins) — done when:
  format clean · analyze clean · suite green (fake unchanged) · ledger
  PASS; VO/presentation untouched. **SHIPPED 2026-08-07** (`37cc68b` +
  `41577a0`): seam + impl + gateway + DI flip, 19 new tests (suite
  857→877), README lockstep, ledger PASS 115.
- [x] **8. Lockstep + evidence + close** — touches: README test count,
  roadmap §14 per-feature flip + gate-table row, completion evidence
  `docs/matters_real_data_completion_evidence_2026-08-07.md`, dated close
  decision — done when: all docs sweep green, full gate re-run on the
  committed state, close decision recorded. **DONE 2026-08-07** — this
  commit; close decision recorded in the evidence §9.
