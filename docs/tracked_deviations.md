# Tracked deviations

A running list of known, documented deviations that are **not** architecture
decisions and so do not belong in the ADR log. Each entry names the deviation,
where it lives, its status, and the batch or slice that owns its resolution.

The batches and slices cited in this file (and in `docs/adr/0007`) are
defined in the canonical execution plan: [`codebase_audit_plan.md`](codebase_audit_plan.md).

Architecture decisions — expensive to reverse, cross-feature, or
safety-critical — live in [`adr/`](adr/). This file is for the rest: known
bugs deferred for a focused slice, and unfinished work that is intentionally
backend-free until the P0 product/legal decisions (D-02–D-09) close.

---

## D-T1: OnboardingScreen overflows at compact/desktop heights

- **Where:** `lib/features/onboarding/presentation/onboarding_screen.dart`.
- **Deviation:** The `PageView` page lays out a fixed-height hero container.
  At the default desktop widget-test surface (800×600) the page area is ~325px
  tall and the page content overflows by ~139px. A phone-class viewport
  (411×867) renders correctly. Short real-world devices may still overflow
  because the page content is not scrollable or flex-sized.
- **Status:** Tracked, deferred. Not a regression — documented in the README
  since the onboarding slice landed.
- **Owner:** Batch 5 of the codebase-audit plan (responsive-hardening slice).
- **Resolution:** Wrap the page in a `SingleChildScrollView` or make the hero
  container `Flexible`; verify EN/AR/RTL + light/dark at both 411×867 and
  800×600 per `INSTRUCTIONS.md` §4.5.
- **Regression guard:** The existing onboarding widget test pumps at a
  411×867 phone viewport to avoid the overflow; the fix must keep that test
  green *and* add a default-surface (800×600) test that currently cannot pass.

## D-T2: Domain value objects built but not wired into presentation — **RESOLVED (2026-07-31)**

- **Where:**
  - ~~`lib/features/auth/domain/sign_up_request.dart` — `SignUpRequest` with
    `toRedactedMap()` redaction contract (ADR-0003). Not constructed by
    `lib/features/auth/presentation/sign_up_screen.dart`.~~ **Resolved:**
    `SignUpRequest` is now wired into `SignUpScreen` via `SignUpCubit` and the
    `SignUpGateway` seam. The screen builds the VO from validated form fields on
    submit, and `SignUpCubit` asserts the redaction invariant in
    `test/features/auth/sign_up_cubit_test.dart` (the failure-path `blocTest`
    pins `password`/`phone`/`email` as `[REDACTED]` in the error context).
  - ~~`lib/features/auth/domain/password_recovery_request.dart` —
    `PasswordRecoveryRequest` with `toRedactedMap()`. Constructed by
    `forgot_password_reset_screen.dart` with **empty email/otp placeholders**
    because routing does not thread the email and OTP from the earlier
    steps.~~ **Resolved (`83f5bbf`):** the email (step 1) and OTP (step 2)
    are threaded to the reset screen via the in-memory
    `RecoveryRoutingContext` route `extra` (never the URL), so the VO is
    built with **real values** from validated form fields on submit.
  - ~~`lib/features/auth/presentation/forgot_password/forgot_password_otp_screen.dart`
    — the "Resend code" button is a no-op (`onPressed: () {}`), which implies
    a sent code that is never sent (a §4.4 "no false assurance" issue).~~
    **Resolved (`83f5bbf`):** the control is now **disabled** (`onPressed:
    null`) with the "Resend Code (unavailable in demo)" label — an honest
    state that does not imply a code was sent.
- **Status:** **RESOLVED (2026-07-31).** Both halves are closed in code
  (sign-up `0d5c66d`, recovery `83f5bbf`): the redaction contracts are tested
  (`test/features/auth/sign_up_request_test.dart`,
  `test/features/auth/password_recovery_request_test.dart`), the recovery
  request is built with real threaded values, and the resend control is
  disabled. The privacy-by-design loop is closed; this entry is retained as a
  resolved record.
- **Owner:** Sign-up half `0d5c66d`; recovery half `83f5bbf`; ledger update by
  Batch 4 of the codebase-audit plan.
- **Constraint:** This slice stays backend-free. It does **not** call a real
  `AuthGateway`/`PasswordRecoveryGateway`, add Supabase, or implement real
  sign-up/reset — those are gated on the P0 product/legal decisions
  (D-02–D-09) recorded in `docs/auth_tenant_authorization_contract.md` §10.
- **Resolution:** All three resolution items are complete (sign-up wiring
  `0d5c66d`; email/OTP threading + disabled resend `83f5bbf`). Retained as a
  historical record.

## D-T3: Hardcoded English fallback display name

- **Where:** `lib/features/home/presentation/home_screen.dart` — greeting uses
  `session?.displayName ?? 'Jonathan'`.
- **Deviation:** A hardcoded English name used as the no-session fallback. Not
  localizable; not synthetic-neutral.
- **Status:** Tracked, minor. Likely demo-era fixture; flagged for a decision
  on whether the no-session branch is reachable in practice (the router
  redirects unauthenticated users away from `/home`).
- **Owner:** Batch 5 of the codebase-audit plan, pending the reachability
  decision.
- **Resolution:** Either localize the fallback (a neutral greeting key) or
  remove it if the no-session branch is unreachable. Decision needed before
  coding.

## D-T4: Demo `Session {id, displayName, role}` shape (pre-P1)

- **Where:** `lib/core/auth/auth_state.dart` / `lib/data/auth/fake_auth_gateway.dart`
  (`Session {id, displayName, role}`) and `lib/core/roles/user_role.dart`
  (UX-only capability map).
- **Deviation:** The bootstrap demo session carries a single client-visible
  `role` — technically the shape contract §5 said a future production session
  must not rely on as the authority. Safe only because the demo session is
  explicitly non-production and non-authoritative (`FakeAuthGateway` wording,
  gate3 §3.3), the capability map is documented UX-only, and no server exists
  to be fooled by a client role.
- **Status:** Tracked. Resolved by Batch 3.1 (contract-P1 session model:
  provider-derived `userId`, `memberships`, `expiresAt` — no single
  client-owned `role`). **Must be recorded here before Batch 3.1 starts** (see
  the audit plan's Batch 3 dependency note).
- **Owner:** Batch 3 of the codebase-audit plan (domain session model).
- **Cross-reference:** `docs/gate3_reconciliation.md` §7.
