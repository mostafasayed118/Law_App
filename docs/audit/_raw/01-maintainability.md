# LegalHub — Maintainability Audit (raw findings)

**Auditor:** maintainability dimension, multi-dimension code-quality audit
**Date:** 2026-09-21
**Method:** static reading only (no `flutter test` / `flutter analyze` run). Every claim below was read in the file with a line citation. Greps scoped to `lib/`, `test/`, `supabase/`, `docs/`.
**HEAD at audit:** `ec4eb73` (`feat(notifications): D-N5 prefs filtering …`), plus **13 tracked modified files + 2 untracked additions in the working tree** (see §0).

---

## 0. Baseline corrections and in-flight state

Facts verified against the tree, where they differ from the audit brief:

| Brief said | Actual | Note |
|---|---|---|
| 25 features under `lib/features/` | **19** | `admin approvals auth billing booking compliance discovery documents home matters messaging notifications onboarding orgs profile research search storage tasks` |
| 278 `.dart` files under `lib/` | 278 total, **274 non-generated** | the 4 `lib/l10n/app_localizations*.dart` are generated |
| ~33,200 LOC | 33,236 total / **27,283 non-generated** | — |
| 155 test files | 155 ✓ | `test/features/` has 19 dirs, mirroring the 19 features |
| 171 files in `docs/` | 171 ✓ | all `.md` (163 + 9 ADR + `adr/README.md`) |

**In-flight (uncommitted) work** — an "audit 2026-09-21" P1 (data-layer row bounding) + P4 (lazy lists / rebuild scoping) slice, not an accident:

- `lib/data/list_query_guards.dart` (**new, untracked**) — `boundedTableSelect()` + `kSupabaseListRowCap = 200` + `kSupabaseListOrderings`.
- 7 × `lib/data/*/supabase_*_api_impl.dart` — `_boundTable` re-pointed at `boundedTableSelect`.
- `lib/shared/widgets/view_state_list.dart` — `itemBuilder: List→Widget` replaced by `tileBuilder: Item→Widget`; success arm became `ListView.builder` (**breaking API change to a shared widget**, all 4 call sites updated in the same diff).
- 4 presentation screens re-pointed; `message_thread_detail_screen.dart` gained a `buildWhen` + a `ValueListenableBuilder` send-button scoping; `pubspec.yaml` loosened the Flutter pin `3.44.4` → `>=3.44.4 <4.0.0`.

Findings F1 and F2 below are **about** this in-flight work; everything else is pre-existing.

---

## HIGH — the in-flight row cap silently truncates chat transcripts to the 200 *oldest* messages

**Location**: `lib/data/list_query_guards.dart:36` and `lib/data/list_query_guards.dart:66`, consumed at `lib/data/messaging/supabase_message_api_impl.dart:42-47`

**Issue**: `kSupabaseListOrderings` maps `'messages': ('sent_at', false)` — i.e. `descending == false` — and `boundedTableSelect` translates that to `query.order(orderColumn, ascending: !descending)` → **`ascending: true`** (oldest first), then `.limit(kSupabaseListRowCap)` (= 200). The thread-scoped read is the only ascending entry in the table; the other six (`matters`, `documents`, `files`, `billing_invoices`, `notifications`, `message_threads`) are descending, where "first 200" correctly means "newest 200". For `messages`, "first 200 ascending" means **the 200 oldest**, so every message past #200 in a thread is dropped — and it is dropped at the seam, before `SupabaseMessageGateway.fetchMessages` (`lib/data/messaging/supabase_message_gateway.dart:132`) maps rows to `Message` VOs. The detail screen renders the resulting list top-to-bottom as if it were the whole transcript (`message_thread_detail_screen.dart`, success arm) with no truncation indicator.

The guard's own doc comment justifies the cap with a list that omits messages — `lib/data/list_query_guards.dart:11-14`: "200 rows covers any realistic matter/document/invoice/notification list" — while `messages` is nonetheless in the ordering map at line 36.

**Impact**: silent, unrecoverable-in-UI data loss on the read path of a legal matter conversation. A lawyer scrolling a long thread sees a plausible, complete-looking transcript that is missing its most recent messages. This is the worst failure direction for a chat surface: the newest messages are the ones a user is looking for, and there is no error, no empty state, and no paging affordance to signal the gap. It is also the failure mode least likely to be caught by the suite: the fake gateway returns a 6-row fixture and `test/data/messaging/supabase_message_gateway_test.dart` injects a stub caller, so nothing in 1356 tests exercises `limit()`.

**Fix**: for chat, fetch the newest N and reverse for display, or exempt the thread-scoped read from the cap until paging lands:

```dart
// list_query_guards.dart — newest-first window; the caller reverses for render
'messages': ('sent_at', true),
```
and in `SupabaseMessageGateway.fetchMessages`, reverse the mapped list before emitting (or have `boundedTableSelect` return `rows.reversed` for this table). If ascending order is a hard requirement of the live-append path (`supabase_message_gateway.dart:219-225`), keep the ascending order but use `.range(0, …)`/`limit` against a *descending* server order instead. At minimum, record the cap in the gateway result so the UI can render "showing the first 200 messages" — a silent cap on a legal transcript is worse than a visible one.

---

## HIGH — a feature's production adapter does not live in the feature slice, and three conventions already coexist

**Location**: `lib/data/documents/supabase_document_gateway.dart:4`, `lib/features/documents/data/fake_document_gateway.dart:3`, `lib/data/orgs/fake_organization_gateway.dart:1`, `lib/data/auth/fake_auth_gateway.dart:1`, `lib/features/auth/data/fake_sign_up_gateway.dart:1`

