# LegalHub — Matter Dashboard & Org Switcher Scope Note (Phase 7, 2026-08-03)

> **APPROVED 2026-08-03** (owner ratification of D-M1…D-M7 + roadmap Phase 7
> row). Prepared per the governance-first flow (the Phase 6 pattern):
> provenance → decision record → slices behind the standard slice gate.
> Implementation starts with slice 7.0 behind the standard slice gate.

## 1. Provenance

- Basis: `docs/legalhub_specification.md` §4 MVP bullet **"Case/matter
  dashboard & details (read-first)"** and §6 remediation row 156
  (`case_management_dashboard, case_details, shared_case_workspace`).
- Org switcher: `docs/p0_decision_capture.md` **D-08** (decided 2026-07-31:
  multi-membership, active-org is a **client-side UX convenience only** —
  every server request re-derives membership, never trusts a client-selected
  org id) and `docs/features_roadmap_2026-08-03.md` §4 slice **2.3**
  ("`Session.memberships` exists but there is no selector UI") — declared,
  never shipped despite the Phase 2 gate row reading "slices 2.1–2.4".
- §10 boundary: `docs/features_roadmap_2026-08-03.md` §10 defers
  **matters** (and documents/messages/storage/realtime/audit/billing/AI)
  until P0 closes + policy tests exist; `docs/permission_matrix.md` §4/§6
  requires that "an org role alone never grants matter access". This phase
  ships a **client-only fake-domain surface**; the real matters data path
  (table + RLS + storage + realtime) stays §10-deferred and untouched.
- Precedent: Phase 5 (`docs/booking_scope_2026-08-03.md` D-B3 fake-domain)
  and Phase 6 (`docs/attorney_discovery_scope_2026-08-03.md` D-A2 fake
  gateway seam, D-A4 synthetic non-PII, D-A6 nav-hint gating) — same
  discipline: no backend, no schema/RLS/policy, no matrix addendum.

## 2. Decision record (owner ratifies each before implementation)

| # | Decision | Status |
|---|---|---|
| D-M1 | Matter surfaces are **read-first**: no create / edit / close / upload / action from matter surfaces. Details render a read-only projection of the synthetic matter; no action affordances | **ratified 2026-08-03** |
| D-M2 | **Fake-domain**: synthetic matter list via a `MatterGateway` seam + dev fake (the Phase 5 D-B3 / Phase 6 D-A2 pattern). No backend, no schema/RLS/policy, no matrix addendum (no server change) | **ratified 2026-08-03** |
| D-M3 | **§10 boundary**: this phase is client-only demo surface. The real matters data path (table, RLS, storage, realtime) stays deferred per roadmap §10; nothing here grants or implies server-side matter access ("an org role alone never grants matter access" is untouched) | **ratified 2026-08-03** |
| D-M4 | Matter previews carry **synthetic, non-PII data only**: stable synthetic id, generic demo title, practice area, lifecycle status (open/active/closed chip), assigned-attorney display name (reusing the Phase 6 synthetic roster), created date. No client names, no real-looking case numbers, no contact data | **ratified 2026-08-03** |
| D-M5 | Matter list is a **client-side view** over the fake list (status filter only); details are a read-only projection of the same VO. No server search RPC | **ratified 2026-08-03** |
| D-M6 | Role gating: matter dashboard + org-switcher entry visible to every bootstrap role via `RoleCapability` (navigation hint only, never authorization — same posture as `canBookConsultation` / `canViewAttorneyDiscovery`) | **ratified 2026-08-03** |
| D-M7 | **Active-org switcher (7.0)**: selector surfaces `Session.memberships` (D-08 client-side convenience); selection updates a session-scoped client `ActiveOrgStore` consumed by the orgs hub. The committed `list_organizations_metadata` RPC stays **unwired** (inventory row keeps ❌; cross-ref here). The client never sends the selected org id as an authority | **ratified 2026-08-03** |

## 3. Assumptions & non-goals

- No matter messaging, no document upload/preview, no availability, no
  billing, no realtime from any matter surface — those are separate MVP rows
  (spec §6 rows 154/155) with their own §10 gates.
- The demo session carries one active membership (`org-demo`); the switcher
  renders that membership and pins the *shape* (multi-org is a D-08
  contract, not a demo fixture).
- The home dashboard practice-area/recent-activity fixtures stay as-is;
  this phase only adds the matter entry card + surfaces.

## 4. Scope

- **7.0 Active-org switcher**: `ActiveOrgStore` (client-side, session-scoped,
  seeded from `Session.activeMembership`), a switcher sheet listing
  `Session.memberships`, entry from the settings/orgs area; orgs hub reads
  the store. Pure client; D-08.
- **7.1–7.3 Matter surfaces**: `Matter` VO + `MatterGateway` seam + dev fake
  (5 deterministic synthetic non-PII matters, D-M2/D-M4); matter list screen
  with status filter + empty state (D-M5); matter details screen (read-first,
  D-M1); home entry card under the discovery card.
- **7.4 l10n**: EN/AR/TR for all new strings; no legal-advice/compliance
  copy (spec §6 row 152 discipline).

## 5. Acceptance criteria (each mapped to a named test)

| # | Criterion | Verified by |
|---|---|---|
| AC-1 | The matter list renders the synthetic matters from the fake gateway (title, status chip, practice area, assigned attorney) | `matter_gateway_test.dart` (fetch shape, determinism, non-PII) + list screen widget test |
| AC-2 | Status filter + empty state work client-side | `matter_cubit_test.dart` (filter, empty) + widget tests |
| AC-3 | Details render the read-only projection — **no action buttons** | `matter_details_screen_test.dart` (AC-3 fields + read-only line pin) |
| AC-4 | The org switcher lists `Session.memberships` and updates the `ActiveOrgStore` (client-side only, D-08) | `active_org_store_test.dart` + switcher widget test + orgs-hub reads the store |
| AC-5 | Capability gating is a nav hint only (every role `canViewMatters` true) | `user_role_test.dart` capability pin + home/router entry tests |
| AC-6 | All new strings resolve in EN/AR/TR (per-locale resolution, no silent EN copy; local-only wording, no legal-advice claim) | `app_localizations_test.dart` 7.4 pin (Phase 6 6.3 pattern) |

## 6. Risks

- **R1 — fake-data honesty:** synthetic matters must never read as real
  cases (local-only note + generic demo wording, D-M4).
- **R2 — read-only line:** any matter action (create/edit/close/upload) is
  out (D-M1); the details surface carries no action affordances.
- **R3 — §10 boundary:** the client-only surface must not imply server
  matter access; the deferral text in roadmap §10 is preserved, and the
  matrix's "org role alone never grants matter access" invariant is
  untouched.
- **R4 — scope creep:** no messaging/documents/availability/billing from
  matter surfaces (rows 154/155 keep their own gates).

## 7. Roadmap & ledger hooks (drafted on ratification)

- Roadmap header status line + **§9 Phase 7** section (gate line + slices
  7.0–7.4 table + exit), gate-table row 7, and the §10–§12 renumbering with
  all cross-refs corrected — same edit shape as the Phase 6 draft.
- Ledger hook bullet for the Phase 7 landing (README count lockstep).
- `docs/features_roadmap_2026-08-03.md` §4 slice 2.3 note updated to point
  here once ratified ("shipped as Phase 7 slice 7.0").

## 8. Exit

Roadmap Phase 7 row advanced → decision record ratified (D-M1…D-M7) → the
five slices built (7.0 switcher, 7.1 gateway+fake, 7.2 list, 7.3 details,
7.4 l10n) → four checks green → suite/README count in lockstep → owner push
approval.
