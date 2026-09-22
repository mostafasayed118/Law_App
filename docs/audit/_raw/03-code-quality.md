# Code Quality Audit — LegalHub (2026-09-21)

**Scope:** `lib/` (278 `.dart`, ~27.3k non-generated LOC), `test/` (155 files, 33.5k LOC), `supabase/` (81 `.sql`, 8.2k LOC), `analysis_options.yaml`, `pubspec.yaml`.
**Method:** static read + scoped grep. `flutter test` / `flutter analyze` not run (per brief). Every claim below was opened in a file before being written; dead-code claims were grepped for references.
**Baseline:** working tree has 13 modified + 1 new file (perf slice P4: lazy lists + `lib/data/list_query_guards.dart`). That work is factored in below, not flagged as breakage.
**Prior audits read:** `docs/phase2_refactor_audit_2026-08-11.md` (E1–E10, C1–C2 — all implemented), `docs/tracked_deviations.md`, `docs/adr/0004-shared-second-use-rule-and-viewstateview.md`. Their resolved clusters (AppTile/AppFilterChips/AppCenteredRetry/WorkspaceSection/AppSectionHeader/ViewStateList/ViewStateSwitch) were re-verified as genuinely adopted and are **not** re-reported. §3 "do NOT extract" claims were re-checked and mostly hold (see §F).

---

## HIGH — Capped list read truncates the *newest* messages of any thread with >200 rows

**Location**: `lib/data/list_query_guards.dart:25-37` (`kSupabaseListOrderings`) + `lib/data/list_query_guards.dart:61-66` (`boundedTableSelect`), consumed by `lib/data/messaging/supabase_message_api_impl.dart:41-47`.

**Issue**: `kSupabaseListOrderings['messages'] = ('sent_at', false)` → `descending == false` → `query.order('sent_at', ascending: !false == true)` → **ORDER BY sent_at ASC LIMIT 200**. The thread-scoped read (`fetchMessages(threadId)`) therefore returns the **oldest 200** rows and silently drops everything newer. The in-file comment states the ascending choice is for "the detail screen's top-to-bottom Column render and the live-append path" — correct for render order, but it was not reconciled with the cap: the cap keeps the *wrong end* of the history.

**Impact**: A thread longer than 200 messages silently shows messages 1–200; 201…N are invisible on load, while live-appended messages still appear. The user sees a transcript with a hole and no error. Every other table in the map is `descending: true`, so this is an isolated ordering/cap interaction, not a systemic choice.

**Fix**: For the capped read, fetch the newest N (`order('sent_at', ascending: false)` + `limit(200)`) and reverse client-side before render — the cap then keeps the most recent history, which is what a chat surface must never drop. Alternatively use `.range()` paging (the file already flags cursor paging as a separate slice). Either way, add a test (see next finding).

---

## HIGH — The new bounded-read guard has zero test coverage

**Location**: `lib/data/list_query_guards.dart` (67 lines, untracked/new); `test/` contains **no** reference to `boundedTableSelect`, `kSupabaseListRowCap`, or `kSupabaseListOrderings` (verified by grep).

**Issue**: Every `supabase_*_api_impl_test.dart` constructs the impl with an injected stub `TableCaller` (e.g. `test/data/documents/supabase_document_api_impl_test.dart:19-30`), so the real `_boundTable` → `boundedTableSelect` path — the `.limit(200)` and per-table `.order()` — is never executed by any test. Grepping `test/` for `.limit(` / `.order(` returns zero hits. The whole point of the in-flight slice is this guard; its correctness (cap value, per-table column, ascending/descending, the unknown-table fallback) is unpinned.

**Impact**: A wrong ordering column, an inverted `ascending`, or a changed cap ships silently. The `messages` bug above is exactly the class of defect this test would have caught. `boundedTableSelect` touches `Supabase.instance.client` (a global), which is why it was left untested — but the ordering/cap *decision* is pure and extractable.

**Fix**: Split the pure part out (`(String column, bool descending) orderingFor(String table)` and the `limit` constant) and unit-test it directly for all 7 mapped tables + an unmapped table; assert `kSupabaseListRowCap == 200`. Then assert the `messages` end-of-history behaviour explicitly.