**Issue**: `lib/data/documents/supabase_document_gateway.dart:4` imports `../../features/documents/domain/document_gateway.dart` — a file in the top-level `lib/data/` tree implements an interface owned by the `documents` **feature**, while its sibling fake lives in `lib/features/documents/data/`. The same split holds for matters, messaging, storage, billing and notifications. But it does *not* hold for:

- **orgs / admin**: both fake *and* real live in `lib/data/orgs/` and `lib/data/admin/` — nothing under `lib/features/orgs/data/` or `lib/features/admin/data/` exists (both features have `presentation/` only).
- **auth**: split *within the feature* — `lib/data/auth/fake_auth_gateway.dart` sits in the top-level tree while `lib/features/auth/data/fake_sign_up_gateway.dart` and `fake_password_recovery_gateway.dart` sit in the feature.

So there are two homes for an identical artifact class, and the codebase already uses three different assignments of them. `grep -rn "lib/data" docs/*.md docs/adr/*.md INSTRUCTIONS.md` returns **zero hits**: the split is not documented in `INSTRUCTIONS.md` §4.1, any ADR, or any doc.

**Impact**: the `features/<name>/{data,domain,presentation}` triad — which the brief rightly treats as the established convention — is only two-thirds true. A maintainer adding a Supabase-backed feature must guess whether the adapter goes in `lib/data/<feature>/` or `lib/features/<feature>/data/`; both compile, both pass tests, and the choice is unreviewable by inspection. The cost compounds at code-review time: "is this slice self-contained?" has no answer that holds for all 19 features. It also makes `lib/data/` an unlabelled grab-bag mixing core-owned adapters (auth, orgs, admin — whose interfaces live in `lib/core/`) with feature-owned ones (documents, matters, … — whose interfaces live in `lib/features/*/domain/`), which is precisely the distinction that should drive placement.

**Fix**: pick one rule and state it. The least-churn rule consistent with the majority is: **feature-owned seam ⇒ everything under `lib/features/<name>/data/`; core-owned seam (`lib/core/…`) ⇒ everything under `lib/data/<name>/`.** Under that rule `lib/data/documents|matters|messaging|storage|billing|notifications/supabase_*` move into the corresponding `lib/features/*/data/`. Cheaper alternative if moving 21 files is unacceptable: keep the paths and add a short subsection to `INSTRUCTIONS.md` §4.1 ("Feature-owned adapters live in `lib/features/<name>/data/`; core-owned adapters live in `lib/data/<name>/`") plus a one-line header comment in each of the six affected `lib/data/*` dirs. Either way the rule must be written down — that is the actual defect here.

---

## HIGH — the list-surface state + cubit skeleton is duplicated verbatim across ≥6 features

**Location**: `lib/features/approvals/presentation/approvals_cubit.dart:19-56`, `lib/features/tasks/presentation/task_board_cubit.dart:16-46`, `lib/features/documents/presentation/document_cubit.dart:32-57`; states at `lib/features/approvals/presentation/approvals_state.dart:11-25`, `lib/features/tasks/presentation/task_board_state.dart:7-20`, `lib/features/documents/presentation/document_state.dart:13-25`

**Issue**: `TaskBoardCubit.load()` and `ApprovalsCubit.load()` are identical line-for-line, differing only in the type (`TaskItem` vs `PendingApproval`), the state field name (`tasks` vs `approvals`) and the gateway method (`fetchTasks()` vs `fetchApprovals()`). `DocumentCubit.load()` is the same body again with `Document`/`documents`/`fetchDocuments()`. The three state classes are likewise identical modulo the type parameter:

```dart
class DocumentState extends Equatable {                       // document_state.dart:13-25
  const DocumentState({this.documents = const ViewLoading<List<Document>>()});
  final ViewState<List<Document>> documents;
  DocumentState copyWith({ViewState<List<Document>>? documents}) =>
      DocumentState(documents: documents ?? this.documents);
  @override List<Object?> get props => <Object?>[documents];
}
```

A normalised-signature scan of the 12 cubits that expose `load()` found **6 with a byte-identical normalised `load()` body** (`billing_cubit`, `discovery_cubit`, `document_cubit`, `matter_cubit`, `storage_cubit`, `task_board_cubit`) and 2 more sharing a second shape (`compliance_alerts_cubit`, `message_cubit`) — 8 of 12 cubits in 2 shapes. The gate/loading/await/empty-success-error skeleton (`if (isClosed || _loading) return; … switch (result) { Success → isEmpty ? ViewEmpty : ViewSuccess; Failure → ViewError }`) is ~35 lines and is reproduced in each.

This is **not** a re-report of `docs/phase2_refactor_audit_2026-08-11.md` / `docs/refactor_close_out_phase2_2026-08-11.md`: that program was scoped to *shared UI components* only, and its §7 declared "the remaining residual list is all deliberate-distinct geometry — **no further duplication clusters exist**". That claim is falsifiable at the state/cubit layer, which the program never scanned. Note also that the E10 decision explicitly declined to genericise over four cubit *types* in the widget layer ("genericizing over four cubit types would have been the over-abstraction the audit warned about") — that reasoning does not apply to removing an identical `load()` body.

**Impact**: ~200 lines of pure copy-paste across 6 features, and it is copy-paste of *control flow with an error path* — the highest-risk kind. Any change to the load contract (adding a `ViewOffline` mapping, a retry counter, a stale-request guard like `SearchCubit._requestSeq` at `search_cubit.dart:47`, or a `isClosed` fix) must be applied 6–8 times, and a missed site fails silently as "one screen behaves differently". Adding the 7th list surface means writing the same 35 lines again.

**Fix**: two independent, incremental steps. (a) Collapse the states — one generic class replaces 3+ files and needs no gateway change:

