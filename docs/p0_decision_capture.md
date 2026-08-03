# LegalHub — P0 Decision Capture (Pre-Backend)

> **Status: P1 APPROVED (2026-07-31); P2 APPROVED (2026-08-01); P3 PLAN APPROVED (2026-08-02).** All ten §1 blockers are decided, the
> §2 Definition-of-Ready checklist is fully satisfied (Supabase dev project
> provisioned, `.env` confirmed git-ignored, rollback plan written), and the
> §3 explicit implementation-approval sign-off is now recorded. **Batch 3 /
> P1 (domain contracts + `supabase_flutter` adapter) may start**, subject to
> the per-step commit/push approval discipline in `INSTRUCTIONS.md` §2/§3 —
> this document authorizes *starting the slice*, not any individual commit
> or push within it.
>
> **Context for these decisions:** LegalHub is a **portfolio/demo project**
> (confirmed by the Project Owner, 2026-07-31) — synthetic data only, no real
> clients, no real legal advice given, built to demonstrate production-grade
> engineering practice (clean architecture, multi-tenant auth, RLS) for job
> applications. Decisions below are scoped accordingly: they close the
> *engineering* blockers needed to build a correct, defensible auth/tenant
> system. They are explicitly **not** legal advice and would need real
> counsel/compliance review before any real client or real legal data ever
> touches this system.
>
> **Authority:** `INSTRUCTIONS.md` §2 (never deploy/migrate/change Supabase
> policies without explicit approval), §3 (Gate 3 specification approval
> required before data-model/RLS/access-changing work), §1.3 (core product
> invariants). Source of the blocker set: `docs/auth_tenant_authorization_
> contract.md` §10. This document does not override that contract; it makes
> its open decisions fillable.

---

## How to use this document

For each blocker, fill in:

- **Owner** — the single role accountable for the decision (not "team").
- **Decision** — the chosen option, written as a declarative statement, or
  `OPEN` if undecided.
- **Decided on** — date the decision was recorded.
- **Blocks slice** — which P1+ slice is unblocked once this closes (see §3).
- **Evidence / notes** — pointer to the supporting doc, spec, or approval
  record. A decision without an owner and a date is not a decision.

A blocker is **Decided** only when Owner, Decision, and Decided-on are filled.
A slice is **Ready** only when all blockers in its "blocks slice" set are
Decided **and** the §4 Definition of Ready checklist is satisfied.

---

## 1. P0 blocker set (from auth_tenant_authorization_contract §10)

### D-02 — Product model

- **Question:** Is LegalHub a law-firm product, a marketplace, a client portal,
  or a combination? This determines tenant semantics, who owns an
  organization, and whether clients can belong to multiple organizations.
- **Owner:** Project Owner (github.com/mostafasayed118)
- **Decision:** **Multi-tenant law-firm client portal.** Each `organization`
  = one law firm. Attorneys and clients are members of one or more
  organizations. No open marketplace/matching functionality in MVP.
- **Decided on:** 2026-07-31
- **Blocks slice:** P1 session model, P2 organization/membership schema, P3
  org-selection UX.
