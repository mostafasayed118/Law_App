# LegalHub — Reverse Cross-Link Scope Note (Phase 12, 2026-08-04)

> **Record type:** Spec-lite scope note required by the Phase 12 gate (the
> Phase 8/9/10/11 pattern): provenance → decision record → assumptions &
> non-goals → slices behind the standard slice gate → acceptance criteria →
> risks → roadmap & ledger hooks. **Status: RATIFIED (2026-08-05) — D-C1…D-C6 ratified + the roadmap
> Phase 12 row added (slice 12.0 shipped `16e9b67` 2026-08-05; slices
> 12.1–12.2 pending per §4).**
> **Planning owner:** `docs/features_roadmap_2026-08-03.md` — this phase is
> **Phase 12** of that roadmap, the owning planning document for feature
> sequencing.

## 0. Audit context (why this phase exists)

Phase 11 explicitly deferred this work: `docs/unified_search_scope_2026-08-04.md`
§3 non-goals and risk R4 both name *"no reverse cross-links from list rows to
matter details (the D-V1/D-MSG1 'rows are not tap targets' pins stay
untouched — a future phase may revisit them)."* That future phase is this
one.

The buildable gap: every matter is reachable from the `/matters` list and
from search matter rows, but a document row in the vault and a thread row in
the messages list carry a `matterRef` (Phase 10, D-W2) that the user cannot
act on — the row renders the association only if it is displayed, and there
is no way to reach the matter it names. The P10 `matterRef` seam is the
natural key for a **reverse cross-link** (list row → matter details), and
the destination route already exists and is read-only.

## 1. Provenance

- Basis: `docs/legalhub_specification.md` §4 MVP bullet **"Case/matter
  dashboard & details (read-first)"** and the shipped Phase 8/9/10 surfaces.
  A cross-link that lands on an existing read-only matter surface extends
  the read-first line; it opens no new content anywhere.
- **Declared future work in shipped artifacts:**
  - `docs/unified_search_scope_2026-08-04.md` §3/R4 — reverse cross-links
    deferred to "a future phase" (the loose shorthand "D-V1/D-MSG1" there
    refers to the vault pin **D-V1** and the messaging pin **D-MSG3** below;
    this note cites them precisely).
  - `test/features/documents/document_list_screen_test.dart` (AC-2) — *"Rows
    are not tap targets: no chevron … and no InkWell anywhere in the list
    (D-V1 — there is no details route)."*
  - `test/features/messaging/message_list_screen_test.dart` (AC-2) — *"Rows
    are not tap targets: no chevron … and no InkWell anywhere in the list
    (D-MSG3 — there is no thread-detail route)."*
  - `lib/features/documents/presentation/document_list_screen.dart` and
    `lib/features/messaging/presentation/message_list_screen.dart` doc
    comments — "no trailing action … rows must [not be tap targets]".
- **Seams reused (all shipped, all client-only):**
  - `Document.matterRef` (Phase 10, D-W2) and `MessageThread.matterRef`
    (Phase 9, D-MSG4) — both keyed on the **known synthetic matter titles**,
    never ids (no identity surface, cannot imply server scoping).
  - `MatterGateway.fetchMatters()` (Phase 7, D-M2/D-M4) + the D-M5
    resolve-from-the-loaded-list discipline (the details screen already
    resolves a matter by id from the loaded list — no per-id fetch exists).
  - The `/matters/:matterId` route (`AppRoutes.matterDetail`) and
    `MatterDetailsScreen` — an existing read-only route (Phase 7).
  - `RoleCapability.canViewMatters` + the router's role-capability
    projection pattern (Phase 10 D-W5 / Phase 11 D-S2) for nav-hint gating.
- §14 boundary: `docs/features_roadmap_2026-08-03.md` §14 still defers the
  **real** matters/documents/messages data paths until P0 closes + policy
  tests exist. This phase ships a **client-only reverse link over the
  existing synthetic fake-domain lists** — no backend, no schema/RLS/policy,
  no matrix addendum (the matrix's "Read a document/message body" row stays
  untouched because a cross-link navigates to the read-only matter surface,
  never to a body).
