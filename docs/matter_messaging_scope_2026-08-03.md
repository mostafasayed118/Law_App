# LegalHub — Matter-Scoped Messaging Scope Note (Phase 9, 2026-08-03)

> **APPROVED 2026-08-03** (owner ratification of D-MSG1…D-MSG6 +
> roadmap Phase 9 row). Prepared per the governance-first flow (the Phase 8
> pattern): provenance → decision record → slices behind the standard slice
> gate. Implementation starts with slice 9.0 behind the standard slice gate.

## 1. Provenance

- Basis: `docs/legalhub_specification.md` §4 MVP bullet **"Matter-scoped
  messaging"** and §6 remediation row 154 (`message_center,
  matter_discussion`).
- §14 boundary: `docs/features_roadmap_2026-08-03.md` §14 ("Explicitly
  deferred") defers **messages** (with matters/documents/storage/realtime/
  audit/billing/AI) until P0 closes + policy tests exist;
  `docs/permission_matrix.md` §4 guards matter/document/message access with
  the **"Read a document/message body"** row (deny unless separately
  assigned for partner/compliance_officer; `platform_owner_admin` deny
  always) and its required negative tests — including the
  `platform_owner_admin` worst-case test that must exist before P2 ships
  (matrix §4). This phase ships a **client-only fake-domain surface that
  carries message-thread metadata only — no message bodies exist anywhere**,
  so the matrix's body-reading row is never exercised; the real messages
  data path (table + RLS + storage + realtime) stays §14-deferred and
  untouched.
- Precedent: Phase 5 (`docs/booking_scope_2026-08-03.md` D-B3 fake-domain),
  Phase 6 (`docs/attorney_discovery_scope_2026-08-03.md` D-A2 fake gateway
  seam, D-A4 synthetic non-PII, D-A6 nav-hint gating), Phase 7
  (`docs/matter_dashboard_scope_2026-08-03.md` D-M1 read-first, D-M2 fake
  domain, D-M3 §12 boundary), and Phase 8 (`docs/document_vault_scope_2026-08-03.md`
  D-V1 metadata-only, D-V2 fake domain, D-V3 §12 boundary) — same
  discipline: no backend, no schema/RLS/policy, no matrix addendum.
- This is the **last unbuilt MVP bullet** (spec §4 line 58): everything else
  in "MVP (safe to build)" shipped through Phase 8.

## 2. Decision record (owner ratifies each before implementation)

| # | Decision | Status |
|---|---|---|
| D-MSG1 | The messaging surface is **read-only and thread-metadata-only**: threads render as a list of metadata rows (thread title, matter reference, participants, last-activity date, message count). **The `MessageThread` VO has no body field — no message body ever exists** (structural, mirroring D-V1). No thread-open affordance, no preview, no send, no reply, no composer, no attachments, no delivery, no notifications, no realtime | **ratified 2026-08-03** |
| D-MSG2 | **Fake-domain**: synthetic thread metadata via a `MessageGateway` seam + dev fake (the D-B3 / D-A2 / D-M2 / D-V2 pattern). No backend, no schema/RLS/policy, no matrix addendum (no server change) | **ratified 2026-08-03** |
| D-MSG3 | **§14 boundary**: this phase is client-only demo surface. The real messages data path (table, RLS, storage, realtime) stays deferred per roadmap §14; nothing here grants or implies server-side message access. The matrix §4 "Read a document/message body" row stays untouched **because no message body ever exists in this phase** — even opening a thread would read as message access, so there is no thread-detail route at all | **ratified 2026-08-03** |
| D-MSG4 | Thread metadata carries **synthetic, non-PII data only**: stable synthetic id, generic demo thread title, matter reference (synthetic matter id/title), participant names (generic demo names), last-activity date, message count. No client names, no message text, no real-looking case references (R1 is the heaviest here — thread titles must never read as real case communications) | **ratified 2026-08-03** |
| D-MSG5 | Role gating: messaging entry visible to every bootstrap role via `RoleCapability.canViewMessages` (navigation hint only, never authorization — same posture as `canViewDocuments` / `canViewMatters`) | **ratified 2026-08-03** |
| D-MSG6 | No send/reply/composer affordances and no realtime/delivery/notification copy anywhere (spec §6 row 152 discipline); the local-only demo note marks every thread row as synthetic (R1) | **ratified 2026-08-03** |

## 3. Assumptions & non-goals

- No message bodies, no thread detail/open route, no send/reply/composer,
  no realtime/delivery/notifications, no attachments — those are separate
  future work that stays behind the §14 gate (the matrix's body-reading row
  is the most-guarded content line in the contract).
- The messaging surface is a standalone read-first list (like the matter
  dashboard and vault); it does not hook into the matter details screen in
  this phase (a per-matter thread cross-link is future work, not scoped
  here; it shipped as Phase 10 — the matter details screen renders the
  matter's threads inline per `docs/matter_workspace_scope_2026-08-04.md`).
- The demo session renders the fixed synthetic thread list; there is no
  free-text search in this phase (client-side list only).

## 4. Scope

- **9.0 Messaging gateway + fake**: `MessageThread` VO (no body field) +
  `MessageGateway` seam + dev fake (5 deterministic synthetic non-PII
  thread-metadata rows, D-MSG2/D-MSG4) — the Phase 8 8.0 shape.
- **9.1 Thread list surface**: read-first thread list (title, matter ref,
  participants, last-activity date, message count chip) + empty/error
  states + home entry card under the vault card (D-MSG1, D-MSG5). No
  thread-open affordance (D-MSG3).
- **9.2 l10n**: EN/AR/TR for all new strings; no send/realtime/delivery/
  legal-advice copy (spec §6 row 152 discipline, D-MSG6).

## 5. Acceptance criteria (each mapped to a named test)

| # | Criterion | Verified by |
|---|---|---|
| AC-1 | The messaging surface renders the synthetic thread metadata from the fake gateway (title, matter ref, participants, last-activity date) | `message_gateway_test.dart` (fetch shape, determinism, non-PII) + list screen widget test |
| AC-2 | **Body-less line pin: no thread-open affordance, no composer, no send/reply icons, no message text anywhere** | `message_list_screen_test.dart` (rows show metadata only; no tap target, no chevron, no composer) |
| AC-3 | Empty + error states work client-side | `message_cubit_test.dart` (empty, error, retry) + widget tests |
| AC-4 | Capability gating is a nav hint only (every role `canViewMessages` true) | `user_role_test.dart` capability pin + home/router entry tests |
| AC-5 | All new strings resolve in EN/AR/TR (per-locale resolution, no silent EN copy; local-only wording, no send/realtime/legal-advice claim) | `app_localizations_test.dart` 9.2 pin (Phase 7 7.3 / Phase 8 8.2 pattern) |

## 6. Risks

- **R1 — fake-data honesty (heaviest of all phases):** synthetic thread
  metadata must never read as real case communications — thread titles,
  participants, and matter references use generic demo wording, and the
  local-only note marks every row (D-MSG4/D-MSG6). Even metadata here sits
  one step closer to the contract's most-guarded content class than the
  vault's did.
- **R2 — body-less line:** no message text, thread-open, composer, or
  send/reply affordance may ever render (D-MSG1); the matrix §4
  body-reading row is never exercised.
- **R3 — §14 boundary:** the client-only surface must not imply server
  message access or delivery; the deferral text in roadmap §14 is
  preserved, and the matrix's "Read a document/message body — deny unless
  separately assigned" invariant is untouched.
- **R4 — scope creep:** no send/reply/composer, no thread detail route, no
  realtime/delivery/notifications, no attachments, no matter-details
  cross-link (future work, separate gate).

## 7. Roadmap & ledger hooks (drafted on ratification)

- Roadmap header status line + **§11 Phase 9** section (gate line + slices
  9.0–9.2 table + exit), gate-table row 9, and the §11–§14 renumbering with
  all cross-refs corrected (current §11 Sequencing → §12, §12 Explicitly
  deferred → §13, §13 Ledger hooks → §14) — same edit shape as the Phase 8
  draft.
- Ledger hook bullet for the Phase 9 landing (README count lockstep).
- The §12-deferred sentence naming **messages** gains a cross-ref note that
  the client-only thread-metadata surface shipped as Phase 9 while the real
  messages data path stays deferred.
- Drive-by: the Phase 8 scope note cites the deferred section as "§11" in
  several places (its §1/D-V3/R3 were drafted pre-renumbering); after the
  Phase 8 landing the deferred section is §12, so those refs are corrected
  in the Phase 9 governance commit (same precedent as the Phase 8
  governance slice's Phase 7 note §-ref sync).

## 8. Exit

Roadmap Phase 9 row advanced → decision record ratified (D-MSG1…D-MSG6) →
the three slices built (9.0 gateway+fake, 9.1 thread list surface, 9.2
l10n) → four checks green → suite/README count in lockstep → owner push
approval.
