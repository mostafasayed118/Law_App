# Kickoff prompt — paste this as your first message to Claude Code

I'm resuming work on **LegalHub**, a Flutter portfolio project (multi-tenant
auth/tenant-authorization architecture, built to demonstrate production-grade
engineering practice — clean architecture, BLoC, provider-neutral auth
seams, RLS-based multi-tenancy). It is governed by a strict process; read
before touching anything.

## 1. Read these first, in this order

1. `INSTRUCTIONS.md` (repo root) — process rules: gates, delivery-slice
   discipline (`Understanding → Discovery → Recommendation → Slice → Gate →
   Implementation → Verification → Learning walkthrough`), and the standing
   rule that **no commit, push, deploy, migration, or RLS-policy change
   happens without my explicit approval, per step, every time** — a past
   approval is not standing authorization for a new step.
2. `docs/codebase_audit_plan.md` — the canonical execution plan and batch
   numbering. This is the source of truth for "what batch am I on."
3. `docs/auth_tenant_authorization_contract.md` — the non-negotiable
   security contract (default-deny, server authority, tenant isolation,
   no role-only matter access, no client secrets, explicit denial, human
   accountability).
4. `docs/gate3_decision.md` + `docs/gate3_reconciliation.md` — what design
   scope is actually approved and what's excluded (no Supabase package, no
   real screens beyond the reclassified bootstrap scaffold, no schema, no
   RLS — until P1/P2 gates open).
5. `docs/p0_decision_capture.md` — **updated and closed (2026-07-31).** All
   ten P0 blockers are decided (§1), the §2 Definition-of-Ready checklist is
   fully satisfied (Supabase dev project provisioned in `eu-central-1`,
   `.env` confirmed git-ignored, rollback plan written), and **§3 records
   explicit P1 approval** (Project Owner, 2026-07-31). Batch 3 / P1 is
   unblocked.
6. `docs/rollback_plan.md` — **new (2026-07-31).** Read this before writing
   any migration or policy — it defines the down-script/revert convention
   you must follow for anything in P2, and the "stop and roll back, don't
   fix forward" trigger conditions that also apply to P1 config mistakes.
7. `docs/permission_matrix.md` — **new (2026-07-31).** The signed
   positive/negative permission matrix required by contract §9 and by the
   P1 readiness checklist. Includes a new `platform_owner_admin` capability
   — read its boundary section (§5) carefully; it is intentionally the most
   restricted row in the matrix (identity/membership metadata only, **never**
   matter/document/message content, always audited).
8. `docs/tracked_deviations.md` — known, deferred issues (D-T1 onboarding
   overflow, D-T3 hardcoded fallback name). Not architecture decisions.

## 2. What to actually do, in order

**All three are unblocked now — but they still each go through the full
delivery-slice process** (`Understanding → Discovery → Recommendation →
Slice → Gate → Implementation → Verification → Learning walkthrough`, per
`INSTRUCTIONS.md` §2.1). Being "approved to start" is not the same as being
pre-approved for every commit inside the slice.

- **Batch 1 (test floor)** — `codebase_audit_plan.md` items 1.1–1.10.
  Backend-free, can run in parallel with the rest. Run `flutter test`,
  `flutter analyze`, and
  `bash scripts/verify_format.sh` (the whole-repo format gate — mirrors
  `ci.yml`'s exact `dart format .` command, so a `lib test`-scoped check
  can't drift from the CI formatter) after each item and report the actual
  output — don't summarize as "passing" without showing the command result.
- **Batch 4 (docs hygiene)** — items 4.1–4.8. Straightforward doc/README
  reconciliation against the real test count and real code state.
- **Batch 3 / P1 (Supabase adapter, real session model)** — now approved
  (`p0_decision_capture.md` §3). Start with the **Understanding/Discovery**
  step before writing code: confirm the `supabase_flutter` package version,
  confirm the dev project has zero existing tables/policies (it's fresh),
  and restate the P1 exit criterion out loud — *"Flutter presentation
  cannot grant a role or bypass a denied result"* — before touching
  `lib/data/auth/*`. Only the files/behavior in `gate3_decision.md` §3.1–3.2
  as amended by `gate3_reconciliation.md` §3–§4 are in scope; do not add
  Supabase calls anywhere outside the adapter layer.
  - Scaffold the **domain contract** for the `platform_owner_admin`
    capability behind the same `AuthGateway`-style seam as part of this
    slice (it's just typed contracts + a fake, same pattern as existing
    code) — but do **not** build the admin screen or wire a real RLS policy
    for it yet. The screen is P3 work; the RLS policy is P2 work. Building
    either now would race ahead of the gates that are specifically there to
    keep a powerful, single-account capability reviewable.

**Still not authorized:** P2 (schema + RLS), P3 (real screens against a real
provider), P4 (release). Each needs its own separate approval recorded in
`p0_decision_capture.md` §3 when you get there — don't self-approve by
inferring it from P1 going smoothly.

## 3. Standing rules while you work

- Every batch is its own delivery slice — don't silently fold Batch 1 work
  into Batch 4 or vice versa; keep commits/PRs scoped to one batch.
- No `git add`/`commit`/`push` without me explicitly saying so **for that
  specific change** — summarize what you'd commit and wait.
- If you find a discrepancy between what a doc claims and what the code
  actually does, don't silently "fix" the doc to match — flag it the way
  `tracked_deviations.md` and the Gate-3 reconciliation did: name the gap,
  propose the resolution, let me decide.
- Treat `docs/permission_matrix.md` as authoritative for any RLS/policy work
  once P2 starts — don't invent a new role or widen an existing row without
  a dated addendum to that file, mirroring how `gate3_reconciliation.md`
  handled scope drift.

Confirm you've read the six docs above and give me your Batch 1 execution
plan before writing any code.
