# LegalHub Performance & Bug Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the P0/P1 performance and correctness defects found by the 2026-10-27 read-only audit, then land the safe P2 cleanup and size wins without weakening the project's gates.

**Architecture:** Wave-based remediation. One fresh subagent per task with exclusive file ownership; the parent verifies every report at source before dispatching the next task. P0 correctness lands first, then failure containment, messaging lifecycle, media/storage, speed, and finally the safe P2 items. No task touches another task's files.

**Tech Stack:** Flutter 3.47.5 local / 3.44.4 CI-pinned, Dart 3.13.4, `bloc`/`flutter_bloc`, `go_router`, Supabase (`postgrest 2.8.0`, `realtime_client 2.11.0`, `gotrue 2.26.0`), LiveKit (`livekit_client 2.13.1`), `shared_preferences`, `flutter_secure_storage`, `intl`.

**Spec:** This document, §Audit Findings. Source evidence: the read-only performance/bug audit run on 2026-10-27 against `fix/audit-remediation` @ `0b52374` (dirty tree).

---

## START GATE — DO NOT SKIP

The audit was executed against a **dirty tree**: 111 `git status` entries, ~90 changed files, +1,856 / −2,786, mid-refactor. Every file:line in this plan is anchored to that tree.

Execution MUST stop at the first of these:

1. `git status --porcelain` is non-empty → **STOP**. Do not stash, reset, commit, or copy the tree yourself. Report the dirty entry count and ask the owner to either commit the in-flight `fix/audit-remediation` work or explicitly authorize a worktree snapshot. (AGENTS.md: ask before destructive or config-changing actions.)
2. HEAD is not the SHA the owner approved for execution → **STOP** and re-verify every file:line anchor in this plan. If the in-flight refactor was committed, HEAD will move; re-anchor before editing.
3. No isolated worktree exists → create one with `superpowers:using-git-worktrees` from the approved clean SHA. Never execute on the main working tree.
4. Baseline gates are not green in the worktree → **STOP**. Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze --no-pub`, `flutter test`, and `bash scripts/verify_ledger.sh` first. The 2026-10-27 baseline was: analyze 0, tests 1,966/1,966, format 0 changed, ledger PASS.

Report the start-gate evidence verbatim:

```text
HEAD=<sha> BRANCH=<name> PORCELAIN=<count> WORKTREES=<list>
analyze=<exit/result> tests=<passed>/<total> format=<changed> ledger=<PASS/FAIL>
```

---

## Global Constraints

- **No commit, no push without explicit owner GO.** Each task ends with `git add <exact files>` and a report; it does NOT commit. The owner opens a commit window per wave.
- **Never weaken an assertion to get green.** The one intentional expectation change is Task 1: the notification test currently pins the wrong provider shape (DateTime) and must be corrected to the real PostgREST shape (ISO string). Record that as an approved correction in the task report.
- **Do not hand-edit** `lib/l10n/app_localizations*.dart`. This plan adds no new l10n keys; it reuses the existing `viewAll` getter.
- **No live Supabase/DDL changes** in this plan. No `supabase db push`. No secret reads or writes.
- **Gates per task:** `flutter analyze --no-pub` and the task's targeted test file. **Gates per wave:** full `flutter test`, `dart format --output=none --set-exit-if-changed .`, `bash scripts/verify_ledger.sh`.
- **One subagent per task.** The brief must include: exclusive file list, the task's exact code/tests, the start gate, the STOP list, and "no commit/no push".
- **Parent verifies at source** before dispatching the next task: open the modified file, confirm the hunk, run the targeted test, and re-count references where the task claims a deletion.
- **README test count:** after each wave the suite count changes. Update the README's tracked count only in the wave close-out, never inside a task.
- **No new dependencies.** Keep-screen-on, font axis subsetting, and LiveKit removal are owner decisions in §Deferred.

---

## Audit Findings (source of truth)

| ID | Severity | Finding | Evidence |
|---|---|---|---|
| F1 | P0 | Notification feed fails every row in configured builds: mapper requires `DateTime`, PostgREST returns an ISO string | `lib/data/notifications/supabase_notification_gateway.dart:77-84`; `test/data/notifications/supabase_notification_gateway_test.dart:48,177-190` |
| F2 | P0 | Startup blocks the first frame on a membership SELECT with a 15s deadline | `lib/main.dart:60-97`; `lib/features/auth/presentation/auth_cubit_hydration.dart:88-89`; `lib/data/list_query_guards.dart:19,154-158` |
| F3 | P1 | `TimeoutException` escapes the org and admin seams because they catch only `PostgrestException` | `lib/data/orgs/supabase_org_api_impl.dart:91-96,113-116,358-367`; `lib/data/admin/supabase_platform_admin_api_impl.dart:41-77,183-192` |
| F4 | P1 | Sign-out clears the provider session then rethrows; the app can remain authenticated locally | `lib/data/auth/supabase_auth_gateway.dart:150-155`; `gotrue-2.26.0/lib/src/gotrue_client.dart:986-1009`; `auth_cubit.dart:146-161` |
| F5 | P1 | `WriteGate` never resets `_inFlight` when the write throws | `lib/shared/state/write_gate.dart:39-41` |
| F6 | P1 | Realtime treats an intentional `closed` as an error, reconnects the old thread, can mix threads, and never closes on last unsubscribe | `lib/data/messaging/supabase_message_realtime_api_impl.dart:53-77,82-96,133-137` |
| F7 | P1 | Live chat transcript appends without a cap | `lib/features/messaging/presentation/message_thread_detail_cubit.dart:129-147` |
| F8 | P1 | Video always publishes 720p/30fps, never pauses camera/mic in background | `lib/features/video/presentation/video_call_screen.dart:19,73-96,150-151`; LiveKit defaults |
| F9 | P1 | Upload has a fixed 15s timeout against a 25 MiB cap; timeout does not cancel; bytes are read before the size check; orphan cleanup misses the upload itself | `supabase_storage_api_impl.dart:75-88`; `file_selector_file_picker.dart:58-59`; `file_transfer_cubit.dart:54-74`; `supabase_storage_gateway.dart:93` |
| F10 | P1 | Search re-fetches the query-independent attorney directory (100 rows) on every 300ms pause | `lib/features/search/presentation/search_cubit.dart:127-137`; `supabase_attorney_gateway.dart:24-30` |
| F11 | P1 | Matter details expands four lists (up to 4 × 200 rows) into one non-lazy `ListView` | `matter_workspace_cubit.dart:56-144`; `workspace_section.dart:62-72`; `matter_details_surface.dart:79-141` |
| F12 | P2 | Notification cubit emits after a second await without rechecking `isClosed` | `notification_cubit.dart:64-95` |
| F13 | P2 | Membership `TypeError` can strand sign-in because the repository catches `Exception`, not `Error` | `supabase_membership_repository.dart:54-64,83-95` |
| F14 | P2 | Recovery email hardcodes the production scheme in development builds | `supabase_auth_api_impl.dart:108-109,214-227` |
| F15 | P2 | Three auth API instances → 3 auth-state subscriptions; 2 are never disposed | `service_locator_auth.dart:23-66`; `supabase_auth_api_impl.dart:68-83,304-305` |
| F16 | P2 | Video Join can stack dialogs / push two call screens | `video_consultation_screen.dart:107-139` |
| F17 | P2 | Dead italic font ships 2.215 MB raw / ~1.37 MB compressed | `pubspec.yaml:49-60`; `assets/fonts/noto_sans/NotoSans-Italic-Variable.ttf` |
| F18 | P2 | Platform-admin audit section expands up to 200 rows eagerly; settings watches whole cubits | `platform_admin_audit_section.dart:65,107-112`; `settings_screen.dart:34-38` |

---

## Wave Map

| Wave | Tasks | Outcome |
|---|---|---|
| 1 | T1–T2 | Notification feed works; first frame no longer waits on membership network |
| 2 | T3–T5 | Timeouts become typed failures; sign-out and write gates cannot wedge; notification/membership guards |
| 3 | T6–T7 | Realtime switch is race-safe, thread-scoped, and closes on last unsubscribe; transcript bounded |
| 4 | T8–T9 | Call uses 360p/15fps and pauses media in background; uploads precheck, time out sanely, and clean up |
| 5 | T10–T11 | Search stops re-fetching the attorney directory; matter details renders 5 preview rows per section |
| 6 | T12–T13 | Auth API singleton, dev recovery scheme, tested Join gate; dead italic font removed |
| 7 | T14 | Full gates, ledger, README count, handoff |

---

## File Ownership Map

| Task | Exclusive files |
|---|---|
| T1 | `lib/data/notifications/supabase_notification_gateway.dart`; `test/data/notifications/supabase_notification_gateway_test.dart` |
| T2 | `lib/features/auth/presentation/auth_cubit.dart`; `lib/features/auth/presentation/auth_cubit_hydration.dart`; `lib/main.dart`; `test/features/auth/auth_cubit_test.dart` |
| T3 | `lib/data/orgs/supabase_org_api_impl.dart`; `lib/data/admin/supabase_platform_admin_api_impl.dart`; `lib/data/matters/supabase_matter_gateway.dart`; `lib/data/admin/supabase_platform_admin_gateway.dart`; `test/data/orgs/supabase_org_api_impl_test.dart`; `test/data/admin/supabase_platform_admin_api_impl_test.dart`; `test/data/matters/supabase_matter_gateway_test.dart`; `test/data/admin/supabase_platform_admin_gateway_test.dart` |
| T4 | `lib/shared/state/write_gate.dart`; `lib/data/auth/supabase_auth_gateway.dart`; `lib/features/auth/presentation/auth_cubit.dart`; `test/shared/state/write_gate_test.dart`; `test/features/auth/auth_cubit_test.dart` |
| T5 | `lib/features/notifications/presentation/notification_cubit.dart`; `lib/data/orgs/supabase_membership_repository.dart`; `test/features/notifications/notification_cubit_test.dart`; `test/data/orgs/supabase_membership_repository_test.dart` |
| T6 | `lib/data/messaging/supabase_message_realtime_api_impl.dart`; `test/data/messaging/supabase_message_realtime_api_impl_test.dart` |
| T7 | `lib/features/messaging/presentation/message_thread_detail_cubit.dart`; `test/features/messaging/message_thread_detail_cubit_test.dart` |
| T8 | `lib/features/video/presentation/video_call_screen.dart`; `test/features/video/video_call_screen_test.dart` |
| T9 | `lib/features/storage/domain/file_picker.dart`; `lib/features/storage/domain/storage_gateway.dart`; `lib/data/files/file_selector_file_picker.dart`; `lib/features/storage/presentation/file_transfer_cubit.dart`; `lib/data/storage/supabase_storage_api_impl.dart`; `lib/data/storage/supabase_storage_gateway.dart`; `test/features/storage/file_transfer_cubit_test.dart`; `test/features/storage/storage_gateway_test.dart`; `test/data/storage/supabase_storage_gateway_test.dart` |
| T10 | `lib/features/search/presentation/search_cubit.dart`; `test/features/search/search_cubit_test.dart` |
| T11 | `lib/shared/widgets/workspace_section.dart`; `lib/features/matters/presentation/matter_documents_section.dart`; `lib/features/matters/presentation/matter_invoices_section.dart`; `lib/features/matters/presentation/matter_files_section.dart`; `lib/features/matters/presentation/matter_messages_section.dart`; `test/shared/widgets/workspace_section_test.dart` |
| T12 | `lib/data/auth/supabase_auth_api_impl.dart`; `lib/app/service_locator_auth.dart`; `lib/features/video/presentation/join_gate.dart`; `lib/features/video/presentation/video_consultation_screen.dart`; `test/data/auth/supabase_auth_api_impl_test.dart`; `test/service_locator_test.dart`; `test/features/video/join_gate_test.dart` |
| T13 | `pubspec.yaml`; delete `assets/fonts/noto_sans/NotoSans-Italic-Variable.ttf` |
| T14 | `README.md` only (count reconciliation); no app code |

Tasks run **sequentially**, so `auth_cubit.dart` (T2 then T4) is safe: the T4
executor must re-read the file after T2's parent verification before editing.
Concurrent dispatch is not permitted for any task in this plan.

---

### Task 1: Notification timestamp compatibility (F1)

**Files:**
- Modify: `lib/data/notifications/supabase_notification_gateway.dart:77-84`
- Modify: `test/data/notifications/supabase_notification_gateway_test.dart:36-50,177-190`

**Interfaces:**
- Consumes: `row['server_timestamp']` from PostgREST (`timestamptz` → ISO-8601 String).
- Produces: `Notification.serverTimestamp` as a local `DateTime`; malformed values still throw `FormatException` and surface as `notification_read_failed`.

- [ ] **Step 1: Update the fixture to the real provider shape**

Replace the `_row` helper signature and timestamp line:

```dart
Map<String, dynamic> _row({
  String id = 'notification-1',
  String category = 'activity',
  String type = 'matter_updated',
  String summary = 'Demo notification — matter status update',
  Object? serverTimestamp,
  bool isRead = false,
}) => <String, dynamic>{
  'id': id,
  'category': category,
  'type': type,
  'summary': summary,
  // PostgREST returns timestamptz as an ISO-8601 string. The DateTime arm
  // remains accepted for unit fixtures but is not the provider shape.
  'server_timestamp': serverTimestamp ?? '2026-07-18T14:05:00.000Z',
  'is_read': isRead,
};
```

- [ ] **Step 2: Replace the wrong “non-DateTime is drift” test**

Replace the test at `:177-190` with two tests:

```dart
test('maps an ISO-8601 string timestamp to local time (PostgREST shape)', () async {
  api.rows = <Map<String, dynamic>>[_row()];

  final Notification notification =
      (await gateway.fetchNotifications()).valueOrNull!.single;

  expect(notification.serverTimestamp.isUtc, isFalse);
  expect(
    notification.serverTimestamp.isAtSameMomentAs(DateTime.utc(2026, 7, 18, 14, 5)),
    isTrue,
  );
});

