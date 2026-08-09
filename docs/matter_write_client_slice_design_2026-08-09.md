# LegalHub — Env-Gated Matter-Creation Client Slice: Design (2026-08-09)

> **Status: BUILT + REVIEW PASS 2026-08-09** (committed `93d5ed0`; the
> mechanism review `docs/matter_write_client_slice_review_2026-08-09.md`
> PASSED with R-1/R-2 remediated — the screen now self-provides its cubit
> and shows a visible no-org state; analyze clean, full suite 1156,
> ledger PASS; awaiting the D-45.1 configured-build verification).
> This
> is the last planned step of the F-01 step 2 chain: the **server** side is
> live (the `create_matter` RPC + categorical trigger applied 2026-08-09,
> RPC-EXECUTE 20, §8 audit, battery 13 16 blocks, matrix §4 row, F-12
> resolved) — the **client** has no matter-write surface yet. This slice
> wires the Flutter app to the applied RPC through the repo's standard
> env-gated seam pattern, and surfaces created-matter audit rows in the
> existing org-audit view.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Governed by:** `docs/f01_step2_matter_write_design_2026-08-09.md`
> (F2-D1…F2-D5) · `docs/matter_write_apply_execution_2026-08-09.md` (the
> applied server surface) · `docs/permission_matrix.md` §4 addendum ·
> `docs/send_message_rpc_plan_2026-08-08.md` (the D-SM2 client-swap
> precedent) · `INSTRUCTIONS.md` §2.1/§3/§4.4.

---

## 1. Context (what exists, what this slice adds)

- **Server (live since 2026-08-09):** `create_matter(uuid, text, text,
  uuid, uuid)` — SECURITY DEFINER, F2-D1 (active partner of the org),
  F2-D2 (platform-owner id never assignable), F2-D4 (assignees active
  members), title validation, practice_area CHECK (the 04 mapping
  contract), §8 audit (`matter:create`/`allowed`, redacted `matter
  created`), EXECUTE granted authenticated / denied anon; the categorical
  `refuse_platform_owner_assignment` trigger backs every path. RPC
  parameter names: `p_organization_id`, `p_title`, `p_practice_area`,
  `p_assigned_client_id`, `p_assigned_attorney_id`.
- **Client read path (exists):** `MatterGateway.fetchMatters()` +
  `SupabaseMatterGateway`/`SupabaseMatterApiImpl` (RLS-scoped SELECT),
  fake for env-less runs, env-flipped in `service_locator.dart`.
- **Client write precedent (exists):** `MessageGateway.sendMessage` — the
  audited RPC call (`SupabaseMessageApiImpl._boundRpc`, `MessageRpcCaller`
  injection for tests, `PostgrestResponse` cast, typed exception mapping
  → `Result`).
- **Audit surfacing (exists):** `AuditEntry` VO (`lib/core/admin/audit_entry.dart`)
  + `OrgAuditCubit`/`OrgAuditScreen` (`/organizations/audit`,
  partner-gated via `OrganizationGateway.readOrgAudit`, 2026-08-09 slice).
  `matter:create` rows **already flow into that view** once created — this
  slice's surfacing work is (a) confirming it live and (b) the optional
  matter-scoped activity section (C-D7).
- **This slice adds:** the `MatterWriteGateway` seam + fake + Supabase
  impl, the create-matter form flow, the `/matters/new` route, and the
  audit surfacing notes — all behind `env.isConfigured`.

## 2. Design decisions

### C-D1 — A dedicated `MatterWriteGateway` seam (write-only)

A separate write seam rather than extending `MatterGateway` — mirrors the
server's standalone write surface, keeps the read seam (and its deterministic
fake) untouched, and gives the slice a self-contained fake↔impl swap. Both
seams register in `service_locator.dart` independently.

```dart
/// Matter-creation boundary (F-01 step 2 client swap).
/// The server is the authority: this seam sends ONLY the create intent;
/// org membership, the owner refusal, and the member guard are re-derived
/// in-function (F2-D1/D2/D4, D-08). Failures arrive as [Failure] with a
/// typed [AppError], never raw exceptions.
abstract interface class MatterWriteGateway {
  Future<Result<CreatedMatter>> createMatter(CreateMatterRequest request);
}
```

