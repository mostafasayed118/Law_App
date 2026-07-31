# LegalHub — Gate 3 Decision Record

> **Record type:** Official Gate 3 (Specification) decision. Design-only
> approval. No code, schema, migration, RLS policy, storage policy, edge
> function, credential flow, production configuration, commit, stage, push,
> remote configuration, environment value, dependency install, build, test,
> format, or destructive git action is authorized by this record.
>
> **Status:** ACCEPTED (design-only, Option C). Conditional on the
> exclusions and preconditions stated below.
>
> **Date:** 2026-07-28.
>
> **Supersedes:** none. This is the first Gate 3 decision for the auth/tenant
> authorization contract.

---

## 1. Proposal under review

- **Document:** `docs/auth_tenant_authorization_contract.md`.
- **Commit:** `f7621df4fc7beb9df173c726720be189f1c22f47` ("docs: define auth
  and tenant authorization contract"), docs-only, 463 lines, no code/tests.
- **Branch/HEAD at approval time:** `feat/dev-auth-domain-p1` and `main`
  both at `f7621df`; no remotes configured; nothing pushed.
- **Self-declared status of the proposal:** "proposal for Gate 1–3 review;
  not approved for production implementation."

This record accepts the proposal **as a design contract only**. It does not
approve production implementation.

---

## 2. Decision

**Option C — Conditionally approve a strictly bounded synthetic P1 slice.**

The product/legal owner accepts the auth/tenant authorization contract as the
Gate 3 specification, with the following conditions, exclusions, and
preconditions. This approval is design-only.

### 2.1 Confirmed authentication policy shape (P1)

The owner confirms that the following domain operations are the intended
authentication policy **shape** for P1, as listed in contract §5:

- Restore session
- Sign up
- Sign in
- Request password reset
- Verify reset OTP
- Reset password
- Refresh / expire
- Sign out

This confirmation covers the *operation list and its observable safety
contract* (non-enumerating reset acknowledgement, no password/token logging,
re-auth on expiry, provider-backed one-time/expiry behavior in production).
It does **not** finalize production authentication policy (email verification,
OTP vs passwordless, MFA, SSO/SCIM, rate limits, session TTL) — those remain
open as §10.6 and are required before P2/P3.

### 2.2 Owner assignments (§10)

| §10 item | Assignment | Status |
|---|---|---|
| §10.2 Jurisdiction and policy owner (D-03) | **[YOUR NAME / ROLE]** | **PLACEHOLDER — NOT YET ASSIGNED.** The owner's acceptance message carried the literal token `[YOUR NAME / ROLE]`; an actual named owner has not yet been provided. This field must be filled with a real name/role before P2 begins, and before the contract's human-accountability clauses can be treated as having an assignee. |
| §10.5 Human-authority owner (D-06) | **[YOUR NAME / ROLE]** | **PLACEHOLDER — NOT YET ASSIGNED.** Same as §10.2: literal token provided, real owner not yet named. Must be filled before P2 begins. |

**All other §10 blockers remain open and are not assigned by this record.**
See §4 below for per-phase gating.

---

## 3. Permitted P1 slice (Option C)

### 3.1 Exact permitted files

Approval covers the following working-tree files (as they exist at the time
of this decision; all currently unstaged and uncommitted):

- `lib/core/auth/auth_gateway.dart`
- `lib/core/auth/auth_state.dart`
- `lib/core/auth/organization_context.dart` (untracked)
- `lib/data/auth/fake_auth_gateway.dart`
- `lib/features/auth/presentation/auth_cubit.dart`
- `lib/features/auth/presentation/organization_context_cubit.dart` (untracked)
- `lib/features/auth/presentation/password_recovery_cubit.dart` (untracked)
- `lib/features/home/presentation/settings_screen.dart`
- `lib/app/router.dart`
- `lib/app/service_locator.dart`
- `lib/main.dart`
- `test/bootstrap_boundaries_test.dart`
- `test/widget_test.dart`
- `test/auth_domain_p1_test.dart` (untracked)

### 3.2 Permitted behavior

- Provider-neutral auth domain contracts behind the existing `AuthGateway`
  seam: `AuthOutcome<T>`, `AuthFailure`/`AuthFailureKind`,
  `SignInRequest`/`PasswordResetRequest`/`ResetCodeRequest`/
  `PasswordUpdateRequest`, `OrganizationMembership`, `MembershipStatus`,
  and a `Session` carrying `memberships` + `expiresAt` (no single
  client-owned `role`).
- A synthetic, in-memory `FakeAuthGateway` implementing restore, sign-in,
  reset (request→verify→complete), expiry, and sign-out against synthetic
  data only.
- `AuthCubit` session lifecycle: `restoring`/`unauthenticated`/
  `authenticated`/`reauthRequired`/`error`, with subscription cleanup.
- `OrganizationContextCubit` as a **non-authoritative** state holder that
  selects among memberships already present in the authenticated session,
  emits `denied` for suspended/unknown orgs, and clears on sign-out.
- `PasswordRecoveryCubit` orchestrating recovery without retaining
  identifier/code/password in state.
- Mechanical wiring in `service_locator.dart`, `main.dart`, `router.dart`,
  `settings_screen.dart` to make the above resolvable and observable.
- Tests covering non-retention, non-enumeration, expired→reauth,
  denied-for-suspended/unknown, and redaction.

### 3.3 Required wording (must be present in the code)

- `FakeAuthGateway` must carry a doc comment stating it is
  **non-production and non-authoritative** — "not an authentication
  mechanism and must not be used as production authorization." (Present at
  approval time.)