test('a malformed timestamp string is provider drift → loud failure', () async {
  api.rows = <Map<String, dynamic>>[
    <String, dynamic>{..._row(), 'server_timestamp': 'not-a-date'},
  ];

  final Result<List<Notification>> result = await gateway.fetchNotifications();

  expect(result.isSuccess, isFalse);
  expect(result.errorOrNull!.code, 'notification_read_failed');
});
```

- [ ] **Step 3: Run the tests to verify the new string test fails**

Run: `flutter test test/data/notifications/supabase_notification_gateway_test.dart`

Expected: FAIL — the ISO-string test gets `notification_read_failed` (or `valueOrNull` is null).

- [ ] **Step 4: Implement the accepted-shape mapping**

Replace the timestamp block in `_notificationFromRow`:

```dart
    // PostgREST returns `timestamptz` as an ISO-8601 string. The DateTime
    // arm is retained for unit fixtures and legacy callers; anything else
    // is provider drift and surfaces as a typed failure.
    final Object? rawTimestamp = row['server_timestamp'];
    final DateTime serverTimestamp;
    if (rawTimestamp is DateTime) {
      serverTimestamp = rawTimestamp;
    } else if (rawTimestamp is String && rawTimestamp.isNotEmpty) {
      final DateTime? parsed = DateTime.tryParse(rawTimestamp);
      if (parsed == null) {
        throw FormatException(
          'Notification row has an invalid server_timestamp',
        );
      }
      serverTimestamp = parsed;
    } else {
      throw FormatException('Notification row has no server_timestamp');
    }
    final Object? isRead = row['is_read'];
    if (isRead is! bool) {
      throw FormatException('Notification row has no is_read');
    }
    return Notification(
      id: id,
      category: _categoryFromString(category),
      type: type,
      summary: summary,
      serverTimestamp: serverTimestamp.toLocal(),
      isRead: isRead,
    );
```

- [ ] **Step 5: Run the test file and the notification feature tests**

Run:

```bash
flutter test test/data/notifications/supabase_notification_gateway_test.dart
flutter test test/features/notifications
```

Expected: PASS.

- [ ] **Step 6: Stage and report (no commit)**

```bash
git add lib/data/notifications/supabase_notification_gateway.dart test/data/notifications/supabase_notification_gateway_test.dart
git status --porcelain
```

Report: the corrected expectation, the two passing tests, and the exact diff stat.

---

### Task 2: Defer membership hydration from the first frame (F2)

**Files:**
- Modify: `lib/features/auth/presentation/auth_cubit.dart:32-45,115-121`
- Modify: `lib/features/auth/presentation/auth_cubit_hydration.dart:65-115` (comment only if the signature stays here)
- Modify: `lib/main.dart:60-110`
- Test: `test/features/auth/auth_cubit_test.dart`

**Interfaces:**
- Consumes: `AuthCubit.restore()` and the existing `hydrate()` background refresh.
- Produces: `Future<void> restore({bool hydrateMemberships = true})`; `main` calls `restore(hydrateMemberships: false)`, then `unawaited(authCubit.hydrate())` after `runApp`.

- [ ] **Step 1: Write the failing test**

Add to `test/features/auth/auth_cubit_test.dart` inside `main()` (near the restore group):

```dart
test(
  'restore(hydrateMemberships: false) emits authenticated before the membership read',
  () async {
    final _CountingMembershipRepository repository =
        _CountingMembershipRepository();
    final AuthCubit cubit = AuthCubit(
      _PreauthenticatedGateway(demoSession()),
      InMemoryErrorReporter(),
      repository,
      FakeOrganizationGateway(),
    );
    addTearDown(cubit.close);

    await cubit.restore(hydrateMemberships: false);

    expect(cubit.state.status, AuthStatus.authenticated);
    expect(repository.calls, 0);

    await cubit.hydrate();

    expect(repository.calls, 1);
    expect(cubit.state.session!.memberships, isNotEmpty);
  },
);
```

Add the counter at the bottom of the file:

```dart
class _CountingMembershipRepository implements MembershipRepository {
  int calls = 0;

