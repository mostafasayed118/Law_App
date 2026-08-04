# LegalHub — Unified Search Scope Note (Phase 11, 2026-08-04)

> **Record type:** Spec-lite scope note required by the Phase 11 gate (the
> Phase 8/9/10 pattern): provenance → decision record → assumptions &
> non-goals → slices behind the standard slice gate → acceptance criteria →
> risks → roadmap & ledger hooks. **Status: RATIFIED (2026-08-04).**
> D-S1…D-S6 ratified 2026-08-04 and slices 11.0–11.2 built (suite 691;
> exit gate + owner push approval pending per `INSTRUCTIONS.md` §2.1).
> **Planning owner:** `docs/features_roadmap_2026-08-03.md` — this phase is
> **Phase 11** of that roadmap, the owning planning document for feature
> sequencing.

## 0. Audit context (why this phase exists)

Remaining deferred/inventory items in `docs/features_roadmap_2026-08-03.md`
fall into three buckets, and only one is buildable client work today:

- **Unwired RPCs (§2)** — `list_members_metadata` and
  `list_organizations_metadata` are owner-side/enrichment-only (deliberately
  unwired per D-08/D-M7); `read_org_audit`, `read_platform_audit`,
  `delete_demo_account`, `suspend_membership_platform`,
  `reactivate_membership_platform` are §14-deferred and require the Addendum's
  server-side enforcement + auditing story first. **Not client slices.**
- **Provider/owner-side actions** — Phase 3 R2 invite emails (GoTrue email
  trigger; touches provider config) and Phase 4.1 R1 (dashboard Redirect
  URL; owner-side dashboard entry). **Not repo-code slices.**
- **§14 (P0-gated)** — real matters/documents/messages data paths, storage,
  realtime, audit surfacing, billing, AI, and the P2 §4.5 provider loop.
  **Do not build until P0 closes + policy tests exist.**

The buildable gap this phase closes: the **home search field is inert**
(`HomeScreen._searchController` + the `searchPlaceholder` l10n key exist, but
the field has no `onChanged`/`onSubmitted` — it renders and does nothing),
while four read-first fake-domain seams (Phases 6–10) already sit in the
service locator. This phase wires search to those seams client-side and
navigates results to the existing read-only routes only.

## 1. Provenance

- Basis: `docs/legalhub_specification.md` §4 MVP bullets and the shipped
  Phase 6–10 surfaces — the search surface is a **client-side aggregation
  view over the existing synthetic fake-domain lists**, nothing more.
- **Declared gap in shipped code:** `HomeScreen` renders a
  `LegalHubTextField(hint: l10n.searchPlaceholder, prefixIcon: Icons.search)`
  with a `TextEditingController` and **no submit handler** — a dead affordance.
  The l10n keys already exist (`searchPlaceholder`); the surface is missing.
- **Seams reused (all shipped, all client-only):**
  - `MatterGateway.fetchMatters()` (Phase 7, D-M2/D-M4)
  - `DocumentGateway.fetchDocuments()` (Phase 8, D-V2/D-V4 — metadata only,
    incl. `matterRef` from Phase 10 D-W2)
  - `MessageGateway.fetchThreads()` (Phase 9, D-MSG2/D-MSG4 — body-less,
    incl. `matterRef`)
  - `AttorneyGateway.fetchAttorneys()` (Phase 6, D-A2/D-A4)
- §14 boundary: `docs/features_roadmap_2026-08-03.md` §14 still defers the
  **real** matters/documents/messages data paths until P0 closes + policy
  tests exist. This phase ships a **client-only search over the existing
  synthetic lists** — no backend, no schema/RLS/policy, no matrix addendum.
  The matrix's "Read a document/message body" row stays untouched because
  search renders metadata rows only, never bodies, and every result
  navigates to an already-shipped read-only surface.
- Precedent: Phases 7–10 (D-M2/D-V2/D-MSG2 fake-domain discipline, D-M5
  client-side-view discipline, D-W2 `matterRef` association, D-W5 capability
  reuse). Search adds **no new identity or server surface** — it filters and
  groups the lists that already exist.

## 2. Decision record (ratified 2026-08-04)

| # | Decision | Status |
|---|---|---|
| D-S1 | The search surface is **client-side, read-first, and aggregating**: it loads the four existing gateway lists and filters/ranks them by a single query — **no new gateway seam, no new RPC, no server change**. Matching fields: matter title/status/practice-area, document title/type/`matterRef`, thread title/participants/`matterRef`, attorney name/practice-area. Results render **metadata only** (the same fields the list surfaces already show) | **ratified 2026-08-04** |
| D-S2 | Results are grouped by kind (Matters / Documents / Messages / Attorneys) with per-group capability gating **reusing** `canViewMatters` / `canViewDocuments` / `canViewMessages` / `canViewAttorneyDiscovery` (nav hints only, never authorization — the D-W5 posture). A group renders only when its capability is granted | **ratified 2026-08-04** |
| D-S3 | Every result row is a **navigation hint to an existing read-only route**: matter → `/matters/:matterId`, document → `/vault`, thread → `/messages`, attorney → `/discovery/:attorneyId`. **No new routes, no new content rendering, no thread-open, no document preview** — the Phase 8/9 AC-2 absence lines hold on the search surface | **ratified 2026-08-04** |
| D-S4 | The home search field is **wired** (submit navigates to `/search?q=<query>`); the search route is a full-surface search (debounced client-side filtering). Empty query on the search route shows the no-query state, not results. The practice-area cards and notification bell **stay inert** — out of scope | **ratified 2026-08-04** |
| D-S5 | **Fake-data honesty + local-only framing**: results reuse the same synthetic non-PII rows (no client names, no real-looking case refs); the search surface carries the local-only demo note (the R1 posture of Phases 6–10). Matching is case-insensitive over demo wording only | **ratified 2026-08-04** |
| D-S6 | All new strings resolve in EN/AR/TR; search-specific copy only (result-group titles, no-query/empty states, results count) — the `searchPlaceholder` key already shipped and is reused | **ratified 2026-08-04** |

