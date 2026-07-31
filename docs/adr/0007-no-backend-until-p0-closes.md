# ADR-0007: No backend package until P0 closes; backend-free batches proceed

- Status: Accepted
- Date: 2026-07-31
- Related: `docs/auth_tenant_authorization_contract.md` §10–12,
  `docs/p0_decision_capture.md`, ADR-0003 (SignUpRequest redaction contract),
  `INSTRUCTIONS.md` §1.3, §2, §3.

## Context

After the B1–B13 foundation and the Batch 1 sign-up wiring, the natural next
request is to add `supabase_flutter` and begin backend implementation. The
auth/tenant authorization contract (`docs/auth_tenant_authorization_contract.md`)
explicitly gates this: §10 lists ten open decisions (D-02–D-09 + invitation
and support access) it calls "blockers, not assumptions to encode in code";
§11 P0 states "no client or SQL code is written before this"; §12's
"Definition of ready for the first implementation slice" requires product,
security, privacy, and counsel sign-off, a non-production backend, a
positive-and-negative permission matrix, documented retention/audit, and a
rollback plan before any backend slice starts.

Adding `supabase_flutter` now would encode those ten decisions by default —
auth policy, residency, retention, role matrix, org semantics — as
implementer assumptions rather than owner decisions. In a legal-tech product
that is exactly the risk INSTRUCTIONS §1.3 (least privilege, tenant isolation,
auditability, no false assurance) is written to prevent, and it is
irreversible in practice: once a client is built against a provider, the
policy shape ossifies around it.

## Decision

1. **No backend package is added to `pubspec.yaml` and no Supabase migration,
   RLS, storage, RPC, or edge-function code is written** until the P0
   decision-capture document (`docs/p0_decision_capture.md`) marks the
   blockers required by the target slice as **Decided** and that document's
   §2 "P1 readiness checklist" is fully checked, including recorded explicit
   implementation approval for that slice.
2. **Backend-free work proceeds in parallel.** Codebase-audit Batches 2–4
   (recovery-half of D-T2, test-floor hardening, responsive/localization
   polish) are not blocked by P0 and continue, because they touch no backend
   contract, no authorization boundary, and no real data.
3. The sequencing is durable: P1 (the first backend slice) starts only with an
   approval recorded in `docs/p0_decision_capture.md` §3, not by engineering
   discretion.

## Scope boundary

This ADR records sequencing only. It does **not**:

- decide any of the ten P0 blockers — those live in
  `docs/p0_decision_capture.md` with their owners;
- authorize any backend code or dependency — it does the opposite;
- block or defer the backend-free batches; or
- change the auth contract. It makes the contract's "definition of ready"
  checkable by pointing it at a single living document.

## Consequences

- The fastest *safe* path to backend work is now unambiguous: fill in
  `docs/p0_decision_capture.md`. Engineering cannot accidentally jump the gate
  by adding a package "just to try it."
- Backend-free batches (2–4) remain valuable and shippable regardless of when
  P0 closes, so the project is never fully blocked on cross-functional
  decisions.
- When P0 does close, the path to Supabase is a clearly-scoped P1 slice
  (provider adapter behind the existing `AuthGateway` seam, config via
  `--dart-define-from-file`, no service-role key on the client, positive/
  negative policy tests) rather than an open-ended "add backend" task.
- This ADR is the standing reference a reviewer cites if a future change
  attempts to add a backend dependency before the checklist is complete.

## Open condition

The open condition is `docs/p0_decision_capture.md` itself: each blocker must
gain an owner and a decision. When the §2 checklist is fully checked and §3
records an approval, this ADR's gate is satisfied for the approved slice and
P1 may begin under the contract's normal Gate 3 specification process.
