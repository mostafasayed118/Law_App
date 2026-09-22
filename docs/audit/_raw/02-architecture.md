# LegalHub — Clean Architecture / Separation of Concerns Audit

> **Dimension:** clean architecture, layering, SOLID, seam integrity,
> composition root, state-management consistency.
> **Date:** 2026-09-21
> **Revision audited:** `main`, working tree with 13 modified files + 1 untracked
> (`lib/data/list_query_guards.dart`). All claims below were read from the
> working tree, not from `HEAD`.
> **Method:** static reading + scoped `grep` over `lib/`, `test/`, `supabase/`.
> `flutter test` / `flutter analyze` deliberately not run (per brief).
> **Prior audits honoured:** `docs/phase2_refactor_audit_2026-08-11.md` (E1–E10 +
> Phase-3 C1/C2 — all duplication findings are closed, not re-reported),
> `docs/tracked_deviations.md` (D-T1…D-T8 — none of the findings below are on
> that ledger), ADR-0004 (shared second-use rule), ADR-0007,
> `docs/security_review_gate_record_2026-08-09.md`,
> `docs/auth_tenant_authorization_contract.md`.

---

## 0. Import-graph evidence (the load-bearing measurements)

Run over the working tree. `lib/l10n/app_localizations*.dart` (generated)
excluded; 274 hand-written `.dart` files under `lib/`.

### 0.1 Provider containment — HOLDS, 0 exceptions

```
grep -rn "^import 'package:supabase_flutter" lib --include=*.dart
  → 12 import sites, ALL under lib/data/
```

| File | Line |
|---|---|
| `lib/data/admin/supabase_platform_admin_api_impl.dart` | 1 |
| `lib/data/auth/supabase_auth_api_impl.dart` | 3 |
| `lib/data/billing/supabase_billing_api_impl.dart` | 1 |
| `lib/data/documents/supabase_document_api_impl.dart` | 1 |
| `lib/data/list_query_guards.dart` (new, in-flight) | 1 |
| `lib/data/matters/supabase_matter_api_impl.dart` | 1 |
| `lib/data/matters/supabase_matter_write_api_impl.dart` | 1 |
| `lib/data/messaging/supabase_message_api_impl.dart` | 1 |
| `lib/data/messaging/supabase_message_realtime_api_impl.dart` | 3 |
| `lib/data/notifications/supabase_notification_api_impl.dart` | 1 |
| `lib/data/orgs/supabase_org_api_impl.dart` | 1 |
| `lib/data/storage/supabase_storage_api_impl.dart` | 1 |

`grep -rln "^import 'package:supabase_flutter" lib | grep -v '^lib/data/' | wc -l
 → 0`

Additional non-import mentions are **comments only**:
`lib/app/deep_link/app_link_parser.dart:29`,
`lib/app/deep_link/app_link_listener.dart:13,64`, `lib/main.dart:54`.

### 0.2 `features/**` → `data/**` imports — 3 total, 1 is a violation

```
grep -rn "import.*data/" lib/features --include=*.dart
lib/features/auth/data/supabase_password_recovery_gateway.dart:3  → data/auth/supabase_auth_api.dart   [data→data, OK]
lib/features/auth/data/supabase_sign_up_gateway.dart:3            → data/auth/supabase_auth_api.dart   [data→data, OK]
lib/features/orgs/presentation/active_org_store.dart:6            → data/local/org_selection_store.dart [PRESENTATION→DATA, violation]
```

### 0.3 Dependency-rule directions — all HOLD

| Rule | Command | Result |
|---|---|---|
| `domain/` imports no Flutter widgets | `grep "import 'package:flutter/" **/domain/**` | **0 matches** |
| `domain/` imports no `data/` | `grep "import.*data/" **/domain/**` | **0 matches** |
| `domain/` import set | 39 files, only `equatable`, `core/*`, sibling `domain/*` | clean |
| `core/` imports no `features/` | `grep "import.*features/" lib/core` | **0 matches** |
| `shared/` imports no `features/` | `grep "import.*features/" lib/shared` | **0 matches** |
| `presentation/` imports no `supabase_flutter` | (⊂ §0.1) | **0 matches** |
| `GetIt.I` in `features/` | `grep "GetIt\|get_it" **/presentation/**` | **0 matches** (locator is reached via the exported `serviceLocator` global) |

`core/` → `data/` also does not occur; `data/` → `core/` + `features/*/domain`
is the inversion direction (correct: adapters depend on contracts).

### 0.4 The `lib/data/` vs `lib/features/*/data/` split — a real, undocumented rule

19 files live under `features/*/data/`. Their imports were checked:

| File | Imports | Provider-free? |
|---|---|---|
| `features/auth/data/supabase_sign_up_gateway.dart` | `core/*`, `data/auth/supabase_auth_api.dart`, `../domain/*` | yes |
| `features/auth/data/supabase_password_recovery_gateway.dart` | same shape | yes |
| `features/matters/data/fake_matter_gateway.dart` | `core/*`, `../domain/*` | yes |
| `features/notifications/data/shared_preferences_notification_prefs_store.dart` | `shared_preferences`, `../domain/*` | yes |
| `features/research/data/synthetic_ai_gateway.dart` | `core/*`, other features' `domain/*` | yes |

