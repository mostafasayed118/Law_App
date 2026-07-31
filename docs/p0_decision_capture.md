# LegalHub — P0 Decision Capture (Pre-Backend)

> **Status: open.** This document is the artifact that gates every backend
> slice. It is *not* an answer key — it is a structured list of the questions
> that must be answered, with an owner and a recorded decision for each,
> before any Supabase package is added, any migration is written, or any RLS
> policy is shipped. Until every blocker below is marked **Decided**, the
> recommended executable action remains backend-free work (codebase-audit
> Batches 1–4); no backend code is written.
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
- **Owner:** _OPEN_
- **Decision:** _OPEN_
- **Decided on:** _OPEN_
- **Blocks slice:** P1 session model, P2 organization/membership schema, P3
  org-selection UX.
- **Evidence / notes:** _OPEN_

### D-03 — Jurisdiction and policy owner

- **Question:** Which counsel/compliance owner approves access rules,
  retention, consent, and high-risk workflow rules, and for which
  jurisdiction(s)?
- **Owner:** _OPEN_
- **Decision:** _OPEN_
- **Decided on:** _OPEN_
- **Blocks slice:** P1 (any auth/identity decision), all legal-workflow
  slices.
- **Evidence / notes:** _OPEN_

### D-04 — Data residency and cross-border transfers

- **Question:** Which Supabase region is approved, and what are the
  backup/cross-border processing constraints? Affects provider project
  selection and storage config.
- **Owner:** _OPEN_
- **Decision:** _OPEN_
- **Decided on:** _OPEN_
- **Blocks slice:** P1 (provider project selection), P2 (storage policies).
- **Evidence / notes:** _OPEN_

### D-05 — Retention, deletion, legal hold, export

- **Question:** What are the retention/deletion/legal-hold/export rules for
  identity, membership, documents, messages, audit records, and recovery
  data? Affects schema design, `DELETE` policy, and audit lifecycle.
- **Owner:** _OPEN_
- **Decision:** _OPEN_
- **Decided on:** _OPEN_
- **Blocks slice:** P2 (schema/migrations — `DELETE` is not assumed safe per
  contract §7), audit slice.
- **Evidence / notes:** _OPEN_

### D-06 — Human authority

- **Question:** Who may grant roles, approve exceptions, and review
  access/audit events? Defines the membership/invitation authority and the
  audit-reader scope.
- **Owner:** _OPEN_
- **Decision:** _OPEN_
- **Decided on:** _OPEN_
- **Blocks slice:** P2 (membership/invitation lifecycle), P3 (invitation UX),
  audit slice.
- **Evidence / notes:** _OPEN_

### D-07 — Authentication policy

- **Question:** Email verification, passwordless/OTP, MFA, SSO/SCIM, account
  recovery, rate limits, session TTL. Provider-backed behavior must be chosen,
  not assumed.
- **Owner:** _OPEN_
- **Decision:** _OPEN_
- **Decided on:** _OPEN_
- **Blocks slice:** P1 (auth adapter + session model), P3 (auth UX states).
- **Evidence / notes:** _OPEN_

### D-08 — Organization semantics

- **Question:** Who owns an organization, may users belong to multiple
  organizations, and how does organization switching work? Active org is a
  session context, not proof of membership — the switching rule must be
  specified.
- **Owner:** _OPEN_
- **Decision:** _OPEN_
- **Decided on:** _OPEN_
- **Blocks slice:** P1 (session model needs active-org context), P2
  (membership schema), P3 (org-switch UX).
- **Evidence / notes:** _OPEN_

### D-09 — Role semantics

- **Question:** Organization roles vs platform roles, multi-role support,
  admin scope (org admin vs platform operator), and the permission matrix
  for each approved MVP action. The six current roles are *candidates*, not
  a matrix.
- **Owner:** _OPEN_
- **Decision:** _OPEN_
- **Decided on:** _OPEN_
- **Blocks slice:** P1 (capability projection), P2 (membership.role), P3
  (role-gated UX).
- **Evidence / notes:** _OPEN_

### D-10a — Invitation policy

- **Question:** Inviter authority, expiry, resend/revoke, identity matching,
  email enumeration behavior, audit/notification rules.
