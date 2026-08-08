# LegalHub — Feature Roadmap Record (2026-08-03)

> **Record type:** The dated roadmap for post-`006fd62` feature work. It
> inventories what is shipped, what the repo's own docs already declare as
> the next slice, which committed server RPCs have **no** client surface yet
> (the unwired-RPC inventory), and the governance gate each phase must pass
> before implementation is authorized. It is a *planning record*, not an
> approval: no phase below starts until its gate row is satisfied and the
> owner records approval per `INSTRUCTIONS.md` §2.1.
>
> **Status: ACTIVE (2026-08-03).** Phase 1 (P3 org/membership UI) **SHIPPED
> 2026-08-03** (`03862ce`, suite 408, ledger PASS 115). Phase 2 (org
> lifecycle wiring) is **APPROVED 2026-08-03** (scope note
> `docs/p3_phase2_scope_2026-08-03.md`), implementation in progress as
> slices 2.1–2.4. Phase 3 (server amendments) R1 is **IMPLEMENTED AND
> APPLIED 2026-08-03** (R1 design
> `docs/p3_r1_roster_rpc_design_2026-08-03.md` + matrix §2 addendum +
> rehearsal plan `docs/p3_r1_rehearsal_plan_2026-08-03.md` + forward
> artifact `supabase/rpc/list_org_members_metadata.sql` + one-line
> `_down.sql` drop; rehearsal r1 **PASSED** — evidence
> `docs/p3_r1_rehearsal_evidence_r1_2026-08-03.md` — then applied to the
> dev project on the owner's dated apply approval 2026-08-03).
> Phase 4: 4.2 (sign-up email-verification UX) **SHIPPED 2026-08-03**
> (`deb72d8`); 4.1 (deep-link recovery) **APPROVED + IMPLEMENTED
> 2026-08-03** (scope note `docs/p4_41_deeplink_recovery_scope_2026-08-03.md`),
> committed with this roadmap's gate-table row. **4.1 accept-invitation
> deep link (D-P34.2) SHIPPED 2026-08-07** (`95c1676`..`58134f6` on
> `feat/p4-1-accept-deeplink`, suite 850, ledger PASS 115 — evidence
> `docs/p4_1_completion_evidence_2026-08-07.md`). The P3 auth & org UX plan's
> **P3.1 (real auth wiring — sign-in / sign-up / password recovery) is
> SHIPPED 2026-08-05** (`2e18b24` merge, suite 717, ledger PASS 115;
> evidence `docs/p3_1_completion_evidence_2026-08-05.md`) — typed
> `SupabaseAuthApi` seam + localized recovery UX. **P3.2 (membership
> hydration + active-org context) SHIPPED 2026-08-05**
> (`24d5ec3`..`6a8f567`, suite 752, ledger PASS 115; evidence
> `docs/p3_2_completion_evidence_2026-08-05.md`) — RLS-scoped
> `Session.memberships` hydration + persisted active-org selection.
> **P3.3 (org-management re-hydration on the hydrated memberships) SHIPPED
> 2026-08-05** (`cda5aec`..`e603fb5`, suite 764, ledger PASS 115; evidence
> `docs/p3_3_completion_evidence_2026-08-05.md`) — `AuthCubit.hydrate()`
> background refresh seam + shared fake org state + hub create-flow trigger.
> **P3.4 (invitation acceptance + account deletion) SHIPPED 2026-08-05**
> (`7548ade`..`e24a49e`, suite 770, ledger PASS 115; evidence
> `docs/p3_4_completion_evidence_2026-08-05.md`) — accept success
> re-hydrates + switches to the new org (D-P33.3 consummated) and the
> delete-confirm states audit-survives semantics.
> **P3.5 (platform-owner admin UX) SHIPPED 2026-08-05**
> (`47f777b`..`06d78a7`, suite 827, ledger PASS 115; evidence
> `docs/p3_5_completion_evidence_2026-08-05.md`) — the applied owner-only
> metadata RPCs' first consumer: orgs + members lists, platform
> suspend/reactivate, delete demo account (never self), non-owner →
> distinct denied, never empty-success (AC-7) — completing the P3 plan.
> Phase 5 (consultation booking, MVP, no live payment) **IMPLEMENTED AND
> SHIPPED 2026-08-03** (`05f13c8` slice 5.0 land the shelved layer; `0eb7ec9`
> slices 5.1–5.2 screen + route + capability entry + l10n; `3bd3d29` slice
> 5.3 l10n pin; `d55e273` README sync to 521) — the `feat/booking-flow`
> layer was previously **shelved** (spec-listed §4 MVP but headless;
> unverifiable approval citations in its code comments; 60 main commits of
> divergence), landed per the gate-table row below and the decision record
> in `docs/booking_scope_2026-08-03.md` (D-B1…D-B7 ratified, D-B7 standalone).
> Phase 6 (attorney discovery, read-only) **IMPLEMENTED AND SHIPPED
> 2026-08-03** (`0f93042` slice 6.1 gateway seam + search surface; `7b5c589`
> slice 6.2 profile + book-from-profile prefill; `d389c69` slice 6.3 l10n
> pins) — per the gate-table row below and the decision record in
> `docs/attorney_discovery_scope_2026-08-03.md` (D-A1…D-A6 ratified, incl.
> the D-B7 additive `attorneyId` booking hook).
> Phase 7 (matter dashboard, read-first, client-only) **IMPLEMENTED AND
> SHIPPED 2026-08-03** (`b31bc1a` slice 7.0 ActiveOrgStore + org switcher;
> `5740594` slice 7.1 gateway seam + fake + list surface; `82d77dc` slice
> 7.2 read-only details; `c2cf3cb` slice 7.3 l10n pins) — per the
> gate-table row below and the decision record in
> `docs/matter_dashboard_scope_2026-08-03.md` (D-M1…D-M7 ratified, incl.
> the D-M7 active-org switcher per D-08).
> Phase 8 (document vault, read-first, metadata-only, client-only)
> **IMPLEMENTED AND SHIPPED 2026-08-03** (`22d63e5` slice 8.0 gateway seam
> + fake + metadata VO; `29fd40a` slice 8.1 vault list + type chips +
> entry; `430b62b` slice 8.2 l10n pins) — per the gate-table row below and
> the decision record in
> `docs/document_vault_scope_2026-08-03.md` (D-V1…D-V6 ratified, incl. the
> metadata-only line — no document bodies ever exist).
> Phase 9 (matter-scoped messaging, thread-metadata-only, client-only)
> **IMPLEMENTED AND SHIPPED 2026-08-04** (`b0de147` slice 9.0 gateway +
> thread VO; `64e6b51` slice 9.1 thread list + `/messages` route + entry;
> slice 9.2 l10n pins) — per the scope note
> `docs/matter_messaging_scope_2026-08-03.md` (D-MSG1…D-MSG6 ratified, incl.
> the body-less line — no message body ever exists).
> Phase 10 (matter workspace, read-first, client-only) **IMPLEMENTED AND
> SHIPPED 2026-08-04** (`90465df` slice 10.0 matterRef + fake rows;
> `31f0624` slice 10.1 workspace sections + per-matter filtering;
> slice 10.2 l10n pins) — per the scope note
> `docs/matter_workspace_scope_2026-08-04.md` (D-W1…D-W6 ratified, incl.
> the per-matter `Document.matterRef` association).
> Phase 11 (unified search, read-first, client-only, aggregating)
> **IMPLEMENTED AND SHIPPED 2026-08-04** (`7c8ead8`: slice 11.0
> `SearchResults`/`SearchState`/`SearchCubit` composing the four gateway
> seams; slice 11.1 `/search?q=…` route + capability-gated grouped surface
> + home search-field wiring; slice 11.2 l10n pins) — per the scope note
> `docs/unified_search_scope_2026-08-04.md` (D-S1…D-S6 ratified, incl. the
> client-side aggregation over the Phase 6–10 gateway seams; suite 691;
> pushed to `origin/main`).
> Phase 12 (reverse cross-link, read-first, client-only) **slice 12.0
> SHIPPED 2026-08-05** (`16e9b67`: vault rows' "View matter" chip — the
> only tap target in the list, D-C2 — via the title-keyed client-side
> resolver, D-C1/D-C3, gated by the `canViewMatters` nav hint, D-C4; l10n
> `viewMatter` EN/AR/TR; suite 701 / README 698; ledger PASS 115; pushed
> to `origin/main`); slice 12.1 (messages reverse link) SHIPPED 2026-08-05
> (`69622ce`, suite 705/README 702, committed; push awaits owner approval);
> slice 12.2 (l10n) SHIPPED 2026-08-05 (`cd5c903`: the AC-5
> per-locale resolution pin for `viewMatter` in
> `app_localizations_test.dart` — exact EN/AR/TR copy +
> no-silent-EN-copy asserts; suite 706/README 703; committed; push
> awaits owner approval), closing Phase 12
> `docs/reverse_crosslink_scope_2026-08-04.md`
> (D-C1…D-C6 ratified 2026-08-05).
> Everything in §14 stays deferred until P0 closes.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/p3_organization_membership_spec_2026-08-03.md` ·
> `docs/p0_decision_capture.md` §1/§3 · `docs/permission_matrix.md` (dated
> addendum discipline, §7) · `docs/codebase_audit_plan.md` (forward hooks) ·
> `docs/tracked_deviations.md` (D-T5, D-T6) · `docs/adr/0007` ·
> `INSTRUCTIONS.md` §2.1/§3 · `scripts/verify_ledger.sh` + `.github/workflows/ci.yml`
> (the B2 gate stack).

---

## 1. Current state (baseline `006fd62`, 2026-08-03)

Shipped and CI-green (355 tests, `flutter analyze` clean, format gate clean,
ledger gate PASS — 114 checks, 0 warnings, 0 failures on `006fd62`):

- **Auth:** sign-in, sign-up (email verification enabled), forgot-password
  (email → OTP → reset) — real Supabase GoTrue behind the
  `AuthGateway`/`SignUpGateway`/`PasswordRecoveryGateway` seams, DI-flipped
  on `env.isConfigured`; dev fakes for env-less runs and tests.
- **Onboarding, home, settings, notifications, profile** presentation with
  EN/AR/TR l10n, RTL, persisted locale, capability-aware shell navigation
  (shell-nav arc complete `8092f0e`–`4b5e4fc`).
- **P3 org/membership data layer** (`bf4c953`): `OrganizationGateway` seam +
  Supabase PostgREST adapter (`lib/data/orgs/`) + dev fake mirroring the
  last-active-partner and existing-member guards + DI flip. **Screens are
  NOT built** — explicitly declared a follow-up slice in the P3 spec §1/§6.
- **Code-based password recovery** (`c2496df`, D1 revised): send OTP →
  verify OTP → change password behind the seam, non-enumerating ack,
  redaction-safe diagnostics.

The README's deliberate product boundary stands: the demo session, route
redirects, and role capability map are **not security controls**; anything
beyond identity/membership metadata requires server-side authorization and
policy tests before it is exposed here.

## 2. Unwired-RPC inventory (client surface vs. committed server RPCs)

`supabase/rpc/` ships 17 applied P2 RPCs plus the applied Phase 3 R1
`list_org_members_metadata` (18 applied, §5) plus the committed-not-applied
`send_message` (19 committed, §14 eighth un-deferral); **18 of 18 applied
RPCs have a client surface**, and the 19th (`send_message`, the audited
send path) is wired client-side behind the env flip — **applied to the
dev project 2026-08-08** (send-message slice T5: the function is live
with the D-SM3 revocation, policies 10→9, `authenticated` INSERT
revoked, §8 audit by construction) —
`SupabaseOrgApi` maps 11 (`listMembers` routes to the R1
member-facing RPC) and `SupabasePlatformAdminApi` (P3.5, `47f777b`; the
audit surfacing slice adds the two audit reads, SHIPPED 2026-08-08) maps
the five P3.5 owner-only RPCs + `read_org_audit` (org-scoped, partner-capable
server-side, owner-only first surface) + `read_platform_audit`
(`platform_owner_admin`-only).
Each row names the owning phase below (or the gate that blocks it).

| RPC (`supabase/rpc/`) | Wired in client today? | Owning phase | Notes |
|---|---|---|---|
| `create_organization` | ✅ `createOrganization` | — | shipped |
| `list_members_metadata` | ✅ `listMembers` | P3.5 owner surface (`47f777b`) | platform-owner-only; the app roster uses the R1 RPC below; the platform-admin screen consumes this RPC |
| `list_org_members_metadata` | ✅ `listMembers` | Phase 3 (R1, applied) | **member-facing roster** — partner-scoped (design §8 client slice) |
| `invite_member` | ✅ `inviteMember` | — | shipped |
| `change_member_role` | ✅ `changeMemberRole` | — | shipped |
| `suspend_membership` | ✅ `suspendMember` | — | shipped |
| `reactivate_membership` | ✅ `reactivateMember` | — | shipped |
| `remove_membership` | ✅ `removeMember` | — | shipped |
| `resend_invitation` | ✅ `resendInvitation` | Phase 2 | partner-only per D-10a / matrix §3; `invalidInvitation` kind already mapped |
| `revoke_invitation` | ✅ `revokeInvitation` | Phase 2 | partner-only per D-10a / matrix §3 |
| `accept_invitation` | ✅ `acceptInvitation` | Phase 2 (UX decision) / Phase 4 (deep link) | **R3** in the P3 spec; token-entry UX decided (accept screen); the deep-link variant is **SHIPPED** (Phase 4.1 D-P34.2, 2026-08-07) |
| `delete_my_account` | ✅ `deleteMyAccount` | Phase 2 | D-05 requires the hard-delete action (cascade identity + memberships) |
| `list_organizations_metadata` | ✅ `listOrganizations` | P3.5 owner surface (`47f777b`) | **also SHIPPED via the client-side path** — the active-org switcher (Phase 7 slice 7.0, `b31bc1a`) reads `Session.memberships` + the `ActiveOrgStore` per D-08/D-M7 (server re-derives membership; never trusts a client-selected org id); the RPC now feeds the platform-admin orgs list |
| `read_org_audit` | ✅ `readOrgAudit` | audit surfacing (fifth §14 un-deferral, `56414a6`/`b0f9022`) | org-scoped audit via the platform-admin Audit section's org selector; redacted-only (contract §8), D-P0C4 (no raw SELECT on `audit_events` ever); owner-only first surface, partner org-audit UI a follow-up |
| `read_platform_audit` | ✅ `readPlatformAudit` | audit surfacing (fifth §14 un-deferral, `56414a6`/`b0f9022`) | owner-gated cross-org audit via the platform-admin Audit section; audit table never publicly readable (matrix §6) |
| `delete_demo_account` | ✅ `deleteDemoAccount` | P3.5 owner surface (`47f777b`) | `platform_owner_admin`-only; the platform-admin screen deletes demo accounts (never self); the server raise `cannot delete your own account` maps to a typed denial |
| `suspend_membership_platform` | ✅ `suspendMembership` | P3.5 owner surface (`47f777b`) | `platform_owner_admin`-only; platform-admin suspend toggle |
| `reactivate_membership_platform` | ✅ `reactivateMembership` | P3.5 owner surface (`47f777b`) | `platform_owner_admin`-only; platform-admin reactivate toggle |
| `send_message` | ✅ `sendMessage` (audited write path, `f874a57`) | send-message slice (eighth §14 un-deferral, `7759181`..`f874a57`) | **applied 2026-08-08** (T5 execution: function live — `security definer`, in-function D-SM1 gate — EXECUTE to `authenticated` only, **D-SM3 revocation** → policies 10→9, `authenticated` INSERT false, `messages_insert_assigned` dropped; §8 audit by construction; demo send `1c031882-…` with the audit row observed) |

## 3. Phase 1 — P3 org & membership UI slice (next approved batch)

**Gate:** owner approval of `docs/p3_organization_membership_spec_2026-08-03.md`
(recorded in `docs/p0_decision_capture.md` §3 P3 row and/or a dated approval
record), then one implementation slice per `INSTRUCTIONS.md` §2.1 with the
full B2 gate stack at the end. **Slices 1.1–1.6 implemented 2026-08-03**
(`org_cubit` + `create_organization_screen` + `member_roster_screen` +
`invite_member_sheet` + `organization_hub_screen` + router/shell wiring +
1.6 EN/AR/TR strings).

| # | Slice | Scope | New files (sketch) | Tests |
|---|---|---|---|---|
| 1.1 | Create organization | Name-only form; trimmed; empty rejected; route to roster on success | `features/orgs/presentation/org_cubit.dart`, `create_organization_screen.dart` | cubit emissions (loading→success/error, invalidName), screen EN/AR |
| 1.2 | Member roster | List with role + lifecycle-status chips; suspended/removed visually distinct; invited rows for pending invites | `member_roster_screen.dart` | chip rendering, status styling, error surface |
| 1.3 | Invite member | Email + role selector (client/attorney/partner only); one-time token shown **once** with copy affordance | `invite_member_sheet.dart` | duplicateMember → typed error; invalidRole blocked client-side; token copy |
| 1.4 | Member actions | Change role / suspend / reactivate / remove; partner-only; last-partner guard surfaced; self-remove denied | actions wired into roster rows | `lastPartner`/`denied` surfaces, confirmation flows |
| 1.5 | Router + shell wiring | Org routes + capability-aware destinations; active-org context from `Session.activeMembership` | `router.dart`, shell | redirect + capability-combination tests |
| 1.6 | l10n | All new user-facing strings EN/AR/TR (repo rule: no hardcoded strings) | 3 `.arb` + generated l10n | TR/AR resolution pins |

**Acceptance criteria are already written in the P3 spec §4** (create-org
appears as its only partner; duplicate invite → typed error; last-partner
ops blocked with the server message; every server error → localized
non-sensitive message; roster shows role + status chips). **Exit:**
`bash scripts/verify_ledger.sh` + `dart format --output=none
--set-exit-if-changed .` + `flutter analyze` + `flutter test` all green,
suite grows to ~430+ (408 on 2026-08-03, up from 355), README coverage
count updated, no push without owner approval.

## 4. Phase 2 — Close the org lifecycle gaps (client wiring of existing RPCs)

**Gate:** standard slice gate (spec-lite scope note + approval, gate stack,
no server changes). Pure client work — every RPC below is already committed,
rehearsed, and applied (`3704a1d`).

- **2.1 Resend / revoke invite** — wire `resend_invitation` /
  `revoke_invitation` into `SupabaseOrgApi` + `OrganizationGateway` + fake;
  partner-only guard, `invalidInvitation` surfaced. Matrix §3 rows exist.
- **2.2 Delete own account** — wire `delete_my_account` (D-05); profile-screen
  action with redaction-safe confirm; fake mirrors cascade. Matrix §2 row.
- **2.3 Active-org switcher** — **SHIPPED as Phase 7 slice 7.0** (`b31bc1a`,
  `ActiveOrgStore` + switcher sheet listing `Session.memberships`, D-08/D-M7).
  Owner path: `list_organizations_metadata` (now also the platform-admin
  orgs list, P3.5 `47f777b`; the switcher itself still reads
  `Session.memberships`, and the server re-derives membership per D-08 —
  never trusts a client-selected org id).
- **2.4 Invitation acceptance (R3)** — **SHIPPED 2026-08-03** as part of
  `68aafc6` (slices 2.1–2.4): the token-entry **paste screen** decision was
  taken and built — `accept_invitation_screen.dart` + `/accept-invitation`
  route + settings entry, wired through `OrganizationGateway.acceptInvitation`
  (`invalidInvitation` mapped). The deep-link variant remains Phase 4
  follow-up if approved.

## 5. Phase 3 — Requires server amendments (spec → rehearsal → apply)

**Gate:** full P2 discipline — spec record, RLS-gate design review
(`docs/p2_schema_rls_design.md` §8 pattern), ephemeral rehearsal with
evidence (r-series), dated apply-approval record, apply execution with
rollback pairing (`docs/rollback_plan.md`), and — because every row below
**widens the approved client surface** — a dated matrix addendum per
`docs/permission_matrix.md` §7 **before** it ships.

**Design status (2026-08-03):** R1 is **APPROVED + IMPLEMENTED + APPLIED
2026-08-03** — `docs/p3_r1_roster_rpc_design_2026-08-03.md`
(signature, SECURITY DEFINER justification, R-4 grant analysis, RLS negative
cases, rollback pairing), the matrix §2 addendum (2026-08-03),
`docs/p3_r1_rehearsal_plan_2026-08-03.md` (executed; evidence
`docs/p3_r1_rehearsal_evidence_r1_2026-08-03.md` — r1 **PASSED**, finding A1
folded in), and the forward artifact `supabase/rpc/list_org_members_metadata.sql`
+ one-line `_down.sql` drop. **Applied to the dev project on 2026-08-03**
on the owner's dated apply approval (18 slice RPCs; grant matrix verified;
backout in place).

- **3.1 Member-facing roster RPC (R1)** — `list_members_metadata` is
  platform-owner-only; a partner-visible roster needs a new RPC + policy
  tests. Recorded as R1 in the P3 spec §5, **not assumed**. **APPROVED +
  IMPLEMENTED + APPLIED 2026-08-03**: `list_org_members_metadata(p_organization_id)`
  — partner-scoped, unions pending `invitations` with `invitation_id` (the
  Phase 2.1 R1 extension), returns display_name/locale from `profiles` under
  the in-body guard; added as `supabase/rpc/list_org_members_metadata.sql`
  (+ one-line `_down.sql` backout), **applied to the dev project 2026-08-03**
  after rehearsal r1 passed (evidence record). **Client slice shipped**:
  `listMembers` routes to this RPC with the invited-row mapping (email
  identity + real `invitation_id`, design §8) — `SupabaseOrgApi` seam maps 11
  of 18 RPCs.
- **3.2 Display-name RPC (audit-plan forward hook 1)** — partners need
  member display names; `profiles` is own-row-only (D-T6). Separate reviewed
  RPC decision; requires the dated matrix addendum first. **ABSORBED into
  3.1 (2026-08-03 design decision)** — the single partner-scoped metadata
  RPC covers display names (Q5 surface minimality, matrix §2 addendum
  2026-08-03); no separate RPC.
- **3.3 Invite emails (R2)** — GoTrue email trigger on invite; touches
  provider config. Separate slice; out-of-band token delivery remains the
  shipped behavior until then.

## 6. Phase 4 — Auth plumbing

- **4.1 Deep-link recovery (original D1 half)** — the link-based + PKCE
  variant: platform intent filters (Android manifest / iOS), the Supabase
  auth callback/deep-link observer, and router + cubit recovery-pending
  handling. **APPROVED + IMPLEMENTED + COMMITTED 2026-08-03** (scope note
  `docs/p4_41_deeplink_recovery_scope_2026-08-03.md`). R1 (dashboard Redirect
  URL) remains owner-side and is tracked as R3 in the P3 spec. The
  **accept-invitation deep link (D-P34.2)** — parsing
  `com.legalhub.app://accept-invite?token=<one-time-token>`, buffering via
  `PendingAcceptInviteStore`, and pre-filling the accept screen (no
  auto-submit) — is **SHIPPED 2026-08-07** (`95c1676`..`58134f6` on
  `feat/p4-1-accept-deeplink`, suite 850; plan
  `docs/p4_1_deeplink_recovery_plan_2026-08-07.md`, evidence
  `docs/p4_1_completion_evidence_2026-08-07.md`).
- **4.2 Sign-up email-verification UX** — verification is enabled
  server-side; today the flow silently routes to sign-in after sign-up. A
  "check your inbox" state closes the false-assurance gap. Client-only;
  standard slice gate. **SHIPPED 2026-08-03** (`deb72d8`; header status
  line + gate-table row 4).

## 7. Phase 5 — Consultation booking (MVP, no live payment)

**Status: IMPLEMENTED + SHIPPED 2026-08-03** — `05f13c8` (slice 5.0: land
the shelved layer + DI), `0eb7ec9` (slices 5.1–5.2: wizard screen, `/book`
route, capability entry, EN/AR/TR l10n), `3bd3d29` (slice 5.3: l10n
resolution pin), `d55e273` (README count sync). Full gate stack passed on
the merged tree: format CLEAN, analyze clean, **521 tests pass**, ledger
PASS 115. Pushed to `origin/main` on the owner's approval.

**Gate (as designed):** scope note approval → decision-record ratification
(D-B7 resolved 2026-08-03: standalone) → **land the shelved layer** (merge
`feat/booking-flow`; four checks green on the merged tree; AC↔test map
closed per scope note §5) → UI + routing slice (screen, /book route,
app-shell entry, EN/AR/TR) → full B2 gate stack → owner push approval.
Client-only; no server change (payment was gated on the provider/tax/PCI
decision — now **D-11 DECIDED 2026-08-08**: Paymob for any real
integration, **no live payment in MVP**, PCI via Paymob-hosted
tokenization, tax out of scope — `docs/d11_billing_payments_decision_2026-08-08.md`;
not the decided p0 D-09 role semantics — see
`docs/send_message_rpc_plan_2026-08-08.md` A.1).

The domain + state-machine layer already exists on `feat/booking-flow`
(`BookingGateway` seam, `BookingRequest` redaction contract, `BookingCubit`
4-step machine category → dateTime → review → success) — **shelved
2026-08-03** because it is unreachable from the app shell (no screen, no
route) and its code comments cite approvals ("SPEC AC#8", "D2/D3/D4", "G1")
that exist in no tracked document. The missing UI slice is the deliverable
of this phase; the shelved layer is reused as-is after the decision record
(`docs/booking_scope_2026-08-03.md`) is ratified.

**Sequencing note (D-B7 — DECIDED 2026-08-03: standalone):** spec §4 lists
"Attorney discovery (read-only)" before booking and the design set carries
`attorney_search, attorney_profile` ahead of the booking screens — but the
spec does not couple them (separate MVP bullets, separate screen groups;
the booking flow row has no attorney step). Phase 5 proceeds with the
shelved flow as built (category/topic/slot); a future discovery phase adds
an optional `attorneyId` to `BookingRequest` + a "book from attorney
profile" entry behind the same `BookingGateway` seam (scope note §3 D-B7).

| # | Slice | Scope | New files (sketch) | Tests |
|---|---|---|---|---|
| 5.0 | Land the shelved layer | Merge `feat/booking-flow` (3 commits, 2026-08-02); four checks green on the merged tree; verify the AC↔test map (scope note §5 — AC-1–AC-6 covered by the branch's 25 test declarations, AC-7–AC-9 added below) | (branch: 8 lib files + 3 test files) | branch suite + gate stack |
| 5.1 | Booking screen + wizard shell | Renders BookingState; category → dateTime → review → success; one-step back; editCategory; submit error surface; local-only wording (no live-payment copy) | `features/booking/presentation/booking_screen.dart` | widget: step transitions, guard no-ops, error surface |
| 5.2 | Route + shell wiring | `/book` route, capability-aware entry, draft never in route params/extra | `router.dart`, shell | redirect + capability tests |
| 5.3 | l10n | All new strings EN/AR/TR | 3 `.arb` + generated l10n | TR/AR resolution pins |

**Exit:** four checks green; suite + README count in lockstep (the ledger §2d
check); `service_locator_test` registration pin retained; no push without
owner approval.

## 8. Phase 6 — Attorney discovery (read-only, client-only)

**Status: IMPLEMENTED + SHIPPED 2026-08-03** — `0f93042` (slice 6.1:
AttorneyGateway seam + dev fake + search surface), `7b5c589` (slice 6.2:
attorney profile + "Book with this attorney" → `/book` with optional
`attorneyId`, the D-B7 additive slice), `d389c69` (slice 6.3: EN/AR/TR
l10n pins, AC-6/R3). Full gate stack passed on the merged tree: format
CLEAN, analyze clean, **565 tests pass**, ledger PASS 115. Pushed to
`origin/main` on the owner's approval.

Scope note `docs/attorney_discovery_scope_2026-08-03.md` (D-A1…D-A6
ratified). Spec basis: MVP §4 "Attorney discovery (read-only)" + §6
remediation row 152 (`attorney_search, attorney_profile`; no
legal-advice/compliance-claim copy).

**Gate (as designed):** scope note approval → decision-record ratification
(D-A1…D-A6, incl. D-A3 booking integration) → slice 6.1 (AttorneyGateway
seam + fake + search surface) → slice 6.2 (profile surface + "Book with
this attorney" → `/book` with optional `attorneyId`, the D-B7 additive
slice) → slice 6.3 (EN/AR/TR l10n pins) → full B2 gate stack → owner push
approval. Client-only; no server change, no payment, no availability, no
attorney messaging.

| # | Slice | Scope | New files (sketch) | Tests |
|---|---|---|---|---|
| 6.1 | Gateway + search surface | `AttorneyGateway` seam + dev fake (synthetic non-PII list, D-A2/D-A4); search/filter screen (client-side filter, D-A5) | `features/discovery/domain/attorney_gateway.dart`, `data/fake_attorney_gateway.dart`, `presentation/attorney_search_screen.dart` | gateway fetch shape; search/filter/empty widget tests (AC-1, AC-2) |
| 6.2 | Profile + booking hook | Attorney profile (name/practice-area/bio, D-A4); "Book with this attorney" → `/book` pre-filled with optional `attorneyId` (D-A3); standalone booking flow regression-pinned (AC-5) | `presentation/attorney_profile_screen.dart`; `BookingRequest` + router/draft threading | profile field assertions (AC-3); router navigation + request pin (AC-4, AC-5) |
| 6.3 | l10n | All new strings EN/AR/TR; no legal-advice copy (spec §6 row 152) | 3 `.arb` + generated l10n | TR/AR resolution pins (AC-6) |

**Exit:** four checks green; suite + README count in lockstep (the ledger
§2d check); no push without owner approval.

## 9. Phase 7 — Matter dashboard (read-first, client-only) + org switcher

**Status: IMPLEMENTED + SHIPPED 2026-08-03** — `b31bc1a` (slice 7.0:
ActiveOrgStore + client-side org switcher, D-08/D-M7, AC-4), `5740594`
(slice 7.1: MatterGateway seam + dev fake + read-first list with status
filter, AC-1/AC-2/AC-5), `82d77dc` (slice 7.2: read-only matter details
+ `/matters/:id`, AC-3), `c2cf3cb` (slice 7.3: EN/AR/TR l10n pins, AC-6).
Full gate stack passed on the merged tree: format CLEAN, analyze clean,
**605 tests pass**, ledger PASS 115. Pushed to `origin/main` on the
owner's approval.

Scope note `docs/matter_dashboard_scope_2026-08-03.md` (D-M1…D-M7
ratified). Spec basis: MVP §4
"Case/matter dashboard & details (read-first)" + §6 remediation row 156
(`case_management_dashboard, case_details, shared_case_workspace`); org
switcher per D-08 (client-side UX convenience only — the server re-derives
membership, never trusts a client-selected org id).

**Gate (as designed):** scope note approval → decision-record ratification
(D-M1…D-M7, incl. D-M7 active-org switcher) → slice 7.0 (active-org
switcher, D-08) → slice 7.1 (`MatterGateway` seam + fake + list surface,
read-first) → slice 7.2 (details, read-only projection) → slice 7.3 (l10n
pins) → full B2 gate stack → owner push approval. Client-only; no server
change, no matter actions, no messaging, no documents (rows 154/155 keep
their §14 gates).

| # | Slice | Scope | New files (sketch) | Tests |
|---|---|---|---|---|
| 7.0 | Active-org switcher | `ActiveOrgStore` (client-side, session-scoped, seeded from `Session.activeMembership`); switcher sheet listing `Session.memberships`; orgs hub reads the store (D-08 — the client never sends the selected org id as an authority; `list_organizations_metadata` stays unwired) | `features/orgs/presentation/active_org_store.dart` (sketch) | store seed/switch tests; switcher widget test; hub reads the store (AC-4) |
| 7.1 | Gateway + matter list | `MatterGateway` seam + dev fake (synthetic non-PII list, D-M2/D-M4); list screen with status filter + empty state (client-side filter, D-M5); capability entry (D-M6) | `features/matters/domain/matter_gateway.dart`, `data/fake_matter_gateway.dart`, `presentation/matter_list_screen.dart` | gateway fetch shape; filter/empty widget tests (AC-1, AC-2, AC-5) |
| 7.2 | Matter details (read-first) | Read-only projection of the synthetic matter (title/status/area/assigned attorney/date, D-M4); no action affordances (D-M1) | `presentation/matter_details_screen.dart` | field assertions + read-only line pin (AC-3) |
| 7.3 | l10n | All new strings EN/AR/TR; no legal-advice copy (spec §6 row 152) | 3 `.arb` + generated l10n | TR/AR resolution pins (AC-6) |

**Exit:** four checks green; suite + README count in lockstep (the ledger
§2d check); no push without owner approval.

## 10. Phase 8 — Document vault (read-first, metadata-only, client-only)

**Status: IMPLEMENTED + SHIPPED 2026-08-03** — `22d63e5` (slice 8.0:
Document VO + DocumentType + gateway seam + dev fake, D-V2/D-V4, AC-1),
`29fd40a` (slice 8.1: read-first vault list + type chips + capability
entry, D-V1/D-V5, AC-2/AC-3/AC-4), `430b62b` (slice 8.2: EN/AR/TR l10n
pins, AC-5). Full gate stack passed on the merged tree: format CLEAN,
analyze clean, **626 tests pass**, ledger PASS 115. Pushed to
`origin/main` on the owner's approval.

Scope note `docs/document_vault_scope_2026-08-03.md` (D-V1…D-V6
ratified). Spec basis: MVP §4
"Document vault (scoped, no e-signature)" + §6 remediation row 155
(`document_vault`).

**Gate (as designed):** scope note approval → decision-record ratification
(D-V1…D-V6) → slice 8.0 (`DocumentGateway` seam + fake + metadata VO) →
slice 8.1 (read-first vault list + home entry) → slice 8.2 (l10n pins) →
full B2 gate stack → owner push approval. Client-only; no server change,
no document bodies/preview/download/upload, no e-signature, no storage or
realtime (the §14 deferred list keeps its gate).

| # | Slice | Scope | New files (sketch) | Tests |
|---|---|---|---|---|
| 8.0 | Gateway + metadata VO | `Document` VO + `DocumentGateway` seam + dev fake (5 deterministic synthetic non-PII metadata rows: title, type chip, created date — no bodies, D-V2/D-V4) | `features/documents/domain/document.dart`, `domain/document_gateway.dart`, `data/fake_document_gateway.dart` | gateway fetch shape + determinism + non-PII (AC-1) |
| 8.1 | Vault list surface | Read-first document list (title/type/date) + empty/error states + home entry card; **metadata-only, no body/preview/download affordances** (D-V1); capability entry (D-V5) | `features/documents/presentation/document_list_screen.dart`, `document_entry_card.dart` | list widget + metadata-only line pin (AC-2); empty/error (AC-3); capability gating (AC-4) |
| 8.2 | l10n | All new strings EN/AR/TR; no e-signature/legal-advice copy (spec §6 row 152) | 3 `.arb` + generated l10n | TR/AR resolution pins (AC-5) |

**Exit:** four checks green; suite + README count in lockstep (the ledger
§2d check); no push without owner approval.

## 11. Phase 9 — Matter-scoped messaging (thread-metadata-only, client-only)

**Status: IMPLEMENTED AND SHIPPED 2026-08-04** — `b0de147` (slice 9.0:
`MessageThread` VO + `MessageGateway` seam + dev fake, D-MSG2/D-MSG4, AC-1),
`64e6b51` (slice 9.1: read-first thread list + `/messages` route + home
entry + capability flag, D-MSG1/D-MSG3/D-MSG5, AC-2/AC-3/AC-4),
`f02bb1c` (slice 9.2: EN/AR/TR l10n resolution pins + local-only framing
rails, AC-5). Full gate stack passed on the merged tree: format CLEAN,
analyze clean, **649 tests pass**, ledger PASS 115. Scope note
`docs/matter_messaging_scope_2026-08-03.md` (D-MSG1…D-MSG6 ratified). Spec
basis: MVP §4 "Matter-scoped messaging" + §6 remediation row 154
(`message_center, matter_discussion`).

**Gate (as designed):** scope note approval → decision-record ratification
(D-MSG1…D-MSG6) → slice 9.0 (`MessageThread` VO + `MessageGateway` seam +
dev fake, no body field) → slice 9.1 (read-first thread list + home entry,
no thread-open affordance) → slice 9.2 (l10n pins) → full B2 gate stack →
owner push approval. Client-only; no server change, no message bodies, no
send/reply/composer, no realtime/delivery/notifications, no thread-detail
route (the §14 deferred list keeps its gate).

| # | Slice | Scope | New files (sketch) | Tests |
|---|---|---|---|---|
| 9.0 | Gateway + thread VO | `MessageThread` VO (id/title/matterRef/participants/lastActivityAt/messageCount — **no body field**, D-MSG1) + `MessageGateway` seam + dev fake (5 deterministic synthetic non-PII thread rows, D-MSG2/D-MSG4) | `features/messaging/domain/message_thread.dart`, `domain/message_gateway.dart`, `data/fake_message_gateway.dart` | gateway fetch shape + determinism + non-PII + body-less structural pin (AC-1) |
| 9.1 | Thread list surface | Read-first thread list (title, matter ref, participants, last-activity date, message-count chip) + empty/error states + home entry card; **no thread-open affordance, no composer, no send/reply icons** (D-MSG1); capability entry (D-MSG5) | `features/messaging/presentation/message_list_screen.dart`, `message_entry_card.dart` | list widget + body-less line pin (AC-2); empty/error (AC-3); capability gating (AC-4) |
| 9.2 | l10n | All new strings EN/AR/TR; no send/realtime/legal-advice copy (spec §6 row 152) | 3 `.arb` + generated l10n | TR/AR resolution pins (AC-5) |

**Exit:** four checks green; suite + README count in lockstep (the ledger
§2d check); no push without owner approval.

## 12. Phase 10 — Matter workspace (read-first, client-only)

**Status: IMPLEMENTED AND SHIPPED 2026-08-04** — `90465df` (slice 10.0:
additive `Document.matterRef` + fake rows + VO/shape pins, D-W2, AC-1),
`31f0624` (slice 10.1: per-matter Documents + Messages sections on the
details screen, client-side filter, D-W1/D-W3/D-W4/D-W5, AC-1..AC-4),
`93c2e28` (slice 10.2: EN/AR/TR l10n resolution pins + local-only
framing rails, AC-5). Full gate stack passed on the merged tree: format
CLEAN, analyze clean, **659 tests pass**, ledger PASS 115. Scope note
`docs/matter_workspace_scope_2026-08-04.md` (D-W1…D-W6 ratified). Spec
basis: MVP §4
"Case/matter dashboard & details (read-first)" + §6 remediation row 156
(`shared_case_workspace`); the per-matter cross-link was declared future
work in the Phase 7/8/9 scope notes' §3 non-goals and shipped here.

**Gate (as designed):** scope note approval → decision-record ratification
(D-W1…D-W6) → slice 10.0 (`Document.matterRef` + fake rows + VO/shape
pins) → slice 10.1 (per-matter Documents + Messages sections on the
details screen, client-side filter) → slice 10.2 (l10n pins) → full B2
gate stack → owner push approval. Client-only; no server change, no new
RPC, no matrix addendum, no matter-scoped actions (the §14 deferred list
keeps its gate).

| # | Slice | Scope | New files (sketch) | Tests |
|---|---|---|---|---|
| 10.0 | Document.matterRef | Additive `matterRef` field on `Document` (one of the 5 known synthetic matter titles, D-W2) + fake rows; VO props-pin + gateway shape tests updated deliberately | `features/documents/domain/document.dart`, `data/fake_document_gateway.dart` | VO props pin (D-W2); gateway shape + known-titles + coverage (AC-1) |
| 10.1 | Matter-workspace sections | Details screen renders Documents + Messages sections (client-side filter by matter title, D-W1/D-W3); per-matter empty states; body-less/read-only lines (D-W4); capability gating reused (D-W5) | `features/matters/presentation/matter_details_screen.dart` (+ feature-local section widgets) | per-matter filter + empty + body-less pin (AC-1/2/3/4) |
| 10.2 | l10n | All new strings EN/AR/TR; local-only framing (spec §6 row 152) | 3 `.arb` + generated l10n | TR/AR resolution pins (AC-5) |

**Exit:** four checks green; suite + README count in lockstep (the ledger
§2d check); no push without owner approval.

## 12a. Phase 11 — Unified search (read-first, client-only, aggregating)

**Status: IMPLEMENTED + SHIPPED 2026-08-04** — slice 11.0 (`SearchResults`
grouping VO + `SearchState` on the shared `ViewState` vocabulary +
`SearchCubit` composing the four gateway seams in parallel with
case-insensitive D-S1 filtering, AC-1), slice 11.1 (`/search?q=…` route +
capability-gated grouped surface + home search-field wiring,
D-S2/D-S3/D-S4/D-S5, AC-2/AC-3/AC-5), slice 11.2 (EN/AR/TR l10n
resolution pins + local-only framing rails, AC-5). Full gate stack: format
CLEAN, analyze clean, **691 tests pass** (executed suite count; the
ledger/README reconcile the declaration count), ledger PASS 115 — landing
commit `7c8ead8` pushed to `origin/main` on the owner's dated push approval
2026-08-04. Scope note
`docs/unified_search_scope_2026-08-04.md` (D-S1…D-S6 ratified). Spec basis:
MVP §4 read-first surfaces; the home search field was an inert affordance
(controller + `searchPlaceholder` key with no submit handler) and the four
fake-domain gateway seams (Phases 6–10) were the buildable seam set —
search aggregates those lists client-side with no server change, no matrix
addendum, and no §14 relaxation.

**Gate (as designed):** scope note approval → decision-record ratification
(D-S1…D-S6) → slice 11.0 (search domain: grouping VO + state + cubit) →
slice 11.1 (route + surface + wiring) → slice 11.2 (l10n pins) → full B2
gate stack → owner push approval. Client-only; no server change, no new
RPC, no matrix addendum, no search history/realtime/full-text (the §14
deferred list keeps its gate).

| # | Slice | Scope | New files (sketch) | Tests |
|---|---|---|---|---|
| 11.0 | Search domain | `SearchResults` grouping VO (matters/documents/threads/attorneys) + `SearchState` (idle/loading/empty-query/results/error on the shared `ViewState`) + `SearchCubit` composing the four gateway seams, filtering case-insensitively on the D-S1 field set (matter title/status/practice-area; document title/type/`matterRef`; thread title/participants/`matterRef`; attorney name/practice-area) | `features/search/domain/search_results.dart`, `presentation/search_state.dart`, `presentation/search_cubit.dart` | cubit: query→grouped subsets, empty-query (zero fetches), no-match→empty, any-gateway failure→error, latest-wins (AC-1) |
| 11.1 | Route + surface + wiring | `/search?q=…` route; grouped surface with capability gating (D-S2), navigation to existing read-only routes only (D-S3), no-query/empty/error states + local-only note (D-S4/D-S5); home search field `onSubmitted` → `/search?q=…` | `features/search/presentation/search_screen.dart`, `router.dart`, `home_screen.dart`, `legalhub_text_field.dart` | widget: metadata-only absences (AC-2), gating, no-query/empty, debounced refine, error-retry; router: 4 navigations + home submit + unauth (AC-3/AC-5) |
| 11.2 | l10n | All new strings EN/AR/TR (title, no-query, empty, error, local-only note); `searchPlaceholder` reused (D-S6) | 3 `.arb` + generated l10n | TR/AR resolution pins + framing rails (AC-5) |

**Exit:** four checks green; suite + README count in lockstep (the ledger
§2d check); no push without owner approval.

## 12b. Phase 12 — Reverse cross-link (read-first, client-only)

**Status: IMPLEMENTED — slices 12.0–12.2 SHIPPED 2026-08-05** — `16e9b67` (slice
12.0: `MatterTitleResolver` title-keyed client-side resolve (D-M5
discipline) + `MatterLinkChip` "View matter" affordance on vault document
rows — the ONLY tap target in the list (D-C2) — gated by the
`canViewMatters` nav hint (D-C4); the router passes the capability
projection to the `/vault` builder; the D-V1 pin in
`document_list_screen_test.dart` re-scoped as a deliberate edit; EN/AR/TR
`viewMatter` key + regenerated localizations). Full gate stack: format
CLEAN, analyze clean, **701 tests pass** (README/ledger reconcile 698
declarations), ledger PASS 115 — landing commit `16e9b67` pushed to
`origin/main` on the owner's dated push approval 2026-08-05. Slice 12.1
(messages reverse link) shipped 2026-08-05 (`69622ce`): the same
title-keyed resolver + thread-row "View matter" chip on `MessageListScreen`
with the D-MSG3 pin re-scoped (D-C2) and the router capability projection
(D-C4); suite 705/README 702, ledger PASS 115 — committed, push awaits
owner approval. Scope note `docs/reverse_crosslink_scope_2026-08-04.md`
(D-C1…D-C6 ratified 2026-08-05). Spec basis: MVP §4 "Case/matter dashboard & details
(read-first)"; the Phase 11 deferral's "future phase" is this phase
(`docs/unified_search_scope_2026-08-04.md` §3/R4).

**Gate (as designed):** scope note approval → decision-record ratification
(D-C1…D-C6) → slice 12.0 (vault reverse link) → slice 12.1 (messages
reverse link, D-MSG3 pin re-scope) → slice 12.2 (l10n) → full B2 gate
stack → owner push approval. Client-only; no server change, no new RPC,
no matrix addendum (the matrix's body-read row stays untouched), no §14
relaxation.

| # | Slice | Scope | New files (sketch) | Tests |
|---|---|---|---|---|
| 12.0 | Vault reverse link | **SHIPPED 2026-08-05** (`16e9b67`): shared title-keyed resolver + document-row "View matter" chip; D-V1 pin re-scoped (D-C2); router passes capability projection (D-C4) | `features/matters/domain/matter_title_resolver.dart`, `features/matters/presentation/matter_link_chip.dart` (+ `document_list_screen.dart`, `router.dart`, l10n) | router navigation pin (AC-1); re-scoped absence pins (AC-3); capability gating (AC-4) |
| 12.1 | Messages reverse link | **SHIPPED 2026-08-05** (`69622ce`): thread-row "View matter" chip on `MessageListScreen`; D-MSG3 pin re-scoped (D-C2); router passes capability projection (D-C4) | `message_list_screen.dart`, `router.dart` | messages widget tests + router pin (AC-2); gating (AC-4) |
| 12.2 | l10n | **SHIPPED 2026-08-05** (`cd5c903`): the AC-5 per-locale resolution pin — `viewMatter` exact copy EN/AR/TR + no-silent-EN-copy asserts (`viewMatter` itself shipped with 12.0) | `app_localizations_test.dart` (+ README count 702→703) | per-locale resolution pins (AC-5) |

**Exit:** four checks green; suite + README count in lockstep (the ledger
§2d check); no push without owner approval.

## 13. Sequencing & governance gate table

| Order | Phase | Depends on | Server changes? | Gate to pass | Status |
|---|---|---|---|---|---|
| 1 | Phase 1 — P3 org/membership UI | P3 spec approval | no | spec approval → slice → B2 gate stack → owner push approval | **SHIPPED 2026-08-03 (`03862ce`, suite 408, ledger PASS 115)** |
| 2 | Phase 2 — org lifecycle wiring | Phase 1 (same seams) | no | spec-lite scope note → approval → gate stack | **SHIPPED 2026-08-03 (`68aafc6`, slices 2.1–2.4)** |
| 3 | Phase 3 — server amendments | Phase 1/2 (surface defined) | **yes** | spec → RLS-gate review → rehearsal evidence → apply approval → apply execution → matrix addendum | **APPLIED 2026-08-03** (`docs/p3_r1_roster_rpc_design_2026-08-03.md` + matrix §2 addendum + `docs/p3_r1_rehearsal_plan_2026-08-03.md` + evidence r1 PASSED + `supabase/rpc/list_org_members_metadata.sql` + `_down.sql` drop → applied to dev project on the owner's dated apply approval) |
| 4 | Phase 4 — auth plumbing | — | 4.1 yes (platform config) | platform config approval → gate stack | **4.2 SHIPPED 2026-08-03 (`deb72d8`); 4.1 APPROVED + IMPLEMENTED 2026-08-03 (scope note `docs/p4_41_deeplink_recovery_scope_2026-08-03.md`); R1 = dashboard Redirect URL (owner-side); P3.1 real-auth wiring (typed `SupabaseAuthApi` + localized recovery) SHIPPED 2026-08-05 (`2e18b24`, suite 717, ledger PASS 115); P3.2 membership hydration + active-org context SHIPPED 2026-08-05 (`24d5ec3`..`6a8f567`, suite 752, ledger PASS 115); P3.3 org-management re-hydration (AuthCubit.hydrate + hub trigger) SHIPPED 2026-08-05 (`cda5aec`..`e603fb5`, suite 764, ledger PASS 115); P3.4 invitation acceptance + account deletion SHIPPED 2026-08-05 (`7548ade`..`e24a49e`, suite 770, ledger PASS 115); P3.5 platform-owner admin UX SHIPPED 2026-08-05 (`47f777b`..`06d78a7`, suite 827, ledger PASS 115 — P3 plan complete); 4.1 accept-invitation deep link (D-P34.2) SHIPPED 2026-08-07 (`95c1676`..`58134f6` on `feat/p4-1-accept-deeplink`, suite 850, ledger PASS 115 — evidence `docs/p4_1_completion_evidence_2026-08-07.md`)** |
| 5 | Phase 5 — consultation booking (no live payment) | MVP spec §4; auth/org track (§§3–4); D-B7 resolved (standalone) | no | scope note → decision-record ratification → UI + routing slice → gate stack → owner push approval | **SHIPPED 2026-08-03** (`05f13c8` + `0eb7ec9` + `3bd3d29` + `d55e273`, suite 521, ledger PASS 115; pushed to origin/main) |
| 6 | Phase 6 — attorney discovery (read-only, client-only) | MVP spec §4; D-B7 additive `attorneyId` hook; Phase 5 booking seams | no | scope note → decision-record ratification (D-A1…D-A6) → slices 6.1–6.3 → gate stack → owner push approval | **SHIPPED 2026-08-03** (`0f93042` + `7b5c589` + `d389c69`, suite 565, ledger PASS 115; pushed to origin/main) |
| 7 | Phase 7 — matter dashboard (read-first, client-only) + org switcher | MVP spec §4; D-08 org semantics; Phase 6 seams (synthetic attorney roster for assignment) | no | scope note → decision-record ratification (D-M1…D-M7) → slices 7.0–7.3 → gate stack → owner push approval | **SHIPPED 2026-08-03** (`b31bc1a` + `5740594` + `82d77dc` + `c2cf3cb`, suite 605, ledger PASS 115; pushed to origin/main) |
| 8 | Phase 8 — document vault (read-first, metadata-only, client-only) | MVP spec §4; Phase 7 seams (fake-domain pattern) | no | scope note → decision-record ratification (D-V1…D-V6) → slices 8.0–8.2 → gate stack → owner push approval | **SHIPPED 2026-08-03** (`22d63e5` + `29fd40a` + `430b62b`, suite 626, ledger PASS 115; pushed to origin/main) |
| 9 | Phase 9 — matter-scoped messaging (thread-metadata-only, client-only) | MVP spec §4; Phase 8 seams (fake-domain pattern) | no | scope note → decision-record ratification (D-MSG1…D-MSG6) → slices 9.0–9.2 → gate stack → owner push approval | **SHIPPED 2026-08-04** (`b0de147` + `64e6b51` + slice 9.2 l10n pins, suite 649, ledger PASS 115; pushed to origin/main) |
| 10 | Phase 10 — matter workspace (read-first, client-only) | MVP spec §4; Phase 7/8/9 seams (details screen + fake-domain pattern) | no | scope note → decision-record ratification (D-W1…D-W6) → slices 10.0–10.2 → gate stack → owner push approval | **SHIPPED 2026-08-04** (`90465df` + `31f0624` + slice 10.2 l10n pins, suite 659, ledger PASS 115; pushed to origin/main) |
| 11 | Phase 11 — unified search (read-first, client-only, aggregating) | MVP spec §4; Phase 6–10 seams (four fake-domain gateway seams + inert home search field) | no | scope note → decision-record ratification (D-S1…D-S6) → slices 11.0–11.2 → gate stack → owner push approval | **SHIPPED 2026-08-04** (`7c8ead8`, slices 11.0–11.2, suite 691, ledger PASS 115; pushed to origin/main) |
| 12 | Phase 12 — reverse cross-link (client-only) | MVP §4 read-first; Phase 10 `matterRef` seam + Phase 7 details route | no | scope note → decision-record ratification (D-C1…D-C6) → slices 12.0–12.2 → gate stack → owner push approval | **IMPLEMENTED + SHIPPED 2026-08-05** — 12.0 `16e9b67` (pushed, suite 701/README 698); 12.1 `69622ce` + 12.2 `cd5c903` (committed, suite 706/README 703); ledger PASS 115; push of 12.1/12.2 awaits owner approval |
| — | §14 deferred capabilities | **P0 closes (D-02…D-10b)** + policy tests + matrix extension | yes | per feature, same P2 discipline | Per-feature un-deferrals — **matters read (first), SHIPPED 2026-08-07** (real-matters read slice: RLS design → battery → rehearsal r1 → dated apply-approval → apply → matrix addendum → env-gated client swap; plan `docs/matters_real_data_plan_2026-08-07.md`, evidence `docs/matters_real_data_completion_evidence_2026-08-07.md`; docs + database commits `bf27f84`..`41577a0`, suite 877, ledger PASS 115; **documents read is the second per-feature un-deferral, SHIPPED 2026-08-07** (real-documents read slice: RLS design → battery → rehearsal r1 → dated apply-approval → apply → matrix addendum → env-gated client swap; plan `docs/documents_real_data_plan_2026-08-07.md`, evidence `docs/documents_real_data_completion_evidence_2026-08-07.md`; commits `77f14fb`..`cb682ca`, suite 897, ledger PASS 115; **messages read is the third per-feature un-deferral, SHIPPED 2026-08-07** (real-messages read slice: RLS design → battery → rehearsal r1 → dated apply-approval → apply → matrix addendum → env-gated client swap; plan `docs/messages_real_data_plan_2026-08-07.md`, evidence `docs/messages_real_data_completion_evidence_2026-08-07.md`; commits `443f42e`..`7168f38`, suite 921/README 918, ledger PASS 115; **storage read is the fourth per-feature un-deferral, SHIPPED 2026-08-08** (real-storage read slice: RLS design → battery (static `--check` 331/0/0) → dated apply-approval APPLY APPROVED → dated matrix §4 + §6 addendum → env-gated client swap (NEW D-STR7 surface); plan `docs/storage_real_data_plan_2026-08-08.md`, evidence `docs/storage_real_data_completion_evidence_2026-08-08.md`; server commits `6f52930`..`92c72e8` (merged `0b81297`) + client `704f212`, suite 953/README 950, ledger PASS 115; **r1 PASSED 2026-08-08 (genuinely executed 74/0/0) + the server apply EXECUTED (owner-approved; 07_storage + both policies + demo seed: tables 10→11, public policies 9→10, storage policies 0→1, bucket `matter-files` 1, 4 demo files + 4 objects — evidence `docs/storage_apply_execution_2026-08-08.md`)**; **audit surfacing is the fifth per-feature un-deferral, SHIPPED 2026-08-08** (client-only slice: dated matrix §6 addendum + platform-admin seam `readPlatformAudit`/`readOrgAudit` + `AuditEntry` VO + Audit section; the audit RPCs already applied 2026-08-01 + battery-pinned; plan `docs/audit_surfacing_plan_2026-08-08.md`, evidence `docs/audit_surfacing_completion_evidence_2026-08-08.md`; commits `7b7c1a8` → `b0f9022`, suite 986/README 983, ledger PASS 115; **18-of-18 RPCs wired**); **realtime read is the sixth per-feature un-deferral, SHIPPED 2026-08-08** (RLS-gate review `790f6e7` → artifacts `60198e2` → battery + harness `9f01870` (static `--check` 333/0/0) → rehearsal r1 genuinely executed 70/0/0 `f22e672`+`8204245` → dated approval + apply `75f1880`+`35cceb9` (dev project: 08_messages + policy + 10 demo messages, 8→9 policies) → matrix addendum `d350824` → env-gated client swap `7b8a808` (fetchMessages + Message VO + thread-detail surface, suite 1011/README 1011, ledger PASS 115); plan `docs/realtime_real_data_plan_2026-08-08.md`, evidence `docs/realtime_real_data_completion_evidence_2026-08-08.md`); **realtime live delivery is the seventh per-feature un-deferral, SHIPPED 2026-08-08** (mechanism review `af1715c` → artifacts `f1d7903` (live-validated on the rehearsal stack) → battery + harness `6302bdc` (static `--check` 335/0/0) → rehearsal r1 genuinely executed 72/0/0 `51532fd` → dated approval + apply `c96eff7`+`7efb32b` (dev project: publication 0→1 exactly `public.messages`, policies 9→10, the first live INSERT `7cbf49e0-…`) → matrix §4 + §6 addenda `de25c6f` → env-gated client swap `6154fa3` (subscription + composer, suite 1045 runtime / README 1042, ledger PASS 115); plan `docs/realtime_push_real_data_plan_2026-08-08.md`, evidence `docs/realtime_push_real_data_completion_evidence_2026-08-08.md`); **the audited send path is the eighth per-feature un-deferral, SHIPPED 2026-08-08** (mechanism review `7759181` → artifact `60dae71` (live-validated on the rehearsal stack) → battery + harness `b013ee5` (static `--check` 337/0/0, RPC-EXECUTE 18→19, policies 11→10, live 74/0/0) → rehearsal r1 genuinely executed 74/0/0 `8df7e47` → dated apply-approval + execution `a5db0af` + `docs/send_message_apply_execution_2026-08-08.md` (APPLY APPROVED 2026-08-08; policies 10→9, INSERT revoked, demo send `1c031882-…` via the RPC with the §8 audit row observed) → matrix addendum `ea74c63` → env-gated client swap `f874a57` (suite 1047 runtime / README 1044, ledger PASS 115); plan `docs/send_message_rpc_plan_2026-08-08.md`, evidence `docs/send_message_real_data_completion_evidence_2026-08-08.md`; billing/AI stay deferred, each a separate per-feature un-deferral) |

Rules that apply to every phase (definition-of-done from
`docs/codebase_audit_plan.md`): scope/assumptions/non-goals documented ·
required approval gates passed · `git status`/`git diff` reviewed for
secrets and real data · verification commands actually run and reported
honestly · **no commit, push, or deployment without explicit owner
approval**.

## 14. Explicitly deferred (do NOT build until P0 closes + policy tests exist)

Per README boundary + `docs/permission_matrix.md` §4/§6, the originally
deferred capabilities are: **matters, documents, messages, storage,
realtime, audit surfacing, billing, AI** (matters, documents, messages,
storage, realtime — read + live delivery — audit surfacing, and the
audited send path now un-deferred — see the flip notes below).
The **real matters data path is the first per-feature un-deferral —
SHIPPED 2026-08-07 (read slice)** under this gate: RLS-gate design review
(`docs/matters_rls_gate_review_2026-08-07.md`), rehearsal-ready artifacts
(`supabase/migrations/04_matters.sql` + `policies/matters.sql`), policy
battery (`supabase/tests/04_matter_rls.sql`, ten checks green), rehearsal
r1 PASSED (ephemeral, owner's host), dated apply-approval + execution on
the dev project (table + `matters_select_assigned` + demo seed, rollback
pairing standing by), dated matrix §4 addendum, and the env-gated client
swap (`SupabaseMatterGateway` behind `env.isConfigured`; VO/presentation
untouched). The **real documents data path is the second per-feature
un-deferral — SHIPPED 2026-08-07 (read slice)** under this gate: RLS-gate
design review (`docs/documents_rls_gate_review_2026-08-07.md`),
rehearsal-ready artifacts (`supabase/migrations/05_documents.sql` +
`policies/documents.sql`), policy battery (`supabase/tests/05_document_rls.sql`,
eleven checks green incl. the org-mismatch row), rehearsal r1 PASSED
(ephemeral, owner's host), dated apply-approval + execution on the dev
project (table + `documents_select_assigned` + demo seed referencing the
applied demo matter ids, rollback pairing standing by), dated matrix §4
addendum, and the env-gated client swap (`SupabaseDocumentGateway` behind
`env.isConfigured`; VO/presentation untouched). The **real messages data
path is the third per-feature un-deferral — SHIPPED 2026-08-07 (read
slice)** under this gate: RLS-gate design review
(`docs/messages_rls_gate_review_2026-08-07.md`), rehearsal-ready artifacts
(`supabase/migrations/06_message_threads.sql` +
`policies/message_threads.sql`), policy battery
(`supabase/tests/06_message_rls.sql`, eleven checks green incl. the
non-vacuous org-mismatch row), rehearsal r1 PASSED (ephemeral, owner's
host), dated apply-approval + execution on the dev project (table +
`message_threads_select_assigned` + demo seed referencing the applied
demo matter ids, rollback pairing standing by), dated matrix §4
addendum, and the env-gated client swap (`SupabaseMessageGateway` behind
`env.isConfigured`; VO/presentation untouched). The **real storage data
path is the fourth per-feature un-deferral — SHIPPED 2026-08-08 (client
read surface)** under this gate: RLS-gate design review
(`docs/storage_rls_gate_review_2026-08-08.md`), rehearsal-ready artifacts
(`supabase/migrations/07_storage.sql` + `policies/files.sql` +
`policies/storage_objects.sql` — private `matter-files` bucket +
`public.files` metadata table), policy battery
(`supabase/tests/07_storage_rls.sql`, 22 check blocks on **both layers**,
static `--check` 331/0/0), dated apply-approval APPLY APPROVED 2026-08-08
(`91c49ce`; **the r1 rehearsal PASSED 2026-08-08 (genuinely executed
74/0/0, evidence `docs/storage_rehearsal_evidence_r1_2026-08-08.md`
PASSED) and the server apply EXECUTED the same day (owner-approved;
evidence `docs/storage_apply_execution_2026-08-08.md` APPLIED —
07_storage + both policies + demo seed: bucket `matter-files` 1, tables
10→11, RLS 10→11, public policies 9→10, storage policies 0→1, 4 demo
files + 4 demo objects on the applied demo matters, smoke partner 3/3 +
family 0, clients 0/0, anon denied on both layers)**), dated
matrix §4 addendum ("View a matter file (metadata)" row) + §6 addendum
(the two storage rows enforced at generation + TTL, caveat recorded), and
the env-gated client swap (`SupabaseStorageGateway` behind
`env.isConfigured` — NEW D-STR7 surface with `RoleCapability.canViewFiles`,
committed `704f212`, suite 953/README 950, ledger PASS 115;
VO/presentation untouched). **Audit surfacing is the fifth per-feature
un-deferral — SHIPPED 2026-08-08 (client surface)** under this gate: the
audit RPCs were already applied to the dev project on 2026-08-01 and
battery-pinned (harness §1d RPC-EXECUTE list), so the slice was
**client-only** — dated matrix §6 addendum (the "Read the audit table"
row's client-surface widening, §7 discipline) + the env-gated
platform-admin seam methods (`readPlatformAudit`/`readOrgAudit`,
`SupabasePlatformAdminApi`/gateway/fake) + `AuditEntry` VO + the
platform-admin Audit section (platform + per-org trails, org-scope
selector, denied-never-empty per P3.5 AC-7, redacted-only per contract §8,
D-P0C4 — no raw SELECT on `audit_events` ever); plan
`docs/audit_surfacing_plan_2026-08-08.md`, evidence
`docs/audit_surfacing_completion_evidence_2026-08-08.md`; commits
`7b7c1a8` → `b0f9022`, suite 986/README 983, ledger PASS 115;
**18-of-18 RPCs now have a client surface** (roadmap §2). **Realtime is
now the sixth per-feature un-deferral — SHIPPED 2026-08-08 (read
slice)** under this gate: RLS-gate design review
(`docs/realtime_rls_gate_review_2026-08-08.md` — the thread gate extended
one hop: `messages_select_assigned` with the **three-way org equality
load-bearing**, D-RT2), rehearsal-ready artifacts
(`supabase/migrations/08_messages.sql` + `policies/messages.sql` — the
`body` column is the **first content column in the public schema**, the
scoped D-MSG1 consummation), policy battery
(`supabase/tests/08_message_rls.sql`, 12 checks incl. the non-vacuous
org-mismatch row; static `--check` 333/0/0), rehearsal r1 **PASSED —
genuinely executed 70/0/0** (`docs/realtime_rehearsal_evidence_r1_2026-08-08.md`,
the first real battery run in the slice history; two latent findings
fixed — the storage-api `protect_objects_delete` GUC host-compat + the
pre-existing 01.08 privileged-observer defect), dated apply-approval
APPLY APPROVED + **executed on the dev project** (table + policy + 10
demo message rows referencing the applied demo thread ids; 8→9 policies;
smoke: partner reads 6/10 as assigned attorney on 3 of 4 demo matters,
the family-thread 4-denial recorded as the clause firing live),
dated matrix §4 addendum (the "Read a document/message body" row's
client/attorney cells SHIP), and the env-gated client swap
(`fetchMessages` with the `.eq('thread_id')` filter + NEW `Message` VO +
read-only thread-detail surface — the first thread-open affordance,  `7b8a808`, suite 1011/README 1011, ledger PASS 115; no composer/send/
reply at that stage — live delivery then shipped as the seventh §14
un-deferral (realtime-push, 2026-08-08 — see the flip note below)).
**Realtime live delivery (push) is the seventh per-feature un-deferral —
SHIPPED 2026-08-08** under this gate: mechanism design review
(`docs/realtime_push_gate_review_2026-08-08.md` — Supabase **Realtime
RLS**: the **existing `messages_select_assigned` SELECT policy IS the
delivery gate**; publication membership = enablement only, exactly
`messages`, nothing else D-LV2), rehearsal-ready artifacts
(`supabase/migrations/09_realtime_push.sql` + `.down.sql` +
`supabase/policies/messages_insert.sql` — the INSERT grant + the
`messages_insert_assigned` WITH CHECK policy, D-LV1, both live-validated
on the rehearsal stack), policy battery
(`supabase/tests/09_realtime_push.sql`, 12 checks incl. the publication
pins (messages count 1 + nothing else) and the delivery-equivalence
negative 09.11/09.12; static `--check` 335/0/0), rehearsal r1 **PASSED —
genuinely executed 72/0/0** (`docs/realtime_push_rehearsal_evidence_r1_2026-08-08.md`;
two T2 live findings fixed — `CREATE PUBLICATION` has no `IF NOT EXISTS`
form, and 08 granted SELECT only so the INSERT policy needed its own
grant), dated apply-approval APPLY APPROVED + **executed on the dev
project** (publication 0→1 exactly `public.messages`, policies 9→10, the
**demo send as the first live INSERT** `7cbf49e0-…` through
`messages_insert_assigned`; smoke: the assigned partner reads the sent
row 1, the assigned client with no membership reads 0 — the D-RT2
membership guard firing live), dated matrix §4 write-row + §6 delivery-
row addenda (the "Send a message" row: client/attorney SHIP behind
`messages_insert_assigned`; the "Realtime subscription for an org/matter
the session no longer has access to → No events delivered" row →
enforced), and the env-gated client swap (NEW `SupabaseMessageRealtimeApi`
seam — per-thread `postgres_changes` + reconnect + backfill via the
shipped `fetchMessages` — `sendMessage` on the gateway/fake + the
thread-detail composer, insert-only D-LV1, `6154fa3`, suite 1045 runtime
/ README 1042, ledger PASS 115).
**The audited message send (send-message) is the eighth per-feature
un-deferral — SHIPPED 2026-08-08** under this gate: the
mechanism design review (`docs/send_message_gate_review_2026-08-08.md`
— the audited `send_message` RPC: `security definer` + the **D-SM1
in-function gate** re-asserting the exact `messages_insert_assigned`
authorization, `write_audit` §8 by construction — closing the
realtime-push review-Q6 gap — and **D-SM3 revoking the direct-INSERT
surface** so the RPC becomes the only write path), the rehearsal-ready
artifact (`supabase/rpc/send_message.sql` + `_down.sql`, **live-validated
on the rehearsal stack** — both assigned positives + all five denies +
anon + the empty-body CHECK + the backout round-trip), the battery +
harness (`supabase/tests/10_send_message_rls.sql`, 10 checks; the 09
battery re-scoped to publication pins + delivery-equivalence + the D-SM3
revocation pins 09.15/09.16; harness §1d RPC-EXECUTE 18→19, policies
11→10; static `--check` 337/0/0), rehearsal r1 **PASSED — genuinely
executed 74/0/0** (`docs/send_message_rehearsal_evidence_r1_2026-08-08.md`),
the dated apply-approval record **APPLY APPROVED + EXECUTED 2026-08-08**
(`docs/send_message_apply_approval_2026-08-08.md` §6 signed;
`docs/send_message_apply_execution_2026-08-08.md` **APPLIED** — baseline
probe matched the §4.1 predictions, `send_message.sql` as ONE unit
(function + EXECUTE grant + **D-SM3 revocation**: policies 10→9,
`authenticated` INSERT revoked, `messages_insert_assigned` dropped), the
demo send via the RPC as the assigned partner on the acquisition thread
(`1c031882-…`) with the **§8 audit row observed** (`message:create`/
`allowed`, actor = the partner, resource id = the returned id, redacted
`message sent`), smoke verified — the write path is now the audited RPC
and the §8 gap is closed on the dev project; one finding recorded: the
author is the account's stored display name (an email — owner-side
account hygiene, D-RT4 honored)), the dated matrix §4 addendum (the "Send a message" row's
mechanism note → the audited RPC; client/attorney SHIP, partner/
`compliance_officer` stay ungranted, `platform_owner_admin` deny always),
and the env-gated client swap (`f874a57` — the seam calls `send_message`
with no org pre-read + no client author (D-SM2), the gateway resolves
the [Message] VO through the shipped read; suite 1047 runtime / README
1044, ledger PASS 115). The remaining deferred paths each keep
this same per-feature discipline: billing, AI — **reconciled 2026-08-08,
billing un-blocked by D-11** (owner **D-11 DECIDED 2026-08-08** —
`docs/d11_billing_payments_decision_2026-08-08.md`: Paymob for any real
integration, **no live payment in MVP** — the fake-gateway pattern — PCI
via Paymob-hosted tokenization (SAQ-A-like, no demo claim), tax out of
scope, D-04 residency confirmed — so a billing-invoices read-metadata
slice is now **plannable**, still §14-deferred as an implementation; AI
stays deferred on D-07/D-08 + undefined scope — see the reconciliation +
next-slice plan `docs/send_message_rpc_plan_2026-08-08.md`).
The client-only document-metadata surface shipped as Phase 8 (slices
8.0–8.2, `22d63e5`/`29fd40a`/`430b62b`) carries no real document data —
the real documents read path is the second per-feature un-deferral
(SHIPPED 2026-08-07 — see the flip note above). The
client-only thread-metadata surface shipped as Phase 9 (slices 9.0–9.2,
`b0de147`/`64e6b51`/`f02bb1c`) carries no real message data — the real
messages data path is the third per-feature un-deferral (SHIPPED
2026-08-07 — see the flip note above). The client-only per-matter view
shipped as Phase 10 (slices 10.0–10.2,
`90465df`/`31f0624`/`93c2e28`) is a client-side view over the same
synthetic lists —the real matters, documents and messages read paths are the first four per-feature un-deferrals (see the flip notes above); message bodies + individual messages shipped as the sixth un-deferral (realtime read, 2026-08-08 — see the flip note above); live delivery shipped as the seventh un-deferral (realtime-push, 2026-08-08 — see the flip note above); the audited send path shipped as the eighth un-deferral (send-message, 2026-08-08 — see the flip note above). The client-only unified-search surface shipped
as Phase 11 (slices 11.0–11.2) is a client-side aggregation over the same
synthetic lists —the real matters, documents and messages read paths are the first four per-feature un-deferrals (see the flip notes above); message bodies + individual messages shipped as the sixth un-deferral (realtime read, 2026-08-08 — see the flip note above); live delivery shipped as the seventh un-deferral (realtime-push, 2026-08-08 — see the flip note above); the audited send path shipped as the eighth un-deferral (send-message, 2026-08-08 — see the flip note above). The client-only reverse cross-link shipped as
Phase 12 slice 12.0 (`16e9b67`) is a navigation hint between the same
synthetic lists —the real matters, documents and messages read paths are the first four per-feature un-deferrals (see the flip notes above); message bodies + individual messages shipped as the sixth un-deferral (realtime read, 2026-08-08 — see the flip note above); live delivery shipped as the seventh un-deferral (realtime-push, 2026-08-08 — see the flip note above); the audited send path shipped as the eighth un-deferral (send-message, 2026-08-08 — see the flip note above). The
matrix requires the `platform_owner_admin` deny-row test and per-row
negative policy tests **before any of these ship**, and an org role alone
never grants matter access. The audit RPCs (`read_org_audit`,
`read_platform_audit`) shipped their first client surface in the fifth §14
un-deferral (audit surfacing, 2026-08-08 — the platform-admin Audit
section; see the flip note above), and the owner-only admin RPCs
(`delete_demo_account`, `suspend_membership_platform`,
`reactivate_membership_platform`) shipped a client surface in P3.5
(`47f777b`, the platform-admin screen; matrix §5 addendum) — the real
enforcement + auditing of those actions remains server-side per the
permission matrix.

## 15. Ledger hooks (what to update when a phase lands)

- P3 spec §1 status line → "UI slice implemented" + commit ref, and
  `docs/p0_decision_capture.md` §3 P3 row → APPROVED/executed with date.
- Each Phase 3 server amendment: `docs/tracked_deviations.md` D-T5/D-T6
  cross-refs, `docs/permission_matrix.md` dated addendum, rehearsal
  evidence + apply-approval/execution records (the P2 record pattern:
  `docs/p2_apply_approval_2026-08-01.md`, `docs/p2_apply_execution_2026-08-01.md`).
- README "Implemented foundation" + test-count lines after every phase that
  touches `lib/` or `test/` (the ledger gate's §2d README-count check fails
  if the suite count drifts from the README claim — keep them in lockstep).
- This roadmap's status header + gate table as each row advances.
- Phase 5 landing: README test-count + implemented-foundation lines in lockstep (the ledger gate's §2d check) — booking's ~975 branch test lines count once committed; `docs/booking_scope_2026-08-03.md` decision record ratified.
- Phase 6 landing: README test-count + implemented-foundation lines in lockstep; `docs/attorney_discovery_scope_2026-08-03.md` decision record ratified (D-A1…D-A6).
- Phase 7 landing: README test-count + implemented-foundation lines in lockstep; `docs/matter_dashboard_scope_2026-08-03.md` decision record ratified (D-M1…D-M7); roadmap §4 slice 2.3 (org switcher) closes as slice 7.0.
- Phase 8 landing: README test-count + implemented-foundation lines in lockstep; `docs/document_vault_scope_2026-08-03.md` decision record ratified (D-V1…D-V6); the §14-deferred sentence gains a cross-ref note that the client-only metadata surface shipped as Phase 8 while the real data path stays deferred.
- Phase 9 landing: README test-count + implemented-foundation lines in lockstep; `docs/matter_messaging_scope_2026-08-03.md` decision record ratified (D-MSG1…D-MSG6); the §14-deferred sentence gains a cross-ref note that the client-only thread-metadata surface shipped as Phase 9 while the real messages data path stays deferred.
- Phase 10 landing: README test-count + implemented-foundation lines in lockstep; `docs/matter_workspace_scope_2026-08-04.md` decision record ratified (D-W1…D-W6); the §14-deferred sentence gains a cross-ref note that the client-only per-matter view shipped as Phase 10 while the real data paths stay deferred.
- Phase 11 landing: README test-count + implemented-foundation lines in lockstep; `docs/unified_search_scope_2026-08-04.md` decision record ratified (D-S1…D-S6); the §14-deferred sentence gains a cross-ref note that the client-only unified-search surface shipped as Phase 11 while the real data paths stay deferred.
- Phase 12 landing: README test-count + implemented-foundation lines in lockstep; `docs/reverse_crosslink_scope_2026-08-04.md` decision record ratified (D-C1…D-C6); the §14-deferred sentence gains a cross-ref note that the client-only reverse cross-link shipped as Phase 12 slice 12.0 while the real data paths stay deferred.