### C-D2 — Contract: request + result VOs

```dart
class CreateMatterRequest extends Equatable {
  final String organizationId;      // the ACTIVE org, resolved at the UI layer
  final String title;               // trimmed non-empty (mirrors the RPC check)
  final PracticeArea practiceArea;  // the 04 CHECK set: corporate/civil/criminal/family
  final String? assignedClientId;   // optional — F2-D5 (orphan creates allowed)
  final String? assignedAttorneyId; // optional — must be an ACTIVE member (F2-D4)
}

class CreatedMatter extends Equatable {
  final String id;                  // the RPC's returned uuid
  final String title;
  final PracticeArea practiceArea;
  final DateTime createdAt;
}
```

Typed failures map 1:1 to the server's in-function refusals (the
`AppError` kinds live in `lib/core/errors/`):

| Server behavior | Client error kind |
|---|---|
| `permission denied` (non-partner / cross-org) | `matterWriteDenied` |
| `platform owner cannot be assigned to a matter` (F2-D2) | `matterWriteOwnerForbidden` |
| `assigned client/attorney must be an active member…` (F2-D4) | `matterWriteAssigneeInvalid` |
| `matter title is required` / practice_area CHECK | `matterWriteValidation` |
| transport / non-Postgrest provider failure | `matterWriteUnavailable` |

### C-D3 — Fake (`FakeMatterWriteGateway`)

In-memory, deterministic, mirrors the `FakeMessageGateway`/`FakeMatterGateway`
discipline:
- Accepts only the synthetic demo org id; returns a **deterministic** uuid
  (a fixed or counter-based id — never `DateTime.now()`-based randomness, so
  tests are stable).
- **Refuses the fixture platform-owner id** as an assignee with
  `matterWriteOwnerForbidden` (mirrors F2-D2 — the fake honors the same
  invariant the battery pins).