- **Owner:** _OPEN_
- **Decision:** _OPEN_
- **Decided on:** _OPEN_
- **Blocks slice:** P2 (invitation lifecycle + token rules), P3 (invitation
  UX).
- **Evidence / notes:** _OPEN_

### D-10b — Support / operator access

- **Question:** Does any operator/support access exist? If so, require
  explicit approval, least privilege, consent/notice, time bounds, and
  audit. Default is *no* operator access.
- **Owner:** _OPEN_
- **Decision:** _OPEN_
- **Decided on:** _OPEN_
- **Blocks slice:** P2 (any platform-role policy), audit slice.
- **Evidence / notes:** _OPEN_

---

## 2. P1 readiness checklist (Definition of Ready for the first backend slice)

P1 is the first slice that may add `supabase_flutter` and write a provider
adapter behind the existing `AuthGateway` seam. It is ready only when **all**
of the following are true (mirrors contract §12):

- [ ] All blockers in the "Blocks slice: P1" set above (D-02, D-03, D-04,
      D-07, D-08, D-09) are **Decided**.
- [ ] A non-production Supabase project exists and its migrations, existing
      policies, functions, storage config, and CI conventions have been
      inspected. Record project ref/region: _OPEN_.
- [ ] A signed permission matrix exists covering **positive and negative**
      cases for each approved MVP action (contract §9). Location: _OPEN_.
- [ ] Data retention/deletion and audit requirements are documented for every
      data class touched by P1 (identity, session, membership). Location:
      _OPEN_.
- [ ] A rollback plan exists for the schema, policy, configuration, and
      client release. Location: _OPEN_.
- [ ] No production credentials or real client/legal data are used. Dev-only
      URL/anon config is injected via `--dart-define-from-file`; no
      service-role key ever reaches the Flutter client.
- [ ] Explicit implementation approval for P1 is recorded in this document
      (§3) with owner and date.

Until every box above is checked, P1 does not start. Adding `supabase_flutter`
before this checklist is complete is a contract violation, not a shortcut.

---

## 3. Slice map and approval log

The phased implementation proposal (contract §11), with the blocker set each
slice depends on and the approval record once granted.

| Slice | Depends on blockers | Status | Approved by | Date |
| --- | --- | --- | --- | --- |
| P0 — Decision capture (this doc) | — | In progress | — | — |
| P1 — Domain contracts + provider adapter (add `supabase_flutter`, adapter behind `AuthGateway`) | D-02, D-03, D-04, D-07, D-08, D-09 + §2 checklist | Blocked | _OPEN_ | _OPEN_ |
| P2 — Non-production schema + default-deny RLS/storage/realtime + narrow RPCs, with positive/negative policy tests | P1 + D-05, D-06, D-10a, D-10b | Blocked | _OPEN_ | _OPEN_ |
| P3 — Auth + organization UX (loading/denial/offline/expiry/retry states, EN/AR/TR + RTL) | P2 | Blocked | _OPEN_ | _OPEN_ |
| P4 — Security review + controlled rollout (threat model, dependency/config review, staging verification, rollback rehearsal, release approval) | P3 | Blocked | _OPEN_ | _OPEN_ |

An approval in this table is the "explicit implementation approval" of
contract §12. It is not granted by engineering alone; it requires the
product/security/privacy/counsel owner sign-off for that slice.

---

## 4. Open questions for the product owner (answer to unblock timeline)

These are the highest-leverage questions — answering even a few moves the P1
date:

1. **Product model (D-02):** firm, marketplace, client portal, or mix?
2. **Jurisdiction + policy owner (D-03):** who, and which jurisdiction(s)?
3. **Provider project (P1 checklist):** does a non-production Supabase
   project already exist? If yes, share the ref + region; if no, when can one
   be provisioned?
4. **Auth policy (D-07):** email+password minimum, or is OTP/SSO in scope for
   the first slice?
5. **Permission matrix (P1 checklist):** can product/security produce a
   positive+negative matrix for the six candidate roles for the first MVP
   actions?

Answering 1–3 even partially lets me start scoping P1's adapter shape without
writing any backend code.