**The operative rule is: anything that touches the provider lives in `lib/data/`;
provider-free doubles and adapters live next to the contract they implement.**
That rule holds with 0 exceptions across all 274 files. It is coherent — but it
is **not written down anywhere** (`INSTRUCTIONS.md` §4.1 describes `data/` as
"cross-feature Supabase, payment, notification, cache services" and
`features/<f>/data/` as "datasources, DTOs, mappers, repository
implementations", which does not predict that `fake_matter_gateway.dart` sits in
`features/matters/data/` while `supabase_matter_gateway.dart` sits in
`lib/data/matters/`). See finding MEDIUM-5.

---

## Findings

### HIGH-1 — Four presentation widgets call `OrganizationGateway` directly and orchestrate with local `setState`, bypassing the Cubit seam

**Locations**

| File:line | Direct call |
|---|---|
| `lib/features/profile/presentation/profile_screen.dart:131` | `await serviceLocator<OrganizationGateway>().deleteMyAccount()` |
| `lib/features/orgs/presentation/accept_invitation_screen.dart:72` | `await serviceLocator<OrganizationGateway>().acceptInvitation(token: …)` |
| `lib/features/orgs/presentation/invite_member_sheet.dart:204` | `await serviceLocator<OrganizationGateway>().inviteMember(…)` |
| `lib/features/matters/presentation/matter_create_screen.dart:106` | `await serviceLocator<OrganizationGateway>().listMembers(…)` |

Exhaustive: `grep -rn "await serviceLocator<" lib/features` returns exactly
these four lines and no others.

**What is wrong**

Each of these is a `StatefulWidget` that owns the async orchestration itself:
`setState` for an in-flight flag, `await` on the gateway, a `switch` on
`OrgOutcome`, `setState` again for the result, and (in two cases) follow-on
cross-store mutations:

- `accept_invitation_screen.dart:33-36` declares `bool _accepting`,
  `OrgFailureKind? _failure`, `bool _accepted` as widget state; `_accept()`
  (lines 59-92) does the whole flow; `_refreshMembershipAndSwitch()`
  (lines 105-125) then calls `auth.hydrate()` and
  `serviceLocator<ActiveOrgStore>().select(joinedOrganizationId)` — an
  **invitation acceptance that grants a membership** is driven entirely from
  widget code.
- `profile_screen.dart:98` declares `bool _deleting`; `_deleteAccount()`
  (lines 104-147) performs **account deletion** from widget state.
- `invite_member_sheet.dart:50-52` declares `bool _sending`, `InviteResult? _invite`,
  `OrgFailureKind? _failure`; `_submit()` (lines 195-219) mints the invitation.

**Why this is a genuine violation, not a style preference**

`INSTRUCTIONS.md` §4.1 (line 239): *"Presentation renders state and dispatches
intent; it does not call Supabase, storage, payment SDKs, or business-policy
helpers directly."* §4.2 (line 252): *"Use `BlocBuilder` for rendering and
`BlocListener` for one-time side effects."* The definition of done (§6, line
335) states: *"Architecture boundaries are respected; **no direct data access
from widgets/Cubits**."* All four sites breach that line.

The contradiction is sharpest in `profile_screen.dart`: the `ProfileScreen`
class doc at lines 20-21 asserts *"It never calls a gateway and never renders
stale identity when the session is expired"* — while `_ProfileBody._deleteAccount()`
in the **same file** calls a gateway. The doc is falsified by its own file.

**Impact**

- The four flows are **untestable at the cubit layer**. There is no
  `deleteAccount`, `acceptInvitation`, `inviteMember`, or `loadAssignableMembers`
  method on any Cubit, so the only way to test them is a widget test with a
  configured service locator (33 test files call `configureDependencies`). The
  project's own test doctrine (`INSTRUCTIONS.md` §5, "Cubit state/async
  orchestration → `bloc_test` success, empty, failure, retry/duplicate-submission
  behavior") cannot be applied.
- **Duplicate-submission protection is hand-rolled per widget.** Each site
  re-implements the same `if (_flag) return;` + `setState` guard. Three copies
  now; a fourth write path will be a fourth copy.
- **Inconsistent failure surfaces.** `profile_screen.dart:143` uses a
  `SnackBar`; `accept_invitation_screen.dart:191` uses `TextField.errorText`;
  `invite_member_sheet.dart:128` renders inline `Text`. The same
  `OrgFailureKind` vocabulary produces three different affordances because no
  single orchestration layer owns the mapping.
- `accept_invitation_screen.dart:66` reads `context.read<AuthCubit>()` before an
  `await` and passes the cubit object across the async gap — a workaround
  (acknowledged at lines 64-65) that a cubit-owned flow would not need.

**Fix**

