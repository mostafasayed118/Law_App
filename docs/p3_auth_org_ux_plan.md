# LegalHub — P3 Auth & Organization UX Plan (Specification Draft)

> **Record type:** The Gate 3 specification draft (per `INSTRUCTIONS.md` §3)
> for the **P3 delivery slice** — "Auth + organization UX" — as scoped in
> `docs/p0_decision_capture.md` §3 ("loading/denial/offline/expiry/retry
> states, EN/AR/TR + RTL") and `docs/auth_tenant_authorization_contract.md`
> §11-P3. It consumes the **applied** P2 slice (`3704a1d`, executed on the
> dev project per `docs/p2_apply_execution_2026-08-01.md`), so every server
> surface named here is **live on the dev project**, not hypothetical.
>
> **Status: PLAN APPROVED (2026-08-02).** The Project Owner approved this
> Gate 3 spec (ledger §14). Implementation is a separate slice requiring
> per-step commit/approval per `INSTRUCTIONS.md` §3. Nothing in this
> document changes code, the schema, or RLS.
>
> **Date:** 2026-08-02. **Owner:** Project Owner
> (github.com/mostafasayed118).
>
> **Governed by:** `docs/permission_matrix.md` (every row ≥1 positive + ≥1
> negative) · `docs/auth_tenant_authorization_contract.md` §2/§5/§7/§9/§11-P3 ·
> `docs/tracked_deviations.md` D-T5 (role enum divergence) + D-T6 (partner
> profile-metadata deferral) · `INSTRUCTIONS.md` §3 gates · `docs/adr/0003`
> (redaction contract), `0004` (ViewState vocabulary), `0006`
> (primary-container) · the applied `supabase/` slice.

---

## 1. Purpose & gate position

P3 turns the applied P2 backend into the product's first real auth +
organization experience. The client bootstrap (B1–B13) already ships the
scaffolded flows against **fake gateways**; P3 replaces those with real
provider-backed behavior over the applied schema, adds organization
selection and management UX for the signed-off actions, and closes the
session-lifecycle states (expiry → re-auth, denial, offline, retry).

| Gate step | Artifact | Status |
|---|---|---|
| P2 decision + approval | `docs/p0_decision_capture.md` §3 · `docs/p2_apply_approval_2026-08-01.md` | ✅ Approved 2026-08-01 |
| P2 apply executed (dev project) | `docs/p2_apply_execution_2026-08-01.md` (`3bcd968`) | ✅ Up 1–5 GREEN; **P2 closed 2026-08-03** — §4.5 provider loop DEFERRED (not executed; see `docs/p2_close_decision_2026-08-03.md`) (§3) |
| Client bootstrap (B1–B13) | current `lib/` + `test/` | ✅ Scaffolded auth/onboarding/home/settings on fakes |
| **P3 plan (this document)** | this document (`275724e` — approval recorded; draft `3bcd7b0`) | ✅ **APPROVED 2026-08-02** — Project Owner (ledger §14) |
| P3 implementation (P3.1 + P3.2 + P3.3 + P3.4 + P3.5 — real auth wiring + membership hydration + org-management re-hydration + invitation acceptance + platform-owner admin UX) | `lib/`, `test/` (code only — no schema/RLS changes) | **P3.1 SHIPPED 2026-08-05** (`2e18b24` merge, suite 717, ledger PASS 115; evidence `docs/p3_1_completion_evidence_2026-08-05.md`); **P3.2 SHIPPED 2026-08-05** (`24d5ec3`..`6a8f567`, suite 752, ledger PASS 115; evidence `docs/p3_2_completion_evidence_2026-08-05.md`); **P3.3 SHIPPED 2026-08-05** (`cda5aec`..`e603fb5`, suite 764, ledger PASS 115; evidence `docs/p3_3_completion_evidence_2026-08-05.md`); **P3.4 SHIPPED 2026-08-05** (`7548ade`..`e24a49e`, suite 770, ledger PASS 115; evidence `docs/p3_4_completion_evidence_2026-08-05.md`); **P3.5 SHIPPED 2026-08-05** (`47f777b`..`06d78a7`, suite 827, ledger PASS 115; evidence `docs/p3_5_completion_evidence_2026-08-05.md`) — the P3 plan is fully shipped |
| P3 verification (P3.1 + P3.2 + P3.3 + P3.4 + P3.5) | widget/integration tests EN/AR/TR + RTL + expiry + denial (contract §11-P3 exit) | **P3.1 VERIFIED 2026-08-05** — suite 717 incl. EN/AR/TR + RTL + denial (evidence §2/§4); **P3.2 VERIFIED 2026-08-05** — suite 752 incl. hydration / AC-3 expiry / failure diagnostics (evidence §2/§4); **P3.3 VERIFIED 2026-08-05** — suite 764 incl. hydrate() guards / epoch / DI shared-instance / hub create-flow trigger (evidence §2/§4); **P3.4 VERIFIED 2026-08-05** — suite 770 incl. accept re-hydration + org switch / pre-seed selection / audit copy EN-AR-TR (evidence §2/§4); **P3.5 VERIFIED 2026-08-05** — suite 827 incl. owner metadata lists / platform actions / non-owner denied-never-empty (AC-7) / never-self / EN-AR-TR (evidence §2/§4); live dev-project E2E owner-side (evidence §3) |

**Exit criteria (contract §11-P3):** widget/integration tests cover
EN/AR/TR, RTL, session expiry, and permission-denied behavior; navigation
capability maps remain labeled UX hints; server denial is rendered
distinctly from generic errors.

---

## 2. Scope

### In scope

1. **Real auth wiring (sign-in / sign-up / password recovery)** over the
   applied schema via the existing DTO-free seams (`AuthGateway`,
   `SupabaseAuthApi`, `SignUpGateway`, `PasswordRecoveryGateway`), with
   email-confirmation pending state (dev project has email confirmation
   **enabled** — apply evidence §6).
2. **Session membership hydration**: populate `Session.memberships` from
   the applied `memberships`/`organizations` SELECT surface (own rows +
   active-org rosters) — currently hard-coded to empty in
   `SupabaseAuthGateway._toSession`.
3. **Active-organization context + switching** (D-08): client-side UX
   convenience, persisted locally, **never an authorization claim**; every
   server request re-derives membership.
4. **Organization creation** (`create_organization`) and **member
   management UX** (partner-gated matrix §3 rows): invite, resend/revoke,
   change role, suspend/reactivate, remove — each calling the applied RPC,
   each rendering the server's typed denial distinctly.
5. **Invitation acceptance UX** (`accept_invitation` token entry) and
   **account deletion UX** (`delete_my_account`) with the generic-denial
   contract respected.
6. **Platform-owner admin UX** (matrix §5, owner-gated): list orgs, list
   members metadata, platform suspend/reactivate, delete demo account.
7. **Cross-cutting states**: `ViewState` loading/empty/error/offline/
   unauthorized + retry on every async screen; session-expiry → re-auth
   flow; EN/AR/TR + RTL; light/dark.

### Explicitly out of scope

- **Storage/realtime** (Q4 deferral — zero buckets/channels by design).
- **Matter/doc schema, messaging, billing, filings** (P2+/P4).
- **New RPCs** without a separate reviewed amendment slice (Q5 surface
  minimality). In particular **no partner profile-metadata RPC** in this
  slice — that is the forward hook recorded in the D-T6 resolution (matrix §2 addendum), not this plan (see §13 Q1).
- **Email/SMTP delivery of invitations or resets** — no email infra is
  approved; invite tokens are returned once to the inviter (server
  contract) and delivered out-of-band (copy/paste or share link).
- **Social sign-in** (Google/Apple buttons stay presentational).
- **Service-role keys, impersonation, audit editing, production/staging**
  — unchanged from P2.
- **Schema/RLS/migration changes** — P3 is client-only.

---

## 3. Dependencies & environment

| Dependency | State |
|---|---|
| Applied dev project (`eutmvevpskerzpqmwplv`) | ✅ Up 1–5 GREEN — the 17 applied P2 RPCs + Phase 3 R1 `list_org_members_metadata` (18 total) + policies + trigger are live |
| `.env` (URL + **anon** key, git-ignored) | ✅ owner-held; anon-key guard must stay in front of any provider wiring |
| P2 §4.5 **provider loop** (post-apply) | ✅ **P2 closed 2026-08-03; loop DEFERRED as documented residual risk** — not executed (no signup/email/confirm against the dev project); see `docs/p2_close_decision_2026-08-03.md`. P3 end-to-end verification runs against the applied schema with the provider loop deferred to P3, not re-opened as a P2 prerequisite. **RATIFIED 2026-08-05 (D-45.1):** completion plan in `docs/p2_provider_loop_decision_2026-08-05.md` — Phase 1 ephemeral rehearsal loop (zero external effect) first, Phase 2 dev-project smoke under a dated apply-approval once a controlled inbox exists |
| Provider behaviors observed at apply | email confirmation **enabled** (signup → pending state); sign-in returns `invalid_credentials` for unknown users; reset returns generic `200 {}` — P3 must handle each distinctly |

---

## 4. Server surface consumed (all applied, all live)

### Direct SELECT (RLS-scoped)

| Table | Policy | What the client may read |
|---|---|---|
| `profiles` | own-row (select/update `(display_name, locale)`) | own profile only — **no other member's name** (drives §13 Q1) |
| `organizations` | active member | orgs the caller is an active member of |
| `memberships` | `is_active_member(org)` **or** own row | own org rosters + own membership rows (status/role) |
| `invitations` | partner | own org's pending invites (partner only) |
| `audit_events`, `platform_config` | **no direct access** | RPC-only |

### RPCs (all `authenticated`-only EXECUTE; security definer)

| RPC | Signature (→ return) | Client actor | Matrix row |
|---|---|---|---|
| `create_organization` | `(name text) → uuid` | any signed-in | D-08 |
| `invite_member` | `(org uuid, email text, role org_role) → text` (literal token, shown once) | partner | §3 invite |
| `resend_invitation` | `(invite uuid) → void` | partner | §3 resend |
| `revoke_invitation` | `(invite uuid) → void` | partner | §3 revoke |
| `change_member_role` | `(org uuid, user uuid, role org_role) → void` | partner | §3 change role |
| `suspend_membership` / `reactivate_membership` | `(org uuid, user uuid) → void` | partner | §3 suspend/reactivate |
| `remove_membership` | `(org uuid, user uuid) → void` | partner (never self) | §3 remove |
| `accept_invitation` | `(token text) → uuid` | invitee (email must match JWT) | §2 / D-10a |
| `delete_my_account` | `() → void` | self | §2 delete own |
| `list_organizations_metadata` | `() → org list` | **owner only** | §5 |
| `list_members_metadata` | `() → id/name/locale/role/status` | **owner only** | §5 |
| `list_org_members_metadata` | `(org uuid) → member + pending-invite rows` | partner | §2 addendum (Phase 3 R1 — applied 2026-08-03; `display_name`/`locale` from `profiles` under the in-body guard; the roster `listMembers` routes here) |
| `suspend_membership_platform` / `reactivate_membership_platform` | `(org uuid, user uuid) → void` | **owner only** | §5 |
| `delete_demo_account` | `(user uuid) → void` | **owner only** (never self) | §5 |
| `read_org_audit` / `read_platform_audit` | `(org uuid) → rows` / `() → rows` | partner / owner | §6 |

**Key server contracts the client must respect:**
- `invite_member` returns the token **once**; only its sha-256 hash is
  stored — the client must show it immediately (one-shot share/copy), never
  attempt to re-read it.
- `accept_invitation` uses a **generic `invalid invitation` error** for
  every failure mode — the client must render one non-enumerating message.
- All mutation RPCs `raise exception 'permission denied'` server-side when
  the actor lacks the role — the client must treat that as the **denied**
  outcome (ViewUnauthorized / typed message), not a generic error.
- Signup trigger `handle_new_user` creates the `profiles` row from
  `raw_user_meta_data.display_name` (fallback: the full email, per `02_rls_functions.sql`) — so
  sign-up should send `display_name` in user metadata.
- `delete_my_account` writes the audit row before deleting the identity —
  the client flow must confirm destructiveness and then sign out locally.

---

## 5. Current client state (what P3 builds on)

> **Baseline note:** this table is the **pre-implementation** state at plan
> approval (2026-08-02) — e.g. "no sign-in/sign-up/reset methods" and
> `Session.memberships` hard-coded empty were true then, not now. Every row
> was changed by P3.1–P3.5 (see §1 gate table + the five evidence records);
> the table is retained as the historical starting point, not a
> description of current code.

| Area | Current | P3 change |
|---|---|---|
| `AuthGateway` / `SupabaseAuthApi` | restore / snapshot stream / signOut only; **no sign-in/sign-up/reset methods** | extend seam with DTO-free provider ops (§6 P3.1) |
| `SignUpGateway`, `PasswordRecoveryGateway` | fake impls registered unconditionally | real Supabase impls behind the same interfaces |
| `Session.memberships` | hard-coded empty (honest placeholder) | hydrated from `memberships`/`organizations` SELECT |
| `Session` model | ✅ contract-§5 shape (`userId/displayName/memberships/expiresAt`, no single client-owned role) | unchanged (already correct) |
| `AuthState` | initial/restoring/loading/authenticated/unauthenticated/reauthRequired/error | reused; reauth flow UI added |
| `ViewState` | loading/success/empty/error/offline/unauthorized (ADR-0004) | enforced on every async screen |
| Router | GoRouter redirects (UX-only) | add reauth guard + token-entry route |
| Screens | sign-in/up/recovery/onboarding/home/settings on fakes | real flows + org screens (§6) |
| Locale | EN/AR/TR + RTL (LocaleCubit + ARB) | extend ARBs with org/member strings |
| `roleCapabilities` | UX-only map, six `UserRole` values (D-T5) | **no schema change**; map 4 schema org roles onto the enum (client/attorney/partner/complianceOfficer); researchAnalyst/admin stay unused |

---

## 6. Proposed architecture & delivery slices

All P3 code follows the existing feature-first clean architecture
(domain → data → presentation), keeps Supabase DTOs below the data seams,
and registers via `service_locator.dart` with the same env-gated fake/real
pattern already used for `AuthGateway` (real when `.env` is configured,
fake otherwise, so tests and env-less runs keep working).

### P3.1 — Real auth wiring
- Extend `SupabaseAuthApi` (DTO-free) with: `signInWithPassword(email,
  password)`, `signUp(email, password, displayName)` (→ snapshot or typed
  failure incl. *pending email verification*), `resetPasswordForEmail`,
  `verifyOtp`, `updateUserPassword` — mapping GoTrue DTOs strictly below
  the seam, dropping tokens (contract §5, ADR-0003). The domain `AuthGateway` seam (the boundary `AuthCubit`/`SignInScreen` depend on) gains a matching DTO-free `signIn`; `startDemoSession` and the `FakeAuthGateway` remain the env-less and test fallback, exactly as today.
- Implement `SupabaseSignUpGateway` and `SupabasePasswordRecoveryGateway`;
  wire them in the service locator behind the existing interfaces.
- Rework `SignInScreen` (real submit → `AuthGateway` sign-in outcome:
  authenticated / invalid-credentials / provider-unavailable / expired),
  `SignUpScreen` (pending-verification success state — "check your email"),
  and the three-step recovery flow (generic non-enumerating responses).
- **Tests:** gateway mapping (DTO→domain, token-free), sign-up
  pending/denied/rate-limit, sign-in failure kinds, recovery generic
  responses.

### P3.2 — Membership hydration + active-org context
- New data repository (e.g. `MembershipRepository`) selecting the caller's
  memberships + org names (RLS-scoped), mapping to
  `OrganizationMembership` (role mapped to `UserRole` per D-T5; unknown
  schema roles → no capability projection). **Name-resolution note:** `organizations` SELECT is active-member-only, so `organizationName` resolves for active memberships; a suspended/removed membership's own row is visible but its org row is not — the client resolves names for active memberships and tolerates a null name for non-active ones.
- Hydrate `Session.memberships` on sign-in / restore — email-confirmed sign-up ends pending, so hydration starts at the post-confirmation first sign-in;
  keep the honest empty case when the provider reports none.
- `ActiveOrgCubit` (app-scoped): selected org id persisted via
  `SharedPreferences` (mirrors the `LocaleStore` pattern), defaulting to
  the first active membership; **no** authorization claim — every RPC call
  still passes the org id the server validates.
- **Tests:** hydration mapper (schema role ↔ `UserRole`, suspended/removed
  excluded from `activeMembership`), ActiveOrgCubit select/persist/restore.

### P3.3 — Organization management UX (partner)
- Org members screen (roster from `memberships` SELECT), invite dialog
  (`invite_member` — show the one-shot token in a copy dialog), pending
  invites list + resend/revoke (`invitations` SELECT + RPCs), member detail
  actions: change role / suspend / reactivate / remove — each RPC call
  rendered through `ViewState` with typed denial (server `permission
  denied` → distinct unauthorized message) and retry.
- **Tests:** roster render (positive/negative — cross-org roster invisible),
  invite success shows token once, revoke/resend, each mutation's denied
  and offline paths, EN/AR/TR + RTL.

### P3.4 — Invitation acceptance + account deletion
- `accept_invitation(token)` entry screen (paste or deep-link), rendering
  the single generic error for not-found/expired/revoked/email-mismatch;
  on success → re-hydrate memberships + switch to the new org.
- Delete-account flow with destructive confirmation → `delete_my_account`
  → local sign-out; audit-survives semantics explained in copy (not
  promised as data recovery).
- **Tests:** token entry success/denial (one message for all failures),
  delete confirmation → sign-out, RTL.

### P3.5 — Platform-owner admin UX
- Owner-only screens gated on the applied `list_organizations_metadata` /
  `list_members_metadata` responses and their typed denials (owner-only
  RPCs deny non-owners server-side → the client renders denied, never
  empty-success): orgs list, members metadata list, platform
  suspend/reactivate, delete demo account (never self).
- **Tests:** owner positive paths, non-owner → denied (not empty), EN/AR/TR.

### Cross-cutting (woven through every slice)
- Session expiry → `reauthRequired` → re-auth screen/dialog; no cached
  role/org restores access (matrix §2 negatives).
- Offline (`ViewOffline`) and retry on every async surface; denied vs
  generic-error message separation (contract §2.7).
- Accessibility: labels, focus order, touch targets, contrast, RTL
  mirroring, light/dark.
- Every new string in `app_en.arb`/`app_ar.arb`/`app_tr.arb`.

---

## 7. Auth & org state requirements (per flow)

| Flow | Loading | Success | Denied | Offline | Expiry/Retry |
|---|---|---|---|---|---|
| Sign-in | button spinner (exists) | → home (hydrated memberships) | invalid-credentials message; distinct from provider-unavailable | offline message + retry | expired session → reauth screen |
| Sign-up | spinner | **pending email verification** notice (not auto-auth) | duplicate/rate-limit/invalid typed distinctly, no enumeration | offline + retry | n/a |
| Recovery (3 steps) | per-step spinner | generic acknowledgement (no enumeration) | generic denial for wrong/expired OTP | offline + retry | token expiry → restart flow |
| Org switch | context spinner | active-org updated (persisted) | suspended/removed membership → no projection (not selectable) | offline + retry | reauth on expired session |
| Member actions (partner) | row spinner | typed success (audit implied server-side) | `permission denied` → distinct unauthorized | offline + retry | reauth |
| Accept invite | spinner | memberships re-hydrated, org switched | one generic `invalid invitation` message | offline + retry | reauth |
| Owner admin | list spinners | metadata rendered (metadata only — never matter content) | non-owner → denied, not empty | offline + retry | reauth |

---

## 8. Security, privacy & audit (unchanged commitments)

- **Client is never the authority:** role/capability maps stay UX hints;
  every server response (including `permission denied`) is rendered as
  returned. No client-supplied role/org/owner fields are trusted.
- **Redaction:** `SignUpRequest`/`PasswordRecoveryRequest` redaction
  contracts (ADR-0003) continue; no password/token/PII in diagnostics.
- **Tokens:** invite tokens shown once and never persisted/logged by the
  client; accept-token is transient in-memory only.
- **No new secrets:** anon key only; the anon-key guard stays first in the
  provider wiring path.
- **Audit:** P3 adds no audit writes of its own — the applied RPCs write
  redacted audit rows server-side; the client simply surfaces outcomes.

---

## 9. Accessibility & localization

- EN/AR/TR for every new string; direction-aware layout
  (`EdgeInsetsDirectional`, `AlignDirectional`), locale-aware dates.
- Light/dark from existing theme tokens; no hard-coded colors.
- Semantic labels, ≥48dp touch targets, destructive-action confirmation
  for remove/delete flows; color never sole status carrier.
- Existing ARB + l10n pipeline reused (`l10n.yaml`, generated
  localizations).

---

## 10. Acceptance criteria (Given/When/Then — extract)

1. **Sign-in (P3.1):** GIVEN valid credentials on the applied dev project,
   WHEN the user signs in, THEN an authenticated session is established and
   memberships hydrate. GIVEN wrong credentials, WHEN submitted, THEN the
   typed invalid-credentials message appears (never a generic error).
2. **Sign-up:** GIVEN email confirmation enabled, WHEN a new user signs up,
   THEN a pending-verification notice is shown and no session is created
   until the email is confirmed.
3. **Session expiry:** GIVEN an expired session, WHEN any protected action
   is attempted, THEN reauthRequired routes to re-auth and no cached
   role/org restores access.
4. **Tenant isolation (matrix §3):** GIVEN an org-a member, WHEN viewing
   rosters, THEN only org-a rows render; org-b rosters are invisible
   (0 rows / denied, never empty-success of the wrong org).
5. **Partner member actions:** GIVEN a partner, WHEN invite/resend/revoke/
   change-role/suspend/reactivate/remove is executed, THEN the RPC outcome
   renders with audit implied server-side; a non-partner executing the same
   action sees the distinct denied state.
6. **Invitation acceptance:** GIVEN a wrong/expired/revoked/foreign token,
   WHEN accepted, THEN the single generic `invalid invitation` message
   appears (no enumeration).
7. **Owner admin:** GIVEN the owner, WHEN listing orgs/members, THEN
   metadata-only rows render and every action is audited server-side;
   GIVEN a non-owner, THEN the denied state appears — not empty success.
8. **Localization/RTL:** GIVEN any P3 screen, WHEN locale is en/ar/tr, THEN
   strings resolve and layout mirrors correctly (AR RTL).
9. **Offline/retry:** GIVEN a failed network call, WHEN retry is tapped,
   THEN the action re-executes and the result replaces the error state.

---

## 11. Test plan

- **Unit:** auth API mapping (DTO-free boundary), sign-up/recovery gateways
  (pending/denied/rate-limit/generic), membership hydration mapper,
  ActiveOrgCubit, each org RPC call (success / `permission denied` /
  offline / generic).
- **Widget:** every P3 screen in EN + AR(RTL) + TR; loading/empty/error/
  offline/unauthorized/retry states; expiry → reauth; destructive
  confirmation; RTL mirroring assertions.
- **Integration (contract §9 client-assertable rows):** against the applied
  dev project, with the provider-level loop **deferred** per the P2 close
  decision (`docs/p2_close_decision_2026-08-03.md`) — env-gated tests cover
  sign-in-like client-assertable surface, sign-up pending is a UI state,
  org/switch, partner invite loop (real token → accept), non-partner denial,
  owner-only denial; the GoTrue signup → confirm → sign-in provider loop
  itself is re-attempted only if a controlled inbox exists.
- **Fakes vs real:** fakes (existing pattern) keep CI deterministic;
  provider-backed integration tests are env-gated like today.

---

## 12. Non-goals (recap)

No storage/realtime; no matter/doc/messaging/billing; no new RPCs (incl.
no partner profile-metadata RPC — that is the D-T6-resolution forward hook); no email/SMTP; no social sign-in;
no service-role keys; no schema/RLS/migration changes; no production/
staging; no real client/legal data.

---

## 13. Open questions / decisions needed from the owner

1. **Partner roster display names (D-T6-resolution forward hook).** The applied
   `profiles` policy is own-row-only, so a partner's org roster shows
   `user_id`/role/status but **no display names**. Options: (a) P3.3 ships
   without names (user ids only) and names wait for a **separate reviewed
   RPC amendment slice** (e.g. a partner-scoped member-metadata RPC — the
   D-T6-resolution forward hook), or (b) the owner approves that amendment slice as
   a P3 prerequisite. **Recommendation: (a)** — keep P3 client-only and
   surface names in a follow-up amendment, per Q5/D-T6. **RESOLVED
   2026-08-03 (R1):** the follow-up amendment shipped as Phase 3 R1 —
   `list_org_members_metadata` returns `display_name`/`locale` from
   `profiles` under the in-body guard (matrix §2 addendum); the P3.3
   roster renders names (see §4).
2. **Invitation delivery.** No email infra is approved; `invite_member`
   returns the token once for out-of-band delivery (copy/share link). Does
   the owner want an in-app "copy invite link" affordance only (default),
   or a separate email-delivery slice later? **RESOLVED (partial,
   2026-08-07):** the one-shot token ships with a copy affordance (P3.3
   paste surface) and the accept deep-link **consume** side shipped as
   Phase 4.1 D-P34.2; the invite-side **share-link generation** shipped as
   the follow-up slice (`b73add5` `AppLinkParser.acceptInviteUri` builder +
   localized copy keys, `2296e05`/`dcfb84b` "Copy invite link" button on
   the invite-success sheet) — `acceptInviteUri` produces
   `com.legalhub.app://accept-invite?token=…` from the same scheme/host
   constants the consume side classifies with, so every produced link
   round-trips as an `AcceptInviteIntent` with the identical token; email
   delivery stays out of scope.
3. **Active-org persistence.** Persist the selected org in
   `SharedPreferences` (default) vs session-only? (Either is fine — it is
   UX context, never authorization.) **RESOLVED 2026-08-05 (D-P32.2):**
   persisted via `SharedPreferences` (the `LocaleStore` pattern).
4. **Re-auth UX.** Dedicated re-auth screen vs inline dialog when a session
   expires mid-flow? (Default: dedicated screen routed from
   `reauthRequired`.) **RESOLVED 2026-08-05 (P3.1):** dedicated re-auth
   screen routed from `reauthRequired`.
5. **Delete-account placement.** Account deletion entry in Settings only,
   or also an in-flow option after failed verification? (Default: Settings
   only.) **RESOLVED 2026-08-05 (P3.4):** account deletion lives in the
   profile/settings surface with a destructive confirm, not an in-flow
   option.

---

## 14. Ledger / forward hooks

- **Plan approval recorded (2026-08-02):** Project Owner
  (github.com/mostafasayed118) approved this Gate 3 spec; the
  `docs/p0_decision_capture.md` §3 P3 row is flipped to **PLAN APPROVED**
  pointing here. Implementation is gated on per-step commit/approval per
  `INSTRUCTIONS.md` §3 — this record authorizes the plan decision, not a
  bundle of commits.
- **P2 closed (2026-08-03, owner decision):** §4.5 provider loop **deferred**,
  not executed — `docs/p2_close_decision_2026-08-03.md`. This plan's end-to-end
  verification (§3) runs against the applied schema with the loop deferred to a
  controlled-inbox exercise; it is not a P2-open prerequisite (§3). **RATIFIED
  2026-08-05 (D-45.1):** the loop-completion plan is `docs/p2_provider_loop_decision_2026-08-05.md`
  — Phase 1 ephemeral rehearsal loop first, Phase 2 dev-project smoke under a
  dated apply-approval once a controlled inbox exists.
- The D-T6-resolution forward hook (partner member display names) is tracked
  here (§13 Q1), not silently resolved inside this slice.