- Rejects blank titles (`matterWriteValidation`) and non-member assignees
  (the fake's roster = the demo synthetic members; `matterWriteAssigneeInvalid`).
- Records created matters in a static in-memory list so a future
  fake-read handoff (open question Q4) can surface them after refresh.
- Env-less runs and ALL tests keep the fake (the env-gate convention).

### C-D4 — Supabase impl (the D-SM2 pattern verbatim)

`SupabaseMatterWriteApi` + `SupabaseMatterWriteApiImpl` mirror
`SupabaseMessageApiImpl` exactly: an injected `MatterRpcCaller`
(`Future<PostgrestResponse<dynamic>> Function(String, Map<String, dynamic>)`)
defaulting to the app-level client's `rpc`:

```dart
// create_matter is called with the RPC's EXACT parameter names.
final response = await _rpcCaller('create_matter', <String, dynamic>{
  'p_organization_id': request.organizationId,
  'p_title': request.title.trim(),
  'p_practice_area': request.practiceArea.name,
  'p_assigned_client_id': request.assignedClientId,
  'p_assigned_attorney_id': request.assignedAttorneyId,
});
final Object? id = response.data; // the returned uuid (cast, never wrapped)
```

- `PostgrestException` → `SupabaseMatterWriteException(kind: …)` with the
  kind derived from the server message/status (the `_kindFor` precedent);
  non-Postgrest provider failures → typed `providerUnavailable`.
- `SupabaseMatterWriteGateway` maps the exception → `Result.failure(AppError)`,
  the RPC's returned id → `Result.success(CreatedMatter(...))`.
- **The client never derives authorization client-side** — no org pre-read,
  no owner check, no membership check in the client (the F-11/“server is the
  authority” discipline); the org id is a routing hint (D-08).

### C-D5 — Env-gated DI (the exact flip pattern)

In `service_locator.dart`, alongside the existing `MatterGateway` block:

```dart
if (!serviceLocator.isRegistered<MatterWriteGateway>()) {
  if (env.isConfigured) {
    serviceLocator.registerLazySingleton<MatterWriteGateway>(
      () => SupabaseMatterWriteGateway(
        (supabaseMatterWriteApiFactory ?? SupabaseMatterWriteApiImpl.bind)(),
      ),
    );
  } else {
    serviceLocator.registerLazySingleton<MatterWriteGateway>(
      FakeMatterWriteGateway.new,
    );
  }
}
```

### C-D6 — Presentation: the create-matter flow

- **Route:** `AppRoutes.matterCreate = '/matters/new'` (a new row in
  `router.dart`; the detail route pattern `matterDetail` is the shape).
- **Entry point:** an add action on `MatterListScreen` (FAB or header
  action — Q5), gated to the partner role at the UI layer (the shell's
  capability map already knows the active role; the server re-asserts).
- **Screen/cubit:** `MatterCreateScreen` + `MatterCreateCubit` with the
  sealed `MatterCreateState` (`initial` / `submitting` / `success(CreatedMatter)`
  / `failure(AppError)`) — the `ViewStateView` loading/success/error
  discipline.
- **Form:** title (`TextFormField`, required, trimmed), practice area
  (dropdown over the `PracticeArea` enum — the 04 CHECK contract), optional
  assignees (dropdowns **pre-filtered to active org members via the roster
  seam** — honest demo note: the demo org has exactly ONE active member,
  the partner; the demo clients hold no membership rows, so they are not
  offerable; orphan create (no assignees) allowed per F2-D5).
- **Submit → success:** navigate to the created matter's details screen
  (`/matters/:id`). **Honest UX note (R1/fake-data honesty):** an **orphan**
  create succeeds server-side but is invisible to every role under RLS
  (the 13.16 pin) — so the success state shows the confirmation with the
  returned matter id and does **not** promise list visibility; an
  assigned-to-partner create IS visible to the partner (RLS read-back).
- **Failure:** the typed copy per C-D2 (denied / owner-forbidden /
  assignee-invalid / validation / unavailable) — **denied is never
  presented as empty success** (AC-7).

### C-D7 — Created-matter audit surfacing

- **No new server surface needed.** `matter:create` rows are already
  returned by `read_org_audit` (partner-gated) and render in the existing
  `OrgAuditScreen` (`action` + redacted `matter created` + timestamp). This
  slice's surfacing work: (a) a live verification note (a configured build
  creating a matter produces a `matter:create` row visible in the org
  audit view), and (b) the optional **matter-scoped activity section** on
  `MatterDetailsScreen` — a small `MatterActivityCubit` reading
  `OrganizationGateway.readOrgAudit` filtered client-side by
  `resourceId == matterId` (the `AuditEntry.resourceId` field already
  carries it). Scope question Q1.

### C-D8 — Copy (l10n)

New EN/AR/TR keys for: the create title/labels, the submit action, the
typed error messages, and the success confirmation — following the existing
`l10n` file conventions (the repo's trilingual discipline applies; the
native-speaker copy pass on new strings is part of the slice).

## 3. Server contract cross-check (what the client must honor)

| Contract | Client behavior |
|---|---|
| Partner-only creator (F2-D1) | UI gates the entry to partner; the server re-asserts — a client/attorney caller gets `matterWriteDenied` |
| Owner id never assignable (F2-D2) | The client offers only roster members as assignees, so the owner (no membership) is never offered; if a caller passes it anyway, the server refusal maps to `matterWriteOwnerForbidden` |
| Assignees active members (F2-D4) | Assignee dropdowns pre-filtered to active members; orphan creates allowed (F2-D5) |
| Title non-empty + practice_area CHECK | Client-side form validation mirrors both; the server re-asserts |
| §8 audit | Server-side only — the client never writes audit rows; the created matter's `matter:create` row surfaces via `read_org_audit` |

## 4. Files (implementation map)