---

## HIGH — Data-layer seam scaffolding duplicated 9–10×

**Location** (all verified by read):
- `_kindFor(PostgrestException)` — 9 byte-identical copies modulo enum name: `lib/data/documents/supabase_document_api_impl.dart:57-64`, `lib/data/billing/supabase_billing_api_impl.dart:59-66`, `lib/data/storage/supabase_storage_api_impl.dart:60-61+`, `lib/data/notifications/supabase_notification_api_impl.dart:73-80`, `lib/data/matters/supabase_matter_api_impl.dart:60-61+`, `lib/data/matters/supabase_matter_write_api_impl.dart:116-117+`, `lib/data/messaging/supabase_message_api_impl.dart:164-165+`, `lib/data/orgs/supabase_org_api_impl.dart:282+`, `lib/data/admin/supabase_platform_admin_api_impl.dart:179+`. Each is the same 3-branch classifier over `message.contains('permission denied') || message.contains('row-level security')`.
- `_mapFailure(...)` — 9 copies with an identical skeleton (`switch (e.kind)` → `(String code, String userMessage)` tuple → `AppError(code:, userMessage:, technicalMessage: e.message)`): `supabase_document_gateway.dart:119`, `supabase_billing_gateway.dart:134`, `supabase_storage_gateway.dart:111`, `supabase_matter_gateway.dart:172`, `supabase_matter_write_gateway.dart:50`, `supabase_notification_gateway.dart:115`, `supabase_message_gateway.dart:188/298/325`.
- The per-domain `enum SupabaseXFailureKind` + `class SupabaseXException implements Exception` pair is declared 9–10 times (`lib/data/*/supabase_*_api.dart`), each repeating the universal `denied` / `providerUnavailable` / `unknown` variants.

**Issue**: ~530 lines of structurally identical plumbing. The RLS-denial detection rule ("permission denied"/"row-level security" → denied) is copy-pasted 9 times; a provider that changes its denial text requires 9 coordinated edits, and a missed one degrades to a generic `unknown` error with no test failure.