Add the missing write-path orchestration to `OrgCubit`
(`lib/features/orgs/presentation/org_cubit.dart`, already 300 lines and already
owns roster writes), or introduce one narrow cubit per surface:

- `OrgCubit.acceptInvitation(token)` → emits accepted/failed; the
  re-hydrate + `ActiveOrgStore.select` handoff becomes a cubit method (the
  membership-diff derivation at `accept_invitation_screen.dart:106-124` is
  domain logic and belongs in the cubit, not a widget).
- `OrgCubit.inviteMember(...)` → returns the one-time `InviteResult`.
- A `ProfileCubit` (or `AuthCubit.deleteAccount()`) for `deleteMyAccount`.
- `MatterCreateCubit.loadAssignableMembers(orgId)` — `_members` is already
  screen state at `matter_create_screen.dart:76`; the cubit should own it.

Each screen then keeps only `BlocBuilder`/`BlocListener`, matching the 34
`BlocBuilder` + 5 `BlocListener` sites that already do it correctly.

---

### HIGH-2 — `AuthGateway.startDemoSession()` is an interface method whose real implementation can never succeed, and the UI exposes it unconditionally

**Locations**

- `lib/core/auth/auth_gateway.dart:40` — declares `Future<AuthOutcome<Session>> startDemoSession();`
- `lib/data/auth/fake_auth_gateway.dart:87` — succeeds, mints the demo session
- `lib/data/auth/supabase_auth_gateway.dart:119-128` — **always fails**:
  `AuthFailure(kind: AuthFailureKind.membershipDenied, message: 'Demo sessions are not available with a real provider.')`
- `lib/features/auth/presentation/sign_in_screen.dart:125-132` — renders
  `OutlinedButton.icon(onPressed: () => context.read<AuthCubit>().startDemoSession(), …)`
  with **no environment gate**

**What is wrong**

The interface presents `startDemoSession` as part of the `AuthGateway`
contract. One implementation honours it; the other's contract is "always deny".
A consumer that treats the interface uniformly — which
`sign_in_screen.dart:125` does — gets divergent behaviour depending on which
implementation the locator happened to register.

**Evidence that the divergence is live, not theoretical**

```
grep -rn "isConfigured" lib --include=*.dart
  → only lib/app/service_locator.dart (lines 147,224,241,256,276,300,366,388,409,433,456,478,500)
    and lib/main.dart:27-30
```

`env.isConfigured` appears **nowhere in `lib/features/`**. `service_locator.dart:147`
registers `SupabaseAuthGateway` on a configured build; `sign_in_screen.dart`
has no matching branch. So on any build with a configured `.env`, the
"Continue as demo" button (`l10n.continueAsDemo`, line 131) is rendered,
tappable, and guaranteed to resolve to a `membershipDenied` failure.

**Impact**

- A configured (i.e. the real) build ships a primary-looking affordance that
  cannot work. That is a §1.3 core-invariant concern in spirit — the label
  promises an action the system will always refuse — and it is the one place
  where the fake/real split produces a *user-visible* defect rather than a
  test-only one.
- It also weakens the seam's credibility: the docs elsewhere lean on
  "the fake and the real honour the same contract" (e.g. D-BI4, D-N7). Here
  they demonstrably do not, and nothing in `docs/tracked_deviations.md` records
  it.

**Fix** — pick one:

1. Gate the button on a single source of truth, e.g. expose
   `bool get supportsDemoSession` on `AuthGateway` (true in `FakeAuthGateway`,
   false in `SupabaseAuthGateway`) and render the button only when true. This
   keeps the decision in the seam rather than duplicating `env.isConfigured`
   into presentation.
2. Or move `startDemoSession` off `AuthGateway` into a `DemoSessionGateway`
   registered only on the unconfigured path, so the real build cannot resolve it.

Option 1 is the smaller change and keeps the single-locator posture.

---

### MEDIUM-3 — `ActiveOrgStore` is an app-scoped persisted store living in `presentation/`, and is the codebase's only presentation→data import

**Location** `lib/features/orgs/presentation/active_org_store.dart:6`
(import) and `:40` (class declaration)

```dart
import '../../../data/local/org_selection_store.dart';
…
class ActiveOrgStore extends ChangeNotifier {
  ActiveOrgStore(this._orgSelectionStore) { _restoreSelection(); }
  final OrgSelectionStore _orgSelectionStore;
```

**What is wrong**

`ActiveOrgStore` is not a presentation concern. It is:

- a `ChangeNotifier` app-scoped singleton — registered at
  `lib/app/service_locator.dart:348-356` as `registerLazySingleton<ActiveOrgStore>`;
- **persistence-owning** — `_restoreSelection()` (line 76) reads and
  `_persistSelection()` (line 168) writes through the `OrgSelectionStore` seam;
- a domain-adjacent session projection — `syncFromSession(Session?)`
  (line 107) validates selections against `session.memberships`, i.e. it
  encodes the D-08 rule "the session is the membership authority".

