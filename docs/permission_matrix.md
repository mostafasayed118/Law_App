# LegalHub — Permission Matrix (v1, MVP)

> **Record type:** The signed permission matrix required by
> `auth_tenant_authorization_contract.md` §9 and referenced as a P1-readiness
> precondition in `docs/p0_decision_capture.md` §2. Covers **positive and
> negative** cases per contract §9 — a passing happy path alone is not
> sufficient.
>
> **Status:** Drafted 2026-07-31, decisions per `p0_decision_capture.md`
> §1 (D-06, D-09, D-10a, D-10b) and its Addendum.
> **Enforcement:** every row here must be enforced **server-side** (RLS /
> RPC / policy) once P2 lands. Nothing in this document authorizes a
> client-only implementation of any row — client-side checks are UX hints
> only, per contract §2 non-negotiable #2.
> **Test contract:** every row must have at least one automated positive
> test and at least one automated negative test once P2 policy tests are
> written (contract §9).

---

## 1. Roles in scope

| Role | Scope | Held by |
|---|---|---|
| `client` | Own profile + explicitly assigned client-facing resources | Org members |
| `attorney` | Assigned matters + approved org functions | Org members |
| `partner` | Organization oversight, membership management | Org members |
| `compliance_officer` | Approved policy-review functions | Org members |
| `platform_owner_admin` | Cross-org identity/membership administration **only** — never matter content | **Project Owner's account only** (not assignable via product UI; see `p0_decision_capture.md` Addendum) |

Unauthenticated / no valid session is treated as a distinct row ("anon") in
every table below — this is the default-deny baseline (contract §2.1).

---

## 2. Identity & session actions

| Action | anon | client | attorney | partner | compliance_officer | platform_owner_admin |
|---|---|---|---|---|---|---|
| Sign up / sign in | ✅ | — | — | — | — | — |
| View own profile | ❌ deny | ✅ own only | ✅ own only | ✅ own only | ✅ own only | ✅ own only |
| Edit own profile | ❌ deny | ✅ own only | ✅ own only | ✅ own only | ✅ own only | ✅ own only |
| View **another** user's profile (any org) | ❌ deny | ❌ deny | ❌ deny | ✅ same org only | ❌ deny | ✅ any org (metadata only, see §5) |
| Delete own account | ❌ deny | ✅ | ✅ | ✅ | ✅ | ✅ |
| Sign out | ✅ (no-op) | ✅ | ✅ | ✅ | ✅ | ✅ |

**Negative tests required (contract §9 identity/session block):**
- No valid session → every non-sign-up/in row above denies, not empty-success.
- Expired/revoked session → re-auth required; a cached client role/org
  selection must **not** restore access.
- Reset request for unknown email → generic response, no enumeration signal.
- Reused/expired/foreign reset token → denied without exposing which part
  failed.
- Old session token reused after sign-out → denied.

---

## 3. Organization & membership actions

