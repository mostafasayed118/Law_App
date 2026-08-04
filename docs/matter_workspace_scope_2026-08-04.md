# LegalHub — Matter Workspace Scope Note (Phase 10, 2026-08-04)

> **APPROVED 2026-08-04** (owner ratification of D-W1…D-W6 + roadmap
> Phase 10 row). Prepared per the governance-first flow (the Phase 8/9
> pattern): provenance → decision record → slices behind the standard
> slice gate. Implementation starts with slice 10.0 behind the standard
> slice gate.

## 1. Provenance

- Basis: `docs/legalhub_specification.md` §4 MVP bullet **"Case/matter
  dashboard & details (read-first)"** and §6 remediation row 156
  (`case_management_dashboard, case_details, shared_case_workspace`).
- **Declared future work in three ratified scope notes:**
  - `docs/document_vault_scope_2026-08-03.md` §3: *"a per-matter vault
    cross-link is future work, not scoped here."*
  - `docs/matter_messaging_scope_2026-08-03.md` §3: *"a per-matter thread
    cross-link is future work, not scoped here."*
  - `docs/matter_dashboard_scope_2026-08-03.md` §3: no matter messaging /
    documents from any matter surface was a non-goal *only because* rows    154/155 kept their own deferred-section gates — **Phases 8 and 9
     shipped those surfaces**, so the per-matter cross-link is now
     unblocked.
- §14 boundary: `docs/features_roadmap_2026-08-03.md` §14 still defers the
  **real** matters/documents/messages data paths (table + RLS + storage +
  realtime) until P0 closes + policy tests exist. This phase ships a
  **client-only per-matter view over the existing synthetic fake-domain
  lists** — no backend, no schema/RLS/policy, no matrix addendum (the
  matrix's "Read a document/message body" row stays untouched because no
  body ever exists anywhere, and no new server surface is introduced).
- Precedent: Phases 5–9 (D-B3 / D-A2 / D-M2 / D-V2 / D-MSG2 fake-domain
  discipline) and the Phase 7 details pattern (D-M5: the details screen
  resolves a matter from the loaded synthetic list — **no per-id fetch**).
  The matter workspace extends that same client-side-view discipline.

## 2. Decision record (owner ratifies each before implementation)

| # | Decision | Status |
|---|---|---|
| D-W1 | The matter workspace is **read-first per-matter views** of the existing fake-domain lists: the matter details screen renders a **Documents section** (documents filtered to the matter) and a **Messages section** (threads filtered to the matter). Client-only; **no server change, no new RPC, no matrix addendum** | **ratified 2026-08-04** |
| D-W2 | `Document` VO gains a **`matterRef`** field — one of the 5 known synthetic matter titles, the same shape `MessageThread.matterRef` already uses (D-MSG4). **No new identity surface**: the per-matter association is keyed on the synthetic matter title shared across the fakes (D-V4/D-M4/D-MSG4), never on ids, so the workspace cannot imply server-side scoping. The `Document` props-pin test is updated as a deliberate edit | **ratified 2026-08-04** |
| D-W3 | Entry points: inline sections on the existing `/matters/:matterId` details screen (which already loads the synthetic matter list and resolves by id, D-M5). **No new routes**; the standalone vault and messages list surfaces keep their current behavior unchanged | **ratified 2026-08-04** |
| D-W4 | **Body-less + metadata-only lines preserved on the matter surface**: no document preview/download, no thread-open affordance, no composer, no send/reply on the sections — the AC-2 pins of Phases 8/9 extend to the sections | **ratified 2026-08-04** |
| D-W5 | Capability gating **reuses** `canViewDocuments` / `canViewMessages` (already true for every bootstrap role; navigation hints only, never authorization). A matter details screen renders a section only when the corresponding capability is granted | **ratified 2026-08-04** |
| D-W6 | All new strings resolve in EN/AR/TR; per-matter sections carry the local-only demo framing (R1) | **ratified 2026-08-04** |

## 3. Assumptions & non-goals

- The per-matter association is a **client-side filter** over the existing
  gateway lists (`fetchDocuments` / `fetchThreads`); no per-matter fetch,
  no new gateway method, no filter RPC.