```dart
// lib/core/state/list_state.dart
class ListState<T> extends Equatable {
  ListState({this.items = ViewLoading<List<T>>()});   // non-const: const cannot take a type var
  final ViewState<List<T>> items;
  ListState<T> copyWith({ViewState<List<T>>? items}) => ListState<T>(items: items ?? this.items);
  @override List<Object?> get props => <Object?>[items];
}
```
(b) Then collapse the cubits over a `Future<Result<List<T>>> Function()` fetch closure:

```dart
abstract class ListCubit<T> extends Cubit<ListState<T>> {
  ListCubit(this._fetch) : super(ListState<T>());
  final Future<Result<List<T>>> Function() _fetch;
  bool _loading = false;
  Future<void> load() async { /* the one body */ }
}
```
Feature cubits that add filters (`MatterCubit.setStatus`, `DiscoveryCubit.setPracticeArea`) keep their extra methods and only inherit `load()`. If (b) is judged over-abstraction under the Phase-1 rules, (a) alone still removes 3+ near-identical files and should be done.

---

## MEDIUM — two of the six canonical `ViewState` variants have zero producers; the typed `denied` signal is flattened into a generic error

**Location**: `lib/core/state/view_state.dart:42-54`, `lib/data/messaging/supabase_message_api_impl.dart:162-169`, `lib/features/admin/presentation/platform_admin_cubit.dart:167-173`, `lib/features/discovery/presentation/discovery_state.dart:38-39`, `lib/features/matters/presentation/matter_state.dart:33-34`

**Issue**: `ViewOffline` (line 42) and `ViewUnauthorized` (line 49) are declared, rendered by all three shared shells, and **constructed nowhere in `lib/`** — `grep -rn "ViewOffline(\|ViewUnauthorized(" lib/` returns only the declarations. They are constructed only in widget tests (`test/shared/widgets/view_state_*_test.dart`) and `test/bootstrap_boundaries_test.dart:32-33`. Every feature consumer folds them into the empty arm (`discovery_state.dart:38-39` → `const <Attorney>[]`; `matter_state.dart:33-34` → `const <Matter>[]`; `document_list_screen.dart:120-121`; `message_list_screen.dart:121-122`; `matter_details_screen.dart:103`; `attorney_profile_screen.dart:85`).

The typed signal that *should* produce `ViewUnauthorized` does exist one layer down: `SupabaseMessageApiImpl._kindFor` maps `'permission denied'`/`'row-level security'` to `SupabaseMessageFailureKind.denied` (`supabase_message_api_impl.dart:162-169`), and `OrgFailureKind.denied` is likewise produced server-side. But no cubit branches on that kind — the failure is flattened to `ViewError(error)` in every `load()` (e.g. `document_cubit.dart:54-55`). Meanwhile the *sealed* feature states do model denial distinctly: `PlatformAdminDenied` (`platform_admin_cubit.dart:93`, produced at `:167-173`), `OrgState`'s create/roster failures. `ViewStateSwitch`'s own doc (`lib/shared/widgets/view_state_switch.dart:12-16`) justifies the folding with "a synthetic list has neither state" — true for the demo fakes, but on the configured Supabase path an offline device or an RLS denial is reachable and still lands in `ViewError`.

**Impact**: two of six variants are dead vocabulary in production and untested at feature level, so a maintainer changing the offline/unauthorized arms gets no failing test. Worse, the *choice of state vocabulary* silently determines whether denial is representable: a surface built on `ViewState` cannot show "you are not permitted" as distinct from "something broke", while `admin`/`orgs` can. A denial therefore renders as a generic error with a Retry button that will never succeed — a `INSTRUCTIONS.md` §1.3 "no false assurance" adjacency (the retry affordance implies a transient fault for a permanent denial).

**Fix**: either delete `ViewOffline`/`ViewUnauthorized` and their arms (honest, removes dead code, keeps the vocabulary at 4), or give them producers — add a typed discriminator to `AppError` (`app_error.dart` has only a free-form `code: String`) and map it in the shared load path:

```dart
// in the shared ListCubit/load body, replacing the blanket ViewError arm
case Failure<List<T>>(error: final AppError e):
  emit(state.copyWith(items: switch (e.code) {
    'denied'        => const ViewUnauthorized<List<T>>(),
    'unavailable'   => const ViewOffline<List<T>>(),
    _               => ViewError<List<T>>(e),
  }));
```
Whichever is chosen, the decision belongs in `docs/tracked_deviations.md` or an ADR — currently the vocabulary claims six states and the data layer can produce four.

---

## MEDIUM — sealed feature states have no `copyWith`, so partial updates re-list every field by hand (10 sites in admin, 6 in orgs)

**Location**: `lib/features/admin/presentation/platform_admin_cubit.dart:182, 218, 237, 261, 271, 294, 321, 379, 400`; `lib/features/orgs/presentation/org_cubit.dart:139, 211, 223, 252, 262`

**Issue**: `PlatformAdminLoaded` has 8 fields and **no `copyWith`**, so every partial update reconstructs the whole object positionally + by name. `platform_admin_cubit.dart` contains **10** such constructions; `org_cubit.dart` contains **6** `OrgRosterLoaded(...)`. Representative example, `_auditFailure` at `:320-330`:

```dart
emit(PlatformAdminLoaded(s.organizations, s.members,
    pendingUserId: s.pendingUserId, platformAudit: s.platformAudit,
    orgAudit: s.orgAudit, selectedAuditOrgId: s.selectedAuditOrgId,
    auditError: failure.kind));
```
Note that `auditLoading` is **omitted** here and therefore resets to its default `false` — which is the intent — but `selectAuditOrg(null)` at `:261-267` also omits `auditError` and `orgAudit`, and `loadAudit`'s success arm at `:237-245` omits `auditError`. Whether each omission is deliberate or accidental is not stated anywhere; there is no `copyWith` to make the intent explicit, and no test that pins the omission.