  @override
  Future<MembershipHydrationResult> loadMemberships({
    required String userId,
  }) async {
    calls += 1;
    return const HydrationSucceeded(<OrganizationMembership>[
      FakeMembershipRepository.demoMembership,
    ]);
  }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/auth/auth_cubit_test.dart -n "restore(hydrateMemberships: false)"`

Expected: FAIL — `restore` does not accept the named parameter.

- [ ] **Step 3: Add the optional parameter**

In `lib/features/auth/presentation/auth_cubit.dart`:

```dart
  Future<void> restore({bool hydrateMemberships = true}) async {
    if (state.status == AuthStatus.restoring ||
        state.status == AuthStatus.loading) {
      return;
    }
    emit(const AuthState(status: AuthStatus.restoring));
    _explicitOperationInFlight = true;
    try {
      final AuthOutcome<Session> outcome = await _gateway.restore();
      await _applySessionOutcome(
        outcome,
        hydrateMemberships: hydrateMemberships,
      );
    } finally {
      _explicitOperationInFlight = false;
    }
  }
```

And:

```dart
  Future<void> _applySessionOutcome(
    AuthOutcome<Session> outcome, {
    bool hydrateMemberships = true,
  }) async {
    switch (outcome) {
      case AuthSuccess<Session>(value: final Session session):
        if (!hydrateMemberships) {
          _emitIfChanged(_stateFor(session));
        } else {
          await _applyAuthenticatedSession(session);
        }
      case AuthFailed<Session>(failure: final AuthFailure failure):
        await _handleFailure(failure);
    }
  }
```

- [ ] **Step 4: Stop blocking bootstrap on the membership read**

In `lib/main.dart`, change the restore call and add the post-frame hydration:

```dart
  await Future.wait(<Future<void>>[
    localeCubit.load(),
    themeCubit.load(),
    // Local session restore only. Membership hydration is a network read
    // and must not hold the first frame (audit 2026-10-27, F2).
    authCubit.restore(hydrateMemberships: false),
  ]);
```

After `runApp(...)` and before `unawaited(appLinkListener.start());`:

```dart
  // The router is attached now; fill the RLS-scoped memberships in the
  // background. hydrate() no-ops when the session is absent/expired.
  unawaited(authCubit.hydrate());
```

- [ ] **Step 5: Run the auth, router, and widget boot tests**

Run:

```bash
flutter test test/features/auth/auth_cubit_test.dart
flutter test test/app/router_test.dart test/widget_test.dart
```

Expected: PASS. The boot test still lands on the sign-in screen; the demo flow still reaches the shell.

- [ ] **Step 6: Stage and report (no commit)**

```bash
git add lib/features/auth/presentation/auth_cubit.dart lib/features/auth/presentation/auth_cubit_hydration.dart lib/main.dart test/features/auth/auth_cubit_test.dart
git status --porcelain
```

Report the measured behavior: `restore(false)` emits authenticated with zero membership calls; `hydrate()` performs exactly one.

---

### Task 3: Map transport timeouts at the org and admin seams (F3)

**Files:**
- Modify: `lib/data/orgs/supabase_org_api_impl.dart`
- Modify: `lib/data/admin/supabase_platform_admin_api_impl.dart`
- Modify: `lib/data/matters/supabase_matter_gateway.dart`
- Modify: `lib/data/admin/supabase_platform_admin_gateway.dart`
- Test: `test/data/orgs/supabase_org_api_impl_test.dart`
- Test: `test/data/admin/supabase_platform_admin_api_impl_test.dart`
- Test: `test/data/matters/supabase_matter_gateway_test.dart`
- Test: `test/data/admin/supabase_platform_admin_gateway_test.dart`

**Interfaces:**
- Consumes: `SupabaseSeam.boundRpc` / `boundRawRpc` with a 15s timeout.
- Produces: `SupabaseOrgException(kind: providerUnavailable)` and `SupabasePlatformAdminException(kind: providerUnavailable)` for timeouts; existing PostgREST mapping is unchanged.

- [ ] **Step 1: Add the failing org test**

In `test/data/orgs/supabase_org_api_impl_test.dart`, add `import 'dart:async';` and a `final Set<String> timeouts = <String>{};` field. In the injected RPC closure, after the `calls.add(...)` line:

```dart
          if (timeouts.contains(function)) {
            throw TimeoutException('slow provider');
          }
```

Add the test:

```dart
test('maps a transport timeout to providerUnavailable', () async {
  timeouts.add('create_organization');

  await expectLater(
    api.createOrganization(name: 'New Firm'),
    throwsA(
      isA<SupabaseOrgException>().having(
        (e) => e.kind,
        'kind',
        SupabaseOrgFailureKind.providerUnavailable,
      ),
    ),
  );
});
```

- [ ] **Step 2: Add the failing admin test**

In `test/data/admin/supabase_platform_admin_api_impl_test.dart`, add `import 'dart:async';` and the same `Set<String> timeouts`. Add the test:

```dart
test('maps a transport timeout to providerUnavailable', () async {
  timeouts.add('list_organizations_metadata');

  await expectLater(
    api.listOrganizations(),
    throwsA(
      isA<SupabasePlatformAdminException>().having(
        (e) => e.kind,
        'kind',
        SupabasePlatformAdminFailureKind.providerUnavailable,
      ),
    ),
  );
});
```

- [ ] **Step 3: Run both to verify they fail with a raw TimeoutException**

Run:

```bash
flutter test test/data/orgs/supabase_org_api_impl_test.dart
flutter test test/data/admin/supabase_platform_admin_api_impl_test.dart
```

Expected: FAIL — the thrown type is `TimeoutException`, not the typed seam exception.

- [ ] **Step 4: Wrap the org RPC field**

In `lib/data/orgs/supabase_org_api_impl.dart`:

1. Add `import 'dart:async';` at the top.
2. Rename the field `final OrgRpcCaller _rpc;` to `final OrgRpcCaller _rpcCaller;`.
3. Change the constructor to `SupabaseOrgApiImpl(this._rpcCaller, this._table);`.
4. Add the wrapper below the fields:

```dart
  Future<PostgrestResponse<dynamic>> _rpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    try {
      return await _rpcCaller(function, params);
    } on TimeoutException {
      // The shared 15s seam deadline; a transport stall is a typed
      // unavailable, never a raw exception across the boundary.
      throw const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.providerUnavailable,
        message: orgRequestFailedMessage,
      );
    }
  }
```

All existing `_rpc(...)` call sites now hit this wrapper. Keep every existing `on PostgrestException` catch.

- [ ] **Step 5: Wrap the admin RPC field**

In `lib/data/admin/supabase_platform_admin_api_impl.dart`:

1. Add `import 'dart:async';`.
2. Rename `final PlatformAdminRpcCaller _rpc;` to `_rpcCaller`.
3. Change the constructor to `SupabasePlatformAdminApiImpl(this._rpcCaller);`.
4. Add:

```dart
  Future<PostgrestResponse<dynamic>> _rpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    try {
      return await _rpcCaller(function, params);
    } on TimeoutException {
      throw const SupabasePlatformAdminException(
        kind: SupabasePlatformAdminFailureKind.providerUnavailable,
        message: platformAdminRequestFailedMessage,
      );
    }
  }
```

`_runVoidRpc` and the list methods now propagate the typed exception; the gateway maps it to `OrgFailureKind.providerUnavailable`.

- [ ] **Step 6: Add a TypeError guard at the matter/admin gateways**

In `lib/data/matters/supabase_matter_gateway.dart`, extend `_run`'s catch list:

```dart
    } on TypeError catch (e) {
      // Mapper drift is an Error, not an Exception. Surface it as a typed
      // provider failure instead of letting it strand the loading state.
      return Result<List<Matter>>.failure(
        AppError(
          code: 'matter_read_failed',
          userMessage: 'Unable to load matters. Please try again.',
          technicalMessage: e.toString(),
        ),
      );
    }
```

In `lib/data/admin/supabase_platform_admin_gateway.dart`, change the list/member read catch blocks from `on FormatException` to also include `on TypeError` (or add `on TypeError` beside each existing `on FormatException`), returning `OrgFailureKind.unknown`. Keep the existing behavior for typed errors.

- [ ] **Step 7: Run the two seam tests and the downstream gateway tests**

Run:

```bash
flutter test test/data/orgs/supabase_org_api_impl_test.dart
flutter test test/data/admin/supabase_platform_admin_api_impl_test.dart
flutter test test/data/matters/supabase_matter_gateway_test.dart
flutter test test/data/admin/supabase_platform_admin_gateway_test.dart
```

Expected: PASS.

- [ ] **Step 8: Stage and report (no commit)**

Stage the four production files and two test files; report the before/after exception type for each new test.

---

### Task 4: Sign-out and WriteGate cannot wedge (F4, F5)

**Files:**
- Modify: `lib/shared/state/write_gate.dart:39-41`
- Modify: `lib/data/auth/supabase_auth_gateway.dart:150-155`
- Modify: `lib/features/auth/presentation/auth_cubit.dart:146-161`
- Create: `test/shared/state/write_gate_test.dart`
- Test: `test/features/auth/auth_cubit_test.dart`

- [ ] **Step 1: Write the failing WriteGate test**

Create `test/shared/state/write_gate_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/shared/state/write_gate.dart';