- **Evidence / notes:** Chat decision log 2026-07-31. Confirms the tenant
  shape already implied by contract §3.2 ("organization is the primary
  tenant boundary").

### D-03 — Jurisdiction and policy owner

- **Question:** Which counsel/compliance owner approves access rules,
  retention, consent, and high-risk workflow rules, and for which
  jurisdiction(s)?
- **Owner:** Project Owner (github.com/mostafasayed118)
- **Decision:** **N/A for this project's actual scope.** This is a synthetic
  demo — no real jurisdiction is served and no legal-compliance claim is
  made anywhere in the product. The Project Owner holds the *accountability
  role* (per `gate3_reconciliation.md` §10) so §10-style clauses have an
  assignee, but the underlying jurisdiction/policy question is explicitly
  deferred indefinitely — it only becomes a real decision if this project
  ever moves from portfolio/demo to handling real client data, at which
  point real counsel review is required and this decision must be revisited.
- **Decided on:** 2026-07-31
- **Blocks slice:** P1 (any auth/identity decision), all legal-workflow
  slices.
- **Evidence / notes:** Chat decision log 2026-07-31; `gate3_reconciliation.md`
  §10.

### D-04 — Data residency and cross-border transfers

- **Question:** Which Supabase region is approved, and what are the
  backup/cross-border processing constraints? Affects provider project
  selection and storage config.
- **Owner:** Project Owner (github.com/mostafasayed118)
- **Decision:** **Region: `eu-central-1` (Frankfurt)** on a Supabase
  free/dev tier project. No real cross-border processing constraints apply
  (synthetic data only); this is a technical proximity choice, not a
  compliance determination.
- **Decided on:** 2026-07-31
- **Blocks slice:** P1 (provider project selection), P2 (storage policies).
- **Evidence / notes:** **Provisioned 2026-07-31** (`eu-central-1`, free/dev
  tier). The project ref is kept in the local, git-ignored `.env` only by the
  owner's choice — not sensitive, but not needed in this shared doc for the
  gate to close. (Reconciled 2026-07-31 from an earlier "not yet provisioned"
  note to match the §2 checklist and the kickoff prompt.)

### D-05 — Retention, deletion, legal hold, export

- **Question:** What are the retention/deletion/legal-hold/export rules for
  identity, membership, documents, messages, audit records, and recovery
  data? Affects schema design, `DELETE` policy, and audit lifecycle.
- **Owner:** Project Owner (github.com/mostafasayed118)
- **Decision:** Synthetic data only — **no legal-hold and no export
  requirement for MVP.** A user-facing **"Delete my account"** action must
  hard-delete (cascade) the identity, memberships, and any owned demo data.
  Audit records are append-only and are *not* deleted by an account deletion
  (they retain only the redacted actor reference, per contract §8).
- **Decided on:** 2026-07-31
- **Blocks slice:** P2 (schema/migrations — `DELETE` is not assumed safe per
  contract §7), audit slice.
- **Evidence / notes:** Implementation note: cascade-delete FK constraints or
  an explicit deletion RPC in P2; a P1 domain-level `deleteAccount` contract
  can be stubbed against the fake gateway now.

### D-06 — Human authority

- **Question:** Who may grant roles, approve exceptions, and review
  access/audit events? Defines the membership/invitation authority and the
  audit-reader scope.
- **Owner:** Project Owner (github.com/mostafasayed118)
- **Decision:** Within an organization, **only members with the `partner`
  role may grant/change roles and manage memberships** (invite, suspend,
  remove). Across organizations, only the **`platform_owner_admin`**
  capability (see Addendum below) may view/manage membership metadata,
  scoped to identity/membership data only — never matter content.
- **Decided on:** 2026-07-31
- **Blocks slice:** P2 (membership/invitation lifecycle), P3 (invitation UX),
  audit slice.
- **Evidence / notes:** See `docs/permission_matrix.md` for the full
  positive/negative test matrix.

### D-07 — Authentication policy

- **Question:** Email verification, passwordless/OTP, MFA, SSO/SCIM, account
  recovery, rate limits, session TTL. Provider-backed behavior must be chosen,
  not assumed.
- **Owner:** Project Owner (github.com/mostafasayed118)
- **Decision:** **Email + password** via Supabase Auth, with **email
  verification required** at sign-up. Password recovery via the existing
  email → OTP → reset flow already scaffolded in the client. **MFA, SSO/SCIM,
  and passwordless are deferred to v1** (not MVP). **Session TTL**: Supabase
  defaults (short-lived access token, longer-lived refresh token) — no
  custom TTL override for MVP. Rate limiting: Supabase Auth's built-in
  defaults; no custom throttling layer for MVP.
- **Decided on:** 2026-07-31
- **Blocks slice:** P1 (auth adapter + session model), P3 (auth UX states).
- **Evidence / notes:** Matches the operation list already confirmed in
  `gate3_decision.md` §2.1.

### D-08 — Organization semantics

- **Question:** Who owns an organization, may users belong to multiple
  organizations, and how does organization switching work? Active org is a
  session context, not proof of membership — the switching rule must be
  specified.
- **Owner:** Project Owner (github.com/mostafasayed118)
- **Decision:** A user **may hold memberships in multiple organizations**.
  An organization is created by whichever user first signs up as its
  `partner`; that user becomes the organization's initial owner/admin.
  Active-organization selection is a client-side UX convenience only
  (already scaffolded); every server request must re-derive and re-check
  membership from the authenticated session, never trust the client-selected
  org id (contract §3.2, non-negotiable #3).
- **Decided on:** 2026-07-31
- **Blocks slice:** P1 (session model needs active-org context), P2
  (membership schema), P3 (org-switch UX).
- **Evidence / notes:** —

### D-09 — Role semantics

- **Question:** Organization roles vs platform roles, multi-role support,
  admin scope (org admin vs platform operator), and the permission matrix
  for each approved MVP action. The six current roles are *candidates*, not
  a matrix.
- **Owner:** Project Owner (github.com/mostafasayed118)
- **Decision:** **Four org-scoped roles for MVP**, per contract §4: `client`,
  `attorney`, `partner`, `compliance_officer`. No org member holds a
  platform-wide role. **One narrow platform-level capability**,
  `platform_owner_admin`, is added for the Project Owner's own account only
  (see Addendum below) — it is not one of the four org roles and does not
  appear in any organization's membership table.
- **Decided on:** 2026-07-31
- **Blocks slice:** P1 (capability projection), P2 (membership.role), P3
  (role-gated UX).
- **Evidence / notes:** Full positive/negative matrix: `docs/permission_matrix.md`.

### D-10a — Invitation policy

- **Question:** Inviter authority, expiry, resend/revoke, identity matching,
  email enumeration behavior, audit/notification rules.
- **Owner:** Project Owner (github.com/mostafasayed118)
- **Decision:** Only members with the `partner` role may invite. Invitations
  expire after **7 days**. Identity matching is by email; if the invited
  email does not yet have an account, the invite is held pending sign-up. No
  email-enumeration signal is given to non-partners. Only the inviting
  organization's `partner`(s) may resend or revoke a pending invite. Every
  invite action produces an audit record (contract §8).
- **Decided on:** 2026-07-31
- **Blocks slice:** P2 (invitation lifecycle + token rules), P3 (invitation
  UX).
- **Evidence / notes:** —

### D-10b — Support / operator access

- **Question:** Does any operator/support access exist? If so, require
  explicit approval, least privilege, consent/notice, time bounds, and
  audit. Default is *no* operator access.
- **Owner:** Project Owner (github.com/mostafasayed118)
- **Decision:** **The default remains no general support/operator tier.**
  However, a single, narrowly-scoped **`platform_owner_admin`** capability is
  approved, bound to the Project Owner's own account only (see Addendum
  below). It does not create a "support role" other accounts can hold.
- **Decided on:** 2026-07-31
- **Blocks slice:** P2 (any platform-role policy), audit slice.
- **Evidence / notes:** See Addendum immediately below and
  `docs/permission_matrix.md`.

---

### Addendum (2026-07-31) — `platform_owner_admin` capability

Added in response to a new requirement: an admin page for the Project Owner
to administer users/organizations directly (portfolio-demo need — creating,
inspecting, and cleaning up synthetic accounts).

This is **not** a new organization role and **not** general support access.
It is scoped as follows:

- **Bound to exactly one account** — the Project Owner's own authenticated
  identity. Not assignable to any other user through product UI.
- **Permitted:** list organizations; list an organization's members and
  their identity/membership metadata (name, email, role, status, timestamps);
  suspend/reactivate a membership; delete a synthetic demo account
  (cascades per D-05).
- **Forbidden, no exceptions:** reading matter/document/message content;
  impersonating a session (acting *as* another user); modifying audit
  records; bypassing organization-scoped RLS for anything other than the
  identity/membership tables explicitly listed above.
- **Audited:** every `platform_owner_admin` action produces an append-only
  audit record per contract §8, same as any other membership change.
- **Enforcement location:** this is a **server-side (RLS/RPC) capability**,
  not a client-side flag. It cannot be built as a real, working feature
  until P1 (session/adapter) and P2 (schema + RLS) exist. Until then, the
  domain contract for it can be designed and stubbed against the fake
  gateway (backend-free), but no working admin screen should be shipped —
  per `gate3_decision.md` §4, screens are P3 work regardless of which role
  they serve.

Full positive/negative test rows: `docs/permission_matrix.md`.

---

## 2. P1 readiness checklist (Definition of Ready for the first backend slice)

P1 is the first slice that may add `supabase_flutter` and write a provider
adapter behind the existing `AuthGateway` seam. It is ready only when **all**
of the following are true (mirrors contract §12):

- [x] All blockers in the "Blocks slice: P1" set above (D-02, D-03, D-04,
      D-07, D-08, D-09) are **Decided** (2026-07-31, see §1 above).
- [x] A non-production Supabase project exists. **Provisioned 2026-07-31**,
      region `eu-central-1`. Project ref: _not recorded in this shared doc
      by owner's choice — kept in the local, git-ignored `.env` only; the
      ref is not sensitive but recording it here isn't necessary for the
      gate to close._ Migrations/policies/functions/storage config
      inspection is N/A — this is a freshly created project with nothing in
      it yet.
- [x] A signed permission matrix exists covering **positive and negative**
      cases for each approved MVP action (contract §9). Location:
      `docs/permission_matrix.md` (added 2026-07-31).
- [x] Data retention/deletion and audit requirements are documented for every
      data class touched by P1 (identity, session, membership). Location:
      D-05 and D-06 decisions above; contract §8.
- [x] A rollback plan exists for the schema, policy, configuration, and
      client release. Location: `docs/rollback_plan.md` (added 2026-07-31).
- [x] No production credentials or real client/legal data are used. Dev-only
      URL/anon config is injected via `--dart-define-from-file`; the `.env`
      holding the URL + anon key is **confirmed git-ignored** by the
      Project Owner (2026-07-31) — no service-role key exists anywhere in
      this project. `.env.example` stays name-only.
- [x] Explicit implementation approval for P1 is recorded in this document
      (§3) with owner and date. **Recorded 2026-07-31 — see §3 below.**

**All boxes closed 2026-07-31.** P1 / Batch 3 is unblocked at the
decision-capture level.

---

## 3. Slice map and approval log

The phased implementation proposal (contract §11), with the blocker set each
slice depends on and the approval record once granted.

| Slice | Depends on blockers | Status | Approved by | Date |
| --- | --- | --- | --- | --- |
| P0 — Decision capture (this doc) | — | **Decisions closed 2026-07-31** | Project Owner | 2026-07-31 |
| P1 — Domain contracts + provider adapter (add `supabase_flutter`, adapter behind `AuthGateway`) | D-02, D-03, D-04, D-07, D-08, D-09 + §2 checklist | **APPROVED — §2 fully satisfied** | Project Owner (github.com/mostafasayed118) | 2026-07-31 |
| P2 — Non-production schema + default-deny RLS/storage/realtime + narrow RPCs, with positive/negative policy tests | P1 + D-05, D-06, D-10a, D-10b | **APPROVED (2026-08-01)** — RLS gate review passed; §8 Q1–Q6 answered in `docs/p2_schema_rls_design.md`; **APPLY APPROVED (2026-08-01)** — ephemeral rehearsals PASSED (r2, re-confirmed on the R-4 slice in r4; 38 PASS + 2 RECORDED, twin gates green); decision in `docs/p2_apply_approval_2026-08-01.md`; **APPLY EXECUTED (2026-08-01)** — Up 1–5 GREEN on the dev project; evidence `docs/p2_apply_execution_2026-08-01.md`; **P2 CLOSED (2026-08-03)** — closed on the probe battery + r2/r4 rehearsals; §4.5 provider loop DEFERRED as documented residual risk (not executed, not passed — see `docs/p2_close_decision_2026-08-03.md`) | Project Owner (github.com/mostafasayed118) | 2026-08-01 |
| P3 — Auth + organization UX (loading/denial/offline/expiry/retry states, EN/AR/TR + RTL) | P2 | **PLAN APPROVED (2026-08-02)** — Gate 3 spec approved; plan: `docs/p3_auth_org_ux_plan.md` (implementation gated on per-step commit/approval per INSTRUCTIONS.md §3) | Project Owner (github.com/mostafasayed118) | 2026-08-02 |
| P4 — Security review + controlled rollout (threat model, dependency/config review, staging verification, rollback rehearsal, release approval) | P3 | Blocked | _OPEN_ | _OPEN_ |

An approval in this table is the "explicit implementation approval" of
contract §12. On a solo project this is still recorded explicitly (owner +
date) rather than assumed from the decisions above, to keep the paper trail
gate-3-reconciliation-style honest.

---

## 4. Open questions for the product owner — RESOLVED 2026-07-31

The five highest-leverage questions originally listed here are now answered;
see the corresponding decisions in §1:

1. **Product model (D-02):** ✅ multi-tenant law-firm client portal.
2. **Jurisdiction + policy owner (D-03):** ✅ N/A for demo scope; owner of
   record is the Project Owner.
3. **Provider project:** ✅ provisioned 2026-07-31 (`eu-central-1`); project
   ref kept in the local, git-ignored `.env` only — see §2.
4. **Auth policy (D-07):** ✅ email+password, email verification required,
   MFA/SSO deferred to v1.
5. **Permission matrix:** ✅ `docs/permission_matrix.md`.

Remaining open items are execution tasks (§2), not decisions.