**Impact**: adding a 9th field to `PlatformAdminLoaded` requires editing 10 call sites. Forgetting one is not a compile error — the field silently reverts to its default, which is exactly the class of bug the 8-field carry-forward code at `:143-155` was written to avoid ("a carried `true` would strand it on a permanent spinner"). This is the single most modification-hostile construct in the codebase: the invariant "every field is either carried or deliberately reset" is enforced only by the author's attention.

**Fix**: add a `copyWith` to each sealed loaded-state class (a `T?`-parameterised one per class, or a hand-written one with explicit `bool` sentinels for nullable fields) and rewrite the 16 sites as `state.copyWith(...)`. For the genuinely destructive transitions (`selectAuditOrg(null)`, the `PlatformAdminDenied` flip) keep the full constructor but add a one-line comment naming the fields that are *deliberately* dropped — that is the information the current code withholds. `test/features/admin/platform_admin_screen_test.dart` should then pin one omission per transition.

---

## MEDIUM — `RoleCapability` is a 14-flag × 6-role literal table; adding a flag is a 7-file-site edit and 9 lookups unwrap with `!`

**Location**: `lib/core/roles/user_role.dart:125-225`; `!`-unwraps at `lib/app/router.dart:201, 213, 224, 251, 285, 303, 315, 412` and `lib/features/home/presentation/home_screen.dart:63`

**Issue**: `roleCapabilities` is a 101-line `const Map<UserRole, RoleCapability>` literal containing **84 hand-written booleans** across 6 entries. All 14 flags are identical `true` for every role except `canViewAudit` (true for `partner` only, `user_role.dart:170`) and `canUseAiResearch` (true for attorney/partner/researchAnalyst, `:157/:175/:207`). So 12 of 14 flags are 6×-repeated constants with no semantic content, and the table's information content is 12 bits. Adding one capability flag requires editing the constructor (`:16-31`), the field + doc (`:33-104`), `props` (`:107-122`), and all six literals — seven edits, and a missed literal is a compile error only because the field is `required`, which is the sole guard.

**Mitigation, stated honestly**: the map's totality over the enum **is** pinned — `test/core/roles/user_role_test.dart:80` asserts `roleCapabilities.length == UserRole.values.length`. So adding a `UserRole` value fails CI rather than silently returning null. This is therefore *not* a silent-breakage class; it is an ergonomics/coupling defect.

**Impact**: the nine `capabilitiesForRole[role]!` unwraps mean the compiler cannot help when the *test seam* is used with a partial map — and it is used that way: 8 tests inject single-entry maps (e.g. `test/app/router_test.dart:555`, `:1686`). Any future test that injects `{UserRole.partner: …}` and then navigates a role-gated route as another role crashes with `Null check operator used on a null value` inside a `GoRoute.builder`, i.e. a router-level exception with no message pointing at the cause. The doc comment on the seam (`router.dart:98-101`) advertises exactly this partial-map usage.

**Fix**: replace the map + `!` with an exhaustive switch, which turns "a new role/flag was forgotten" into a compile error and lets the seam be total by construction:

```dart
// user_role.dart
RoleCapability capabilityFor(UserRole role) => switch (role) {
  UserRole.client           => const RoleCapability(canViewAudit: false, canUseAiResearch: false, /* … */),
  UserRole.partner          => const RoleCapability(canViewAudit: true,  canUseAiResearch: true,  /* … */),
  // …
};
```
Then define the 12 constant flags once as a `const _base = RoleCapability(...)` and build each role as a small delta (a `copyWith` on `RoleCapability` would make the table ~8 lines instead of 101). Update the 9 call sites to `capabilityFor(role)` — or, for the test seam, keep the injected map but read it through `capabilitiesForRole[role] ?? roleCapabilities[role]!` so a partial map degrades to the default instead of crashing.

---

## MEDIUM — `docs/screen_completeness_matrix_2026-08-09.md` is factually stale and is not superseded by any later record

**Location**: `docs/screen_completeness_matrix_2026-08-09.md:56`, `:73-76`; contradicted by `lib/features/research/presentation/ai_research_screen.dart` (present, 11,421 bytes, dated 2026-09-02) and `lib/features/notifications/presentation/notification_feed_screen.dart`

**Issue**: row 56 reads `| legal_research_ai_assistant / citation / statutory browser / draft / library | legalhub §6:167 | DEFERRED_DECIDED (D-07/D-08; §14 AI-only path) | no screen |`. The AI research-assistant slice shipped on 2026-09-02 (`235003f feat(research): AI research-assistant demo slice`) with `lib/features/research/presentation/ai_research_screen.dart`, `ai_research_cubit.dart`, `ai_research_entry_card.dart` and a `/research` route (`router.dart:276-287`). The summary block at `:73-76` claims "**30** `*_screen.dart`" and "Suite 1127"; the tree now holds **33** `*_screen.dart` files and the suite is 1356 (per `README.md:363`). The record also lists `DONE_WIP (uncommitted) | 0`, which no longer describes the working tree.

`grep -rn "screen_completeness_matrix" docs/` finds exactly one reference — `docs/tracked_deviations.md:218`, a row-renumber citation, not a supersession. So no later doc corrects the matrix.

**Mitigation**: the file is explicitly self-dated ("Status date: 2026-08-09, `origin/main` @ `b7325f8`") and is a point-in-time audit record, not a living reference. That is the right format for this class of document, and it materially reduces the harm.

**Impact**: a maintainer doing a "what's left to build?" pass on the repo's screen inventory will read "research/AI: no screen" and either duplicate work or mis-scope a slice. The matrix is the only document in `docs/` that purports to be the screen inventory, and its counts (30 / 1127) disagree with the tree (33 / 1356) by 3 weeks of shipping.