void main() {
  test('a throwing write releases the gate', () async {
    final WriteGate gate = WriteGate();

    await expectLater(
      gate.run<void>(
        isClosed: () => false,
        write: () async => throw StateError('boom'),
        onSuccess: () async {},
      ),
      throwsStateError,
    );

    final AppError? second = await gate.run<void>(
      isClosed: () => false,
      write: () async => const Success<void>(null),
      onSuccess: () async {},
    );

    expect(second, isNull);
  });
}
```

Run: `flutter test test/shared/state/write_gate_test.dart`
Expected: FAIL — the second run returns `busyError`.

- [ ] **Step 2: Fix WriteGate with try/finally**

```dart
    _inFlight = true;
    final Result<T> result;
    try {
      result = await write();
    } finally {
      _inFlight = false;
    }
```

- [ ] **Step 3: Write the failing sign-out test**

Add to `test/features/auth/auth_cubit_test.dart`:

```dart
test('a provider sign-out failure still clears the local state', () async {
  final AuthCubit cubit = AuthCubit(
    _ThrowingSignOutGateway(demoSession()),
    InMemoryErrorReporter(),
    FakeMembershipRepository(),
    FakeOrganizationGateway(),
  );
  addTearDown(cubit.close);

  await cubit.restore(hydrateMemberships: false);
  expect(cubit.state.status, AuthStatus.authenticated);

  await cubit.signOut();

  expect(cubit.state.status, AuthStatus.unauthenticated);
});
```

Add the gateway:

```dart
class _ThrowingSignOutGateway extends _PreauthenticatedGateway {
  _ThrowingSignOutGateway(super.session);

  @override
  Future<void> signOut() async => throw StateError('offline sign-out');
}
```

Run: `flutter test test/features/auth/auth_cubit_test.dart -n "provider sign-out failure"`
Expected: FAIL — the exception escapes and the state remains authenticated.

- [ ] **Step 4: Fix the gateway and cubit**

`SupabaseAuthGateway.signOut`:

```dart
  @override
  Future<void> signOut() async {
    try {
      await _api.signOut();
    } finally {
      // GoTrue removes the local session before it rethrows a transport
      // failure; the app must mirror that state in every outcome.
      _session = null;
      _recoveryPending = false;
      _changes.add(null);
    }
  }
```

`AuthCubit.signOut`:

```dart
  Future<void> signOut() async {
    _explicitOperationInFlight = true;
    try {
      await _gateway.signOut();
    } catch (error) {
      AppLog.diagnostic(
        'AuthCubit: provider sign-out failed; local session cleared: $error',
      );
    } finally {
      _hydrationEpoch += 1;
      _emitIfChanged(const AuthState.unauthenticated());
      _explicitOperationInFlight = false;
    }
  }
```

- [ ] **Step 5: Run both tests and the auth suite**

Run:

```bash
flutter test test/shared/state/write_gate_test.dart
flutter test test/features/auth/auth_cubit_test.dart
```

Expected: PASS.

- [ ] **Step 6: Stage and report (no commit)**

Report: the second WriteGate call no longer returns `busyError`; sign-out reaches `unauthenticated` even when the provider throws.

---

### Task 5: Notification closed guard and membership TypeError guard (F12, F13)

**Files:**
- Modify: `lib/features/notifications/presentation/notification_cubit.dart:64-95`
- Modify: `lib/data/orgs/supabase_membership_repository.dart:54-64,83-95`
- Test: `test/features/notifications/notification_cubit_test.dart`
- Test: `test/data/orgs/supabase_membership_repository_test.dart` (create if absent; check first)

- [ ] **Step 1: Write the failing notification close test**

Add `import 'dart:async';` to `test/features/notifications/notification_cubit_test.dart`.
`NotificationCubit` reads the prefs store through `LoadVisibleNotifications`, so
the delay lives in the store, not in a new constructor parameter. Add:

```dart
test('closing while the prefs read is pending does not emit after close', () async {
  final Completer<NotificationPrefs?> prefs = Completer<NotificationPrefs?>();
  final NotificationCubit cubit = NotificationCubit(
    _StubNotificationGateway(),
    _DelayedPrefsStore(prefs.future),
  );

  final Future<void> load = cubit.load();
  // The gateway is immediate; this microtask lets load reach the prefs read.
  await Future<void>.delayed(Duration.zero);
  await cubit.close();
  prefs.complete(null);

  await expectLater(load, completes);
});
```

Add the store at the bottom:

```dart
class _DelayedPrefsStore implements NotificationPrefsStore {
  _DelayedPrefsStore(this._read);

  final Future<NotificationPrefs?> _read;

  @override
  Future<NotificationPrefs?> read() => _read;

