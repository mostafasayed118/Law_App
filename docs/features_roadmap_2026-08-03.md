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
> committed with this roadmap's gate-table row.
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
> Everything in §10 stays deferred until P0 closes.
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
`list_org_members_metadata` (18 total, §5); the client `SupabaseOrgApi` seam
maps **11** (`listMembers` routes to the R1 member-facing RPC). The remaining
7 are committed and rehearsed server-side but
have no Flutter surface. Each row names the owning phase below (or the gate
that blocks it).

| RPC (`supabase/rpc/`) | Wired in client today? | Owning phase | Notes |
|---|---|---|---|
| `create_organization` | ✅ `createOrganization` | — | shipped |
| `list_members_metadata` | — | owner surface (unused in app UI) | platform-owner-only; the app roster uses the R1 RPC below |
| `list_org_members_metadata` | ✅ `listMembers` | Phase 3 (R1, applied) | **member-facing roster** — partner-scoped (design §8 client slice) |
| `invite_member` | ✅ `inviteMember` | — | shipped |
| `change_member_role` | ✅ `changeMemberRole` | — | shipped |
| `suspend_membership` | ✅ `suspendMember` | — | shipped |
| `reactivate_membership` | ✅ `reactivateMember` | — | shipped |
| `remove_membership` | ✅ `removeMember` | — | shipped |
| `resend_invitation` | ✅ `resendInvitation` | Phase 2 | partner-only per D-10a / matrix §3; `invalidInvitation` kind already mapped |
| `revoke_invitation` | ✅ `revokeInvitation` | Phase 2 | partner-only per D-10a / matrix §3 |
| `accept_invitation` | ✅ `acceptInvitation` | Phase 2 (UX decision) / Phase 4 (deep link) | **R3** in the P3 spec; token-entry UX decided (accept screen) |
| `delete_my_account` | ✅ `deleteMyAccount` | Phase 2 | D-05 requires the hard-delete action (cascade identity + memberships) |
| `list_organizations_metadata` | ❌ | Phase 2 (owner) or Phase 3 (member-facing) | backs the active-org switcher, D-08 |
| `read_org_audit` | ❌ | deferred (§10) | audit surfacing is P2-gated; `platform_owner_admin` self-audit rules apply |
| `read_platform_audit` | ❌ | deferred (§10) | owner-gated; audit table never publicly readable (matrix §6) |
| `delete_demo_account` | ❌ | deferred (§10) | `platform_owner_admin`-only; no owner admin screen until the Addendum's server-side enforcement story is complete |
| `suspend_membership_platform` | ❌ | deferred (§10) | `platform_owner_admin`-only |
| `reactivate_membership_platform` | ❌ | deferred (§10) | `platform_owner_admin`-only |

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
- **2.3 Active-org switcher** — `Session.memberships` exists but there is no
  selector UI. Owner path: `list_organizations_metadata`. Member-facing path
  requires the Phase 3 RPC (matrix §3 "switch active organization" is a UX
  hint only — server re-derives membership per D-08; never trust the
  client-selected org id).
- **2.4 Invitation acceptance (R3)** — `accept_invitation(token)` is already
  failure-mapped (`invalidInvitation`). Needs the **token-entry UX decision**
  (paste-screen vs. deep link). Recommendation: paste-screen in Phase 2;
  deep-link variant moves to Phase 4 with the platform intent-filter work.

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
  URL) remains owner-side and is tracked as R3 in the P3 spec.
- **4.2 Sign-up email-verification UX** — verification is enabled
  server-side; today the flow silently routes to sign-in after sign-up. A
  "check your inbox" state closes the false-assurance gap. Client-only;
  standard slice gate.

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
Client-only; no server change (payment is gated on D-09).

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

## 9. Sequencing & governance gate table

| Order | Phase | Depends on | Server changes? | Gate to pass | Status |
|---|---|---|---|---|---|
| 1 | Phase 1 — P3 org/membership UI | P3 spec approval | no | spec approval → slice → B2 gate stack → owner push approval | **SHIPPED 2026-08-03 (`03862ce`, suite 408, ledger PASS 115)** |
| 2 | Phase 2 — org lifecycle wiring | Phase 1 (same seams) | no | spec-lite scope note → approval → gate stack | **SHIPPED 2026-08-03 (`68aafc6`, slices 2.1–2.4)** |
| 3 | Phase 3 — server amendments | Phase 1/2 (surface defined) | **yes** | spec → RLS-gate review → rehearsal evidence → apply approval → apply execution → matrix addendum | **APPLIED 2026-08-03** (`docs/p3_r1_roster_rpc_design_2026-08-03.md` + matrix §2 addendum + `docs/p3_r1_rehearsal_plan_2026-08-03.md` + evidence r1 PASSED + `supabase/rpc/list_org_members_metadata.sql` + `_down.sql` drop → applied to dev project on the owner's dated apply approval) |
| 4 | Phase 4 — auth plumbing | — | 4.1 yes (platform config) | platform config approval → gate stack | **4.2 SHIPPED 2026-08-03 (`deb72d8`); 4.1 APPROVED + IMPLEMENTED 2026-08-03 (scope note `docs/p4_41_deeplink_recovery_scope_2026-08-03.md`); R1 = dashboard Redirect URL (owner-side)** |
| 5 | Phase 5 — consultation booking (no live payment) | MVP spec §4; auth/org track (§§3–4); D-B7 resolved (standalone) | no | scope note → decision-record ratification → UI + routing slice → gate stack → owner push approval | **SHIPPED 2026-08-03** (`05f13c8` + `0eb7ec9` + `3bd3d29` + `d55e273`, suite 521, ledger PASS 115; pushed to origin/main) |
| 6 | Phase 6 — attorney discovery (read-only, client-only) | MVP spec §4; D-B7 additive `attorneyId` hook; Phase 5 booking seams | no | scope note → decision-record ratification (D-A1…D-A6) → slices 6.1–6.3 → gate stack → owner push approval | **SHIPPED 2026-08-03** (`0f93042` + `7b5c589` + `d389c69`, suite 565, ledger PASS 115; pushed to origin/main) |
| — | §10 deferred capabilities | **P0 closes (D-02…D-10b)** + policy tests + matrix extension | yes | per feature, same P2 discipline | Deferred |

Rules that apply to every phase (definition-of-done from
`docs/codebase_audit_plan.md`): scope/assumptions/non-goals documented ·
required approval gates passed · `git status`/`git diff` reviewed for
secrets and real data · verification commands actually run and reported
honestly · **no commit, push, or deployment without explicit owner
approval**.

## 10. Explicitly deferred (do NOT build until P0 closes + policy tests exist)

Per README boundary + `docs/permission_matrix.md` §4/§6: **matters,
documents, messages, storage, realtime, audit surfacing, billing, AI**.
The matrix requires the `platform_owner_admin` deny-row test and per-row
negative policy tests **before any of these ship**, and an org role alone
never grants matter access. The audit RPCs exist (`read_org_audit`,
`read_platform_audit`) but surfacing them is P2-gated; the owner-only admin
RPCs (`delete_demo_account`, `suspend_membership_platform`,
`reactivate_membership_platform`) stay unwired until the Addendum's
server-side enforcement + auditing story is complete.

## 11. Ledger hooks (what to update when a phase lands)

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