**Fix**: add a dated `## Addendum` section at the top (the pattern `docs/permission_matrix.md` already uses for its §2 addendum) recording the 2026-09-02 AI-research slice and the three later screens, or rename the file to make the snapshot explicit (e.g. `…_2026-08-09_snapshot.md`). Do not silently edit the historical rows — the self-dating is a feature.

---

## MEDIUM — adding one feature requires lockstep edits in 5–6 files, and `service_locator.dart` is the largest file in the codebase

**Location**: `lib/app/service_locator.dart:117-131` (11 factory parameters), `:447-512` (the per-feature registration blocks); `lib/app/router.dart:42-93` (route constants), `:186-343` (route table); `lib/features/home/presentation/home_screen.dart:134-214`; `lib/core/roles/user_role.dart:16-225`; `lib/l10n/app_{en,ar,tr}.arb`

**Issue**: `service_locator.dart` is **559 lines** — the largest non-generated file in `lib/`, ahead of `router.dart` (492) and `home_screen.dart` (450). Its body is ~40 near-identical registration blocks, each of the shape:

```dart
if (!serviceLocator.isRegistered<XGateway>()) {
  if (env.isConfigured) {
    serviceLocator.registerLazySingleton<XGateway>(() => SupabaseXGateway((supabaseXApiFactory ?? SupabaseXApiImpl.bind)()));
  } else {
    serviceLocator.registerLazySingleton<XGateway>(FakeXGateway.new);
  }
}
```
plus one matching `SupabaseXApi Function()? supabaseXApiFactory` parameter per feature in the 11-parameter signature at `:117-131` and the mirrored `configureDependencies(...)` call in `main.dart`. The env-flip body appears **9 times** verbatim (`:151-165, 224-235, 241-252, 256-270, 276-291, 300-315, 366-378, 388-399, 409-420, 433-446, 456-467, 478-489, 500-512`).

The full cost of one new Supabase-backed feature surface, counted from the tree:

1. `lib/app/router.dart` — a route constant (`:45-75`) + a `GoRoute` (`:151-343`) + an import (`:7-38`), and, if role-gated, the 3-line `primaryRole` + `capabilitiesForRole[role]!` block.
2. `lib/features/home/presentation/home_screen.dart` — a 4-line `if (capabilities.canX) ...[SizedBox, XEntryCard(onTap: …)]` block (`:134-214`) plus an import.
3. `lib/core/roles/user_role.dart` — a field, a doc comment, a `props` entry, and 6 literal edits (F6).
4. `lib/app/service_locator.dart` — a factory parameter + a registration block (~12 lines).
5. `lib/l10n/app_en.arb` + `app_ar.arb` + `app_tr.arb` — the entry title/subtitle keys ×3, then regenerate (4 files change in git).
6. `main.dart` — the mirrored factory argument.

`home_screen.dart:134-214` is 11 repetitions of the same 4-line pattern (`if (capabilities.canX) ...[const SizedBox(height: LegalHubTheme.spaceMd), XEntryCard(onTap: () => context.go(AppRoutes.y))]`) — a hand-maintained parallel registry that must be kept in step with `router.dart:151-343` and `user_role.dart:125-225`.

**Impact**: the "how many files to add a feature" answer is **6–8**, spread across `app/`, `core/roles/`, `features/home/`, `features/<new>/`, `lib/l10n/` and `main.dart`. Every one of them is a place a reviewer must independently verify, and two of them (`home_screen.dart`'s entry block and `service_locator.dart`'s registration) are pure ceremony with no decision content. The `service_locator.dart` size is a direct symptom: it is the file most likely to produce merge conflicts, and it is the one file a reader must scroll 559 lines through to answer "what is wired?".

**Fix**: three independent reductions, in value order. (a) Drive the home entries from a data list instead of 11 inline blocks — a `const List<({bool Function(RoleCapability) visible, Widget Function() build})>` (or a small `HomeEntry` record list) collapses `:134-214` to a loop and makes the entry set a single reviewable table. (b) Extract the env-flip into one helper so the 9 blocks become one line each:

```dart
void _registerFlip<T>(T Function() real, T Function() fake) {
  if (!serviceLocator.isRegistered<T>()) {
    serviceLocator.registerLazySingleton<T>(env.isConfigured ? real : fake);
  }
}
```
(c) Replace the 11 factory parameters with a single `SupabaseApiFactories` record/class (or move them to the `SupabaseEnv` seam) so the signature stops growing linearly with the feature count.

---

## LOW — 4 of 19 state classes are declared inside their cubit file, not in `<feature>_state.dart`

**Location**: `lib/features/admin/presentation/platform_admin_cubit.dart:12`, `lib/features/orgs/presentation/org_cubit.dart:15`, `lib/features/orgs/presentation/org_audit_cubit.dart`, `lib/features/notifications/presentation/notification_prefs_cubit.dart:7`

**Issue**: 15 of 19 state declarations live in a `<name>_state.dart` file. Four do not: `PlatformAdminState`, `OrgState`, `OrgAuditState` and `NotificationPrefsState` are declared inside their cubit file. Three of the four are multi-variant `sealed` hierarchies (5, 10 and ~4 variants), for which co-location with the cubit is defensible; `NotificationPrefsState` is a single class with no such justification.

**Impact**: minor. A maintainer looking for `OrgState` finds nothing at `lib/features/orgs/presentation/org_state.dart` and must grep; the `test/features/**` mirror is unaffected. Cost is a few seconds per lookup, plus the ambiguity of two conventions for new code.