  @override
  Future<void> write(NotificationPrefs prefs) async {}
}
```

Run the new test before the production change; expected: FAIL with
`StateError: Cannot emit new states after calling close` (or the test harness
surfaces an unhandled async error).

- [ ] **Step 2: Implement the guard**

In `notification_cubit.dart`, move the `await _visibleNotifications(list)` into a local, re-check `isClosed`, then switch on the local:

```dart
        final Result<NotificationVisibility> visibilityResult =
            await _visibleNotifications(list);
        if (isClosed) {
          return;
        }
        switch (visibilityResult) {
```

- [ ] **Step 3: Write the failing membership TypeError test**

Create `test/data/orgs/supabase_membership_repository_test.dart` using mocktail
(the repository takes the `SupabaseOrgApi` interface):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/data/orgs/supabase_membership_repository.dart';
import 'package:legalhub/data/orgs/supabase_org_api.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrgApi extends Mock implements SupabaseOrgApi {}

void main() {
  test('a non-string role is dropped instead of throwing TypeError', () async {
    final _MockOrgApi api = _MockOrgApi();
    when(() => api.listMyMemberships(userId: 'u-1')).thenAnswer(
      (_) async => <Map<String, dynamic>>[
        <String, dynamic>{
          'user_id': 'u-1',
          'organization_id': 'org-1',
          'organization_name': 'Firm',
          'role': 42,
          'status': 'active',
        },
      ],
    );

    final SupabaseMembershipRepository repository =
        SupabaseMembershipRepository(api);
    final MembershipHydrationResult result = await repository.loadMemberships(
      userId: 'u-1',
    );

    expect(result, isA<HydrationSucceeded>());
    expect((result as HydrationSucceeded).memberships, isEmpty);
  });
}
```

Run: `flutter test test/data/orgs/supabase_membership_repository_test.dart`
Expected: FAIL with `TypeError`.

- [ ] **Step 4: Guard the casts**

Replace the role/status reads with:

```dart
    final Object? roleValue = row['role'];
    if (roleValue is! String) {
      AppLog.diagnostic('membership hydration: dropping a non-string role');
      return null;
    }
    final UserRole? role = userRoleFromServerName(roleValue);

    final Object? statusValue = row['status'];
    if (statusValue is! String) {
      AppLog.diagnostic('membership hydration: dropping a non-string status');
      return null;
    }
    final MembershipStatus? status = membershipStatusFromServerName(statusValue);
```

Keep the existing unknown-role/status drops.

- [ ] **Step 5: Run the tests**

Run:

```bash
flutter test test/features/notifications/notification_cubit_test.dart
flutter test test/data/orgs/supabase_membership_repository_test.dart
```

Expected: PASS.

- [ ] **Step 6: Stage and report (no commit)**

Report: the exact `StateError` reproduced before the guard, and the `HydrationSucceeded(empty)` result after the cast guard.

---

### Task 6: Realtime switch, thread scope, and channel lifetime (F6)

**Files:**
- Modify: `lib/data/messaging/supabase_message_realtime_api_impl.dart`
- Test: `test/data/messaging/supabase_message_realtime_api_impl_test.dart`

**Interfaces:**
- Consumes: the existing `MessageRealtimeBinder` and `MessageRealtimeSubscriptionHandle`.
- Produces: one active handle; old-thread inserts dropped; intentional closes do not reconnect; last listener cancellation closes the channel.

- [ ] **Step 1: Extend the test binder to model real close callbacks and late handles**

In `test/data/messaging/supabase_message_realtime_api_impl_test.dart`, replace `_RecordingBinder` with a version that stores every binding and can emit a `closed` callback from the handle:

```dart
class _Binding {
  _Binding(this.threadId, this.onInsert, this.onChannelError, this.handle);

  final String threadId;
  final void Function(Map<String, dynamic> row) onInsert;
  final void Function(Object error) onChannelError;
  final Completer<MessageRealtimeSubscriptionHandle> handle;
}
```

Keep a `List<_Binding> bindings` and a `List<String> calls`. In `bind`, create the binding, add it, and return `handle.future`. In `_FakeHandle.close`, optionally invoke the binding's `onChannelError(StateError('closed'))` when `emitClosedOnClose` is true. This reproduces `realtime_client`'s `unsubscribe → closed` callback.

- [ ] **Step 2: Write the failing switch tests**

Add:

```dart
test('switching threads closes the old handle and opens the new thread', () async {
  api.watchMessages('thread-a');
  await Future<void>.delayed(Duration.zero);
  api.watchMessages('thread-b');
  await Future<void>.delayed(Duration.zero);

  expect(binder.calls, <String>['thread-a', 'thread-b']);
  expect(binder.closedHandles, 1);
});

test('a closed callback during an intentional switch does not reconnect the old thread', () async {
  binder.emitClosedOnClose = true;

  api.watchMessages('thread-a');
  await Future<void>.delayed(Duration.zero);
  api.watchMessages('thread-b');
  await Future<void>.delayed(Duration.zero);

  expect(binder.calls, <String>['thread-a', 'thread-b']);
});

test('an insert from the old binding is dropped after a switch', () async {
  final events = <SupabaseMessageRealtimeEvent>[];
  final sub = api.watchMessages('thread-a').listen(events.add);
  addTearDown(sub.cancel);
  await Future<void>.delayed(Duration.zero);

  api.watchMessages('thread-b');
  await Future<void>.delayed(Duration.zero);

  binder.bindings.first.onInsert(<String, dynamic>{'id': 'old'});
  await Future<void>.delayed(Duration.zero);

  expect(events.whereType<SupabaseMessageRealtimeInsert>(), isEmpty);
});

test('cancelling the last listener closes the channel', () async {
  final sub = api.watchMessages('thread-a').listen((_) {});
  await Future<void>.delayed(Duration.zero);

  await sub.cancel();
  await Future<void>.delayed(Duration.zero);

  expect(binder.closedHandles, 1);
});
```

Run: `flutter test test/data/messaging/supabase_message_realtime_api_impl_test.dart`
Expected: FAIL — the old thread reconnects / old insert is delivered / the channel stays open.

- [ ] **Step 3: Implement the lifecycle**

In `supabase_message_realtime_api_impl.dart`:

```dart
class SupabaseMessageRealtimeApiImpl implements SupabaseMessageRealtimeApi {
  SupabaseMessageRealtimeApiImpl(this._binder) {
    _events = StreamController<SupabaseMessageRealtimeEvent>.broadcast(
      onCancel: () {
        unawaited(_closeActiveHandle());
      },
    );
  }

  final MessageRealtimeBinder _binder;

  late final StreamController<SupabaseMessageRealtimeEvent> _events;
  MessageRealtimeSubscriptionHandle? _handle;
  String? _threadId;
  bool _closed = false;
  bool _reconnecting = false;
  bool _switching = false;
```

Add:

```dart
  Future<void> _closeActiveHandle() async {
    final MessageRealtimeSubscriptionHandle? handle = _handle;
    _handle = null;
    await handle?.close();
  }
```

Replace `_switchThread`:

```dart
  Future<void> _switchThread(String threadId) async {
    _switching = true;
    try {
      await _closeActiveHandle();
    } finally {
      _switching = false;
    }
    if (!_closed && _threadId == threadId) {
      _open(threadId);
    }
  }
```

Replace `_open`:

```dart
  void _open(String threadId) {
    unawaited(
      _binder(
        threadId: threadId,
        onInsert: (Map<String, dynamic> row) {
          if (!_closed && _threadId == threadId) {
            _events.add(SupabaseMessageRealtimeInsert(row));
          }
        },
        onChannelError: (Object error) => _onChannelError(threadId),
      ).then(
        (MessageRealtimeSubscriptionHandle handle) {
          if (_closed || _threadId != threadId) {
            unawaited(handle.close());
            return;
          }
          _handle = handle;
        },
        onError: (Object error) {
          if (!_closed && _threadId == threadId) {
            _onChannelError(threadId);
          }
        },
      ),
    );
  }
```

Guard `_onChannelError` and `_reconnect`:

```dart
  void _onChannelError(String threadId) {
    if (_closed || _reconnecting || _switching || _threadId != threadId) {
      return;
    }
    _reconnecting = true;
    unawaited(_reconnect(threadId));
  }

  Future<void> _reconnect(String threadId) async {
    await _closeActiveHandle();
    if (_closed || _threadId != threadId) {
      _reconnecting = false;
      return;
    }
    _open(threadId);
    _events.add(const SupabaseMessageRealtimeReconnected());
    _reconnecting = false;
  }
```

Keep `close()` as-is, but call `_closeActiveHandle()` instead of duplicating the handle teardown.

- [ ] **Step 4: Run the realtime test file and the messaging suite**

Run:

```bash
flutter test test/data/messaging/supabase_message_realtime_api_impl_test.dart
flutter test test/features/messaging
```

Expected: PASS, including the pre-existing reconnect test.

- [ ] **Step 5: Stage and report (no commit)**

Report the call sequence for the switch test (`['thread-a','thread-b']` exactly), the old-insert drop, and the last-listener close count.

---

### Task 7: Bound the live transcript (F7)

**Files:**
- Modify: `lib/features/messaging/presentation/message_thread_detail_cubit.dart:129-147`
- Test: `test/features/messaging/message_thread_detail_cubit_test.dart`

- [ ] **Step 1: Write the failing cap test**

Add to `test/features/messaging/message_thread_detail_cubit_test.dart` using the
existing `_StubMessageGateway` (its constructor accepts a `results` queue and
its `live` controller drives inserts):

```dart
test('live inserts retain at most 200 messages', () async {
  final _StubMessageGateway stub = _StubMessageGateway(
    results: <Result<List<Message>>>[
      Result<List<Message>>.success(
        List<Message>.generate(
          200,
          (int i) => Message(
            id: 'm-$i',
            authorDisplayName: 'A',
            body: 'body-$i',
            sentAt: DateTime.utc(2026, 8, 8).add(Duration(minutes: i)),
          ),
        ),
      ),
    ],
  );
  final MessageThreadDetailCubit cubit = MessageThreadDetailCubit(stub);
  addTearDown(cubit.close);

  await cubit.load('thread-1');
  await cubit.subscribe('thread-1');

  stub.live.add(
    MessageLiveInsert(
      Message(
        id: 'm-new',
        authorDisplayName: 'A',
        body: 'newest',
        sentAt: DateTime.utc(2026, 8, 9),
      ),
    ),
  );
  await Future<void>.delayed(Duration.zero);

  final List<Message> messages =
      (cubit.state.messages as ViewSuccess<List<Message>>).data;
  expect(messages, hasLength(200));
  expect(messages.last.id, 'm-new');
  expect(messages.first.id, 'm-1');
});
```

Run it first.

Expected: FAIL — the list has 201 rows.

- [ ] **Step 2: Implement the cap**

In `message_thread_detail_cubit.dart`:

```dart
  /// The retained live window. The initial read is bounded at 200 rows;
  /// live inserts must not grow the transcript without bound.
  static const int maxRetainedMessages = 200;

  void _appendLive(Message message) {
    if (isClosed) {
      return;
    }
    final ViewState<List<Message>> current = state.messages;
    if (current is! ViewSuccess<List<Message>>) {
      _bufferLive(message);
      return;
    }
    final List<Message> messages = current.data;
    if (messages.any((Message m) => m.id == message.id)) {
      return;
    }
    final List<Message> next = <Message>[...messages, message];
    if (next.length > maxRetainedMessages) {
      next.removeRange(0, next.length - maxRetainedMessages);
    }
    emit(state.copyWith(messages: ViewSuccess<List<Message>>(next)));
  }
```

- [ ] **Step 3: Run the test and the messaging suite**

Run:

```bash
flutter test test/features/messaging/message_thread_detail_cubit_test.dart
flutter test test/features/messaging
```

Expected: PASS.

- [ ] **Step 4: Stage and report (no commit)**

---

### Task 8: Video uses a 360p/15fps profile and pauses media in background (F8)

**Files:**
- Modify: `lib/features/video/presentation/video_call_screen.dart`
- Test: `test/features/video/video_call_screen_test.dart`

- [ ] **Step 1: Write the failing option and lifecycle tests**

Add to `test/features/video/video_call_screen_test.dart`:

```dart
test('the room uses a 360p/15fps adaptive profile', () {
  final RoomOptions options = videoRoomOptions();

  expect(options.adaptiveStream, isTrue);
  expect(options.dynacast, isTrue);
  expect(
    options.defaultCameraCaptureOptions.params,
    VideoParametersPresets.h360_169,
  );
  expect(options.defaultCameraCaptureOptions.maxFrameRate, 15);
  expect(options.defaultVideoPublishOptions.videoEncoding?.maxBitrate, 450000);
  expect(options.defaultVideoPublishOptions.videoEncoding?.maxFramerate, 15);
});
```

Add a lifecycle widget test with a mock local participant:

```dart
testWidgets('backgrounding disables camera and mic, resuming re-enables them', (
  tester,
) async {
  final _MockRoom room = _newRoom();
  final _MockLocalParticipant local = _MockLocalParticipant();
  when(() => local.isCameraEnabled()).thenReturn(true);
  when(() => local.isMicrophoneEnabled()).thenReturn(true);
  when(() => local.setCameraEnabled(any())).thenAnswer((_) async => true);
  when(() => local.setMicrophoneEnabled(any())).thenAnswer((_) async => true);
  when(() => room.localParticipant).thenReturn(local);

  await pumpCall(
    tester,
    roomFactory: () => room,
    connector: (_, _, _) async {},
  );
  await tester.pumpAndSettle();

  // Initial enable from _enableMedia.
  verify(() => local.setCameraEnabled(true)).called(1);
  verify(() => local.setMicrophoneEnabled(true)).called(1);

  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  verify(() => local.setCameraEnabled(false)).called(1);
  verify(() => local.setMicrophoneEnabled(false)).called(1);

  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  // The initial enable + the resume re-enable.
  verify(() => local.setCameraEnabled(true)).called(2);
  verify(() => local.setMicrophoneEnabled(true)).called(2);
});
```

Add `class _MockLocalParticipant extends Mock implements LocalParticipant {}` at the bottom.

Expected before implementation: `videoRoomOptions` is undefined; lifecycle verification fails because the screen has no observer.

- [ ] **Step 2: Implement the room profile**

At the top of `video_call_screen.dart`:

```dart
/// The call profile: 360p at 15fps, with adaptive stream and dynacast so
/// off-screen remote video and unused publisher layers stop consuming
/// bandwidth/CPU (audit 2026-10-27, F8).
RoomOptions videoRoomOptions() => const RoomOptions(
  adaptiveStream: true,
  dynacast: true,
  defaultCameraCaptureOptions: CameraCaptureOptions(
    params: VideoParametersPresets.h360_169,
    maxFrameRate: 15,
  ),
  defaultVideoPublishOptions: VideoPublishOptions(
    videoEncoding: VideoEncoding(maxBitrate: 450000, maxFramerate: 15),
  ),
);

Room _createRoom() => Room(roomOptions: videoRoomOptions());
```

- [ ] **Step 3: Implement the lifecycle pause**

Change the state class:

```dart
class _VideoCallScreenState extends State<VideoCallScreen>
    with WidgetsBindingObserver {
```

In `initState`, add `WidgetsBinding.instance.addObserver(this);`.
In `dispose`, add `WidgetsBinding.instance.removeObserver(this);` before super.

Add:

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final Room? room = _room;
    if (room == null) {
      return;
    }
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_setMedia(room, camera: false, microphone: false));
      case AppLifecycleState.resumed:
        unawaited(_setMedia(room, camera: _cameraOn, microphone: _micOn));
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _setMedia(
    Room room, {
    required bool camera,
    required bool microphone,
  }) async {
    final LocalParticipant? local = room.localParticipant;
    if (local == null) {
      return;
    }
    try {
      await local.setCameraEnabled(camera);
      await local.setMicrophoneEnabled(microphone);
    } on Object {
      // The room may already be tearing down; never surface a lifecycle
      // failure as a call failure.
    }
  }