## 3. Assumptions & non-goals

- Search is a **client-side filter over the loaded gateway lists** (the D-M5
  "no server search RPC" discipline extended); no per-result fetch, no
  ranking service, no fuzzy matching, no history.
- The search route loads the lists through the existing cubits/gateways
  registered in the service locator; no new DI registrations beyond the
  search cubit itself.
- Non-goals: no full-text/body search (no bodies exist anywhere, D-V1/D-MSG1),
  no realtime/suggestions, no search history, no filters beyond the single
  query, no changes to the standalone vault/messages/discovery/matters
  surfaces, no reverse cross-links from list rows to matter details (the
  D-V1/D-MSG1 "rows are not tap targets" pins stay untouched — a future
  phase may revisit them), no server amendment of any kind, no matrix
  addendum.
- The demo session renders the fixed synthetic lists; search returns each
  list's matching subset.

## 4. Scope

- **11.0 Search domain**: `SearchResults` grouping VO (matters/documents/
  threads/attorneys, each an ordered subset) + a `SearchCubit` that composes
  the four existing gateways (sequential loads via `Future.wait`), filters
  case-insensitively on the D-S1 field set, and emits a `SearchState`
  (idle / loading / empty-query / results / error) on the shared `ViewState`
  vocabulary. Provider-free: depends only on the four gateway seams.
  *Sketch:* `lib/features/search/domain/search_results.dart`,
  `presentation/search_cubit.dart`, `presentation/search_state.dart`.
- **11.1 Search surface + wiring**: `/search` route (query read from the
  route's `q` query-param, `?q=` never carries real data — local-only),
  search screen rendering grouped metadata rows with capability gating
  (D-S2/D-S3), empty/no-query/error states, local-only note (D-S5); the home
  search field gains an `onSubmitted` that navigates to `/search?q=…`.
  *Sketch:* `presentation/search_screen.dart` + feature-local result-row
  widgets (matter/document/thread/attorney rows reusing the existing
  read-only row shapes).
- **11.2 l10n**: EN/AR/TR for all new strings (group titles, no-query,
  empty, count); reuse `searchPlaceholder`; no legal-advice/send/realtime
  copy (spec §6 row 152 discipline, D-S6).

## 5. Acceptance criteria (each mapped to a named test)

| # | Criterion | Verified by |
|---|---|---|
| AC-1 | A query filters all four synthetic lists client-side (case-insensitive, D-S1 field set) and groups results by kind | `search_cubit_test.dart` (query → grouped subsets; empty query → empty-query state; no match → empty) |
| AC-2 | Results render **metadata only** — no document body, no message text, no thread-open affordance, no preview, no send/reply on the search surface | search screen widget tests (the Phase 8/9 AC-2 absence assertions, extended to search rows) |
| AC-3 | Result rows navigate to the existing read-only routes only (`/matters/:id`, `/vault`, `/messages`, `/discovery/:id`); no new routes | router test (route + query-param handling) + widget navigation pins |
| AC-4 | Capability gating reused per group (nav hints only; a group hides without its capability) | capability combination tests (no new flag; existing flags reused, D-S2) |
| AC-5 | Home search field is wired: submit navigates to `/search?q=…`; all new strings resolve in EN/AR/TR | home widget test (submit → route) + `app_localizations_test.dart` 11.2 pin (Phase 9 9.2 / Phase 10 10.2 pattern) |

## 6. Risks

- **R1 — fake-data honesty:** search must never read as a real case file or
  real communication search; results reuse synthetic demo wording only, and
  the local-only note renders on the surface (D-S5).
- **R2 — read-only/body-less line:** search renders metadata rows only and
  never opens content; the Phase 8/9 AC-2 absences hold on every result row
  (D-S3).
- **R3 — §14 boundary:** the surface is client-side over synthetic lists; it
  must not imply server-side search or scoping. The deferral text in roadmap
  §14 is preserved; no matrix row is exercised.
- **R4 — scope creep:** no full-text/body search, no reverse cross-links,
  no changes to the standalone surfaces, no search history/realtime, no
  server amendment. The inert practice-area cards and notification bell stay
  as-is (tracked separately if ever pursued).

## 7. Roadmap & ledger hooks (landed 2026-08-04)

- Roadmap header status line + a new **Phase 11** section (gate line +
  slices 11.0–11.2 table + exit) + gate-table row 11 — same edit shape as
  the Phase 10 draft (`docs/matter_workspace_scope_2026-08-04.md` §7).
- §14 boundary note: the deferred list gains no new entry — search is a
  client-side view over the same synthetic lists (the Phase 8/9/10
  cross-ref sentence pattern).
- Ledger hook bullet for the Phase 11 landing (README test-count +
  implemented-foundation lines in lockstep — the ledger gate's §2d check).

## 8. Exit

~~Roadmap Phase 11 row added → decision record ratified (D-S1…D-S6) → the
three slices built (11.0 search domain, 11.1 surface + wiring, 11.2 l10n) →
four checks green (`bash scripts/verify_ledger.sh` + `dart format
--output=none --set-exit-if-changed .` + `flutter analyze` + `flutter test`)
→ suite/README count in lockstep → owner push approval.~~ **Landing state
2026-08-04:** D-S1…D-S6 ratified, slices 11.0–11.2 built, `flutter analyze`
clean + `dart format` clean + **691 tests pass** (README/ledger sync and
owner push approval still pending — the phase is not yet closed).
