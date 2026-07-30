# ADR-0003: SignUpRequest is a pure-domain redaction contract

- Status: Accepted
- Date: 2026-07-30
- Related: `auth_tenant_authorization_contract.md` (P1 Task 1), ADR-0001.

## Context

Real authentication is blocked behind the P0 product/legal decisions recorded
in `docs/auth_tenant_authorization_contract.md` §10. No `AuthGateway` accepting
credentials exists, and none should be introduced until those decisions are
made. The sign-up form (`SignUpScreen`) currently validates input and navigates
with a snackbar — it has no domain object and no Cubit.

The one safe, backend-free slice of P1 work is the **domain contract** for the
sign-up request itself: a value object that carries the captured fields and
guarantees, by construction, that PII never reaches a diagnostic surface.

## Decision

Introduce `SignUpRequest` in `lib/features/auth/domain/` (feature-first Clean
Architecture — the object belongs to the auth feature, not to `core/`). It is:

- A transient value object (Equatable) with fields `name`, `email`, `phone`,
  `password` — matching the four `SignUpScreen` controllers.
- Constructed via `SignUpRequest.fromRaw(...)`, which trims and lower-cases the
  email to the canonical stored form.
- Equipped with `toRedactedMap()`, which delegates to the existing `Redactor` so
  `password`, `email`, and `phone` are masked before any diagnostic surface.
  The returned map is idempotent under `Redactor.map` and safe to embed in
  `AppError.context`.

Tests are written first and assert the redaction invariants directly: the
clear-text password never appears in the map, PII keys are `[REDACTED]`, and
re-running the redactor is a no-op.

## Scope boundary

`SignUpRequest` is **not** wired into `SignUpScreen` yet. Wiring it to the
presentation layer requires a real `AuthGateway` (or a sign-up use case backed
by one), which remains blocked behind the P0 decisions. This ADR records only
the domain contract and its privacy invariant.

## Consequences

- Privacy-by-design becomes a verifiable invariant for the sign-up path, not an
  aspiration.
- When the P0 decisions land, the sign-up use case can accept a `SignUpRequest`
  and call `toRedactedMap()` for any `AppError.context` it builds — the contract
  is already in place.
- The object lives in `features/auth/domain`, establishing the feature-first
  domain layout for future auth value objects.