```

Do not change `_cameraOn` / `_micOn` on pause; they represent user intent.

- [ ] **Step 4: Run the video test file**

Run: `flutter test test/features/video/video_call_screen_test.dart`

Expected: PASS, including all pre-existing pre-connect/teardown tests.

- [ ] **Step 5: Stage and report (no commit)**

Report: room profile values, pause/resume verification counts, and the measured diff.

---

### Task 9: Upload precheck, size-aware timeout, and orphan cleanup (F9)

**Files:**
- Modify: `lib/features/storage/domain/file_picker.dart`
- Modify: `lib/features/storage/domain/storage_gateway.dart`
- Modify: `lib/data/files/file_selector_file_picker.dart`
- Modify: `lib/features/storage/presentation/file_transfer_cubit.dart`
- Modify: `lib/data/storage/supabase_storage_api_impl.dart`
- Modify: `lib/data/storage/supabase_storage_gateway.dart`
- Test: `test/features/storage/file_transfer_cubit_test.dart`
- Test: `test/features/storage/storage_gateway_test.dart`
- Test: `test/data/storage/supabase_storage_gateway_test.dart`

- [ ] **Step 1: Write the failing picker-size test**

In `test/features/storage/file_transfer_cubit_test.dart`, add:

```dart
blocTest<FileTransferCubit, FileTransferState>(
  'the picker can reject an oversize file before reading bytes',
  build: () => FileTransferCubit(gateway, _TooLargePicker(), opener),
  act: (FileTransferCubit cubit) => cubit.pickAndUpload('m-1'),
  expect: () => <FileTransferState>[
    const FileTransferState.failure(
      AppError(
        code: 'file_upload_too_large',
        userMessage: 'This file is too large.',
      ),
    ),
  ],
  verify: (_) => expect(gateway.uploads, isEmpty),
);
```

Add:

```dart
class _TooLargePicker implements FilePicker {
  @override
  Future<PickedFile?> pickFile() async => throw const FileTooLargeException();
}
```

Expected: FAIL — `FileTooLargeException` is undefined / not caught.

- [ ] **Step 2: Add the typed exception**

In `file_picker.dart`:

```dart
/// The picked file exceeds the bucket cap. The picker raises this before
/// reading bytes so a huge file is never allocated just to be rejected.
class FileTooLargeException implements Exception {
  const FileTooLargeException();

  @override
  String toString() => 'FileTooLargeException';
}
```

- [ ] **Step 3: Check length before reading**

In `file_selector_file_picker.dart`:

```dart
      final int length = await file.length();
      if (length < 0 || length > matterFileMaxBytes) {
        throw const FileTooLargeException();
      }
      final Uint8List bytes = await file.readAsBytes();
```

Import `storage_gateway.dart` for `matterFileMaxBytes`.

- [ ] **Step 4: Map the exception in the cubit**

In `file_transfer_cubit.dart`, add before the generic picker catch:

```dart
    } on FileTooLargeException {
      if (!isClosed) {
        emit(
          const FileTransferState.failure(
            AppError(
              code: 'file_upload_too_large',
              userMessage: 'This file is too large.',
            ),
          ),
        );
      }
```

- [ ] **Step 5: Add the size-aware timeout helper**

In `storage_gateway.dart`:

```dart
/// Upload deadline: 30s base plus one second per 128 KiB of payload.
/// 25 MiB → 230s, enough for a ~1 Mbps uplink without hanging forever.
const Duration kUploadTimeoutBase = Duration(seconds: 30);
const int kUploadBytesPerTimeoutSecond = 128 * 1024;

Duration uploadTimeoutForBytes(int bytes) {
  final int payloadSeconds = bytes <= 0
      ? 0
      : (bytes + kUploadBytesPerTimeoutSecond - 1) ~/
            kUploadBytesPerTimeoutSecond;
  return kUploadTimeoutBase + Duration(seconds: payloadSeconds);
}
```

Add to `test/features/storage/storage_gateway_test.dart`:

```dart
test('uploadTimeoutForBytes scales with payload size', () {
  expect(uploadTimeoutForBytes(0), const Duration(seconds: 30));
  expect(
    uploadTimeoutForBytes(25 * 1024 * 1024),
    const Duration(seconds: 230),
  );
});
```

- [ ] **Step 6: Use the helper and set the cleanup path before upload**

In `supabase_storage_api_impl.dart` `_boundUpload`:

```dart
    final Duration timeout = uploadTimeoutForBytes(bytes.length);
    await Supabase.instance.client.storage
        .from('matter-files')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        )
        .timeout(timeout);
```

In `supabase_storage_gateway.dart`, move `uploadedPath = path;` **before** `await _api.uploadObject(path, bytes, mimeType);` so a timeout still cleans up an object that landed late.

- [ ] **Step 7: Add the orphan-cleanup test**

In `test/data/storage/supabase_storage_gateway_test.dart`, add a test where the injected `uploadObject` throws `SupabaseStorageException(providerUnavailable)` and assert `removeObject` was called with the same path passed to upload. Use the existing test's stub fields; capture the upload path and the removed path.

- [ ] **Step 8: Run the storage tests**

Run:

```bash
flutter test test/features/storage/file_transfer_cubit_test.dart
flutter test test/features/storage/storage_gateway_test.dart
flutter test test/data/storage/supabase_storage_gateway_test.dart
flutter test test/data/storage/supabase_storage_api_impl_test.dart
```

Expected: PASS.

- [ ] **Step 9: Stage and report (no commit)**

Report the timeout values for 0 and 25 MiB, and the verified cleanup path.

---

### Task 10: Reuse the attorney directory across searches (F10)

**Files:**
- Modify: `lib/features/search/presentation/search_cubit.dart`
- Test: `test/features/search/search_cubit_test.dart`

- [ ] **Step 1: Write the failing cache test**

Add:

```dart
test('reuses the attorney directory across searches', () async {
  final SearchCubit cubit = build();
  addTearDown(cubit.close);

  await cubit.search('Demo');
  await cubit.search('Beta');

  expect(attorneys.calls, 1);
});
```

Expected: FAIL — `attorneys.calls` is 2.

- [ ] **Step 2: Implement the cache**

Add a field:

```dart
  List<Attorney>? _attorneyCache;