- `OrganizationContextCubit` / `OrganizationContext` must carry a doc comment
  stating the selected organization is **never an authorization grant; the
  future server boundary must re-check the authenticated membership for
  every protected operation.** (Present at approval time.)

### 3.4 No commit authorized

This approval is a **design approval only**. The working-tree files listed in
§3.1 must remain **unstaged and uncommitted** until the owner separately
authorizes a closeout/commit. No `git add`, `git commit`, `git push`, or
remote configuration is authorized by this record.

---

## 4. Explicit exclusions (NOT authorized)

The following remain excluded regardless of the §3 permitted slice:

- No Supabase package, adapter, or client of any kind.
- No network calls, HTTP clients, or real-time transports.
- No real credentials, service-role keys, anon keys, or non-empty
  environment values. `.env.example` stays name-only with empty values.
- No schema, migration, RLS policy, storage policy, RPC, edge function, or
  generated backend types.
- No tenant, role, or matter authorization represented as server-enforced.
  Client-side selection remains UX/request context only.
- No organization or matter backend work. Organization exists only as domain
  vocabulary inside the synthetic session.
- No invitation UX or invitation backend.
- No sign-in / sign-up / recovery **screens**. The P1 slice is contracts,
  fakes, and tests only. Any screen built on `AuthCubit`,
  `PasswordRecoveryCubit`, or `OrganizationContextCubit` is P3 work and
  remains gated.
- No legal workflow, conflict check, waiver, ethical wall, regulatory
  filing, research/AI, payment, analytics, or compliance claim.
- No dark theme UI (D-14 deferred).
- No production or real user/legal data in any environment.

---

## 5. Phase gating (unchanged by this approval)

| Phase | Status after this decision | Authorization required to proceed |
|---|---|---|
| P0 — Decision capture | Partially advanced: §5 policy shape confirmed; §10.2/§10.5 placeholders only. | Close §10.2, §10.5 with real owners; close §10.1 (product model), §10.7 (org semantics), §10.8 (role vocabulary) before P2. |
| P1 — Domain contracts + synthetic adapter | **Approved (design-only, Option C).** WIP remains uncommitted. | Separate closeout/commit authorization from the owner. |
| P2 — Non-production schema + enforcement | Not authorized. | All §10 blockers relevant to identity/tenant decided; non-production backend available; signed permission matrix; retention/deletion/audit documented; rollback plan; mandatory Supabase/RLS review gate (bootstrap spec §6/§9). |
| P3 — Auth + org UX | Not authorized. | P2 exit (cross-tenant denial proven across every access path) + explicit P3 approval. |
| P4 — Security review + controlled rollout | Not authorized. | P3 exit + explicit release approval. |

The bootstrap spec's "future gate: mandatory Supabase/RLS review before any
real-data feature" (§6/§9) remains in force and independently blocks P2.

---

## 6. Preconditions not yet satisfied

The following must be closed before the corresponding next step:

1. **§10.2 (D-03) jurisdiction/policy owner** — real name/role required (the
   `[YOUR NAME / ROLE]` token is not an assignment).
2. **§10.5 (D-06) human-authority owner** — real name/role required (same).
3. **§10.1 (D-02) product model** — firm/marketplace/portal/combo; required
   before P2.
4. **§10.6 authentication policy** — full production policy (MFA, SSO/SCIM,
   rate limits, session TTL, email verification, OTP vs passwordless);
   required before P2/P3. The §5 shape is confirmed; the production policy is
   not.
5. **§10.7 organization semantics** — who owns an org, multi-org, switching;
   required before P2.
6. **§10.8 role semantics** — org vs platform roles, multi-role, admin scope,
   permission matrix; required before P2 (matrix) and before P3 (UX).
7. **Separate commit/closeout authorization** — required before the P1 WIP
   may be staged or committed.

---

## 7. Acknowledgments by the owner

The owner has explicitly acknowledged:

- This is a **design-only approval**.
- **No commit is authorized yet.**
- **P2/P3/P4 remain gated** behind their own approvals and the open §10
  blockers.
- The §5 auth-operation list is the intended authentication policy **shape**
  for P1 (not the finalized production policy).

---

## 8. Evidence of WIP safety (as of approval time)

Recorded for traceability. The P1 WIP was verified to contain:

- No Supabase, backend, or networking packages or imports.
- No credentials, keys, URLs, or non-empty environment values.
- No PII in state, logging, errors, tests, or diagnostics (request types
  redact `toString()`; `Redactor` redacts credential-shaped keys, emails,
  bearer tokens; recovery cubit does not retain identifier/code/password).
- No tenant/role authorization represented as server-enforced.
- No schema, migration, RLS, storage policy, RPC, edge function, or matter
  entities.
- No legal workflow, compliance claims, AI, payments, analytics, or
  conflict-check behavior.

This evidence supports the Option C approval; it does not authorize a commit.

---

## 9. How to fill the §10.2 / §10.5 placeholders

Send the real owner name/role for §10.2 (jurisdiction/policy) and §10.5
(human authority). On receipt, this record will be updated **in place** (as
an unstaged edit, still uncommitted) to replace the two
`PLACEHOLDER — NOT YET ASSIGNED` rows with the real assignments, and the
record's status will remain ACCEPTED (design-only). No other change to this
decision is implied by filling those fields.

---

Gate 3 decision recorded. No files were staged, committed, or pushed.