- Precedent: Phase 10 D-W2 (title-keyed `matterRef` association), Phase 7
  D-M5 (client-side resolve from the loaded list), Phase 11 D-S3
  (navigate-to-existing-read-only-routes-only discipline). The cross-link
  adds **no new identity or server surface** — it resolves a title the fakes
  already share and reuses a route that already exists.

## 2. Decision record (ratified 2026-08-05)

| # | Decision | Status |
|---|---|---|
| D-C1 | The reverse cross-link is a **client-side navigation hint** from vault document rows and messages thread rows to the existing matter details route `/matters/:matterId`, built on the Phase 10 `matterRef` association. **No new route, no new gateway method, no RPC, no server change** | ratified 2026-08-05 |
| D-C2 | **The D-V1 / D-MSG3 "rows are not tap targets" pins are deliberately revisited** (the Phase 11 deferral named this phase): a row whose `matterRef` resolves to a known synthetic matter renders a **trailing "View matter" affordance — the only tap target in the list** (a compact chip/link with l10n copy + a distinct icon; **not** `chevron_right`, `download`, `visibility`, or `open_in_new`, and no Preview/Download text, so the Phase 8/9 AC-2 absence lists stay meaningful). A row whose `matterRef` does not resolve renders **no affordance** and stays metadata-only. The pins are **re-scoped, not deleted**: the no-chevron line holds everywhere, and the only `InkWell` in the list lives inside a resolved row's chip | ratified 2026-08-05 |
| D-C3 | Resolution is **title-keyed and client-side** (D-M5): load the synthetic matter list through `MatterGateway.fetchMatters()` and match `matterRef == matter.title` to obtain the destination `matterId`. No per-id fetch, no filter RPC, and the association stays keyed on the shared synthetic titles (D-W2) — it cannot imply server-side scoping | ratified 2026-08-05 |
| D-C4 | Capability gating **reuses** `canViewMatters` (the destination is a matter surface; navigation hint only, never authorization — the D-W5 posture). The router passes the role-capability projection to the vault and messages builders (the Phase 11 search-route pattern), and the affordance renders only when the capability is granted | ratified 2026-08-05 |
| D-C5 | The cross-link is **read-only navigation only**: the destination is the existing read-only matter details surface (title, status, practice area, assigned attorney, created date, capability-gated workspace sections). No document preview/download, no thread-open, no composer, no send/reply — the body-less AC-2 lines of Phases 8/9 hold everywhere except for the added affordance itself | ratified 2026-08-05 |
| D-C6 | All new strings resolve in EN/AR/TR; the affordance copy stays generic demo wording and the list surfaces keep their local-only notes (R1, D-S5 posture) | ratified 2026-08-05 |

## 3. Assumptions & non-goals

- The fake rows are coherent: every synthetic `Document.matterRef` and
  `MessageThread.matterRef` names one of the 5 known synthetic matter
  titles, so every row resolves — the unresolved-row case is a defensive
  pin (D-C2) for future fake drift, not a shipped scenario.
- Each list screen loads its own gateway list through its existing feature
  cubit; the cross-link's matter lookup reuses `MatterGateway` (resolved
  from the service locator, D-M5 style) — no shared cache, no new DI
  registration beyond any feature-local resolver widget.
- Non-goals: no thread-detail route, no document preview/download, no
  changes to the standalone `/matters` list or the search surface's matter
  rows, **no matter affordance on search document/thread rows** (a
  follow-up if wanted — search rows already navigate to `/vault` and
  `/messages` per D-S3), no deep links / URI scheme, no server amendment of
  any kind, no matrix addendum. The vault and messages surfaces change only
  by the added affordance.
- The demo session renders the fixed synthetic lists; the cross-link works
  entirely against those lists.

## 4. Scope

- **12.0 Vault reverse link**: a shared client-side matter resolver
  (title → matter, D-M5 discipline) + the document-row "View matter"
  affordance on `DocumentListScreen`; the D-V1 pin in
  `document_list_screen_test.dart` is re-scoped as a **deliberate edit**
  (D-C2, justified in the test comment); the router passes the capability
  projection to the vault builder (D-C4). *Sketch:*
  `features/documents/presentation/` row-affordance widget +
  `features/matters/domain/` title-resolver helper.