```

In `search`, replace the fourth element of the record `.wait`:

```dart
    final Future<Result<List<Attorney>>> attorneyFuture = _attorneyCache != null
        ? Future<Result<List<Attorney>>>.value(
            Result<List<Attorney>>.success(_attorneyCache!),
          )
        : _attorneyGateway.fetchAttorneys();
```

Use `attorneyFuture` in the record:

```dart
    ) = await (
      _matterGateway.searchMatters(trimmed, limit: effectiveLimit),
      _documentGateway.searchDocuments(trimmed, limit: effectiveLimit),
      _messageGateway.searchThreads(trimmed, limit: effectiveLimit),
      attorneyFuture,
    ).wait;
```

After the `attorneys` switch, cache a successful value:

```dart
      case Success<List<Attorney>>(value: final List<Attorney> value):
        _attorneyCache = value;
        attorneyRows = value
            .where((Attorney a) => _attorneyMatches(a, needle, l10n))
            .take(effectiveLimit)
            .toList(growable: false);
```

- [ ] **Step 3: Run the search tests**

Run: `flutter test test/features/search/search_cubit_test.dart test/features/search/search_screen_test.dart`

Expected: PASS; the existing blank-query test still asserts zero attorney calls.

- [ ] **Step 4: Stage and report (no commit)**

Report the call count before/after (2 → 1) and note that the two list reads still run per query.

---

### Task 11: Preview rows in matter sections (F11)

**Files:**
- Modify: `lib/shared/widgets/workspace_section.dart`
- Modify: `lib/features/matters/presentation/matter_documents_section.dart`
- Modify: `lib/features/matters/presentation/matter_invoices_section.dart`
- Modify: `lib/features/matters/presentation/matter_files_section.dart`
- Modify: `lib/features/matters/presentation/matter_messages_section.dart`
- Test: `test/shared/widgets/workspace_section_test.dart`

- [ ] **Step 1: Write the failing preview test**

In `test/shared/widgets/workspace_section_test.dart`, update the helper to pass the new parameters, and add:

```dart
testWidgets('renders a preview and expands on VIEW ALL', (tester) async {
  final List<String> many = List<String>.generate(7, (int i) => 'Row $i');

  await tester.pumpWidget(
    pumpWorkspaceSection(
      state: ViewSuccess<List<String>>(many),
      viewAllCopy: 'VIEW ALL',
    ),
  );

  expect(find.byType(AppTile), findsNWidgets(5));
  expect(find.text('VIEW ALL'), findsOneWidget);

  await tester.tap(find.text('VIEW ALL'));
  await tester.pump();

  expect(find.byType(AppTile), findsNWidgets(7));
  expect(find.text('VIEW ALL'), findsNothing);
});
```

Expected: FAIL — the widget renders all 7 and has no `viewAllCopy`.

- [ ] **Step 2: Convert `WorkspaceSection` to a stateful preview shell**

Change `class WorkspaceSection<T> extends StatelessWidget` to `StatefulWidget` and use this constructor/state shape:

```dart
class WorkspaceSection<T> extends StatefulWidget {
  const WorkspaceSection({
    required this.state,
    required this.onRetry,
    required this.errorCopy,
    required this.emptyCopy,
    required this.itemBuilder,
    required this.viewAllCopy,
    this.previewCount = 5,
    super.key,
  });

  final ViewState<List<T>> state;
  final VoidCallback onRetry;
  final String errorCopy;
  final String emptyCopy;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String viewAllCopy;
  final int previewCount;

  @override
  State<WorkspaceSection<T>> createState() => _WorkspaceSectionState<T>();
}
```

State:

```dart
class _WorkspaceSectionState<T> extends State<WorkspaceSection<T>> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return ViewStateSwitch<List<T>>(
      state: widget.state,
      onRetry: widget.onRetry,
      builder: (BuildContext context, List<T> items) => _rows(context, items),
      empty: _empty(text, scheme),
      errorCopy: widget.errorCopy,
      loadingPadding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
      errorPadding: EdgeInsets.zero,
      errorTextStyle: text.bodySmall?.copyWith(color: scheme.error),
    );
  }

  Widget _rows(BuildContext context, List<T> items) {
    final List<T> visible = _expanded || items.length <= widget.previewCount
        ? items
        : items.take(widget.previewCount).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final T item in visible) ...<Widget>[
          widget.itemBuilder(context, item),
          const SizedBox(height: LegalHubTheme.spaceSm),
        ],
        if (!_expanded && items.length > widget.previewCount)
          TextButton(
            onPressed: () => setState(() => _expanded = true),
            child: Text(widget.viewAllCopy),
          ),
      ],
    );
  }

  Widget _empty(TextTheme text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceXs),
      child: Text(
        widget.emptyCopy,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
```

Preserve the existing `ViewStateSwitch` arm configuration exactly.

- [ ] **Step 3: Pass the localized label at all four call sites**

In each section's `WorkspaceSection<...>(` add `viewAllCopy: l10n.viewAll,`. The files already have `final AppLocalizations l10n`.

- [ ] **Step 4: Run the workspace and matter tests**

Run:

```bash
flutter test test/shared/widgets/workspace_section_test.dart
flutter test test/features/matters
```

Expected: PASS. The existing 3-item test still shows all 3.

- [ ] **Step 5: Stage and report (no commit)**

Report the default details-page cost: 4 sections × 5 preview rows = 20 rows instead of up to 800.

---

### Task 12: Auth API singleton, dev recovery scheme, Join gate (F14, F15, F16)

**Files:**
- Modify: `lib/data/auth/supabase_auth_api_impl.dart`
- Modify: `lib/app/service_locator_auth.dart`
- Create: `lib/features/video/presentation/join_gate.dart`
- Modify: `lib/features/video/presentation/video_consultation_screen.dart`
- Test: `test/data/auth/supabase_auth_api_impl_test.dart`
- Test: `test/service_locator_test.dart`
- Test: `test/features/video/join_gate_test.dart` (create)

- [ ] **Step 1: Write the failing recovery-scheme test**

In `test/data/auth/supabase_auth_api_impl_test.dart`, add:

```dart
test('uses the injected recovery deep link scheme', () async {
  final SupabaseAuthApiImpl devApi = SupabaseAuthApiImpl(
    client,
    recoveryDeepLinkUri: 'com.legalhub.app.dev://auth/v1/callback',
  );
  addTearDown(devApi.dispose);
  when(
    () => client.signInWithOtp(
      email: any(named: 'email'),
      shouldCreateUser: any(named: 'shouldCreateUser'),
      emailRedirectTo: any(named: 'emailRedirectTo'),
    ),
  ).thenAnswer((_) async => AuthResponse(session: null));

  await devApi.resetPasswordForEmail('amira@example.com');

  verify(
    () => client.signInWithOtp(
      email: 'amira@example.com',
      shouldCreateUser: false,
      emailRedirectTo: 'com.legalhub.app.dev://auth/v1/callback',
    ),
  ).called(1);
});
```

Expected: FAIL — the constructor has no named parameter.

- [ ] **Step 2: Implement the injectable recovery URI**

```dart
  SupabaseAuthApiImpl(
    this._client, {
    String recoveryDeepLinkUri = 'com.legalhub.app://auth/v1/callback',
  }) : _recoveryDeepLinkUri = recoveryDeepLinkUri {
    _subscription = _client.onAuthStateChange.listen((AuthState state) {
      // existing body
    });
  }

  final String _recoveryDeepLinkUri;
```

Remove the static const `_recoveryDeepLinkUri`. Change the factory:

```dart
  factory SupabaseAuthApiImpl.bind({String? recoveryDeepLinkUri}) {
    final SupabaseAuthApiImpl api = SupabaseAuthApiImpl(
      Supabase.instance.client.auth,
      recoveryDeepLinkUri:
          recoveryDeepLinkUri ?? 'com.legalhub.app://auth/v1/callback',
    );
    AuthCallbackObserver.ensureStarted();
    return api;
  }
```

- [ ] **Step 3: Share one auth API instance and pass the build scheme**

In `service_locator_auth.dart`, inside `_registerAuthSeams`:

```dart
  final String recoveryUri = AuthCallbackUri.callbackUriFor(
    AppConfig.fromEnvironment().deepLinkScheme,
  );
  final SupabaseAuthApi Function() apiFactory =
      supabaseAuthApiFactory ??
      () => SupabaseAuthApiImpl.bind(recoveryDeepLinkUri: recoveryUri);
  SupabaseAuthApi? sharedApi;
  SupabaseAuthApi api() => sharedApi ??= apiFactory();
```

Replace the three `(supabaseAuthApiFactory ?? SupabaseAuthApiImpl.bind)()` calls with `api()`. Keep the existing AuthGateway dispose callback; it disposes the shared API once at app shutdown.

- [ ] **Step 4: Add the auth-singleton test**

In `test/service_locator_test.dart`, add:

```dart
test('the three auth seams share one API instance', () {
  int factoryCalls = 0;
  configureDependencies(
    supabaseEnv: SupabaseEnv(
      url: 'https://example.supabase.co',
      anonKey: _anonJwt(),
    ),
    supabaseAuthApiFactory: () {
      factoryCalls += 1;
      return _FakeSupabaseAuthApi();
    },
  );

  serviceLocator<AuthGateway>();
  serviceLocator<PasswordRecoveryGateway>();
  serviceLocator<SignUpGateway>();

  expect(factoryCalls, 1);
});
```

If `_FakeSupabaseAuthApi` is not accessible, use the existing factory helper at the top of the test.

- [ ] **Step 5: Add the JoinGate and its test**

Create `lib/features/video/presentation/join_gate.dart`:

```dart
/// Serializes the Join action. A second tap while the token request is in
/// flight is a no-op instead of a second dialog + call screen.
class JoinGate {
  bool _inFlight = false;

  bool tryBegin() {
    if (_inFlight) {
      return false;
    }
    _inFlight = true;
    return true;
  }

  void end() {
    _inFlight = false;
  }
}
```

Create `test/features/video/join_gate_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/video/presentation/join_gate.dart';

void main() {
  test('admits one join at a time and releases after end', () {
    final JoinGate gate = JoinGate();

    expect(gate.tryBegin(), isTrue);
    expect(gate.tryBegin(), isFalse);

    gate.end();

    expect(gate.tryBegin(), isTrue);
  });
}
```

- [ ] **Step 6: Use the gate and always dismiss the dialog**

In `video_consultation_screen.dart`:

```dart
  final JoinGate _joinGate = JoinGate();

  Future<void> _join(VideoSession session) async {
    if (!_joinGate.tryBegin()) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => const _JoinProgressDialog(),
      ),
    );
    Result<VideoToken>? result;
    try {
      result = await _cubit.fetchToken(session.id);
    } finally {
      _joinGate.end();
      // The progress dialog belongs to the root navigator; close it even
      // when the token call throws or the list route unmounts.
      if (navigator.mounted) {
        navigator.pop();
      }
    }
    if (!mounted || result == null) {
      return;
    }
    switch (result) {
      case Success<VideoToken>(value: final VideoToken token):
        // existing push + reload
      case Failure<VideoToken>(error: final AppError error):
        await _showJoinError(error);
    }
  }
