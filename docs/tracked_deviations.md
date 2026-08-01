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

## D-T1: OnboardingScreen overflows at compact/desktop heights — **RESOLVED (2026-08-01)**

- **Where:** ~~`lib/features/onboarding/presentation/onboarding_screen.dart` —
  the `PageView` page laid out a fixed-height hero container that overflowed
  by ~139px at the 800×600 widget-test surface.~~ **Resolved:** the carousel
  page is now `LayoutBuilder` + `SingleChildScrollView` +
  `ConstrainedBox(minHeight)` with the content Column centered inside — it
  centers at phone-class heights and scrolls at compact/desktop heights.
- **Status:** **RESOLVED (2026-08-01).** The existing 411×867 tests stay green
  and a default-surface (800×600) test asserting `takeException() == null` was
  added to `test/features/onboarding/onboarding_screen_test.dart`.
- **Owner:** Resolved by Batch 5 of the codebase-audit plan
  (responsive-hardening slice).
- **Resolution:** Wrap the page in a `SingleChildScrollView` over a
  `ConstrainedBox` with `minHeight` = viewport minus padding, so the column
  centers when it fits and scrolls when it does not.
- **Regression guard:** `onboarding_screen_test.dart` — the 411×867 tests
  (centered layout unchanged) *and* the new 800×600 test (no overflow
  exception) both pin the behavior.

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

## D-T3: Hardcoded English fallback display name — **RESOLVED (2026-08-01)**

- **Where:** ~~`lib/features/home/presentation/home_screen.dart` — greeting
  used `session?.displayName ?? 'Jonathan'`.~~ **Resolved:** the fallback is
  now `l10n.homeFallbackName` — a localized neutral name key
  (`Guest`/`ضيف`/`Misafir`), so the branch renders localized text in every
  supported locale instead of a hardcoded English fixture.
- **Deviation:** A hardcoded English name used as the no-session fallback. Not
  localizable; not synthetic-neutral.
- **Status:** **RESOLVED (2026-08-01).** The reachability decision: the
  no-session branch is reachable only by direct pump (the router guard
  redirects unauthenticated users away from `/home`), so the fallback was
  **localized, not removed** — keeping the greeting defined for any render
  context. Pinned in `test/features/home/home_screen_test.dart` with EN
  (`Hello, Guest`) plus AR/TR assertions proving the key resolves in all
  locales.
- **Owner:** Resolved by Batch 5 of the codebase-audit plan.
- **Resolution:** Add a `homeFallbackName` localization key (EN/AR/TR) and use
  it as the no-session fallback in the greeting.

## D-T4: Demo `Session {id, displayName, role}` shape (pre-P1) — **RESOLVED (2026-07-31)**

- **Where:**
  - ~~`lib/core/auth/auth_state.dart` / `lib/data/auth/fake_auth_gateway.dart`
    (`Session {id, displayName, role}`) and `lib/core/roles/user_role.dart`
    (UX-only capability map).~~ **Resolved (`1042daf`):** the demo session
    now carries the contract-§5 shape — `Session {userId, displayName,
    memberships, expiresAt}` with **no single client-owned `role`**.
- **Deviation:** The bootstrap demo session used to carry a single
  client-visible `role` — technically the shape contract §5 said a future
  production session must not rely on as the authority. Safe only while the
  demo session is explicitly non-production and non-authoritative
  (`FakeAuthGateway` wording, gate3 §3.3), the capability map is documented
  UX-only, and no server exists to be fooled by a client role.
- **Status:** **RESOLVED (2026-07-31, `1042daf`).** Batch 3.1 replaced the
  demo shape with the contract-§5 model: roles now live only inside
  `OrganizationMembership` with explicit lifecycle status, and presentation
  reads a UX-only `primaryRole` projection from the active membership — it
  cannot grant itself a role. Expired sessions resolve to `reauthRequired`
  rather than a misleading authenticated state.
- **Owner:** Resolved by Batch 3 of the codebase-audit plan (domain session
  model).
- **Cross-reference:** `docs/gate3_reconciliation.md` §7.

## D-T5: `UserRole` code enum (six values) vs P2 `org_role` schema enum (four) — **TRACKED (2026-08-01)**

- **Where:** `lib/core/roles/user_role.dart` declares six `UserRole` values
  including `researchAnalyst` and `admin`; the approved P2 schema enum
  (`docs/p2_schema_rls_design.md` §4.1) contains **four** MVP org roles
  (`client`, `attorney`, `partner`, `compliance_officer`) per D-09.
- **Deviation:** intentional vocabulary divergence — `researchAnalyst` and
  `admin` are not org roles in MVP and must **not** be added to the schema;
  the code-side enum stays as UX-only candidate vocabulary (its own doc
  comment marks the capability map as UX-only, never authorization).
- **Status:** **TRACKED (2026-08-01).** Confirmed intentional by the P2 RLS
  gate review (Q3). Not to be "fixed" by adding non-MVP roles to the schema
  enum, nor by silently deleting code enum values before P3.
- **Owner:** P2 RLS gate review (2026-08-01).
- **Cross-reference:** `docs/p2_schema_rls_design.md` §3 (reconciliation
  flag), §4.1; `docs/p0_decision_capture.md` §1 D-09.

## D-T6: Matrix §2 "partner views another user's profile (same org)" vs own-row-only profiles — **RESOLVED (2026-08-01)**

- **Where:** `docs/permission_matrix.md` §2 row "View **another** user's
  profile (any org)" promised `partner` = "✅ same org only"; the gate-approved
  design (`docs/p2_schema_rls_design.md` §5.2) makes `profiles` **own-row-only**
  and the reviewed slice (`supabase/policies/profiles.sql`, `b5f7e7c`) ships
  no partner profile-metadata RPC (`list_members_metadata` is owner-gated).
- **Deviation:** the signed matrix row promised a partner capability the
  approved design deliberately did not implement — surfaced by the rehearsal
  plan (`docs/p2_rehearsal_plan.md` §4) as a recorded finding before any apply.
- **Status:** **RESOLVED (2026-08-01).** Decision: **amend the matrix, not
  the slice.** The matrix §2 partner cell was narrowed to "❌ deny" via a
  dated §2 addendum — the default-deny direction, aligning the signed matrix
  with the approved design and the committed slice. No partner-profile-metadata
  RPC was added: that would widen the client surface (Q5) to satisfy an
  outdated row, and the approved design already chose own-row-only.
- **Owner:** Project Owner (github.com/mostafasayed118), 2026-08-01.
- **Cross-reference:** `docs/permission_matrix.md` §2 (addendum),
  §7 (dated-addendum discipline); `docs/p2_schema_rls_design.md` §5.2;
  `docs/p2_rehearsal_plan.md` §4 (row updated to RESOLVED).
