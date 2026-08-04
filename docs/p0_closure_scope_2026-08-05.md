# LegalHub — P0-Closure Scope Note (2026-08-05)

> **Record type:** Spec-lite scope note required by the P0-closure gate
> (`docs/features_roadmap_2026-08-03.md` §14 — "P0 closes (D-02…D-10b) +
> policy tests + matrix extension"): gap analysis → decision record →
> assumptions & non-goals → slices behind the full P2 discipline (spec →
> RLS-gate review → rehearsal evidence → dated apply approval → apply with
> rollback pairing) → acceptance criteria → risks → roadmap & ledger hooks.
> **Status: DRAFT (2026-08-05) — prepared for owner ratification of
> D-P0C1…D-P0C5. Nothing here is authorized to build or apply until the
> owner ratifies the decision record and approves the slices per
> `INSTRUCTIONS.md` §2/§3.**
> **Planning owner:** `docs/features_roadmap_2026-08-03.md` §14.

---

## 0. Audit context (why this phase exists)

`docs/features_roadmap_2026-08-03.md` §14 defers every real-data capability
(matters, documents, messages, storage, realtime, audit surfacing, billing,
AI) behind **"P0 closes (D-02…D-10b) + policy tests + matrix extension"**.
All ten blockers (D-02…D-10b) are already **Decided (2026-07-31)** and
P1/P2/P3 approvals are recorded in `docs/p0_decision_capture.md` §1/§3 — so
"closing P0" no longer means deciding policy; it means completing the
**enforcement + testing close-out** that the matrix and the Addendum
already promised but never shipped as durable, re-runnable artifacts:

- `docs/permission_matrix.md` §5: *"No owner admin screen ships until the
  Addendum's server-side enforcement + auditing story is complete"* and the
  §5 negative test *"must exist before P2 ships"*.
- Matrix §4 negative block: the `platform_owner_admin` content-deny row —
  *"the row that most directly guards against admin-capability creep"*.
- Matrix §2/§3 negative-test blocks (contract §9: every row ≥1 positive +
  ≥1 negative test).
- `docs/p0_decision_capture.md` Addendum: enforcement location is
  **server-side (RLS/RPC)**, never a client-side flag.

The buildable gap, verified against the repo: the server-side surface
exists (`is_platform_owner()` + the five owner RPCs + `write_audit`, all
applied 2026-08-01), but there is **no committed policy-test battery** and
**no standing harness** — the P2 r1–r5 rehearsals proved specific
migrations on ephemeral projects, not a durable negative-test contract.

## 1. Provenance

- Matrix §4 (§14 gate): *"`platform_owner_admin` attempting to read any
  matter/document/message content must be denied at the RLS layer, not just
  hidden in the UI — this is the row that most directly guards against
  admin-capability creep."*
- Matrix §5: *"Negative test required: an authenticated session bearing the
  `platform_owner_admin` capability but attempting to read a
  document/message row must be denied by policy, identically to any other
  unauthorized role — …must exist before P2 ships."* And: *"No owner admin
  screen ships until the Addendum's server-side enforcement + auditing
  story is complete."*
- `docs/p0_decision_capture.md` Addendum (2026-07-31): permitted/forbidden
  lists for `platform_owner_admin`; enforcement server-side; the admin
  screen is buildable only after the enforcement story is complete.
- `docs/features_roadmap_2026-08-03.md` §14: P0 closure = decisions +
  policy tests + matrix extension, before any §14 capability ships.
- `docs/p2_schema_rls_design.md` §5.1/§5.2/§5.3: `is_platform_owner()`,
  `write_audit`, the owner RPC set, and the audit RPC-only rule — the
  applied baseline this phase's battery proves.
- `docs/adr/0007`: the P0 gate mechanics (decisions → readiness → approval
  → slice).

## 2. Decision record (drafted for owner ratification)

| # | Decision | Status |
|---|---|---|
| D-P0C1 | **Deny-row shape.** No matter/document/message tables exist, so the §4/§5 content-deny rows are satisfied in two parts: (a) a **negative battery over every existing grant/RPC path** proving the owner cannot exceed identity/membership metadata through any reachable surface, and (b) a **forward design pin** — every future content table ships with an explicit `platform_owner_admin → deny` RLS row and its own negative test, enforced at schema-review time (recorded in this note and the matrix addendum) | drafted 2026-08-05 |
| D-P0C2 | **Policy-test harness.** A committed `supabase/tests/` battery + `scripts/verify_policy_tests.sh` (bash + psql, the `scripts/verify_ledger.sh` pattern), runnable against an **ephemeral rehearsal project** (the P2 pattern) built from the same migration/RPC/policy files — durable teeth for the per-row positive/negative contract | drafted 2026-08-05 |
| D-P0C3 | **Single-account bound.** The battery includes a negative test that a second `platform_config` owner row cannot be created through any reachable path (the capability stays bound to exactly one account per the Addendum); if the battery finds a widening path, that is a P0C.2 server amendment | drafted 2026-08-05 |
| D-P0C4 | **Audit surfacing stays RPC-only.** `read_org_audit`/`read_platform_audit` self-audit their reads; no raw `SELECT` on `audit_events` is ever granted; the battery pins the absence | drafted 2026-08-05 |
| D-P0C5 | **The owner admin UI is NOT part of P0 closure.** It is the first §14 capability that closure unblocks (Addendum condition), gated behind its own scope note after this phase closes — no client change ships here | drafted 2026-08-05 |

## 3. Assumptions & non-goals

- The migration set is stable: `supabase/migrations/01–03` + `policies/` +
  `rpc/` as committed constitute the baseline the battery tests; no schema
  change is assumed until the battery proves one is needed.
- An ephemeral rehearsal project is available for the battery (the P2 r1–r5
  pattern); the harness never runs against the live dev project.
- Non-goals: **no matter/document/message tables** (still §14-deferred),
  **no owner admin screen** (D-P0C5), **no client changes**, **no matrix
  widening** (the addendum records a test contract, not new permissions),
  no RLS relaxation, no new production grants, no changes to the shipped
  P2 RPCs unless the battery proves a defect (then P0C.2, full discipline).

## 4. Scope

| # | Slice | Scope | New files (sketch) | Tests |
|---|---|---|---|---|
| P0C.0 | Scope note + matrix addendum | This note ratified; dated matrix §5/§7 addendum recording the deny-row/negative-test contract and the content-table forward pin (D-P0C1) | `docs/p0_closure_scope_2026-08-05.md`, `docs/permission_matrix.md` §5 addendum | doc review (addendum dates + no permission widening) |
| P0C.1 | Harness + battery | `supabase/tests/` SQL battery covering matrix §2/§3/§5 rows (positive+negative), both owner deny-rows (D-P0C1), the single-account bound (D-P0C3), and the audit RPC-only pin (D-P0C4); `scripts/verify_policy_tests.sh` runner; `supabase/README.md` update | `supabase/tests/` (per-row SQL files), `scripts/verify_policy_tests.sh` | battery green on an ephemeral project (rehearsal evidence) |
| P0C.2 | Server amendments (conditional) | Only if the battery finds a defect (e.g., a second-owner insert path, a grant widening): fix via the full P2 discipline — design → RLS-gate review → rehearsal → dated apply approval → apply with rollback pairing | per-finding | same battery re-green + rehearsal evidence |
| P0C.3 | P0-close record | Dated owner close decision + roadmap §14 status update; the §14 list becomes buildable per-feature behind new scope notes (owner admin screen first, per D-P0C5) | `docs/p0_close_decision_2026-08-05.md`, `docs/features_roadmap_2026-08-03.md` §14 | ledger PASS; matrix addendum dated |

## 5. Acceptance criteria (each mapped to a named test)

| # | Criterion | Verified by |
|---|---|---|
| AC-1 | The harness script exists and runs a battery **green** against an ephemeral rehearsal project; every matrix §2/§3/§5 row has ≥1 positive + ≥1 negative test | `scripts/verify_policy_tests.sh` output + rehearsal evidence (P0C.1) |
| AC-2 | Owner deny-rows pinned: (a) the battery proves the owner cannot read any non-identity/membership surface through any existing grant or RPC path; (b) the content-table forward pin (D-P0C1) is referenced by the matrix addendum and enforced at schema review | battery rows + matrix §5 addendum (AC-2a/2b) |
| AC-3 | Single-account bound proven: no reachable path creates a second `platform_config` owner row (D-P0C3) | battery negative row |
| AC-4 | Audit surfacing stays RPC-only: no raw audit-table grant exists and owner reads self-audit (D-P0C4) | battery negative row + grant inspection |
| AC-5 | Dated matrix addendum + P0-close decision record signed; roadmap §14 updated to CLOSED | doc records (P0C.3) |

## 6. Risks

- **R1 — no content tables today:** the §4/§5 content-deny "deny at the RLS
  layer" test cannot execute against tables that do not exist. Mitigation:
  the two-part D-P0C1 (battery on the existing surface + forward pin),
  recorded, not silently skipped.
- **R2 — harness fidelity:** an ephemeral-project battery can drift from
  the live dev project. Mitigation: the harness pins the committed
  migration/RPC/policy files it builds from; rehearsal evidence records the
  exact refs.
- **R3 — owner-account bound:** `platform_config` is seeded
  (`03_platform_config_seed.sql`); if the battery finds a second-owner
  insert path, P0C.2 is triggered (server amendment, full discipline).
- **R4 — scope creep toward the admin screen:** D-P0C5 is an explicit
  non-goal; the screen is the first post-closure feature, not part of this
  phase.
- **R5 — matrix drift:** this addendum records a test contract and a
  forward boundary — it widens no permission. The §7 dated-addendum
  discipline is followed; any future widening requires its own addendum.

## 7. Roadmap & ledger hooks

- `docs/features_roadmap_2026-08-03.md` §14 → on close: "P0 CLOSED
  (2026-08-XX) — enforcement + policy-test battery green (record
  `docs/p0_close_decision_2026-08-05.md`); §14 capabilities become buildable
  per-feature behind new scope notes (owner admin surface first, D-P0C5)."
- `docs/p0_decision_capture.md` §3 → P4 row (security review + controlled
  rollout) becomes the next phase after closure; this note is its
  prerequisite record.
- `docs/permission_matrix.md` → §5 addendum (2026-08-05) as drafted in §4
  P0C.0.
- Ledger: **no Flutter test-count change** (the battery is SQL, not
  `test/`), README untouched, `verify_ledger.sh` stays PASS 115.

## 8. Exit

Scope note approved → matrix addendum dated → harness + battery green on
the ephemeral rehearsal project (evidence record) → P0C.2 only if the
battery finds a defect (full P2 discipline) → dated P0-close decision →
roadmap §14 updated. **No commit, push, or apply without the owner's dated
approval at each gate** (INSTRUCTIONS.md §2/§3).