Placing it in `presentation/` is what forces the sole presentation→data import
in the repository (§0.2). The `data/local/org_selection_store.dart` interface it
consumes is provider-free (read in full — 16 lines, two methods), so no
provider type leaks; the problem is the **layer direction**, not DTO leakage.

**Not a tracked deviation.** `grep -rn "ActiveOrgStore" docs/*.md` returns 12
hits; the closest to a placement decision is
`docs/features_roadmap_2026-08-03.md:427`, which lists the file path
`features/orgs/presentation/active_org_store.dart` as the "sketch" location for
slice 7.0. That is a *planned file path*, not a ratified deviation from the
`INSTRUCTIONS.md` §4.1 layering rule, and it is absent from
`docs/tracked_deviations.md`.

**Impact**

- The stated rule "presentation may not import `lib/data/**`" has exactly one
  exception, and that exception is invisible to a reader of the rule.
- `ActiveOrgStore` cannot be reused by a non-presentation consumer (a future
  background job, a data-layer decorator) without dragging a `presentation/`
  import along.
- It invites the widget-level misuse already present in
  `matter_create_screen.dart:89-90` (`store.syncFromSession(…)` called from
  `initState`) and `accept_invitation_screen.dart:123`
  (`store.select(…)` called from a widget) — see HIGH-1.

**Fix**

Move the file to `lib/core/organizations/active_org_store.dart` (it is
org-scoped session state, alongside `organization_gateway.dart` and
`membership_repository.dart`, both of which are already there). Update the
import at `lib/app/service_locator.dart:88` and the three consumers
(`organization_hub_screen.dart:46`, `org_audit_screen.dart:41`,
`accept_invitation_screen.dart`, `matter_create_screen.dart:89`). No behaviour
change; the `OrgSelectionStore` seam stays where it is.

---

### MEDIUM-4 — `PlatformAdminLoaded` fuses two independent concerns into one 8-field state, forcing manual field re-threading at seven emit sites

**Locations**

- State class: `lib/features/admin/presentation/platform_admin_cubit.dart:43-88`
  — `PlatformAdminLoaded` carries `organizations`, `members`, `pendingUserId`,
  `platformAudit`, `orgAudit`, `selectedAuditOrgId`, `auditLoading`, `auditError`
- Manual re-threads (each re-lists 5–8 named fields):
  `:143-155` (carry-forward destructure), `:181-191`, `:217-224`,
  `:236-245`, `:260-267`, `:270-280`, `:293-302`, `:320-330`, `:378-389`,
  `:399-409`
- Cubit size: 418 lines (the largest cubit in the codebase; next is
  `auth_cubit.dart` at 374)

**What is wrong**

Two concerns share one state: the orgs/members metadata read
(`load()`, `suspendMembership`, `reactivateMembership`, `deleteDemoAccount`) and
the audit trail read (`loadAudit()`, `selectAuditOrg()`). The class doc at
lines 36-42 acknowledges this — *"The audit trail is section-local … A non-denial
audit read failure is carried as `auditError` so the already-loaded
orgs/members surface is never destroyed by a section failure"* — and the
design intent (D-AUD2, section-local fetch on mount) is legitimate. The
**implementation cost** is not: because both concerns live in one immutable
state class, every audit emission must hand-copy the orgs/members fields and
every action emission must hand-copy the four audit fields. Adding a ninth
field means editing ~7 call sites, each of which can silently drop it.

Concrete evidence of the fragility: the comment at lines 137-142 documents a
past bug where `auditLoading: true` was carried into a reload and
*"stranded it on a permanent spinner"*. That is exactly the class of defect
that manual field threading produces.

**Impact**

- Single-responsibility: the cubit is the app's most likely place for a
  state-field-omission regression.
- Open/closed: the audit concern cannot be extended without touching the
  metadata concern's emit sites (and vice versa).
- Reviewers cannot verify correctness locally — every `emit` must be diffed
  field-by-field against the previous state.

**Fix**

Either (a) split into `PlatformAdminCubit` (orgs/members/actions) +
`PlatformAuditCubit` (trail + org selection), mounted as a sibling provider in
`platform_admin_audit_section.dart` — which is what "section-local" already
means; or (b) if one state class must stay, give it a `copyWith` and reduce
every emit to `emit(current.copyWith(…))`. Option (b) is the minimal change and
removes the entire class of omission bugs; option (a) matches the documented
section-local design more honestly. Note that (a) does not conflict with the
`E10 WorkspaceSection` pattern — that widget is presentational, not a cubit
split.

---

### MEDIUM-5 — Feature-slice shape: **verdict — principled in 5 of 6 cases, one real drift, and the drift is causally responsible for HIGH-1**

The brief asks for a verdict rather than a hedge. Here it is, with the
classification evidence.

**Slice inventory** (`find lib/features -maxdepth 2 -type d`):