**Impact**: Divergence risk on the single most safety-relevant mapping in the app (a denial must never render as "empty success"). The domain-specific kinds (`matter_write`'s `ownerForbidden`/`assigneeInvalid`/`validation`) are genuinely different and must stay — but the *shared* three kinds and the classifier are not.

**Fix**: Add a shared `SupabaseSeamFailure` enum + `classifyPostgrest(PostgrestException) -> SupabaseSeamFailure` in `lib/data/`, and a `AppError mapSeamFailure({required SupabaseSeamFailure kind, required String codePrefix, required String noun})` helper that owns the `technicalMessage: e.message` tail. Per-domain enums keep only their extra variants and map the shared three through the helper. This is the data-layer analogue of the E1–E10 widget extractions and is *not* covered by the prior audit (which was widget-scoped).

---

## MEDIUM — The Cubit-scoped list-surface skeleton is repeated across ~7 screens

**Location**: `lib/features/approvals/presentation/approvals_screen.dart:21-87`, `lib/features/compliance/presentation/compliance_alerts_screen.dart:19-84`, `lib/features/tasks/presentation/task_board_screen.dart:17-82`, `lib/features/billing/presentation/billing_invoices_screen.dart:23-83`, `lib/features/notifications/presentation/notification_feed_screen.dart:33-96`, `lib/features/documents/presentation/document_list_screen.dart:44-95`, `lib/features/messaging/presentation/message_list_screen.dart:44-95`. 18 feature files in total pair `BlocProvider` with `addPostFrameCallback` (3,251 lines across them).

**Issue**: The same ~50-line skeleton appears in each: `StatelessWidget` shell (`Scaffold` + `AppBar(l10n title)` + `BlocProvider<XCubit>(create: XCubit(serviceLocator<XGateway>()))`) → `_XSurface extends StatefulWidget` → `initState` `addPostFrameCallback { if (!mounted) return; context.read<XCubit>().load(); }` → `build` reading `l10n`/`scheme`/`text`, building the identical `empty` widget (`Padding(EdgeInsetsDirectional.only(top: spaceMd))` + `Text(bodyMedium, onSurfaceVariant)`) → `ViewStateList`/`ViewStateSwitch`. Only the cubit type, gateway type, l10n keys, and the tile differ. `approvals_screen.dart:64-72`, `compliance_alerts_screen.dart:62-70` and `task_board_screen.dart:60-68` contain the **byte-identical** 9-line `empty` widget.

**Impact**: ~300–350 lines of framework-shaped boilerplate; a change to the load-on-open idiom or the empty-copy style must be made in ~7 places. `document_list_screen.dart` and `message_list_screen.dart` are near-clones of each other (same private names `_ListSurface`/`_ListSurfaceState`, same `MultiBlocProvider[MatterCubit]` + dual-`load()` cross-link preamble).

**Fix**: Extract a `CubitListSurface<TState, TItem>` (or `AsyncListScaffold`) that owns the shell + post-frame load + empty copy + `ViewStateList`, taking the cubit factory, the state→`ViewState<List<TItem>>` projector, the retry closure, and the tile builder. `WorkspaceSection<T>` (E10) already proves this shape is extractable in this codebase.

---

## MEDIUM — `_AlertTile` hand-rolls `AppTile` exactly (E8 miss)

**Location**: `lib/features/compliance/presentation/compliance_alerts_screen.dart:108-146` (39 lines) vs `lib/shared/widgets/app_tile.dart:73-119`.

**Issue**: `_AlertTile` builds `Material(color: surfaceContainerLowest, shape: RoundedRectangleBorder(radiusLg, side: outlineVariant))` → `Padding(spaceMd)` → `Row[Icon(20, onSurfaceVariant), SizedBox(spaceMd), Expanded(Column[Text(title, bodyMedium w600), SizedBox(2), Text(subtitle, bodySmall onSurfaceVariant)])]` — structurally identical to `AppTile`'s content. The sibling screens in the same "v1 queue" family already delegate: `approvals_screen.dart:115-119` and `task_board_screen.dart:100-104` are 5-line `AppTile(leading: Icon(...), title: ..., subtitles: [...])` calls. E8's four workspace rows → `AppTile` migration did not sweep this file.

**Impact**: 39 lines that collapse to ~6, and the one alert row drifts from the shared card contract (radius/padding/gap) if `AppTile` changes.

**Fix**: Replace the `_AlertTile` body with `AppTile(leading: Icon(icon, size: 20, color: scheme.onSurfaceVariant), title: alert.title, subtitles: <String>[label])`. Behavior-preserving; the existing screen tests pin the rendered copy.

---

## MEDIUM — Three parallel `Result`-style sealed types for one concept

**Location**: `lib/core/errors/result.dart:4-31` (`Result<T>`/`Success`/`Failure` + `AppError`), `lib/core/organizations/organization_models.dart:182-212` (`OrgOutcome<T>`/`OrgSuccess`/`OrgFailed` + `OrgFailure`), `lib/core/auth/auth_outcome.dart:47-77` (`AuthOutcome<T>`/`AuthSuccess`/`AuthFailed` + `AuthFailure`).

**Issue**: All three are the same sealed generic with the same members (`isSuccess`, `valueOrNull`, `failureOrNull`) and the same factory shape, ~90 lines of duplicated generic machinery. The failure payloads differ only in whether the discriminator is a `String code` (`AppError`) or an enum (`AuthFailureKind`/`OrgFailureKind`) — and `AuthCubit._handleFailure` (`auth_cubit.dart:330-349`) already converts the enum to `AppError(code: failure.kind.name, ...)`, i.e. the enum layer is immediately flattened back into the `AppError` shape at the boundary. The org/admin cubits do the same (`org_cubit.dart:267`, `org_audit_cubit.dart:114`, `platform_admin_cubit.dart:414`).

**Impact**: Three vocabularies for "did it work" forces every reader to check which one a given gateway returns (`Result` for billing/documents/matters/messaging/notifications/storage/booking/tasks/approvals/compliance/research, `OrgOutcome` for orgs, `AuthOutcome` for auth). New code has to guess. `SearchCubit.search` (`search_cubit.dart:72-112`) consumes `Result` while the matter cubit next door consumes the same — but the org hub consumes `OrgOutcome` for a comparably-shaped read.

**Fix**: Keep the typed failure enums (they carry real domain meaning) but collapse the three transport types onto one `Result<T, F>` (or at minimum make `OrgOutcome`/`AuthOutcome` typedefs of a shared generic). Add a single `AppError fromFailure(...)` conversion so the enum→`AppError` step happens once, not in four cubits.

---

## MEDIUM — Two logging paths: the `ErrorReporter` seam vs raw `debugPrint`

**Location**: `lib/core/observability/error_reporter.dart:61-69` (the `ConsoleErrorReporter` seam, used by `AuthCubit`) vs raw `debugPrint` at `lib/data/orgs/supabase_membership_repository.dart:66,76,84`, `lib/features/auth/presentation/auth_cubit.dart:289`, `lib/features/orgs/presentation/active_org_store.dart:81,172`.

**Issue**: `AuthCubit._reportHydrationFailure` (`auth_cubit.dart:272-291`) explicitly routes through `_reporter.report(...)` — and its own doc comment says "the `ErrorReporter` seam instead of repository `debugPrint`" — yet its catch fallback uses `debugPrint` (`:289`), and the `SupabaseMembershipRepository` it depends on logs its three hydration drops with `debugPrint` (`:66/76/84`). `ActiveOrgStore` logs both persistence failure paths with `debugPrint`. Net: 7 raw `debugPrint` call sites bypass the redaction + reporting seam that the project built.

**Impact**: Diagnostics from the persistence/hydration paths are (a) not redacted by `Redactor` (`error_reporter.dart:26-58`), (b) not reportable when a real reporter is wired, and (c) inconsistent with the auth path. The `membership hydration: dropping row without organization id` message (`:84`) is a data-integrity signal that a future Sentry integration would want, and it will not reach it.

**Fix**: Route these through `ErrorReporter` (a `report(AppError(...))` call; the reporter already swallows/`print`s in dev). If a synchronous dev-only trace is genuinely wanted, add a single `debugLog(String)` helper in `lib/core/observability/` so the `debugPrint` call sites are one, auditable place.

---

## MEDIUM — `home_screen.dart`: 243-line `build` with 11 near-identical capability-gated blocks, plus 5 dead affordances

**Location**: `lib/features/home/presentation/home_screen.dart:52-294` (243 lines, the second-longest function in `lib/`); the repeated blocks are `:134-214`; the no-op handlers are `:97` (`onPressed: () {}`), `:244/250/256/262` (`onTap: () {}`).

**Issue (a) — long method + repetition**: lines 134–214 are eleven copies of `if (capabilities.canX) ...[ const SizedBox(height: spaceMd), XEntryCard(onTap: () => context.go(AppRoutes.x)) ]`. That is ~80 lines of one shape differing only in a capability flag, an entry-card class, and a route constant — a data-driven list (`List<(bool, Widget Function(), String)>`) collapses it to ~15. The `SliverChildListDelegate(<Widget>[ ... ])` literal alone is ~106 lines.

**Issue (b) — no-op affordances**: the notifications bell (`:97`) and all four `PracticeAreaCard`s (`:244/250/256/262`) render as tappable (ripple, and for the cards an `onTap` that does nothing) but perform no action. This is the same "no false assurance" defect the project *did* fix elsewhere — `docs/tracked_deviations.md` D-T2 records disabling the recovery "Resend code" button for exactly this reason. It is the only remaining set of no-op handlers in `lib/` (verified by grep: 5 hits, all here).

**Impact**: The 11-block list is the single largest maintainability hotspot in the presentation layer; adding a surface means another 8-line copy. The no-op cards/bell imply functionality that does not exist.

**Fix**: Drive the entry cards from a `const` list of `(capability, route, builder)` and map over it. For the no-op affordances, either disable them (`onTap: null` / omit `onPressed`) or drop them until the destination exists — matching the D-T2 precedent.

---

## MEDIUM — `configureDependencies` is a 438-line function with ~30 repeated registration guards

**Location**: `lib/app/service_locator.dart:117-554`.

**Issue**: The longest function in the codebase. It is linear and well-commented, but ~30 blocks repeat `if (!serviceLocator.isRegistered<X>()) { ... registerLazySingleton<X>(...) }`, and 8 of them repeat the identical `if (env.isConfigured) { SupabaseXGateway(...) } else { FakeXGateway.new }` env-flip shape (`:146-512`). The 13 `Function()` factory parameters (`:120-130`) exist only to thread test seams.

**Impact**: Every new gateway adds another ~10-line block to a function that is already 438 lines and cannot be read at a glance; the env-flip contract ("configured → Supabase, else fake") is restated 8 times and can drift.

**Fix**: Extract `void _registerEnvGated<G>({required G Function() real, required G Function() fake})` and call it per gateway; move the per-domain registrations into `registerAuth()`, `registerOrg()`, `registerContent()` helpers so the entry point is a short sequence. This is a pure refactor with no behavior change and is directly testable via the existing `test/service_locator_test.dart` (891 lines).

---

## MEDIUM — Dead code: 3 unreferenced units (~76 lines)

**Location / verification**:
- `lib/shared/responsive/responsive_breakpoints.dart` (46 lines) — the `ResponsiveBreakpoint` enum and the `ResponsiveBreakpointContext` extension (`breakpoint`, `isCompact`, `isMedium`, `isExpanded`, `responsiveHorizontalPadding`). Grep across `lib/` **and** `test/` for `ResponsiveBreakpoint`, `isCompact`, `isMedium`, `responsiveHorizontalPadding` returns **0** hits; the 4 `isExpanded` hits are `DropdownButtonFormField.isExpanded` (unrelated, in `settings_screen.dart`/`organization_hub_screen.dart`/`platform_admin_audit_section.dart`). It is exported by `lib/shared/responsive/responsive.dart:7` but the barrel's only consumer (`lib/app/router.dart:40`) uses `ResponsiveContent` only. Not listed in `tracked_deviations.md` or ADR-0004.
- `lib/core/use_cases/use_case.dart` (11 lines) — `UseCase<Output, Input>` + `NoInput`. Zero production consumers; the only references are the self-referential `test/core/use_cases/use_case_test.dart` (which defines its own `_SucceedingUseCase`/`_FailingUseCase`). Not exported by any barrel.
- `lib/core/sample_service.dart` (19 lines) — `SampleService`/`SampleServiceImpl`, a bootstrap-era DI proof (its own doc says "intentionally non-functional and is NOT a feature"). Referenced only by `service_locator.dart:9,143-145` (registration) and `test/service_locator_test.dart`.

**Impact**: `responsive_breakpoints.dart` is the notable one — a responsive foundation that no surface adopted, while `ResponsiveContent` in the sibling file *is* used; readers cannot tell which half is live. `UseCase` and `SampleService` add two indirection layers to `core/` that no feature consumes.

**Fix**: Delete `responsive_breakpoints.dart` (and its `export`), `use_case.dart` (+ its test), and `sample_service.dart` (+ its registration and the 3 test assertions). If any is a deliberate foundation awaiting a consumer, record it in `tracked_deviations.md` the way ADR-0004 did for `ViewStateView` — but ADR-0004's own criterion ("re-opens if no feature adopts it") argues for deletion, since `ViewStateView` earned retention by *use* and these have not.

---

## MEDIUM — Duplicated widget-test scaffolding; no shared pump harness

**Location**: 19 test files each declare their own local `pumpX(WidgetTester)` helper with a near-identical body — `test/features/tasks/task_board_screen_test.dart:13-28` (`pumpTasks`), plus `pumpAt` (×7), `pumpSearch` (×2), `pumpApp` (×2), `pumpVault`, `pumpResearch`, `pumpProfile`, `pumpMessages`, `pumpList`, `pumpInvoices`, `pumpFeed`, `pumpDetails`, `pumpDetail`, `pumpCreate`, `pumpBooking`, `pumpApprovals`, `pumpAlerts`.

**Issue**: Each helper repeats the same five steps: `configureDependencies()`, `tester.view.physicalSize` + `devicePixelRatio` + `addTearDown(...)`, `pumpWidget(MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: ..., home: ...))`, `pumpAndSettle()`. `localizationsDelegates: AppLocalizations.localizationsDelegates` appears **76 times**; `tester.view.physicalSize` 21 times; `configureDependencies()` 111 times. There is no `test/support/` or `test/helpers/` directory (`test/` contains only `app/`, `core/`, `data/`, `features/`, `responsive/`, `shared/`, and 2 root files).

**Impact**: ~19 duplicated ~12-line helpers; a change to the localization-delegate wiring or the view-sizing teardown must be applied 19+ times. The `responsive_smoke_test.dart:51-76` `pumpApp` is the most complete version and is the natural template.

**Fix**: Add `test/support/pump_app.dart` exposing `Future<void> pumpApp(WidgetTester tester, {required Widget home, Size size = const Size(800, 1600), double textScale = 1.0, Locale locale = const Locale('en')})` and migrate the 19 local helpers onto it. Keep each test's *specific* overrides local.

---

## LOW — `_appError(OrgFailure)` declared 3× with only a code prefix differing

**Location**: `lib/features/orgs/presentation/org_cubit.dart:267-270` (`'org.${kind.name}'`), `lib/features/orgs/presentation/org_audit_cubit.dart:114-117` (`'org.audit.${kind.name}'`), `lib/features/admin/presentation/platform_admin_cubit.dart:414-417` (`'platformAdmin.${kind.name}'`).

**Issue**: Three copies of the same 4-line enum→`AppError` conversion differing only in a string prefix and a fallback message. It is the same conversion the `AuthCubit` performs inline at `auth_cubit.dart:343-346`.

**Impact**: Minor; the code strings are user-invisible diagnostics, so drift is low-consequence. But it is the 3rd/4th instance of "flatten a typed failure into `AppError`".

**Fix**: One helper `AppError appErrorFromFailure(OrgFailure failure, {required String codePrefix, required String fallback})` in `lib/core/organizations/` (or fold into the `Result` unification in the MEDIUM finding above).

---

## LOW — Silent catch-all in the reset screen

**Location**: `lib/features/auth/presentation/forgot_password/forgot_password_reset_screen.dart:66-73` — `try { routing = GoRouterState.of(context).extra ... } on Object catch (_) { routing = RecoveryRoutingContext.empty; }`.

**Issue**: The only `catch (_)` in `lib/` (verified by grep). It is *documented* (`:60-64`: guards `GoRouterState.of` outside a router) and the recovery is intentional, so this is not a defect — but it swallows the exception object entirely, so a genuinely broken router wiring would be indistinguishable from the expected "no router above me" case.

**Impact**: Low; the fallback is safe and the branch is reachable only outside a router (tests / deep links). The concern is diagnosability, not correctness.

**Fix**: Keep the fallback but pass the error to the reporter, or narrow the catch to the specific assertion/`GoError` type so an unexpected failure still surfaces.

---

## LOW — Test-file oddity: tests wrapped in invoked local closures

**Location**: `test/features/orgs/presentation/org_audit_cubit_test.dart:43-64`, `:74-98`, `:100-130`.

**Issue**: Three `blocTest`s are each wrapped in a `void someTest() { ... }` closure that is then called immediately (`freshOrgEmptyTest();`, `nonDeniedFailureTest();`, `retryTest();`). The indirection buys nothing (the `late` variables they scope are equally scoped by the `blocTest` `build` closure) and it is the only occurrence in the suite (3 hits, all this file). It also breaks the flat `group > test` shape every other test file uses.

**Impact**: Cosmetic; tests still run and assert correctly.

**Fix**: Inline the three `blocTest`s back into the `group` body.

---

## LOW — 4 dated docs not linked from any index

**Location**: `docs/collaboration_task_board_scope_draft_2026-08-09.md`, `docs/pending_approvals_queue_scope_draft_2026-08-09.md`, `docs/invite_share_link_completion_evidence_2026-08-07.md`, `docs/notification_read_flag_apply_record_2026-09-02.md`.

**Issue**: Determined by building the set of all `*.md` names mentioned anywhere in `docs/`, `README.md`, `AGENTS.md`, `INSTRUCTIONS.md` and diffing against the 171 files in `docs/` — these 4 are referenced by nothing (the other 167 are linked). They are dated evidence/scope records, so the content is legitimate; only discoverability is lost.

**Impact**: Low — a reader of the docs index cannot find the evidence for the task-board / approvals / invite-share-link / notification-read-flag slices.

**Fix**: Add them to the relevant slice's cross-reference line, or to a `docs/README.md` index.

---

## Notes on things checked and found clean (so they are not re-raised)

- **`flutter_lints` is strengthened, not weakened.** `analysis_options.yaml:3-7` enables `strict-casts`, `strict-inference`, `strict-raw-types`; `:8-10` promotes `missing_required_param`/`missing_return` to errors; `:12-25` adds 11 lints (`always_declare_return_types`, `avoid_dynamic_calls`, `avoid_print`, `directives_ordering`, `prefer_final_locals`, `prefer_single_quotes`, `require_trailing_commas`, `sort_constructors_first`, `sort_pub_dependencies`, `unawaited_futures`, `always_put_control_body_on_new_line`). Nothing from the default set is disabled.
- **No `use_build_context_synchronously` suppressions** (0 `// ignore:` for it) and **30 explicit `mounted` guards**. Spot-checked the two async-handler candidates: `create_organization_screen.dart:139-144` uses `context` only before its single `await`; `profile_screen.dart:127-146` guards with `if (!mounted) return;` at `:133` before every post-await `context` use.
- **Only 4 `// ignore:` comments in `lib/`** — 3 generated `unused_import` headers and 1 intentional `avoid_print` in `ConsoleErrorReporter` (`error_reporter.dart:66`).
- **`late` usage is disciplined**: 9 declarations, all `late final` subscriptions/controllers initialised in `initState` or with a non-`context` initializer.
- **SQL is genuinely factored**: `public.write_audit(...)` (`supabase/migrations/02_rls_functions.sql:45`) is a shared audit helper, and `has_org_role` / `is_platform_owner` / `active_membership` (`:14-36`) are shared gate helpers — the 23 RPC files call them rather than re-implementing. The `*_platform` RPC pairs were diffed and are **real variants**, not clones (`suspend_membership_platform.sql` swaps `has_org_role` for `is_platform_owner`, drops the last-partner guard, and changes the audit action) — the prior audit's "structurally different" discipline holds here.
- **Prior duplication work verified as landed**: `AppTile`, `AppFilterChips`, `AppCenteredMessage`, `AppCenteredRetry`, `AppSectionHeader`, `WorkspaceSection`, `ViewStateList`, `ViewStateSwitch`, `LabelChip`, `DirectionalIcon` are all present in `lib/shared/widgets/widgets.dart` and have real call sites. The in-flight `ViewStateList` signature change (`itemBuilder` → `tileBuilder`, generic over the item) was applied coherently: all 3 call sites (`approvals_screen.dart:73`, `compliance_alerts_screen.dart:71`, `task_board_screen.dart:69`) are updated in the same working tree, so the slice is not half-migrated.
- **ARB sources are healthy**: `app_en.arb` 373 keys, `app_ar.arb`/`app_tr.arb` 371 each; the only diffs are the `minutes`/`referenceId` placeholder *declarations* inside `@`-metadata blocks, which correctly live only in the template. No unused keys — every key is referenced, including the 8 that only appear via `AppLocalizations.of(context).key` (`aiResearchTitle`, `alertsTitle`, `approvalsTitle`, `codeSentNotice`, `inviteShareLinkCopied`, `invoicesTitle`, `notificationsFeedTitle`, `tasksTitle`).
- **No unused dependencies**: `app_links` → `lib/app/deep_link/app_links_adapter.dart` + `main.dart:58`; `http` (dev) → 2 contract tests; `mocktail`/`bloc_test` → used.

---

## What's done well (evidence-backed)

1. **A real error-handling contract, applied consistently at the seam.** Typed per-domain failure kinds, `Result<T>`/`AppError` boundaries, and a `Redactor` that strips emails/bearer tokens/sensitive keys *before* any diagnostic is stored (`lib/core/observability/error_reporter.dart:11-58`) — with a test (`test/bootstrap_boundaries_test.dart:45,68`). The `Supabase*ApiImpl` catches `on PostgrestException` and `on Object` separately so a transport failure becomes a typed `providerUnavailable`, never a raw exception across the boundary (`supabase_document_api_impl.dart:41-51`). This is the strongest aspect of the codebase.
2. **Lint discipline above the framework default** (`analysis_options.yaml:3-25`) — strict casts/inference/raw-types plus 11 opt-in lints, with only 4 `// ignore:` in all of `lib/` (3 generated). The `avoid_dynamic_calls` + `strict-raw-types` pair is why the data layer's `dynamic` is confined to `Map<String, dynamic>` row shapes and does not leak into UI (only 3 `dynamic` occurrences in `lib/features/`, all in `BlocProvider<dynamic>` list literals).
3. **Tests assert behaviour, not implementation.** 33,483 test LOC against 27,283 lib LOC; only **32** `expect(..., isNotNull)` fillers, only **5** `verify(...)` calls and 21 `thenAnswer/thenReturn` — i.e. the suite overwhelmingly drives the real `fake_*_gateway` doubles instead of mocks (`test/features/tasks/task_board_screen_test.dart` asserts rendered copy and a retry round-trip; `test/features/orgs/presentation/org_audit_cubit_test.dart` asserts full state sequences including the loading→denied→loading→loaded retry path). `test/responsive/responsive_smoke_test.dart` pumps the real app across 7 device sizes, 2 text scales, and RTL.
4. **SQL policy/RPC layer is factored, not copy-pasted.** Shared `write_audit` + gate helpers (`supabase/migrations/02_rls_functions.sql:14-45`) mean the 23 RPC files express only their own gate and mutation; the `_platform` variants differ meaningfully rather than duplicating.
5. **Documented-deviation discipline that actually closes.** `docs/tracked_deviations.md` D-T1–D-T4 and D-T8 are recorded as RESOLVED with commit hashes and regression guards; ADR-0004's `ViewStateView` retention was converted from "by contract" to "by use" once two real consumers landed. This is why most of the prior audit's claims survive re-checking.
6. **The in-flight perf slice is coherent and self-consistent.** `ViewStateList` was re-generified over the item type with a lazy `ListView.builder` (`lib/shared/widgets/view_state_list.dart:19-155`), the `_Composer` dropped its per-keystroke `setState` for a scoped `ValueListenableBuilder` (`message_thread_detail_screen.dart:298-379`), and all three call sites plus the widget test were migrated together.

---

## Dimension score

**7 / 10.**

**Justification:** The strongest aspect is the error/observability design and its enforcement — a typed `Result`/`AppError` seam, a redacting reporter, per-domain failure kinds, strict analyzer settings, and a behavioural test suite that uses real fakes rather than mock theatre; this is materially better than a typical production Flutter app. The weakest aspect is the *data layer's* structural copy-paste (9 `_kindFor` + 9 `_mapFailure` + 9–10 enum/exception pairs ≈ 530 lines) sitting right next to that otherwise-excellent error contract, compounded by a ~50-line Cubit-surface skeleton repeated across ~7 screens, three parallel `Result` types, two dead abstractions in `core/`, and a brand-new bounded-read guard that is both untested and — for threads over 200 messages — truncating the wrong end of the history. Those are concentrated, fixable, and mostly mechanical, which is why the score is a high 7 rather than a 5 or 6.