- The workspace reuses the shipped `DocumentCubit` / `MessageCubit`
  (feature-scoped, per-screen `BlocProvider`) — no new cubits.
- Non-goals: no matter-scoped actions (create/edit/close), no attachments,
  no realtime/delivery, no document preview/download, no thread-detail
  route, no per-matter search, no changes to the standalone vault or
  messages surfaces, no server amendment of any kind.
- The demo session renders the fixed synthetic lists; the workspace shows
  each matter's subset of those lists.

## 4. Scope

- **10.0 `Document.matterRef` + fake rows**: additive `matterRef` field on
  `Document` (D-V4 discipline) and the 5 synthetic rows gain a matter
  reference (one of the known synthetic matter titles); the VO props-pin
  test and the gateway shape test are updated deliberately (D-W2).
- **10.1 Matter-workspace sections**: the details screen renders a
  Documents section and a Messages section, each a feature-local widget
  that provides its own `DocumentCubit` / `MessageCubit` and filters the
  loaded list by the matter's title (`matter.title == matterRef`);
  per-matter empty sections render localized empty copy (D-W1/D-W3/D-W5).
- **10.2 l10n**: EN/AR/TR for all new strings (section titles, per-matter
  empty copy); local-only framing; no legal-advice/send/realtime copy
  (spec §6 row 152 discipline, D-W6).

## 5. Acceptance criteria (each mapped to a named test)

| # | Criterion | Verified by |
|---|---|---|
| AC-1 | Each matter's details surface renders **only that matter's** synthetic documents and threads (per-matter filter over the fake lists) | `document_gateway_test.dart` / `message_gateway_test.dart` (matterRef shape) + matter-workspace widget tests |
| AC-2 | **Body-less/read-only line pin**: no document preview/download, no thread-open affordance, no composer/send-reply on the matter surface | matter-workspace widget tests (the Phase 8/9 AC-2 absence assertions, extended to the sections) |
| AC-3 | Per-matter empty sections render the localized empty copy client-side | matter-workspace widget tests (empty stub) |
| AC-4 | Capability gating unchanged — sections render only under `canViewDocuments` / `canViewMessages` (nav hints only) | home/router/capability tests (no new flag; existing flags reused) |
| AC-5 | All new strings resolve in EN/AR/TR (per-locale resolution, no silent EN copy; local-only wording) | `app_localizations_test.dart` 10.2 pin (Phase 8 8.2 / Phase 9 9.2 pattern) |

## 6. Risks

- **R1 — fake-data honesty:** per-matter associations must reuse the known
  synthetic matter titles only — the sections must never read as real case
  files or real case communications (D-W2/D-W6).
- **R2 — body-less/read-only line:** the Phase 8/9 AC-2 absences hold on
  the matter surface too (D-W4); the matrix's body-reading row stays
  unexercised.
- **R3 — §14 boundary:** the per-matter view is client-side over synthetic
  lists; it must not imply server-side matter workspaces or scoping. The
  deferral text in roadmap §14 is preserved.
- **R4 — scope creep:** no matter-scoped actions, attachments, realtime,
  per-matter fetches, or changes to the standalone surfaces.

## 7. Roadmap & ledger hooks (drafted for ratification)

- Roadmap header status line + a new **Phase 10** section (gate line +
  slices 10.0–10.2 table + exit), gate-table row 10, and the §12–§14
  renumbering (current §12 Sequencing → §13, §13 Explicitly deferred →
  §14, §14 Ledger hooks → §15) with all cross-refs corrected — same edit
  shape as the Phase 9 draft.
- The three scope notes' "future work" sentences (vault §3, messaging §3,
  matter dashboard §3) gain a cross-ref that the per-matter view shipped as
  Phase 10.
- Ledger hook bullet for the Phase 10 landing (README count lockstep).

## 8. Exit

Roadmap Phase 10 row added → decision record ratified (D-W1…D-W6) → the
three slices built (10.0 Document.matterRef, 10.1 workspace sections, 10.2
l10n) → four checks green → suite/README count in lockstep → owner push
approval.