**Fix**: either move `NotificationPrefsState` into `notification_prefs_state.dart` (one-file change, closes the inconsistency), or state the rule — "multi-variant sealed hierarchies may be declared in the cubit file; single-class states live in `<name>_state.dart`" — in `INSTRUCTIONS.md` §4.1.

---

## LOW — the enum→localized-label helper files use three different naming conventions

**Location**: `lib/features/matters/presentation/matter_labels.dart`, `lib/features/documents/presentation/document_labels.dart`, `lib/features/billing/presentation/invoice_labels.dart`, `lib/features/notifications/presentation/notification_labels.dart`; `lib/features/orgs/presentation/org_error_messages.dart`; `lib/features/auth/presentation/forgot_password/recovery_error_localizer.dart`

**Issue**: six files holding the same artifact — a top-level function `(AppLocalizations, SomeEnum) → String` — under three suffixes: `_labels.dart` (×4), `_error_messages.dart`, `_error_localizer.dart`. `orgErrorMessage(l10n, kind)` and `recoveryErrorLocalizer`/equivalent have the same signature shape as `matterStatusLabel(l10n, status)`.

**Impact**: negligible functionally; it costs a grep to find the right helper and makes "where do I put the label for my new enum?" a coin flip.

**Fix**: rename to `*_labels.dart` for all six (`org_labels.dart`, `recovery_labels.dart`) or, if the error-vs-enum distinction is intentional, say so in a one-line header comment. Purely mechanical; do it in the same pass as F7's addendum to avoid a second doc-touch.

---

## LOW — `buildWhen`/`listenWhen` are used at 2 of 38 `BlocBuilder` sites

**Location**: `lib/features/orgs/presentation/create_organization_screen.dart:110`, `lib/features/messaging/presentation/message_thread_detail_screen.dart:305` (in-flight), `lib/features/auth/presentation/sign_in_screen.dart:61`, `forgot_password_{email,otp,reset}_screen.dart:50/72/88`

**Issue**: `grep -rn "buildWhen" lib/` → 2 sites; `listenWhen` → 4 sites, all in `lib/features/auth/`. There are 38 `BlocBuilder` and 5 `BlocListener` sites and **7 `context.watch<…>()`** sites (`home_screen.dart:56`, `settings_screen.dart:32-34`, `member_roster_screen.dart:55`, `organization_hub_screen.dart:67`, `profile_screen.dart:31`), each of which rebuilds the entire screen subtree on **every** emission of the watched cubit. `home_screen.dart:56` watches `AuthCubit` and rebuilds a 450-line `CustomScrollView` — including the 11 entry cards — on any `AuthState` change, e.g. the membership-hydration emission.

**Impact**: a rebuild-scoping gap rather than a correctness bug, and the in-flight P4 slice is already moving in this direction (the composer `buildWhen` + `ValueListenableBuilder` in `message_thread_detail_screen.dart:305, 347`). The maintainability cost is that the pattern is not established: a contributor has 36 examples of "just rebuild everything" and 2 of "scope the rebuild", so the default they will copy is the wrong one. `context.select`/`BlocSelector` are used nowhere.

**Fix**: adopt the in-flight pattern as the house rule for the two hot screens (`home_screen.dart:56` → `context.select<AuthCubit, Session?>((c) => c.state.session)`, `member_roster_screen.dart:55` and `organization_hub_screen.dart:67` likewise), and note the rule in `INSTRUCTIONS.md` §4 so it is not re-derived per screen. Not worth a mechanical sweep of all 38 sites.

---

## LOW — ARB message metadata is 3% populated (11 of 367 messages carry an `@` description)

**Location**: `lib/l10n/app_en.arb` (11 `@`-metadata entries), `lib/l10n/app_ar.arb` / `app_tr.arb` (9 each)

**Issue**: all three ARBs are **key-complete** — 367 message keys each, zero missing, zero extra (verified by JSON key diff). But only 11 of the 367 EN messages carry a `@key` metadata block (description/placeholders), and the AR/TR files carry 9. So a translator (or an LLM asked to extend AR/TR) has almost no context for the other 356 strings, and placeholder-bearing messages are undocumented except where the generator infers placeholders from the ICU string itself.

**Impact**: low today because AR/TR are complete and in lockstep; it becomes a real cost the next time strings are added or a native-speaker review pass happens (`docs/screen_completeness_matrix_2026-08-09.md` §6 already lists "AR/TR copy semantic pass for the 2026-08-09 strings" as an open owner item). The health of the ARB pipeline itself is otherwise good.

**Fix**: add `@` descriptions opportunistically for new keys only (no retro-fit sweep), and add a lint note to `INSTRUCTIONS.md` §1.3 that new keys ship with an `@` description. Note also that the ARBs carry a UTF-8 BOM (`json.load` fails without `utf-8-sig`) — harmless for `flutter gen-l10n`, worth normalising if a script ever parses them.

---

## LOW — `AuthCubit` and `ViewStateView` have no class-level dartdoc

**Location**: `lib/features/auth/presentation/auth_cubit.dart:12`, `lib/shared/widgets/view_state_view.dart:6`

**Issue**: class-level dartdoc coverage is otherwise **94.4%** (251 of 266 public classes in `lib/` excluding generated l10n — measured by scanning for a `///` block immediately preceding each public class declaration). Of the 15 undocumented, most are `State` subclasses or trivial holders (`_`-prefixed privates were excluded). The two that matter are the app's central session cubit, `AuthCubit` (374 lines, a lazy singleton read by the router, the shell and 7 screens), and `ViewStateView`, the canonical renderer that ADR-0004 devotes a full section to justifying. Both have well-documented *members* but no class-level statement of responsibility; ADR-0004's rationale for `ViewStateView` lives only in the ADR.