| Action | client | attorney | partner (own org) | compliance_officer | platform_owner_admin |
|---|---|---|---|---|---|
| View own org's member list | ✅ | ✅ | ✅ | ✅ | ✅ (any org) |
| View **another** org's member list | ❌ deny | ❌ deny | ❌ deny | ❌ deny | ✅ (metadata only) |
| Invite a new member | ❌ deny | ❌ deny | ✅ | ❌ deny | ❌ deny |
| Resend / revoke a pending invite | ❌ deny | ❌ deny | ✅ (own org's invites) | ❌ deny | ❌ deny |
| Change a member's role | ❌ deny | ❌ deny | ✅ (own org) | ❌ deny | ❌ deny |
| Suspend / reactivate a membership | ❌ deny | ❌ deny | ✅ (own org) | ❌ deny | ✅ (any org, metadata-level action) |
| Remove a member | ❌ deny | ❌ deny | ✅ (own org) | ❌ deny | ❌ deny |
| Delete a synthetic demo account | ❌ deny | ❌ deny | ❌ deny | ❌ deny | ✅ |
| Switch active organization (own memberships) | ✅ | ✅ | ✅ | ✅ | n/a (no org membership) |

**Negative tests required (contract §9 tenant/membership block):**
- An active `org-a` member cannot read/write/subscribe-to/download `org-b`
  data by changing a request parameter — proven for **every** action row
  above, not just reads.
- A suspended/removed/expired membership cannot authorize any protected
  path, even if the client's cached session still shows the old role.
- A user with two active memberships cannot touch the second org without
  explicitly selecting a valid context; selection never bypasses the
  membership check.
- Client-supplied `organization_id`, `role`, `owner_id`, `approved_by`, and
  audit-actor values cannot elevate access or cross tenant boundaries.
- `partner` in `org-a` cannot invite/change-role/suspend/remove a member of
  `org-b`.

---

## 4. Matter & document actions (P2+, scaffolded now for completeness)

| Action | client | attorney | partner | compliance_officer | platform_owner_admin |
|---|---|---|---|---|---|
| View a matter | ✅ if assigned as the client on it | ✅ if assigned to it | ✅ org policy-approved oversight only, not blanket | ✅ policy-review scope only | ❌ **deny, always** |
| Read a document/message body | ✅ if assigned | ✅ if assigned | ❌ deny unless separately assigned | ❌ deny unless separately assigned | ❌ **deny, always** |
| An org role alone (no matter assignment) | ❌ deny | ❌ deny | ❌ deny | ❌ deny | ❌ deny |

**Negative tests required (contract §9 role/nested-scope block):**
- An org role without an explicit matter assignment cannot read a
  restricted matter or its documents/messages — true for **every** role,
  including `partner` and `compliance_officer`.
- A matter in `org-a` cannot be accessed by an otherwise-authorized member
  of `org-b`.
- `platform_owner_admin` attempting to read any matter/document/message
  content must be denied at the RLS layer, not just hidden in the UI — this
  is the row that most directly guards against admin-capability creep.
- Role changes take effect on the **next** authorization check; a role
  change leaves an audit record; stale client capability state is never
  authoritative.

---

## 5. `platform_owner_admin` — explicit boundary (contract §2 #2, #4)

This role exists to let the Project Owner administer synthetic/demo data for
the portfolio project. Its boundary is intentionally narrow and is repeated
here as a standalone checklist because it is the highest-risk row in this
matrix (a single powerful account):

- ✅ May: list orgs, list members + their identity/membership metadata
  (name, email, role, status, timestamps), suspend/reactivate a membership,
  delete a demo account.
- ❌ May never: read matter/document/message content, impersonate another
  user's session, edit or delete an audit record, act on any table other
  than identity/membership metadata.
- Every action produces an audit record (contract §8) with the
  `platform_owner_admin` actor reference — **it is not exempt from
  auditing just because it's the owner's own account.**
- Enforced server-side only (RLS/RPC); a client-side "isOwner" flag is a UX
  affordance, never the authorization boundary.

**Negative test required:** an authenticated session bearing the
`platform_owner_admin` capability but attempting to read a document/message
row must be denied by policy, identically to any other unauthorized role —
this is the row's own worst-case test and must exist before P2 ships.

---

## 6. Storage / realtime / audit (contract §9 storage block)

| Scenario | Expected result |
|---|---|
| Download a private object via a guessed path | Denied |
| Reuse a stale signed URL after membership removal | Denied |
| Realtime subscription for an org/matter the session no longer has access to | No events delivered |
| Membership or sensitive-access change | Produces an attributable, redacted audit record (no credentials/content) |
| Read the audit table | Scope-checked per reader's role; audit table is never publicly readable, and `platform_owner_admin` reading it is itself an audited action |

---

## 7. Sign-off

| Role | Name | Date |
|---|---|---|
| Product / Project Owner | github.com/mostafasayed118 | 2026-07-31 |

This matrix satisfies the "signed permission matrix... positive and negative
cases" precondition in `p0_decision_capture.md` §2. It must be extended (not
replaced) as new MVP actions are approved — do not silently widen an
existing row without a dated addendum, per the same discipline used in
`gate3_reconciliation.md`.