- **12.1 Messages reverse link**: the same resolver + the thread-row "View
  matter" affordance on `MessageListScreen`; the D-MSG3 pin in
  `message_list_screen_test.dart` is re-scoped as a deliberate edit; the
  router passes the capability projection to the messages builder.
  *Sketch:* `features/messaging/presentation/` row-affordance widget.
- **12.2 l10n**: EN/AR/TR for the affordance copy (and any empty/edge copy);
  local-only framing preserved; no legal-advice/send/realtime copy (spec §6
  row 152 discipline, D-C6).

## 5. Acceptance criteria (each mapped to a named test)

| # | Criterion | Verified by |
|---|---|---|
| AC-1 | A document row whose `matterRef` resolves renders the "View matter" affordance and navigates to `/matters/:matterId` of the matching matter (title-keyed client-side resolution) | vault widget tests + router navigation pin (12.0) |
| AC-2 | A thread row whose `matterRef` resolves renders the affordance and navigates to the matching matter's details route | messages widget tests + router navigation pin (12.1) |
| AC-3 | **Re-scoped absence pins**: rows never carry `chevron_right` / `download` / `visibility` / `open_in_new` / Preview / Download text, and the only `InkWell` in either list is inside a resolved row's chip; a stubbed unresolved `matterRef` renders no affordance | the deliberately edited AC-2 tests in `document_list_screen_test.dart` / `message_list_screen_test.dart` (D-C2) |
| AC-4 | Capability gating reused — the affordance renders only under `canViewMatters` (nav hints only; no new flag) | capability-combination router/widget tests (D-C4) |
| AC-5 | All new strings resolve in EN/AR/TR (per-locale resolution, no silent EN copy; local-only wording) | `app_localizations_test.dart` 12.2 pin (Phase 9 9.2 / Phase 10 10.2 / Phase 11 11.2 pattern) |

## 6. Risks

- **R1 — fake-data honesty:** the cross-link must read as navigation between
  demo surfaces, never as a real case-file link; it reuses the known
  synthetic titles only (D-W2/D-C3) and the list surfaces keep their
  local-only notes (D-C6).
- **R2 — read-only/body-less line:** the link navigates to the existing
  read-only details surface and opens no content; the Phase 8/9 AC-2
  absences hold everywhere except the affordance itself (D-C5).
- **R3 — §14 boundary:** the link is client-side over synthetic lists; it
  must not imply server-side matter scoping or access. The deferral text in
  roadmap §14 is preserved; no matrix row is exercised.
- **R4 — scope creep:** no thread-detail route, no preview/download, no
  search-surface changes, no deep links, no matter-scoped actions, no
  server amendment.
- **R5 — pin churn:** the D-V1 / D-MSG3 pins are load-bearing absence
  guarantees; re-scoping them must be a **deliberate, commented edit** that
  narrows rather than deletes the guarantee (the D-W2 "deliberate edit"
  discipline) so the metadata-only line survives review.

## 7. Roadmap & ledger hooks (ratified 2026-08-05)

- Roadmap header status line + a new **Phase 12** section (gate line +
  slices 12.0–12.2 table + exit) + gate-table row 12 + the §14 cross-ref
  sentence — same edit shape as the Phase 11 ratification.
- Cross-refs from the artifacts that named the deferral: the search note's
  §3/R4 "future phase" sentence, and the vault/messages test pins + doc
  comments, gain a note that the pins were deliberately re-scoped by
  Phase 12 (D-C2).
- Ledger hook bullet for the Phase 12 landing (README test-count +
  implemented-foundation lines in lockstep — the ledger gate's §2d check).

## 8. Exit

Roadmap Phase 12 row added → decision record ratified (D-C1…D-C6) → the
three slices built (12.0 vault reverse link, 12.1 messages reverse link,
12.2 l10n) → four checks green (`bash scripts/verify_ledger.sh` +
`dart format --output=none --set-exit-if-changed .` + `flutter analyze` +
`flutter test`) → suite/README count in lockstep → owner push approval.
