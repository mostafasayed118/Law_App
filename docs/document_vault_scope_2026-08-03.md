# LegalHub — Document Vault Scope Note (Phase 8, 2026-08-03)

> **APPROVED 2026-08-03** (owner ratification of D-V1…D-V6 + roadmap Phase 8
> row). Prepared per the governance-first flow (the Phase 7 pattern):
> provenance → decision record → slices behind the standard slice gate.
> Implementation starts with slice 8.0 behind the standard slice gate.

## 1. Provenance

- Basis: `docs/legalhub_specification.md` §4 MVP bullet **"Document vault
  (scoped, no e-signature)"** and §6 remediation row 155 (`document_vault`).
- §14 boundary: `docs/features_roadmap_2026-08-03.md` §14 ("Explicitly
  deferred") defers **documents** (with matters/messages/storage/realtime/
  audit/billing/AI) until P0 closes + policy tests exist;
  `docs/permission_matrix.md` §4 guards matter/document access with the
  "Read a document/message body" row (deny unless separately assigned;
  `platform_owner_admin` deny always) and the "org role alone never grants
  matter access" invariant. This phase ships a **client-only fake-domain
  surface that carries document metadata only — no bodies exist anywhere**,
  so the matrix's body-reading row is never exercised; the real documents
  data path (table + RLS + storage + realtime) stays §14-deferred and
  untouched.
- Precedent: Phase 5 (`docs/booking_scope_2026-08-03.md` D-B3 fake-domain),
  Phase 6 (`docs/attorney_discovery_scope_2026-08-03.md` D-A2 fake gateway
  seam, D-A4 synthetic non-PII, D-A6 nav-hint gating), and Phase 7
  (`docs/matter_dashboard_scope_2026-08-03.md` D-M1 read-first, D-M2 fake
  domain, D-M3 §12 boundary) — same discipline: no backend, no
  schema/RLS/policy, no matrix addendum.

## 2. Decision record (owner ratifies each before implementation)

| # | Decision | Status |
|---|---|---|
| D-V1 | The vault is **read-first and metadata-only**: documents render as a list of metadata rows (title, document type, created date). **No bodies, no preview, no download, no upload, no e-signature, no storage semantics** — nothing renders document content | **ratified 2026-08-03** |
| D-V2 | **Fake-domain**: synthetic document metadata via a `DocumentGateway` seam + dev fake (the Phase 5 D-B3 / Phase 6 D-A2 / Phase 7 D-M2 pattern). No backend, no schema/RLS/policy, no matrix addendum (no server change) | **ratified 2026-08-03** |
| D-V3 | **§14 boundary**: this phase is client-only demo surface. The real documents data path (table, RLS, storage, realtime) stays deferred per roadmap §14; nothing here grants or implies server-side document access. The matrix §4 "Read a document/message body" row stays untouched because no document body ever exists in this phase | **ratified 2026-08-03** |
| D-V4 | Document metadata carries **synthetic, non-PII data only**: stable synthetic id, generic demo title, document type (contract / brief / evidence / correspondence chip), created date. No client names, no content, no body text, no real-looking case or file references | **ratified 2026-08-03** |
| D-V5 | Role gating: vault entry visible to every bootstrap role via `RoleCapability.canViewDocuments` (navigation hint only, never authorization — same posture as `canViewMatters` / `canViewAttorneyDiscovery`) | **ratified 2026-08-03** |
| D-V6 | No e-signature / legal-advice / compliance-claim copy anywhere (spec §6 row 152 discipline); the local-only demo note marks every document row as synthetic (R1) | **ratified 2026-08-03** |

## 3. Assumptions & non-goals

- No document upload/preview/download, no e-signature, no storage/realtime,
  no matter-scoped messaging from the vault — those are separate MVP rows
  (spec §6 rows 154/155) with their own §14 gates.
- The vault is a standalone read-first surface (like the matter dashboard);
  it does not hook into the matter details screen in this phase (a
  per-matter vault cross-link is future work, not scoped here; it shipped
  as Phase 10 — the matter details screen renders the matter's documents
  inline per `docs/matter_workspace_scope_2026-08-04.md`).
- The demo session renders the fixed synthetic metadata list; there is no
  free-text search in this phase (client-side list only, mirroring the
  matter dashboard's status-filter posture).

## 4. Scope

- **8.0 Vault gateway + fake**: `Document` VO + `DocumentGateway` seam +
  dev fake (5 deterministic synthetic non-PII metadata rows, D-V2/D-V4) —
  the Phase 7 7.1 shape.
- **8.1 Vault list surface**: read-first document list (title, type chip,
  created date) + empty/error states + home entry card under the matter
  card (D-V1, D-V5).
- **8.2 l10n**: EN/AR/TR for all new strings; no e-signature/legal-advice
  copy (spec §6 row 152 discipline, D-V6).

## 5. Acceptance criteria (each mapped to a named test)

| # | Criterion | Verified by |
|---|---|---|
| AC-1 | The vault renders the synthetic document metadata from the fake gateway (title, type chip, created date) | `document_gateway_test.dart` (fetch shape, determinism, non-PII) + list screen widget test |
| AC-2 | **Metadata-only line pin: no body/preview/download/upload affordances anywhere** | `document_list_screen_test.dart` (rows show metadata only; no action buttons) |
| AC-3 | Empty + error states work client-side | `document_cubit_test.dart` (empty, error, retry) + widget tests |
| AC-4 | Capability gating is a nav hint only (every role `canViewDocuments` true) | `user_role_test.dart` capability pin + home/router entry tests |
| AC-5 | All new strings resolve in EN/AR/TR (per-locale resolution, no silent EN copy; local-only wording, no e-signature/legal-advice claim) | `app_localizations_test.dart` 8.2 pin (Phase 7 7.3 pattern) |

## 6. Risks

- **R1 — fake-data honesty:** synthetic document metadata must never read as
  real files (local-only note + generic demo wording, D-V4).
- **R2 — metadata-only line:** no body/preview/download/upload affordance may
  ever render (D-V1); the matrix §4 body-reading row is never exercised.
- **R3 — §14 boundary:** the client-only surface must not imply server
  document access; the deferral text in roadmap §14 is preserved, and the
  matrix's "Read a document/message body — deny unless separately assigned"
  invariant is untouched.
- **R4 — scope creep:** no e-signature, storage/realtime, upload, or
  matter-scoped messaging from the vault (rows 154/155 keep their own gates).

## 7. Roadmap & ledger hooks (drafted on ratification)

- Roadmap header status line + **§10 Phase 8** section (gate line + slices
  8.0–8.2 table + exit), gate-table row 8, and the §10–§13 renumbering with
  all cross-refs corrected (current §10 Sequencing → §11, §11 Explicitly
  deferred → §12, §12 Ledger hooks → §13) — same edit shape as the Phase 7
  draft.
- Ledger hook bullet for the Phase 8 landing (README count lockstep).
- The §12-deferred sentence naming **documents** gains a cross-ref note that
  the client-only metadata surface shipped as Phase 8 while the real data
  path stays deferred.

## 8. Exit

Roadmap Phase 8 row advanced → decision record ratified (D-V1…D-V6) → the
three slices built (8.0 gateway+fake, 8.1 list surface, 8.2 l10n) → four
checks green → suite/README count in lockstep → owner push approval.