**Impact**: low — the surrounding prose is unusually good, so a reader can reconstruct intent. But these are the two types a new contributor must understand first, and `AuthCubit`'s contract (when memberships hydrate, what `recoveryPending` means, which emissions the router depends on) is currently spread across inline comments at `:15-19, :22-27, :30-32` and the ADRs rather than stated once at the top.

**Fix**: two 4–6 line `///` blocks. `ViewStateView`: "the renderer-of-record for `ViewState<T>`; see ADR-0004 for why it is retained and `view_state_switch.dart`/`view_state_list.dart` for the list-content variants." `AuthCubit`: state the session lifecycle and the router's dependency on `isAuthenticated` + `recoveryPending`.

---

## LOW — five ratified-but-inert affordances on the home dashboard; the ratification lives in a scope doc, not the deviations ledger

**Location**: `lib/features/home/presentation/home_screen.dart:97`, `:244`, `:250`, `:256`, `:262`

**Issue**: the notification bell (`onPressed: () {}`) and the four practice-area cards (`onTap: () {}`) are dead controls — they render with ripple/press feedback and do nothing. `SectionHeader(actionLabel: l10n.viewAll)` at `:226-229` is a *disabled* `TextButton` (`onPressed: null`, `home_cards.dart:38`), which is the honest variant.

This is **documented and ratified**, not a discovery: `docs/unified_search_scope_2026-08-04.md:74` — "The practice-area cards and notification bell **stay inert** — out of scope | **ratified 2026-08-04**", restated at `:141` and listed in `docs/screen_completeness_matrix_2026-08-09.md:79` as `OUT_OF_SCOPE_MVP`. It is *not* in `docs/tracked_deviations.md`, and the ledger's own charter (its header) says it is "for the rest: known bugs deferred for a focused slice" — which is what this is.

**Impact**: low. The deviation is deliberate and traced. The residual risk is the same class `tracked_deviations.md` D-T2 addressed for the recovery "Resend" control (`docs/codebase_audit_plan.md:223` records the fix as "disabled, not a no-op") — an inert control that looks live is a "no false assurance" adjacency under `INSTRUCTIONS.md` §1.3, and it is currently recorded in a scope doc that a maintainer reading the ledger will not open.