```

Remove the old `navigator.pop()` that ran before the switch.

- [ ] **Step 7: Run the auth, locator, and video tests**

Run:

```bash
flutter test test/data/auth/supabase_auth_api_impl_test.dart
flutter test test/service_locator_test.dart
flutter test test/features/video/join_gate_test.dart
flutter test test/features/video
```

Expected: PASS. The auth redirect test still asserts the production scheme; the dev-scheme test asserts the injected one.

- [ ] **Step 8: Stage and report (no commit)**

Report: factory call count, dev redirect URI, and JoinGate admit/reject sequence.

---

### Task 13: Remove the dead italic font and measure the release artifact (F17)

**Files:**
- Modify: `pubspec.yaml:49-60`
- Delete: `assets/fonts/noto_sans/NotoSans-Italic-Variable.ttf`

- [ ] **Step 1: Prove the font is unused**

Run:

```bash
rg -n -i "italic" lib test
```

Expected: **no output**. The only repo hit is the pubspec entry. If any Dart hit appears, STOP and report it; do not delete the asset.

- [ ] **Step 2: Remove the pubspec entry**

Delete these two lines:

```yaml
        - asset: assets/fonts/noto_sans/NotoSans-Italic-Variable.ttf
          style: italic
```

- [ ] **Step 3: Delete the file**

```bash
git rm assets/fonts/noto_sans/NotoSans-Italic-Variable.ttf
```

(If the owner has not approved a commit window, use `rm` and stage later; `git rm` also stages. Either is acceptable; report the exact command used.)

- [ ] **Step 4: Run the gates and measure**

Run:

```bash
flutter analyze --no-pub
flutter test
```

Expected: analyze 0, full suite green.

Then build a non-shipping release AAB for measurement only (owner GO required for the build command; it is not a store upload). The build script's debug-signing opt-in is an environment variable, not a Gradle `-P` flag:

```powershell
$env:ALLOW_DEBUG_SIGNING = 'true'
flutter build appbundle --release --flavor production -t lib/main_production.dart
```

Record the AAB byte size and compare with the pre-change release artifact if one exists. If no release artifact exists, record "no baseline; measured post-change only" and do not claim a size delta.

- [ ] **Step 5: Stage and report (no commit)**

Report: unused proof, file size removed (2,322,640 bytes raw / ~1.37 MB compressed), and the measured AAB size or the missing-baseline note.

---

### Task 14: Final gates, ledger, and handoff

**Files:**
- Modify: `README.md` only if the tracked test count is stale.

- [ ] **Step 1: Run the full gates from the worktree root**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test
bash scripts/verify_ledger.sh
```

Record exact outputs and exit codes. All four must be green.

**Windows line-ending note:** this checkout has `core.autocrlf=true`. If
`bash scripts/verify_ledger.sh` fails with `set: -`, `$'\r': command not found`,
or `syntax error near unexpected token`, run a temporary LF-normalized copy and
execute that (do not commit the normalized copy). This is the known
`verify_policy_tests.sh` failure mode recorded in the project contract.

- [ ] **Step 2: Reconcile the README test count**

If `verify_ledger.sh` reports a stale count, update the README number to the exact `flutter test` total and re-run the ledger gate. Do not change any other README claim.

- [ ] **Step 3: Verify no unintended files**

```bash
git status --porcelain
git diff --stat
```

Confirm only the files owned by the executed tasks are modified; no generated l10n, no `.env`, no secrets, no build artifacts staged.

- [ ] **Step 4: Produce the handoff report**

Include:

```text
HEAD=<sha> BRANCH=<name> UNPUSHED=<count>
analyze=<0 issues> tests=<passed>/<total> format=<0 changed> ledger=<PASS>
Tasks: T1..T13 status
Deferred: <owner-decision list>
Known residual risks: <e.g. no runtime profiling, release AAB is debug-signed compile proof>
```

- [ ] **Step 5: Stop. Do not commit or push.**

The owner opens the commit window and push window separately.

---

## Deferred — Owner Decisions (do not implement in this plan)

| Item | Why deferred | Safe next step |
|---|---|---|
| Keep-screen-on during calls | Requires a new dependency (`wakelock_plus`) or a platform channel; the project contract prefers no new dependencies without owner approval | Owner approves dependency, then add a small task |
| Auto-leave when the last remote participant disconnects | Product/UX decision (1:1 vs group behavior; `canEnd` may end the session) | Owner defines the rule, then add a tested task |
| Font axis trimming / Latin subset | Binary font surgery risks missing glyphs for user-generated content; the dead italic deletion is the safe win | Build a font QA checklist and measure on a device first |
| Drop the Turkish locale | Product decision; complete translation exists and the size saving is small | Owner decides; no code change now |
| Remove LiveKit/WebRTC | Product feature decision; 11.72 MB arm64 native payload | Separate feature-retirement plan |
| Platform-admin audit lazy flatten | Admin-only, server-capped at 200-500 rows, low user impact; flat-index refactor risk is higher than the gain | Revisit if the admin surface ships to real tenants |
| Settings screen whole-cubit watches | 20-child form; rebuild cost is small; correct fix needs `context.select` and a keyed dropdown | Low-priority UI hygiene batch |
| `AppLinkListener` / `RouterRefreshStream` disposal | App-lifetime singletons; no practical leak for a single bootstrap | Fold into an app-root lifecycle refactor |
| Live payment polling while backgrounded | Needs lifecycle coordination with an in-flight payment; current timer is cancelled on close | Owner-approved billing UX task |
| Route role projections using `primaryRole` | Navigation-hint only; server remains authoritative | Separate correctness task with explicit role matrix |

---

## Self-Review (completed before saving)

- **Spec coverage:** F1→T1, F2→T2, F3→T3, F4/F5→T4, F12/F13→T5, F6→T6, F7→T7, F8→T8, F9→T9, F10→T10, F11→T11, F14/F15/F16→T12, F17→T13, F18→Deferred with rationale.
- **Placeholder scan:** no TBD/TODO; every production step shows the code or the exact replacement; every test step shows the test body or the exact new file.
- **Type consistency:** `restore({bool hydrateMemberships = true})`, `videoRoomOptions()`, `uploadTimeoutForBytes(int)`, `JoinGate.tryBegin/end`, `viewAllCopy`, and `SupabaseAuthApiImpl(recoveryDeepLinkUri:)` are used consistently across tasks.
- **Dirty-tree control:** the start gate blocks execution until the owner resolves the in-flight refactor; line anchors are explicitly re-checked if HEAD moves.