| Slice | Layers present | Where its contract/impl live |
|---|---|---|
| 13 slices | `domain` + `data` + `presentation` | `features/<f>/domain`, fakes in `features/<f>/data`, provider adapters in `lib/data/<f>/` |
| `search` | `domain` + `presentation` | `search_results.dart` composes 4 **other slices'** domain types (`search_results.dart:3-6`) and the cubit takes 4 gateways (`search_screen.dart:63-66`) |
| `admin` | `presentation` only (6 files) | contract `lib/core/admin/platform_admin_gateway.dart`, impls `lib/data/admin/*` |
| `orgs` | `presentation` only (10 files) | contract `lib/core/organizations/organization_gateway.dart`, impls `lib/data/orgs/*` |
| `home` | `presentation` only (3 files) | pure dashboard/settings UI |
| `profile` | `presentation` only (1 file) | reads `AuthCubit`; writes via a direct gateway call |
| `onboarding` | `presentation` only | static carousel |

**Verdict on the five that look inconsistent — four are principled:**

- **`admin`, `orgs`** — the contract genuinely lives in `core/`
  (`core/admin/platform_admin_gateway.dart`,
  `core/organizations/organization_gateway.dart`) and the adapters in
  `lib/data/admin/`, `lib/data/orgs/`. These are cross-cutting
  identity/tenant concerns that more than one slice consumes
  (`OrganizationGateway` is used by `orgs`, `matters`, `profile`, and the
  membership repository). Materialising an empty `features/orgs/domain/` next
  to `core/organizations/` would be ceremony, and `INSTRUCTIONS.md` §2
  explicitly forbids ceremony-only abstractions. **Correct as-is.**
- **`search`** — its "data" *is* other slices' gateways. A `features/search/data/`
  would contain nothing but re-exports. **Correct as-is.**
- **`home`, `onboarding`** — stateless rendering. **Correct as-is.**

**The one real drift — `profile` (and the write half of `orgs`):**

`lib/features/profile/presentation/profile_screen.dart` is the *entire*
feature (1 file, 209 lines). Because the slice never materialised a
presentation-layer orchestration unit, its one mutation
(`deleteMyAccount`, line 131) had nowhere to go but the widget. The same is
true for `orgs`: `OrgCubit` exists and is 300 lines, but it owns only the
roster read path — the invite/accept writes were left in
`invite_member_sheet.dart:204` and `accept_invitation_screen.dart:72`.

So the answer to the brief's question is: **the "only materialise the layers you
need" stance is principled and defensible, and it is not the cause of the
inconsistency contributors will trip on.** The drift is narrower and more
concrete: **`presentation`-only slices that nonetheless perform writes have no
home for orchestration, and in this codebase they resolved that by putting the
orchestration in the widget.** That is the mechanism behind HIGH-1.

**Impact**

A contributor adding a new write to `profile` or `orgs` has no precedent to
copy for the correct pattern — the precedent they will find is a direct
`serviceLocator<Gateway>()` call in a `StatefulWidget`. The inconsistency is
therefore self-propagating.

**Fix**

Not "add empty domain folders". Instead: (1) fix HIGH-1 by giving `orgs` and
`profile` cubits; (2) write the rule down — one paragraph in
`INSTRUCTIONS.md` §4.1 or a new ADR stating: *a slice materialises `domain/`
and `data/` only when it owns a contract; cross-cutting contracts live in
`core/` with adapters in `lib/data/`; every slice that performs a write owns a
presentation-layer Cubit.* That converts an inferred convention into a checkable
one and makes the six shapes above obviously intentional.

---

### MEDIUM-6 — `core/use_cases/` is a declared architectural layer with zero consumers

**Location** `lib/core/use_cases/use_case.dart:4-10`

```dart
abstract interface class UseCase<Output, Input> {
  Future<Result<Output>> call(Input input);
}

class NoInput { const NoInput(); }
```

**What is wrong**

The layer is named in three normative places — `INSTRUCTIONS.md` §4.1 line 227
(*"core/ # errors, Result, use cases, auth/security/logging primitives"*), the
repository-structure block at lines 224-235, and the brief's own declared
layering — and the abstraction is a textbook clean-architecture primitive. But:

```
grep -rn "use_cases\|UseCase" lib --include=*.dart
 → lib/core/use_cases/use_case.dart:4   (its own declaration)
```

Zero implementers, zero references, zero tests. All 39 domain operations are
methods on gateway interfaces (`fetchMatters()`, `inviteMember()`,
`loadRoster()`), and all orchestration sits in the 24 Cubits.

**Impact**

- This is the one place where the architecture is **layers in name only**.
  A reviewer auditing "does the codebase have use cases?" gets a `yes` from the
  directory listing and a `no` from the code. That is precisely the kind of
  claim the report must not let stand.
- It is a magnet for speculative future work: a contributor reading §4.1 will
  reasonably assume use cases are the expected home for domain operations and
  start introducing them for one flow, producing a third competing pattern
  alongside gateway methods and cubits.

