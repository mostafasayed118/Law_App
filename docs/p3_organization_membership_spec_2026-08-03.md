# LegalHub — P3 Organization & Membership Slice Spec (2026-08-03)

> **Record type:** The spec required by the governance gates before P3 UI work
> is authorized (permission_matrix / p0 decision-capture pattern): scope,
> RPC mapping, acceptance criteria, risks, and what this slice explicitly
> does NOT do. Data-layer foundation committed 2026-08-03; screens are a
> follow-up slice gated on this spec + approval.
> **Status: SPEC DRAFT — data-layer foundation implemented (2026-08-03);
> UI slice NOT started (needs approval on this spec).**
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Scope

Build the client surface for the applied P2 org/membership schema
(server-side source of truth, enforced by RLS + RPC guards, hardened
2026-08-03):

1. **Create organization** — name-only input; server makes the caller its
   initial partner (D-08).
2. **Member list** — roster with role + lifecycle status for the active org.
3. **Invite member** — email + assignable role; one-time token returned for
   out-of-band delivery (the server stores only the sha-256 hash; there is no
   email-sending integration — the partner copies the token).
4. **Change role / suspend / reactivate / remove** — partner-only, with the
   server-enforced last-active-partner guard.
5. **Data layer only (this batch):** domain models, gateway seam, Supabase
   PostgREST adapter, dev fake, DI flip, tests. **Screens are NOT in this
   batch** — they follow approval of this spec.

## 2. Boundary & authority

- The server is the authority: roles/statuses arrive from the RPC surface;
  `Session.primaryRole` stays a UX-only projection (never authorization).
- Provider types stay in `lib/data/orgs/` (the impl file holds the
  supabase import, mirroring the auth adapter); everything above the seam is
  provider-free.
- Only the three server-assignable roles (`client`, `attorney`, `partner`)
  can be requested; the wider `UserRole` enum (compliance officer, research
  analyst, admin) has no server counterpart and is rejected loudly.
- Unknown server role/status names fail loudly (FormatException → typed
  failure) — never a silently wrong role.

## 3. RPC mapping

| Operation | RPC | Client surface |
|---|---|---|
| Create org | `create_organization(p_name)` → uuid | `OrganizationGateway.createOrganization` |
| Member list | `list_members_metadata()` — **platform-owner-only** ⚠️ | `listMembers` (see risk R1) |
| Invite | `invite_member(org, email, role)` → token | `inviteMember` |
| Change role | `change_member_role(org, user, role)` | `changeMemberRole` |
| Suspend | `suspend_membership(org, user)` | `suspendMember` |
| Reactivate | `reactivate_membership(org, user)` | `reactivateMember` |
| Remove | `remove_membership(org, user)` | `removeMember` |

Error mapping: `permission denied` / self-removal → `denied`; existing-member
→ `duplicateMember`; last-partner → `lastPartner`; name-required →
`invalidName`; invalid invitation → `invalidInvitation` (future accept
slice).

## 4. Acceptance criteria (when the UI slice lands)

1. Partner creates org → appears as its only partner; name is trimmed;
   empty name rejected.
2. Invite: fresh email → token shown once (copy affordance); existing member
   email → typed duplicate error; non-partner invite attempt → denied.
3. Change role/suspend/remove: partner-only; last-active-partner operations
   blocked with the server message; remove self → denied (use account
   deletion).
4. Every server error surfaces as a localized, non-sensitive message; no
   provider exception ever reaches presentation.
5. Member list shows role + status chips, with suspended/removed visually
   distinct; invited rows appear for pending invites.

## 5. Risks & recorded decisions

- **R1 — member list RPC is platform-owner-only.** `list_members_metadata`
  is the platform_owner_admin surface; the member-facing roster RPC does not
  exist in P2 (matrix §2 D-T6 amend: no partner-profile-metadata RPC — Q5
  minimality). The gateway maps it today (works for the owner); a
  member-facing read is a server amendment (new RPC + rehearsal + apply) —
  recorded, not assumed.
- **R2 — no email integration.** Invites are token-based, delivered
  out-of-band by the partner. No GoTrue email trigger exists for invites; the
  server sends nothing. (Scope guard: adding invite emails is a separate
  slice touching provider config.)
- **R3 — invitation acceptance is deferred.** `accept_invitation(token)`
  wiring requires the token-entry UX decision and deep-link work; the
  failure kind (`invalidInvitation`) is already mapped at the gateway.
- **D1 — recovery flow decision (2026-08-03):** the 3-step OTP-style recovery
  UX stays as designed (B12); real GoTrue recovery uses an **email link with
  a PKCE code**, which requires deep-link registration (platform intent
  filters + auth callback + router handling) before it can be wired honestly.
  Until that slice exists, recovery remains demo-gated — no half-wired
  provider path that looks real but dead-ends.

## 6. Authorization

- Data-layer foundation: implemented under the owner's 2026-08-03 approval
  batch (no UI, no behavior visible to end users beyond the demo fake).
- UI slice: requires approval of this spec (governance pattern: spec →
  approval → implementation), then a follow-up batch.
