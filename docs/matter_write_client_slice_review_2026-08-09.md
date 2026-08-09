# LegalHub — F-01 Client Swap: Mechanism Review (2026-08-09)

> **Verdict: PASS — with two findings found and remediated within the
> review (R-1: a real production-path crash; R-2: a silent dead-end
> state).** The slice is client-only (no server change, no battery change);
> this review is the gate between the build (`93d5ed0`, 2026-08-09) and the
> D-45.1 configured-build verification. Reviewed against the applied server
> contract (`supabase/rpc/create_matter.sql`, F2-D1/F2-D2/F2-D4, §8 audit),
> the design (`docs/matter_write_client_slice_design_2026-08-09.md`,
> C-D1…C-D8), and the repo's seam/DI conventions.
>
> **Artifacts reviewed:** `matter_write_gateway.dart` (seam + VOs) ·
> `fake_matter_write_gateway.dart` (fake) · `supabase_matter_write_api{,_impl,_gateway}.dart`
> (RPC caller + kind mapping) · `matter_create_{state,cubit,screen}.dart`
> (flow) · `router.dart` + `matter_list_screen.dart` (route + entry) ·
> `service_locator.dart` (DI flip) · l10n EN/AR/TR.

---

## 1. Seam contract (C-D1/C-D2) — SOUND

- `MatterWriteGateway` is write-only and separate from the read `MatterGateway`;
  both register independently in the locator. The read fake is untouched
  (Q4 stays open).
- `CreateMatterRequest` carries exactly the RPC's inputs (org id, title,
  practice area, two optional assignees); `CreatedMatter` carries the
  server-returned id + the client's trimmed title/area — **no fabricated
  timestamp or row** (the read path's `Matter` VO supplies the full row).
- Failures cross the seam as `Result.failure(AppError)` with the C-D2 codes;
  no raw exception crosses the `Result` boundary (§D.4). Each C-D2 kind
  maps 1:1 to an in-function refusal (see §3).

## 2. Fake mirrors (C-D3) — SOUND

- **F2-D2:** refuses `platformOwnerId` (`10000000-…-0001`, the
  `00_fixtures.sql` owner) as client or attorney with
  `matter_write_owner_forbidden` — checked **before** the member guard,
  mirroring the RPC's refusal order (the battery-13 pins prove the RPC
  order). The fake honors the same invariant the batteries pin.
- **F2-D4:** assignees must be in the fake roster (the demo org's active
  members = the demo user, matching the `FakeOrganizationGateway` seed the
  dropdowns read), else `matter_write_assignee_invalid`.
- **F2-D1 / validation:** only the demo org id is known (else
  `matter_write_denied`); trimmed-blank titles → `matter_write_validation`
  — same order as the RPC (org → owner → member → title).
- **Determinism:** counter-based ids (`created-N`), instance-scoped created
  list (hermetic — the fake determinism pin; the Q4 read-handoff would
  need a static list, deferred).

## 3. RPC-param exactness (C-D4) — SOUND

- The impl calls `create_matter` with the RPC's **exact** parameter names —
  `p_organization_id`, `p_title`, `p_practice_area`, `p_assigned_client_id`,
  `p_assigned_attorney_id` — pinned by the impl test's recorded-call shape
  (the `MessageRpcCaller` test precedent).
- `p_title` is trimmed; `p_practice_area` is the `PracticeArea` enum-name,
  which the 04 CHECK accepts verbatim (`corporate`/`civil`/`criminal`/`family`).
- Null assignees are sent as null (orphan creates, F2-D5).
- The client never derives authorization: no org pre-read for membership,
  no owner check client-side — the roster filter is a UX convenience and
  the server re-asserts every gate (F-11). §8 audit is server-side only.

## 4. DI flip (C-D5) — SOUND

- `service_locator.dart` registers `MatterWriteGateway` behind
  `env.isConfigured`: `SupabaseMatterWriteGateway` (with the
  `supabaseMatterWriteApiFactory` test seam) when configured, the fake
  otherwise. The flip is pinned by the DI test (both directions).

## 5. Error copy (C-D2/C-D8) — SOUND

- All six C-D2 codes (`denied` / `owner_forbidden` / `assignee_invalid` /
  `validation` / `unavailable` / `failed`) map to `AppError` codes and to
  **localized** copy in the screen via the code → l10n switch; unknown codes
  fall back to the seam's redaction-safe English message (never empty
  success — AC-7). Key sweep: all 7 new keys present in EN/AR/TR.

---

## 6. Findings → remediated within the review

### R-1 (HIGH for the production path): the `/matters/new` route crashed — no cubit provider

The build's router constructed `const MatterCreateScreen()` with **no**
`BlocProvider<MatterCreateCubit>`, but the screen's `build`/`_submit`
require one — navigating to `/matters/new` in the real app threw
`ProviderNotFoundException`. The widget test masked it by wrapping the
screen in a provider manually.

- **Evidence:** the new router test (real `GoRouter`, demo partner session,
  `router.go(AppRoutes.matterCreate)`) failed with the provider missing;
  the seam review caught the wiring gap the test suite had not exercised.
- **Fix:** the screen now **provides its own cubit** (the
  `MatterListScreen` pattern): `MatterCreateScreen` wraps
  `BlocProvider(create: … MatterCubit(serviceLocator<MatterWriteGateway>()))`
  around the form surface. The widget test now pumps the screen **bare**
  (no external provider) — pinning the self-providing behavior — and the
  router test pins the production path renders the form.

### R-2 (Low): silent dead-end when no active org is selected

The screen resolved the org id at submit time and **silently returned** on
null (`_submit` no-op) — a user landing on `/matters/new` without an active
org (cold start / deep link before a hub visit; `syncFromSession` runs only
in the org hub) got a form whose submit did nothing.

- **Fix:** the screen now seeds the store from the session in `initState`
  (the hub's idempotent `syncFromSession` — a cold-start deep link resolves
  the same way a hub visit would) and, when the org is still null, renders
  a **visible no-org message** (`matterCreateNoOrg`, EN/AR/TR) instead of
  the form. Pinned by a widget test (no org → message, no form).

---

## 7. Observations (no action required)

- **CHECK-violation technical-message hygiene (Low):** a practice_area
  CHECK violation's Postgrest detail can include the failing row (the
  submitted title) in `AppError.technicalMessage`. Unreachable through the
  UI (the client only sends enum-names; the form blocks blank titles), and
  the screen never renders `technicalMessage` — only the localized
  `userMessage`. Noted for the D-45.1 build verification; a future pass
  could trim technical messages at the seam (the messages seam's discipline).
- **Assignee dropdown disabled while the roster loads:** honest (no
  guessing), and orphan creates remain available via "None".
- **FAB gate is build-time:** the list's partner gate resolves the role at
  route build (the existing `matterDetails` pattern); the server re-asserts
  F2-D1 regardless.

---

## 8. Re-verified with the remediations

- `flutter analyze` — **clean**.
- Full suite — **1156 passing** (the two new review-pin tests: the R-1
  router test + the R-2 no-org widget test).
- `scripts/verify_ledger.sh` — **PASS (115/115)**, README count updated to
  **1153**.
- All changes are the review's own (screen restructure, 3 l10n keys, 2 new
  tests, README) — uncommitted on top of `93d5ed0`.

## 9. Boundary

Client-side proof only. The slice is **not yet verified against the live
`create_matter` RPC** — that is the next gate: the **D-45.1 configured-build
verification** (the configured build's create flow calls the live RPC and
the §8 `matter:create` row is observed in the org-audit view). Nothing in
this review touches the dev project or the server surface.