**Fix** — delete `lib/core/use_cases/use_case.dart` and correct the
`INSTRUCTIONS.md` §4.1 comment to read `core/ # errors, Result, auth/security
primitives` (the layer's other members are all real and used). If the owner
genuinely intends to adopt use cases, the honest alternative is to convert one
real flow (e.g. `MatterWriteGateway` create → `CreateMatter` use case) and
document the pattern, rather than leaving the interface orphaned.

Related, same file-family, lower stakes: `lib/core/sample_service.dart` is
still registered at `service_locator.dart:143-145` and asserted by
`test/service_locator_test.dart:315-354,882-886`. It is **documented as
intentional** (its own doc comment lines 1-7: *"B3 sample service … exists only
to prove the GetIt foundation resolves a registered service … intentionally
non-functional"*), so this is a deliberate deviation, not a defect. Noted for
completeness only.

---

### MEDIUM-7 — The composition root is readable and test-pinned, but it is order-coupled through a mutable local and repeats its env branch 13 times

**Location** `lib/app/service_locator.dart` (559 lines, of which the great
majority is explanatory comment — the executable body is ~120 statements)

**Assessment against the brief's question ("readable declarative registry or
untestable god-object?"):**

It is **not** a god-object and it **is** testable:
`test/service_locator_test.dart` is 891 lines and pins registrations, the env
flip, the anon-key guard, and idempotency. Each registration is a single
guarded `if (!serviceLocator.isRegistered<T>())` block with a rationale
comment. `serviceLocator.reset()` is exposed at `:557-559`. That is a
well-disciplined composition root.

**Two concrete defects.**

**(a) Order coupling via a mutable captured local.**
`:142` declares `FakeOrganizationGateway? fakeOrgGateway;` — a *local variable*
inside `configureDependencies`. It is assigned at `:265` inside the
`OrganizationGateway` block, then captured by two later closures:

- `:288` `FakeMembershipRepository(organizationGateway: fakeOrgGateway)`
- `:312` `FakePlatformAdminGateway(organizationGateway: fakeOrgGateway)`

Because `fakeOrgGateway` is only non-null on the unconfigured path, both
closures rely on the null-assertion idiom documented at `:308-310`
(*"`fakeOrgGateway` is non-null exactly on this unconfigured path"*). The
invariant is enforced by **block ordering inside a 400-line function**, not by
types. Reordering the `OrganizationGateway` block below either consumer — a
plausible refactor when regrouping registrations by feature — turns a
registration-time mistake into a runtime `Null check operator used on a null
value` on first resolution.

**(b) Open/closed pressure: 13 hand-written env branches.**
`grep -c "env.isConfigured" lib/app/service_locator.dart → 13`, each a full
`if/else` block choosing between a `Supabase*Gateway` and a `Fake*Gateway`
(e.g. `:366-378`, `:388-399`, `:409-420`, `:433-446`, `:456-467`, `:478-489`,
`:500-512`). The `configureDependencies` signature already carries 12
`Supabase*Api Function()?` factory seams (`:120-130`) — a test seam per
gateway. Adding one gateway means: add a factory parameter, add an import pair,
add an `if/else` block, and extend the 891-line test.

**Impact**

(a) is a latent runtime failure with a misleading error; (b) is a linear
maintenance tax that has already produced 12 near-identical test-seam
parameters. Neither is severe enough to block, but together they explain why
the file is 559 lines.

**Fix**

- For (a): make the shared-instance intent explicit and order-independent by
  registering the fake org gateway *first*, unconditionally, as a typed local
  that is non-nullable on the unconfigured path — or better, register it in the
  locator and have the consumers resolve `serviceLocator<OrganizationGateway>()`
  lazily (they are already lazy singletons, so the resolution order is safe and
  the null-assertion disappears).
- For (b): extract a small private helper —
  `void _registerFlip<T>({required bool configured, required T Function() real,
  required T Function() fake})` — and collapse the 13 blocks to 13 one-liners.
  This is the same "extract the repeated shape" move the project already
  executed successfully for widgets (E1–E10) and it would remove ~60 lines and
  all the duplicated `if/else` scaffolding. The `Supabase*Api Function()?`
  parameters can be folded into the same helper's `real` argument.

---

### LOW-8 — App-scoped Cubits are consumed via `context.watch` with no selector, alongside 34 `BlocBuilder` sites

**Locations** `grep -rn "context.watch<" lib/features`

- `lib/features/home/presentation/home_screen.dart:56` — `context.watch<AuthCubit>()`
- `lib/features/home/presentation/settings_screen.dart:32-34` — three
  `context.watch` calls (`LocaleCubit`, `AuthCubit`, `ThemeCubit`)
- `lib/features/orgs/presentation/member_roster_screen.dart:55` — `context.watch<AuthCubit>().state.session`
- `lib/features/orgs/presentation/organization_hub_screen.dart:67` — same
- `lib/features/profile/presentation/profile_screen.dart:31` — `context.watch<AuthCubit>().state`

Counts across `lib/features`: `context.read` 82, `context.watch` 7,
`context.select` **0**; `BlocBuilder<` 34, `BlocProvider<` 32, `BlocListener<` 5.

**What is wrong**

The split is *coherent* — app-scoped cubits (Auth/Locale/Theme) are watched
from the widget tree, feature cubits are built with `BlocBuilder` — so this is
not architectural drift and I am not calling it a violation. The narrow defect
is that `context.watch<AuthCubit>()` rebuilds the whole enclosing screen on
**every** `AuthState` change with no filter, and `context.select` is used
nowhere. `settings_screen.dart:32-34` rebuilds on any locale, auth, or theme
tick. `home_screen.dart:56` and the two org screens watch the full cubit but
only read `state.session`.

**Impact**

Unnecessary rebuilds of fairly large subtrees (`home_screen.dart` is 450 lines,
`member_roster_screen.dart` is 526). Low, but free to fix and it is the kind of
thing a Flutter reviewer flags immediately.

**Fix**

Use `context.select<AuthCubit, Session?>((c) => c.state.session)` at the four
session-only sites, and `context.select` per field in `settings_screen.dart`.
No structural change.

---

### LOW-9 — A hardcoded English display-name fallback is invented in the data layer

**Location** `lib/data/auth/supabase_auth_gateway.dart:148`

```dart
displayName: snapshot.displayName ?? 'User',
```

**What is wrong**

The adapter that maps `SupabaseAuthSnapshot` → domain `Session` injects a
user-facing English literal. `Session.displayName` is rendered directly by
presentation (`profile_screen.dart:159`, and the home greeting). The
provider-facing type already models absence honestly — `SupabaseAuthSnapshot.displayName`
is `String?` and `_displayNameFrom` (`supabase_auth_api_impl.dart:313-327`)
returns `null` deliberately rather than the raw email. The fallback then
re-materialises a literal one layer up, where it cannot be localized.

This is the same class of defect the project already resolved once: D-T3 in
`docs/tracked_deviations.md:92-110` records the identical problem in
`home_screen.dart` (`session?.displayName ?? 'Jonathan'`) and its resolution was
to add a localized `homeFallbackName` key. The data-layer twin was not covered
by that fix.

**Impact**

Arabic and Turkish users see the English word "User" as their own name in the
profile and greeting. It also puts a presentation concern (what to show when a
name is absent) inside an adapter, which is the layering point — the adapter
should pass `null` through and let presentation choose the localized fallback.

**Fix**

Keep `displayName` nullable through the domain `Session` (or add a
`hasDisplayName` projection) and render `l10n.homeFallbackName`-style copy in
presentation — reusing the key D-T3 already introduced. If making `Session.displayName`
nullable is too wide a change, at minimum replace the literal with a
locale-independent placeholder that presentation detects and localizes.

---

## What's done well

1. **Provider containment is absolute.** All 12 `supabase_flutter` imports live
   under `lib/data/`; **0** files elsewhere in `lib/` import the provider
   (§0.1). This is the hardest rule in the brief to actually hold and the
   codebase holds it with no exceptions, including in the in-flight
   `lib/data/list_query_guards.dart` addition — the new shared helper was placed
   in `lib/data/` precisely because it touches `Supabase.instance`
   (`list_query_guards.dart:1,57`). Nothing was smuggled into `core/` or
   `shared/` to avoid the rule.

2. **The auth seam is genuinely token-free, and it is enforced by types, not by
   convention.** `lib/data/auth/supabase_auth_api.dart:137-188` declares
   `SupabaseAuthApi` using only `SupabaseAuthSnapshot` (fields: `userId`,
   `displayName`, `expiresAt`, `recoveredViaLink` — `:11-34`, with an explicit
   "deliberately carries **no tokens**" doc at `:6-7`), a DTO-free
   `SupabaseAuthFailureKind` enum (`:48-69`), and sealed result types (`:87-130`).
   `SupabaseAuthApiImpl` is the only class that holds `GoTrueClient`
   (`supabase_auth_api_impl.dart:67`) and it maps `AuthException` → typed kinds
   in `_failureKindFor` (`:258-281`) before anything crosses. `SupabaseAuthGateway`
   then maps snapshot → domain `Session` (`supabase_auth_gateway.dart:138-156`)
   and **denies `startDemoSession` rather than fabricating authority**
   (`:119-128`). The `AuthGateway` contract
   (`core/auth/auth_gateway.dart:9-11`) states the invariant in prose and the
   code matches it. Two independent layers of seam, both clean.

3. **`domain/` is a real, import-clean layer.** All 39 `domain/` files were
   checked: **zero** import `package:flutter/*` and **zero** import `data/`
   (§0.3). The import set is only `equatable`, `core/*`, and sibling `domain/*`.
   Representative: `features/matters/domain/matter_gateway.dart:1-2`
   (`core/errors/result.dart` + `matter.dart`),
   `features/messaging/domain/message_gateway.dart:1-6` (dart:async + core +
   three sibling VOs). `core/` does not import `features/` and `shared/` does
   not import `features/` — both verified 0 matches. The dependency rule is
   real, not aspirational.

4. **DI inversion is real for the demo/real flip, and the anon-key guard is
   correctly placed.** `service_locator.dart:147-164` registers the real
   `SupabaseAuthGateway` only when configured, else `FakeAuthGateway`, and
   `:150` calls `SupabaseEnv.ensureAnonKey(env.anonKey)` **before** any provider
   is wired so a service-role key cannot reach a client build — the guard is on
   the registration path, not on a UI path. The same flip is applied uniformly
   to 13 gateways. The env decision lives in exactly two files
   (`service_locator.dart`, `main.dart`) — a single source of truth that is
   *correct* even where HIGH-2 shows the presentation layer failed to consult it.

5. **State consumption is overwhelmingly the sanctioned pattern.** 34
   `BlocBuilder<` + 32 `BlocProvider<` + 5 `BlocListener<` versus only 7
   `context.watch` sites, and every feature Cubit is created per screen via
   `BlocProvider(create: …)` (e.g. `matter_documents_section.dart:33`,
   `notification_feed_screen.dart:44-45`, `search_screen.dart:63-66`). The
   app-scoped exceptions (`AuthCubit`, `LocaleCubit`, `ThemeCubit`) are
   registered as lazy singletons with `dispose:` handlers
   (`service_locator.dart:196-199`, `:213-216`, `:515-522`) so their lifecycle
   is explicit. `ViewState<T>` (`core/state/view_state.dart:6-54`, six sealed
   variants) is the single shared async vocabulary, rendered by one widget
   (`shared/widgets/view_state_view.dart`) — and ADR-0004's open condition is
   honestly closed by pointing at two real consumers.

6. **The shared surface obeys its own documented rule, verifiably.** ADR-0004
   required "second use or app-level responsibility" for `shared/`. The barrel
   (`shared/widgets/widgets.dart`) now exports 21 entries, all with ≥2 consumers
   or an app-level role, and the Phase-2 audit's E1–E10 + C1/C2 extractions were
   executed with per-extraction tests (suite 1236 → 1261). The `ViewStateList`
   API change in the working tree (`itemBuilder`→`tileBuilder`, generic over
   `ItemT`, `view_state_list.dart:29-52`) was applied to **all three** call sites
   (`approvals_screen.dart:73`, `task_board_screen.dart:69`,
   `compliance_alerts_screen.dart:71`) — no half-migrated consumer, which is
   what a shared-widget refactor usually gets wrong.

---

## Dimension score

**8 / 10.**

The strongest aspect is that the dependency rule is not decoration: 12 of 12
provider imports are confined to `lib/data/`, 39 of 39 domain files are
widget-free and data-free, `core/` and `shared/` never reach into `features/`,
and the auth seam strips tokens and GoTrue DTOs at two independent layers with
the mapping code to prove it. The `env.isConfigured` flip and the anon-key guard
are correctly located, and the shared-widget surface is governed by a rule that
is actually enforced. That is materially better than "layers in name only" and
better than most working apps.

The weakest aspect is that the rule holds for *imports* but breaks for
*orchestration*: four presentation widgets (`profile_screen.dart:131`,
`accept_invitation_screen.dart:72`, `invite_member_sheet.dart:204`,
`matter_create_screen.dart:106`) perform consequential writes — account
deletion, invitation acceptance, invitation minting — directly against the
gateway with hand-rolled `setState`, and the slice shapes that made that
tempting (`profile` is presentation-only) were never given a rule to follow.
Secondary deductions: an interface method whose real implementation can never
succeed is still exposed as a live button (HIGH-2), and `core/use_cases/` is a
declared layer with zero consumers, which means the architecture description and
the code disagree in one place. Fixing HIGH-1, HIGH-2, and MEDIUM-6 — all
mechanical — would move this to 9.

---

## Appendix — claims deliberately NOT made

- **No duplication findings.** The brief's prior audits
  (`docs/phase2_refactor_audit_2026-08-11.md` §7-9) closed E1–E10 and C1/C2 with
  commit hashes and a test-count trail (1236 → 1261). I did not re-scan for
  duplication; nothing in the code read contradicted that record.
- **Not reported as defects:** `lib/core/sample_service.dart` (documented
  intentional B3 scaffolding, `sample_service.dart:1-7`); the
  `lib/data/` vs `lib/features/*/data/` placement split (the operative rule
  holds with 0 exceptions — reported as a documentation gap in MEDIUM-5, not a
  code defect); `context.watch` for app-scoped cubits (coherent pattern, LOW-8
  only for the missing selector); `PlatformAdminCubit`'s section-local audit
  design intent (legitimate per D-AUD2 — MEDIUM-4 targets the state-class
  threading cost, not the design).
- **Not verified / out of scope:** anything requiring execution — test
  pass/fail, analyzer cleanliness, runtime behaviour of the in-flight
  `ViewStateList` API change (the three call sites were read and are consistent,
  but the suite was not run per the brief). The 13 modified + 1 untracked file
  in the working tree were read and factored in; they are a coherent
  performance-hardening slice (`boundedTableSelect` + lazy list arms + a scoped
  `buildWhen`) and none of them introduces a layering regression.