```
lib/features/matters/domain/matter_write_gateway.dart      (seam + VOs)
lib/features/matters/data/fake_matter_write_gateway.dart    (fake)
lib/data/matters/supabase_matter_write_api.dart             (api contract)
lib/data/matters/supabase_matter_write_api_impl.dart        (RPC caller + kind mapping)
lib/data/matters/supabase_matter_write_gateway.dart         (Result mapping)
lib/features/matters/presentation/matter_create_state.dart  (sealed state)
lib/features/matters/presentation/matter_create_cubit.dart
lib/features/matters/presentation/matter_create_screen.dart
lib/features/matters/presentation/matter_activity_section.dart  (C-D7, if approved)
lib/app/service_locator.dart   (env flip)
lib/app/router.dart            (/matters/new)
lib/features/matters/presentation/matter_list_screen.dart   (entry point)
lib/core/errors/               (the new AppError kinds)
l10n/                          (EN/AR/TR keys)
test/                          (see §5) + README counts
```

## 5. Tests

- **Fake gateway contract test:** success returns a deterministic id ·
  owner assignee → `matterWriteOwnerForbidden` · blank title →
  `matterWriteValidation` · non-member assignee → `matterWriteAssigneeInvalid`
  · result-shape assertions (the existing gateway-test discipline).
- **API impl test:** the injected `MatterRpcCaller` receives `create_matter`
  with the **exact** parameter names/values (the `MessageRpcCaller` test
  precedent); the returned id is cast to `CreatedMatter`; a
  `PostgrestException` maps to the typed kind.
- **Cubit test:** idle → submitting → success(CreatedMatter) and idle →
  submitting → failure(AppError) with the distinct kinds.
- **Service-locator/env test:** the fake is registered when `!isConfigured`
  and the Supabase gateway when configured (the existing env-test pattern).
- Suite count + README runtime/README numbers updated; `verify_ledger.sh`
  stays PASS.

## 6. Gate sequence

1. **This design → owner approval** (Gate 3; the F-01 register's client
   swap step flips from DESIGNED to APPROVED). — **DONE 2026-08-09**
   (the build instruction is the approval; open questions Q1–Q5 resolved
   in-build: Q1 deferred — surfacing ships as-is via the org-audit view;
   Q2 roster-filtered dropdowns; Q3 orphan creates allowed with the honest
   note; Q4 deferred — read fake untouched; Q5 FAB entry + in-screen
   success confirmation).
2. **Build** per §4 (client-only — no server change, no battery change). —
   **DONE 2026-08-09.**
3. **`flutter analyze` + tests green** (the suite grows; README counts
   updated; ledger PASS). — **DONE 2026-08-09** (analyze clean; full suite
   1154 passed; README 1151; ledger PASS at the committed state).
4. **Commit** (rehearse-before-commit; the fake-first env-less path is what
   CI tests). — **PENDING** (the next slice step; the pre-commit ledger
   count reads 1130 until the new test files are tracked).
5. **Configured-build verification (D-45.1 tie-in):** the configured build's
   create flow calls the live `create_matter` RPC on the dev project and the
   §8 `matter:create` audit row is observed in the org-audit view — this
   extends the existing D-45.1 checklist (which currently covers the read
   surface) with the write surface; the checklist gets a dated update.
6. **Dated plan/evidence docs** per the slice convention (this design is
   the plan; a completion-evidence record closes it).

## 7. Open questions (owner)

- **Q1 (C-D7 scope):** include the matter-scoped **activity section** on
  the details screen in this slice, or ship the surfacing as-is (the org
  audit view already shows `matter:create` rows) and defer the section?
- **Q2 (assignee UX):** pre-filtered dropdowns from the roster seam
  (recommended) vs. free-form id entry (demo-only)?
- **Q3 (orphan create):** allow orphan creates in the UI (F2-D5, honest
  note: invisible to everyone under RLS) or require an assignee?
- **Q4 (fake-read handoff):** should a fake-created matter appear on the
  matter list after refresh (fake write → read-fake shared list), the demo
  nicety?
- **Q5 (entry point):** FAB vs header action on the matters list; and the
  success destination — matter details (recommended) vs. list refresh?