**Fix**: add a one-line `D-T9` entry to `docs/tracked_deviations.md` pointing at `unified_search_scope_2026-08-04.md:74` (the ledger's stated purpose), and consider switching the bell + practice-area cards to the `onPressed: null` disabled style so the UI matches the honest `viewAll` treatment. No behaviour change either way.

---

## LOW — the README test count is a manual lockstep edit enforced by CI

**Location**: `scripts/verify_ledger.sh:298-301`, `README.md:363`

**Issue**: `verify_ledger.sh` recomputes the suite size from the working tree and fails if `README.md` does not match in **two** forms — `Tests (N total)` and `**N tests**` (`:298-301`). So every commit that adds or removes a test must also edit `README.md`. `README.md:363` currently reads "Current suite: **1356 tests passing** (1353 tracked declarations…)".

**Impact**: deliberate and effective — it is the mechanism that keeps the governance docs from silently drifting, and the same script recomputes the 8 milestone suite claims from git history (`:36-39`) and verifies every cited commit hash resolves (`:10-16`). The cost is real though: a contributor adding a test gets a red gate for a documentation reason, and the fix (a hand-computed count) is unrelated to their change. It also means the count can be *right by accident* if two commits add and remove tests in one push.

**Fix**: keep the check but make it self-healing in the failure path — have the script print the exact `sed` command to run (the script already contains that `sed` at `:398` for its own negative test) so the contributor does not have to derive it. Optionally accept a `# suite-count: auto` marker in the README and have the script rewrite it, which preserves the drift guard while removing the manual arithmetic. Low priority; the mechanism's value currently exceeds its cost.

---

## LOW — `docs/adr/0004`'s "Consequences" statement about the barrel is superseded (6 exports → 22)

**Location**: `docs/adr/0004-shared-second-use-rule-and-viewstateview.md:46-50`, `:88-90`; `lib/shared/widgets/widgets.dart:13-34`

**Issue**: ADR-0004 §Consequences states "The `shared/` barrel now exposes only widgets with ≥2 consumers or a demonstrated app-level responsibility", and its decision text fixes the barrel at six exports (`LabelledField`, `LegalHubTextField`, `PasswordField`, `AuthScaffold`, `IconHeroBadge`, `LegalHubAppBar`). The barrel now has **22** exports — the 16 additions (`AppEntryCard`, `AppTile`, `AppFilterChips`, `AppSectionHeader`, `AppCenteredMessage`, `AppCenteredRetry`, `LabelChip`, `DirectionalIcon`, `showConfirmDialog`, `ViewStateList`, `ViewStateSwitch`, `ViewStateView`, `WorkspaceSection`, …) came from the E1–E10 program and are recorded in `docs/phase2_refactor_audit_2026-08-11.md` / `docs/refactor_close_out_phase2_2026-08-11.md`, not in the ADR.

**Verification of the rule itself (positive result)**: I re-checked every one of the 22 exports against ADR-0004's rule by counting consumer files. All 22 have **≥2** non-`shared/` consumers — `AppTile` 14, `AppEntryCard` 12, `ViewStateSwitch` 12, `LegalHubTextField` 11, `ViewStateView` 11, `DirectionalIcon` 8, `LabelChip` 6, `AuthScaffold` 6, `WorkspaceSection` 5, `IconHeroBadge` 5, `ViewStateList` 4, `LabelledField` 4, `PasswordField` 4, `AppCenteredMessage` 3, `AppCenteredRetry` 3, `AppFilterChips` 3, `AppSectionHeader` 3, `PasswordStrengthIndicator` 3, `LegalHubAppBar` 2, plus the label helpers. **No export violates the rule** — the barrel is healthy, which is a notable result given ADR-0004 explicitly invites re-auditing it.

**Impact**: low. ADR-0004 is a dated decision record and the later exports are traceable through the close-out records. The only cost is that a reader who takes the ADR's six-export list as current is wrong by 16 entries.

**Fix**: append a dated `> **Later additions:**` note to ADR-0004 §Consequences listing the E1–E10 additions and pointing at `docs/refactor_close_out_phase2_2026-08-11.md` — the same addendum style the ADR already uses for its "Open condition — RESOLVED" and "Later deleted" updates.

---

## What's done well

1. **The Supabase adapter layer is fully tested against stub seams — the "fakes shadow the real adapters" hazard does not exist here.** Every one of the 11 production adapters has a dedicated test: `test/data/` holds 33 files with one `supabase_*_gateway_test.dart` + `supabase_*_api_impl_test.dart` pair per feature (`test/data/documents/`, `matters/`, `messaging/`, `orgs/`, `admin/`, `billing/`, `notifications/`, `storage/`, `auth/`, `local/`). `SupabaseDocumentGateway`, `SupabaseMatterGateway`, `SupabaseMessageGateway`, `SupabaseStorageGateway`, `SupabaseBillingGateway`, `SupabaseOrganizationGateway`, `SupabasePlatformAdminGateway`, `SupabaseAuthGateway` and `SupabaseMembershipRepository` each appear in ≥2 test files. The `_table`/`_rpc` callable seams (`supabase_message_api_impl.dart:12-16`) are a genuinely good testability design.

2. **The `docs/` corpus is an asset, not a liability.** 171 markdown files, and a scan for backtick-quoted `lib/**/*.dart` references that no longer resolve found **4 broken paths total**, all in explicitly dated point-in-time records (`gate3_decision.md`, `gate3_reconciliation.md`, `audit_surfacing_plan_2026-08-08.md`, `p4_1_deeplink_recovery_plan_2026-08-07.md`). `scripts/verify_ledger.sh` enforces this mechanically: it re-resolves every cited commit hash via `git cat-file` + `git rev-list --all`, recomputes suite counts at 8 milestone revisions, and re-asserts byte-exact content markers in the current on-disk docs (`:10-39`). That is a level of documentation integrity I have rarely seen in a working app repo.

3. **`docs/tracked_deviations.md` + the ADR log are a working decision ledger with the right boundary between them.** The ledger distinguishes RESOLVED / TRACKED / DECIDED, cites the owning commit and the regression guard for each entry (D-T1's `onboarding_screen_test.dart` 800×600 pin, D-T2's `sign_up_cubit_test.dart` redaction pin), and `docs/adr/README.md` states the split explicitly ("Known deviations that are not architecture decisions … live in tracked_deviations.md, not the ADR log, to keep the ADR log's contract honest"). F14 above is a ledger-hygiene nit against a genuinely well-run mechanism, and D-T2's handling of the no-op Resend control is exactly the reasoning I would want applied to F14.

4. **Class-level dartdoc coverage is 94.4%** (251 of 266 public classes), and the comments carry *decision* content rather than restating code — e.g. `list_query_guards.dart:43-49` explains why unlisted tables get a cap without ordering ("an unknown table falling back to a guessed column would turn a SELECT into a 400"), `platform_admin_cubit.dart:137-142` explains why `auditLoading` is deliberately *not* carried across a reload ("a carried `true` would strand it on a permanent spinner"), and `view_state_switch.dart:18-20` explains the distinction from `ViewStateView`. The `docs/` cross-references in code (`ADR-0004`, `D-S4`, `F2-D4`, `D-RT5`) make the reasoning traceable from the call site.

5. **The l10n pipeline is in lockstep and the ARB sources are healthy.** All three ARBs carry exactly the same **367 message keys** (verified by JSON diff: zero missing, zero extra in AR and TR), `@@locale` is correct in each, and `l10n.yaml` is minimal. The only gap is `@` metadata coverage (F12), which does not affect correctness.

6. **The shared-widget barrel obeys its own ADR-0004 second-use rule, re-verified.** All 22 exports in `lib/shared/widgets/widgets.dart:13-34` have ≥2 non-shared consumers (counts in F15). Combined with the E1–E10 program's discipline — 13 shared components extracted with dedicated shared-widget tests, 1193 → 1261 tests, "no extraction where the shape was similar but not a clone" (`docs/refactor_close_out_phase2_2026-08-11.md:20-24`) — this is a codebase that has already paid down its UI duplication with evidence, and the residuals are documented with structural reasons rather than left implicit.

---

## Dimension score

**Maintainability: 6 / 10**

Justification: the strongest aspect is the **testability seams plus governance discipline** — every production Supabase adapter has a dedicated stub-seam test (33 files in `test/data/`), class-level dartdoc is 94.4%, and 171 docs with only 4 broken path references are kept honest by a verification script that re-resolves commit hashes and recomputes suite counts. That is well above the ordinary working app and is the reason this is not a 5. The weakest aspect is **the feature slice is not self-contained and the state/cubit layer was never refactored**: production adapters live in a parallel `lib/data/<feature>/` tree with three undocumented conventions already in use (F2), the list-surface `state` + `load()` skeleton is reproduced verbatim across 6–8 features while the recorded close-out declares "no further duplication clusters exist" (F3), and adding one feature means lockstep edits across 6–8 files including a 559-line `service_locator.dart` (F8). F1 is a live silent-truncation defect in uncommitted work that should be fixed before that slice lands. The honest read: the *governance and test* layers operate at a 8–9 level while the *structural decomposition* of the feature/state layer operates at a 4–5, and the average lands at 6.
