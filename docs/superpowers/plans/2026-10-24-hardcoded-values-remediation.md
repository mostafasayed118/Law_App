# Hardcoded Values Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collect every hardcoded value in LegalHub, move it to a semantic canonical home, and fix the six correctness issues the census found — without changing any other behavior.

**Architecture:** Layered constant homes (theme/motion, core contracts, data wire names, error message keys, demo corpus) plus wave-scoped mechanical replacement. No junk drawer; component-only values become `static const` in their owning widget.

**Tech Stack:** Flutter 3.44.4 (CI pin), Dart 3.x, `flutter_test`, generated `flutter gen-l10n`, GetIt, GoRouter, Supabase Flutter.

**Spec:** `docs/superpowers/specs/2026-10-24-hardcoded-values-design.md`

## Global Constraints

- **No commit and no push without explicit owner GO.** The "Commit" step in the standard template is replaced by "stage + gate". Stage new files with explicit `git add <path>` so count/ledger scripts can see them; never `git add .`.
- Work happens in `C:\flutter_projects\law_app_hardcoded` on branch `refactor/hardcoded-values`. All paths below are relative to that worktree.
- `flutter analyze` must report zero errors after every task.
- Full `flutter test` must stay green at every wave boundary. Never weaken an assertion to get green; update imports/expectations only.
- Format gate: `dart format --output=none --set-exit-if-changed <touched files>`.
- Do not hand-edit `lib/l10n/app_localizations*.dart`; run `flutter gen-l10n`.
- Never print or commit secret values. `.env` files are untracked; only touch `.env*.example`.
- Flutter pin is CI's `3.44.4`; do not change `pubspec.yaml` constraints.
- Each task lists its exact files. An executor must not edit files outside its task's list without a STOP report.

---

## Phase 0 — Setup and inventory

### Task 1: Isolated worktree and green baseline

**Files:**
- Create: `..\law_app_hardcoded` (worktree), `docs/hardcoded_values_baseline_2026-10-24.md`
- Read: `pubspec.yaml`, `README.md`

**Interfaces:**
- Produces: baseline HEAD SHA, baseline test count, baseline analyze result consumed by Task 28.

- [ ] **Step 1: Verify the main tree and create the worktree**

```powershell
cd C:\flutter_projects\law_app
git status --porcelain
git rev-parse HEAD
git worktree add C:\flutter_projects\law_app_hardcoded -b refactor/hardcoded-values
```

Expected: porcelain shows only the spec and plan files (untracked). HEAD recorded. Worktree created.

- [ ] **Step 2: Install and capture the analyzer baseline**

```powershell
cd C:\flutter_projects\law_app_hardcoded
flutter pub get
flutter analyze 2>&1 | Tee-Object baseline_analyze.log
```

Expected: `No issues found!`. If not, STOP and report.

- [ ] **Step 3: Capture the full test baseline and count**

```powershell
flutter test --reporter expanded 2>&1 | Tee-Object baseline_test.log
Select-String -Path baseline_test.log -Pattern '\+(\d+)' | Select-Object -Last 1
```

Expected: `All tests passed!` and a final `+N`. Record `N`; this is the baseline, not the README's 1924 claim.

- [ ] **Step 4: Write the baseline record**

Create `docs/hardcoded_values_baseline_2026-10-24.md` with HEAD, branch, analyze result, final `+N`, and any skipped tests.

- [ ] **Step 5: Stage and report**

```powershell
git add docs/hardcoded_values_baseline_2026-10-24.md
git status --porcelain
```

No commit.

---

### Task 2: Complete hardcoded-value inventory

**Files:**
- Create: `tool/hardcoded_inventory.dart`, `docs/hardcoded_values_inventory_2026-10-24.md`
- Read: `lib/app/legalhub_theme.dart`, `lib/app/legalhub_text_theme.dart`, `lib/data/list_query_guards.dart`

**Interfaces:**
- Produces: a complete ledger consumed by every later task and reconciled in Task 28.

- [ ] **Step 1: Write the inventory tool**

```dart
import 'dart:io';

class Rule {
  const Rule(this.name, this.pattern, {this.exempt = const <String>{}});
  final String name;
  final RegExp pattern;
  final Set<String> exempt;
}

const List<Rule> rules = <Rule>[
  Rule('raw-color', RegExp(r'Color\(0x[0-9A-Fa-f]{6,8}\)'),
      exempt: <String>{'lib/app/legalhub_theme.dart'}),
  Rule('material-color', RegExp(r'Colors\.[a-zA-Z]+')),
  Rule('motion-200-300ms', RegExp(r'Duration\(milliseconds:\s*(200|300)\)'),
      exempt: <String>{'lib/app/legalhub_motion.dart'}),
  Rule('timeout-15s', RegExp(r'Duration\(seconds:\s*15\)'),
      exempt: <String>{'lib/core/contracts/network.dart'}),
  Rule('table-from', RegExp(r"from\('([a-z_]+)'\)")),
  Rule('rpc-call', RegExp(r"rpc(?:<[^>]+>)?\('([a-z_]+)'")),
  Rule('edge-invoke', RegExp(r"invoke\('([a-z0-9-]+)'")),
  Rule('max-length', RegExp(r'maxLength:\s*(\d+)')),
  Rule('duration-seconds', RegExp(r'Duration\(seconds:\s*(\d+)\)')),
  Rule('raw-font-size', RegExp(r'fontSize:\s*(\d+)')),
];

void main() {
  final List<File> files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .where((File f) => !f.path.contains('app_localizations'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  print('| rule | file:line | literal |');
  print('|---|---|---|');
  for (final File file in files) {
    final String relative = file.path.replaceAll('\\', '/');
    final List<String> lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      for (final Rule rule in rules) {
        if (rule.exempt.contains(relative)) {
          continue;
        }
        final RegExpMatch? match = rule.pattern.firstMatch(lines[i]);
        if (match != null) {
          final String literal = match.group(0)!.replaceAll('|', r'\|');
          print('| ${rule.name} | $relative:${i + 1} | `$literal` |');
        }
      }
    }
  }
}
```

- [ ] **Step 2: Run it and write the ledger**

```powershell
dart run tool/hardcoded_inventory.dart > docs/hardcoded_values_inventory_2026-10-24.md
(Get-Content docs/hardcoded_values_inventory_2026-10-24.md | Measure-Object -Line).Lines
```

Expected: at least 700 rows. Append a header and four columns (`verdict`, `wave`, `status`) to the generated table; fill every row with `extract`, `component-local`, or `leave`.

- [ ] **Step 3: Cross-check the census totals**

Confirm the ledger contains the census anchors: 53 color matches, 24 `Duration(`, 10 table names, 48 RPC names, 3 edge functions, 175 failure-copy occurrences. Any mismatch is recorded as a deviation in the ledger header.

- [ ] **Step 4: Stage and report**

```powershell
git add tool/hardcoded_inventory.dart docs/hardcoded_values_inventory_2026-10-24.md
```

No commit.

---

## Phase 1 — Theme and motion cosmetics

### Task 3: Motion tokens and policy test

**Files:**
- Create: `lib/app/legalhub_motion.dart`, `test/app/legalhub_motion_test.dart`, `test/policy/hardcoded_values_policy_test.dart`
- Modify: `lib/features/onboarding/presentation/onboarding_screen.dart:128,132,178,179`, `lib/features/search/presentation/search_surface.dart:44`, `lib/features/discovery/presentation/discovery_cubit.dart:27`

**Interfaces:**
- Produces: `LegalHubMotion.durationFast`, `.durationBase`, `.debounce`, `.curveStandard`; policy test reused by later waves.

- [ ] **Step 1: Write the failing token test**

```dart
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_motion.dart';

void main() {
  test('motion tokens are the approved values', () {
    expect(LegalHubMotion.durationFast, const Duration(milliseconds: 200));
    expect(LegalHubMotion.durationBase, const Duration(milliseconds: 300));
    expect(LegalHubMotion.debounce, const Duration(milliseconds: 300));
    expect(LegalHubMotion.curveStandard, Curves.easeOut);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/app/legalhub_motion_test.dart`
Expected: FAIL — `legalhub_motion.dart` not found.

- [ ] **Step 3: Implement the tokens**

```dart
import 'package:flutter/animation.dart';

/// Approved UI motion values. Network timeouts and fixture delays do not
/// belong here.
abstract final class LegalHubMotion {
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationBase = Duration(milliseconds: 300);
  static const Duration debounce = Duration(milliseconds: 300);
  static const Curve curveStandard = Curves.easeOut;
}
```

- [ ] **Step 4: Replace the UI literals**

Run: `rg -n "Duration\(milliseconds: (200|300)\)|Curves\.easeOut" lib/features`
Replace each UI site in the listed files with `LegalHubMotion.*`. Leave network timeouts and fixture delays untouched.

- [ ] **Step 5: Write the policy test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no raw UI motion literals outside the motion token file', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (path.endsWith('legalhub_motion.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'Duration\(milliseconds:\s*(200|300)\)').hasMatch(lines[i])) {
          offenders.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/app/legalhub_motion_test.dart test/policy/hardcoded_values_policy_test.dart test/features/onboarding test/features/search test/features/discovery`
Expected: PASS.

- [ ] **Step 7: Stage and report**

```powershell
git add lib/app/legalhub_motion.dart test/app/legalhub_motion_test.dart test/policy/hardcoded_values_policy_test.dart
git add lib/features/onboarding/presentation/onboarding_screen.dart lib/features/search/presentation/search_surface.dart lib/features/discovery/presentation/discovery_cubit.dart
```

No commit.

---

### Task 4: Spacing, radius, and component-local dimensions

**Files:**
- Modify: `lib/app/legalhub_theme.dart`, `lib/features/admin/presentation/attorney_admin_tile.dart:53`, `lib/shared/widgets/app_tile.dart:90`, `lib/features/matters/presentation/matter_detail_row.dart:25`, `lib/features/discovery/presentation/attorney_search_tile.dart:53`, `lib/shared/widgets/view_state_message.dart:25,27,29`, `lib/shared/widgets/loading_elevated_button.dart:33`, `lib/features/matters/presentation/matter_link_chip.dart:39,49`, `lib/features/video/presentation/video_call_screen.dart:461,498,499`, `lib/features/notifications/presentation/notification_feed_screen.dart:106`, `lib/shared/widgets/label_chip.dart:46`, `lib/shared/widgets/social_button.dart:28`, `lib/features/onboarding/presentation/onboarding_screen.dart:109`
- Modify for component constants: `attorney_profile_surface.dart` (avatar 40), `otp_field_row.dart` (56), `onboarding_screen.dart` (240), home card files (160x192, maxWidths 520/360/320)

**Interfaces:**
- Consumes: existing `LegalHubTheme.space*`/`radius*`.
- Produces: `LegalHubTheme.space2xs = 2`, `LegalHubTheme.radius2xl = 24`.

- [ ] **Step 1: Read the token block and record exact values**

Read `lib/app/legalhub_theme.dart` lines containing `static const double space` and `radius`. Record the exact mapping in the task log before editing.

- [ ] **Step 2: Add the two missing tokens**

```dart
static const double space2xs = 2;
static const double radius2xl = 24;
```

- [ ] **Step 3: Replace exact-match one-offs**

Map `2 → space2xs` (only where the dimension is spacing/padding), `4 → spaceXs`, `8 → spaceSm`, `12 → spaceMd`, `6 → radiusMd`, `8-radius → radiusLg`, `12-radius → radiusXl`, `24-radius → radius2xl`. Do not change a value that is not an exact semantic match.

- [ ] **Step 4: Name component-only dimensions**

In each owning widget add `static const double _avatarSize = 40;` (etc.) and use it. Do not promote these to global tokens.

- [ ] **Step 5: Verify no visual change**

Run: `flutter test test/features/onboarding test/features/video test/features/notifications test/shared`
Expected: PASS. If any widget/golden test changes, revert that specific swap instead of updating the expectation.

- [ ] **Step 6: Stage and report**

```powershell
git add lib/app/legalhub_theme.dart
git add lib/features lib/shared
```

No commit.

---

### Task 5: Conditional section-header dedupe

**Files:**
- Modify: `lib/features/matters/presentation/matter_details_surface.dart:109`
- Test: `test/features/matters/matter_details_screen_test.dart`

**Interfaces:**
- Consumes: `AppSectionHeader` from `lib/shared/widgets/app_section_header.dart`.

- [ ] **Step 1: Compare the local style with `AppSectionHeader`**

Read `matter_details_surface.dart:109` and `app_section_header.dart:46`. If padding, spacing, or semantics differ, STOP and keep the local style with a `static const` name.

- [ ] **Step 2: If pixel-equivalent, replace the four call sites**

Replace `text.titleSmall?.copyWith(fontWeight: FontWeight.w700)` headers with `AppSectionHeader`.

- [ ] **Step 3: Run the matter tests**

Run: `flutter test test/features/matters/matter_details_screen_test.dart`
Expected: PASS with no assertion updates.

- [ ] **Step 4: Stage or record the skip**

If skipped, record the reason in the inventory ledger. Otherwise stage the file.

No commit.

---

## Phase 2 — Config and wire names

### Task 6: Supabase tables and storage bucket constants

**Files:**
- Create: `lib/data/supabase_wire.dart`, `test/data/supabase_wire_test.dart`
- Modify: 19 table call sites and 3 bucket sites listed in the census (`lib/data/**` and `lib/features/**`)

**Interfaces:**
- Produces: `SupabaseTables.matters`, `.documents`, `.files`, `.billingInvoices`, `.messageThreads`, `.messages`, `.notifications`, `.tasks`, `.consultationSlots`, `.memberships`; `SupabaseBuckets.matterFiles`.

- [ ] **Step 1: Write the failing uniqueness test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/supabase_wire.dart';

void main() {
  test('table and bucket names are unique and stable', () {
    const tables = <String>[
      SupabaseTables.matters,
      SupabaseTables.documents,
      SupabaseTables.files,
      SupabaseTables.billingInvoices,
      SupabaseTables.messageThreads,
      SupabaseTables.messages,
      SupabaseTables.notifications,
      SupabaseTables.tasks,
      SupabaseTables.consultationSlots,
      SupabaseTables.memberships,
    ];
    expect(tables.toSet(), hasLength(10));
    expect(SupabaseBuckets.matterFiles, 'matter-files');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/data/supabase_wire_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement the constants**

```dart
/// Runtime table and bucket names. One source; do not duplicate literals.
abstract final class SupabaseTables {
  static const String matters = 'matters';
  static const String documents = 'documents';
  static const String files = 'files';
  static const String billingInvoices = 'billing_invoices';
  static const String messageThreads = 'message_threads';
  static const String messages = 'messages';
  static const String notifications = 'notifications';
  static const String tasks = 'tasks';
  static const String consultationSlots = 'consultation_slots';
  static const String memberships = 'memberships';
}

abstract final class SupabaseBuckets {
  static const String matterFiles = 'matter-files';
}
```

- [ ] **Step 4: Replace the literals**

Run: `rg -n "from\('(matters|documents|files|billing_invoices|message_threads|messages|notifications|tasks|consultation_slots|memberships)'\)" lib`
Replace with `from(SupabaseTables.<name>)`. Repeat for `'matter-files'` with `SupabaseBuckets.matterFiles`, including the realtime schema/table pair (`public`, `messages`).

- [ ] **Step 5: Run data tests**

Run: `flutter test test/data`
Expected: PASS. Address any `.contains('messages')` string assertions by using the constant.

- [ ] **Step 6: Stage and report**

No commit.

---

### Task 7: RPC and edge-function constants

**Files:**
- Modify: `lib/data/supabase_wire.dart`, `test/data/supabase_wire_test.dart`
- Modify: 51 RPC call sites and 3 edge-function sites in `lib/data/**`

**Interfaces:**
- Produces: `SupabaseRpcs` with 48 names; `SupabaseEdgeFunctions.paymobInitiate`, `.videoToken`, `.researchAnalyze`.

- [ ] **Step 1: Add the full RPC list**

```dart
abstract final class SupabaseRpcs {
  // approvals
  static const String listApprovalRequests = 'list_approval_requests';
  static const String createApprovalRequest = 'create_approval_request';
  static const String decideApprovalRequest = 'decide_approval_request';
  static const String cancelApprovalRequest = 'cancel_approval_request';
  // attorney directory
  static const String listAttorneyProfiles = 'list_attorney_profiles';
  static const String getAttorneyProfile = 'get_attorney_profile';
  static const String createAttorneyProfile = 'create_attorney_profile';
  static const String updateAttorneyProfile = 'update_attorney_profile';
  static const String deactivateAttorneyProfile = 'deactivate_attorney_profile';
  // compliance
  static const String listComplianceAlerts = 'list_compliance_alerts';
  static const String createComplianceAlert = 'create_compliance_alert';
  static const String acknowledgeComplianceAlert = 'acknowledge_compliance_alert';
  static const String resolveComplianceAlert = 'resolve_compliance_alert';
  // video
  static const String listVideoSessions = 'list_video_sessions';
  static const String createVideoSession = 'create_video_session';
  static const String markVideoSessionLive = 'mark_video_session_live';
  static const String endVideoSession = 'end_video_session';
  // billing
  static const String getInvoicePaymentStatus = 'get_invoice_payment_status';
  // admin
  static const String listOrganizationsMetadata = 'list_organizations_metadata';
  static const String listMembersMetadata = 'list_members_metadata';
  static const String suspendMembershipPlatform = 'suspend_membership_platform';
  static const String reactivateMembershipPlatform = 'reactivate_membership_platform';
  static const String deleteDemoAccount = 'delete_demo_account';
  static const String readPlatformAudit = 'read_platform_audit';
  // organizations
  static const String createOrganization = 'create_organization';
  static const String listOrgMembersMetadata = 'list_org_members_metadata';
  static const String listMatterAssignableMembers = 'list_matter_assignable_members';
  static const String inviteMember = 'invite_member';
  static const String changeMemberRole = 'change_member_role';
  static const String suspendMembership = 'suspend_membership';
  static const String reactivateMembership = 'reactivate_membership';
  static const String removeMembership = 'remove_membership';
  static const String resendInvitation = 'resend_invitation';
  static const String revokeInvitation = 'revoke_invitation';
  static const String deleteMyAccount = 'delete_my_account';
  static const String acceptInvitation = 'accept_invitation';
  static const String readOrgAudit = 'read_org_audit';
  // matters, messaging, notifications, storage, booking
  static const String createMatter = 'create_matter';
  static const String sendMessage = 'send_message';
  static const String markNotificationsRead = 'mark_notifications_read';
  static const String registerMatterFile = 'register_matter_file';
  static const String bookConsultation = 'book_consultation';
  // research
  static const String listResearchRuns = 'list_research_runs';
  static const String listResearchFindings = 'list_research_findings';
  // tasks
  static const String createTask = 'create_task';
  static const String advanceTaskStatus = 'advance_task_status';
  static const String assignTask = 'assign_task';
  static const String acknowledgeTask = 'acknowledge_task';
}

abstract final class SupabaseEdgeFunctions {
  static const String paymobInitiate = 'paymob-initiate';
  static const String videoToken = 'video-token';
  static const String researchAnalyze = 'research-analyze';
}
```

- [ ] **Step 2: Extend the uniqueness test**

Assert `SupabaseRpcs` has 48 distinct values and the edge functions 3. Add a compile-time `const <String>[...]` list of every constant.

- [ ] **Step 3: Replace call sites**

Run: `rg -n "rpc(?:<[^>]+>)?\('([a-z_]+)'" lib/data`
Replace with `rpc(..., SupabaseRpcs.<name>, ...)`. Repeat for `invoke('...')` with `SupabaseEdgeFunctions.<name>`.

- [ ] **Step 4: Run data tests**

Run: `flutter test test/data`
Expected: PASS.

- [ ] **Step 5: Stage and report**

No commit.

---

### Task 8: One request timeout, including edge functions

**Files:**
- Create: `lib/core/contracts/network.dart`, `lib/core/async/with_timeout.dart`, `test/core/async/with_timeout_test.dart`
- Modify: `lib/data/supabase_seam.dart:41,53`, `lib/data/storage/supabase_storage_api_impl.dart:53,87,94,101`, `lib/data/video/supabase_video_api_impl.dart:41`, `lib/data/billing/supabase_payment_api_impl.dart:24`, `lib/data/research/supabase_research_api_impl.dart:42`

**Interfaces:**
- Produces: `kSupabaseRequestTimeout` and `withRequestTimeout<T>(Future<T>, {Duration timeout})`.

- [ ] **Step 1: Write the failing timeout test**

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/async/with_timeout.dart';

void main() {
  test('a never-completing future times out', () async {
    final future = Completer<void>().future;
    await expectLater(
      withRequestTimeout(future, timeout: const Duration(milliseconds: 10)),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('a completing future returns its value', () async {
    expect(await withRequestTimeout(Future<int>.value(7)), 7);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/async/with_timeout_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement**

```dart
const Duration kSupabaseRequestTimeout = Duration(seconds: 15);
```

```dart
import 'package:legalhub/core/contracts/network.dart';

Future<T> withRequestTimeout<T>(
  Future<T> future, {
  Duration timeout = kSupabaseRequestTimeout,
}) => future.timeout(timeout);
```

- [ ] **Step 4: Replace the seven literals and wrap the three invokes**

In `supabase_seam.dart`, `storage_api_impl`, and the storage gateway, replace `Duration(seconds: 15)` with `kSupabaseRequestTimeout`. In the three `_boundInvoke` helpers, wrap the invoke:

```dart
final FunctionResponse response = await withRequestTimeout(
  Supabase.instance.client.functions.invoke(function, body: body),
);
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/core/async/with_timeout_test.dart test/data`
Expected: PASS.

- [ ] **Step 6: Stage and report**

No commit.

---

### Task 9: Config-aware deep links

**Files:**
- Create: `lib/app/deep_link/deep_link_config.dart`, `test/app/deep_link/deep_link_config_test.dart`
- Modify: `lib/app/deep_link/app_link_parser.dart:55,63,89,104`, `lib/data/auth/auth_callback.dart:23-35,49-53`, `lib/main.dart:93`, `test/app/deep_link/app_link_parser_test.dart`, `test/data/auth/auth_callback_test.dart`

**Interfaces:**
- Produces: `DeepLinkConfig({required String scheme, String verifiedHost})`, `DeepLinkConfig.forConfig(AppConfig)`, `.acceptInviteUri(token)`, `.isAcceptInvite(Uri)`, `.isAuthCallback(Uri)`.

- [ ] **Step 1: Write the failing dev-scheme test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/deep_link/app_link_parser.dart';
import 'package:legalhub/app/deep_link/deep_link_config.dart';

void main() {
  test('dev scheme classifies an accept-invite link', () {
    const config = DeepLinkConfig(scheme: 'com.legalhub.app.dev');
    final parser = AppLinkParser(config: config);
    final intent = parser.parse(config.acceptInviteUri('token-1'));
    expect(intent, isA<AcceptInviteIntent>());
    expect((intent as AcceptInviteIntent).token, 'token-1');
  });

  test('production scheme is unchanged', () {
    const parser = AppLinkParser();
    final intent = parser.parse(
      const DeepLinkConfig.production().acceptInviteUri('t-2'),
    );
    expect(intent, isA<AcceptInviteIntent>());
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/app/deep_link/deep_link_config_test.dart`
Expected: FAIL — file/parameter not found.

- [ ] **Step 3: Implement the config holder**

```dart
import 'package:legalhub/app/flavor.dart';

class DeepLinkConfig {
  const DeepLinkConfig({
    required this.scheme,
    this.verifiedHost = 'legalhub.app',
    this.acceptedSchemes = const <String>{
      'com.legalhub.app',
      'com.legalhub.app.dev',
    },
  });

  const DeepLinkConfig.production()
      : scheme = 'com.legalhub.app',
        verifiedHost = 'legalhub.app',
        acceptedSchemes = const <String>{
          'com.legalhub.app',
          'com.legalhub.app.dev',
        };

  factory DeepLinkConfig.forConfig(AppConfig config) =>
      DeepLinkConfig(scheme: config.deepLinkScheme);

  final String scheme;
  final String verifiedHost;
  final Set<String> acceptedSchemes;

  static const String acceptInviteHost = 'accept-invite';
  static const String authHost = 'auth';
  static const String appCallbackPath = '/v1/callback';
  static const String httpsCallbackPath = '/auth/v1/callback';

  Uri acceptInviteUri(String token) => Uri(
    scheme: scheme,
    host: acceptInviteHost,
    queryParameters: <String, String>{'token': token},
  );
}
```

- [ ] **Step 4: Wire the parser**

Change `AppLinkParser` to `const AppLinkParser({this.config = const DeepLinkConfig.production()})`; use `config.scheme` at the scheme check and `config.acceptInviteUri` for the produce side. Keep a static `productionAcceptInviteUri` only if a call site cannot access an instance.

- [ ] **Step 5: Wire `AuthCallbackUri`**

Add `{DeepLinkConfig config = const DeepLinkConfig.production()}` to `pkceCode` and use `config.acceptedSchemes`, `config.verifiedHost`, `config.authHost`, `config.appCallbackPath`, `config.httpsCallbackPath`. Remove the duplicated private constants.

- [ ] **Step 6: Wire `main.dart`**

```dart
final AppLinkParser(
  config: DeepLinkConfig.forConfig(config),
)
```

- [ ] **Step 7: Update the parser/auth tests and run them**

Update any test that constructs `AppLinkParser.acceptInviteUri` to use `const DeepLinkConfig.production().acceptInviteUri`. Add the dev case.

Run: `flutter test test/app/deep_link test/data/auth/auth_callback_test.dart test/app/flavor_test.dart`
Expected: PASS.

- [ ] **Step 8: Stage and report**

No commit.

---

### Task 10: Env templates and dead config

**Files:**
- Modify: `.env.example`, `.env.development.example`, `.env.production.example`, `lib/app/flavor.dart:107,116,133`, `test/app/flavor_test.dart`

**Interfaces:**
- Consumes: `PAYMENTS_MODE` reader in `lib/data/billing/payment_mode.dart`.
- Produces: documented env template keys.

- [ ] **Step 1: Add `PAYMENTS_MODE` to all three templates**

Add `PAYMENTS_MODE=disabled` with a comment: `disabled|live`.

- [ ] **Step 2: Verify `API_BASE_URL` consumers across lib and test**

Run: `rg -n 'apiBaseUrl|API_BASE_URL' lib test`
If only `flavor.dart` matches, remove the field, the constructor parameter, and the env read. If tests reference it, keep the field and mark it deprecated in a comment; record the decision.

- [ ] **Step 3: Run the flavor tests**

Run: `flutter test test/app/flavor_test.dart test/service_locator_test.dart`
Expected: PASS.

- [ ] **Step 4: Stage and report**

No commit.

---

## Phase 3 — Domain contracts and correctness

### Task 11: Server limits and missing client caps

**Files:**
- Create: `lib/core/contracts/server_limits.dart`, `test/core/contracts/server_limits_test.dart`
- Modify: `lib/features/approvals/presentation/approval_create_sheet.dart:54,55`, `lib/features/approvals/presentation/approval_detail_sheet.dart:211`, `lib/features/compliance/presentation/compliance_alert_create_sheet.dart:52,53`, `lib/features/compliance/presentation/compliance_alert_detail_sheet.dart:191`, `lib/features/admin/presentation/attorney_admin_form.dart:97-121,175`, `lib/features/booking/presentation/booking_topic_field.dart:34`, `lib/features/messaging/presentation/message_thread_detail_cubit.dart:33`, `lib/features/research/domain/research_request.dart:25-26`, `lib/data/research/supabase_research_gateway.dart:132`

**Interfaces:**
- Produces: the seven `k*MaxLength`/`kResearchFindingsMax` constants.

- [ ] **Step 1: Write the failing boundary test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/contracts/server_limits.dart';

void main() {
  test('server limits match the database contract', () {
    expect(kTitleMaxLength, 160);
    expect(kDescriptionMaxLength, 4000);
    expect(kDecisionNoteMaxLength, 2000);
    expect(kAttorneyNameMaxLength, 120);
    expect(kAttorneyBioMaxLength, 2000);
    expect(kBookingTopicMaxLength, 2000);
    expect(kResearchFindingsMax, 12);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/contracts/server_limits_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement and replace**

```dart
/// Values mirrored by the database CHECK constraints and RPC caps.
const int kTitleMaxLength = 160;
const int kDescriptionMaxLength = 4000;
const int kDecisionNoteMaxLength = 2000;
const int kAttorneyNameMaxLength = 120;
const int kAttorneyBioMaxLength = 2000;
const int kBookingTopicMaxLength = 2000;
const int kResearchFindingsMax = 12;
```

Replace the private `_titleMaxLength`/`_descriptionMaxLength` and raw `maxLength:` values. Add the missing 120 cap to the attorney display-name validator and the 2000 cap to the booking topic field. Reuse `ResearchRequest.minQuestionLength`/`maxQuestionLength` instead of the hardcoded copy.

- [ ] **Step 4: Add widget boundary tests**

In `test/features/admin/presentation/attorney_admin_screen_test.dart`, type a 121-character name and assert the validator error. In `test/features/booking/booking_screen_test.dart`, type 2001 characters and assert the cap.

- [ ] **Step 5: Run the feature tests**

Run: `flutter test test/core/contracts test/features/approvals test/features/compliance test/features/admin test/features/booking test/features/messaging test/features/research`
Expected: PASS.

- [ ] **Step 6: Stage and report**

No commit.

---

### Task 12: Pagination constants

**Files:**
- Create: `lib/core/pagination.dart`
- Modify: `lib/data/list_query_guards.dart:13`, 13 `limit = 30` sites in domain gateways/impls/fakes, `lib/features/search/presentation/search_cubit.dart:62`

**Interfaces:**
- Produces: `kSearchPageSize = 30`, `kListRowCap = 200`; `kSupabaseListRowCap` aliases `kListRowCap`.

- [ ] **Step 1: Implement**

```dart
const int kSearchPageSize = 30;
const int kListRowCap = 200;
```

- [ ] **Step 2: Replace duplicates**

In `list_query_guards.dart`: `const int kSupabaseListRowCap = kListRowCap;`. Replace `int limit = 30` and `.take(30)` with `kSearchPageSize`. Point `SearchCubit.searchPageSize` at the same constant.

- [ ] **Step 3: Run the data and search tests**

Run: `flutter test test/data test/features/search`
Expected: PASS.

- [ ] **Step 4: Stage and report**

No commit. Do **not** add `p_offset` or pagination UI.

---

### Task 13: Approval status wire mapper

**Files:**
- Modify: `lib/features/approvals/domain/pending_approval.dart:8` (add `toWire`/`fromWire`), `lib/data/approvals/supabase_approval_gateway.dart:97,178-195`, `test/data/approvals` gateway tests

**Interfaces:**
- Produces: `String approvalStatusToWire(ApprovalStatus)` and `ApprovalStatus approvalStatusFromWire(String)`.

- [ ] **Step 1: Write the failing round-trip test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/approvals/domain/pending_approval.dart';

void main() {
  test('denied maps to rejected on the wire and back', () {
    expect(approvalStatusToWire(ApprovalStatus.denied), 'rejected');
    expect(approvalStatusFromWire('rejected'), ApprovalStatus.denied);
    for (final status in ApprovalStatus.values) {
      expect(approvalStatusFromWire(approvalStatusToWire(status)), status);
    }
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/approvals/approval_status_wire_test.dart`
Expected: FAIL — functions not found.

- [ ] **Step 3: Implement and use**

Move `_serverStatus` into the domain file as `approvalStatusToWire`; add `approvalStatusFromWire`. Replace the gateway's private helper and the raw `approve ? 'approved' : 'rejected'` with `approvalStatusToWire(approve ? ApprovalStatus.approved : ApprovalStatus.denied)`.

- [ ] **Step 4: Run the approval tests**

Run: `flutter test test/features/approvals test/data/approvals`
Expected: PASS.

- [ ] **Step 5: Stage and report**

No commit.

---

### Task 14: SQLSTATE/HTTP constants, research codes, audit outcome

**Files:**
- Modify: `lib/data/postgrest_failures.dart`, `lib/data/research/supabase_research_gateway.dart:289-339`, `lib/data/research/supabase_research_api_impl.dart:231-243`, `lib/features/research/presentation/ai_research_findings.dart:54-59`, `lib/features/research/presentation/ai_research_cubit.dart:111`, `lib/core/admin/audit_entry.dart`, `lib/features/orgs/presentation/org_audit_outcome_chip.dart:16-20`
- Test: matching data/feature tests

**Interfaces:**
- Produces: `PostgrestCodes.validation = '23514'`, `.uniqueViolation = '23505'`, `.undefinedFunction = '42883'`, `.schemaCacheMiss = 'PGRST202'`, `.invalidResponse = 'PGRST116'`; `ResearchWireError` enum; `AuditOutcome` enum.

- [ ] **Step 1: Add constants and enums**

```dart
abstract final class PostgrestCodes {
  static const String validation = '23514';
  static const String uniqueViolation = '23505';
  static const String undefinedFunction = '42883';
  static const String schemaCacheMiss = 'PGRST202';
  static const String invalidResponse = 'PGRST116';
}
```

```dart
enum ResearchWireError {
  unauthorized,
  forbidden,
  invalidRequest,
  contextTooLarge,
  providerNotConfigured,
  providerUnavailable,
  invalidResponse,
  unknown;

  static ResearchWireError fromWire(String? value) => switch (value) {
    'unauthorized' => unauthorized,
    'forbidden' => forbidden,
    'invalid_request' => invalidRequest,
    'context_too_large' => contextTooLarge,
    'provider_not_configured' => providerNotConfigured,
    'provider_unavailable' => providerUnavailable,
    'invalid_response' => invalidResponse,
    _ => unknown,
  };
}
```

```dart
enum AuditOutcome { allowed, denied }
```

- [ ] **Step 2: Replace literals and add the explicit unknown fallback**

Use `ResearchWireError.fromWire` at the three research sites. Replace `'23514'`, `'23505'`, `'42883'`, `'PGRST202'`, `'PGRST116'` with the constants. Replace `'allowed'/'denied'` in the audit chip with `AuditOutcome`.

- [ ] **Step 3: Add the unknown-code UI test**

Pump the research surface with an unknown wire code and assert the localized unavailable copy, not the generic fallback.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/data/research test/features/research test/features/orgs test/data/approvals test/data/booking test/data/compliance test/data/discovery test/data/tasks`
Expected: PASS.

- [ ] **Step 5: Stage and report**

No commit.

---

### Task 15: TTL, polling, MIME, locale, and role mapping

**Files:**
- Modify: `lib/features/storage/domain/storage_gateway.dart`, `lib/data/storage/supabase_storage_gateway.dart:143`, `lib/features/storage/data/fake_storage_gateway.dart:122`, `lib/data/files/file_selector_file_picker.dart:19-45`, `lib/features/home/presentation/settings_screen.dart:18-20`, `lib/app/legalhub_theme.dart:192`, `lib/app/legalhub_text_theme.dart:9`, `lib/data/orgs/supabase_organization_gateway_mapping.dart:29-36`, `lib/data/orgs/fake_organization_helpers.dart:19-26`, `lib/features/billing/presentation/payment_cubit.dart:23-24`

**Interfaces:**
- Produces: `kSignedUrlTtl`, `kPaymentPollInterval`, `kPaymentPollTimeout`, `matterFileAllowedExtensions`, `userRoleToAssignableServerName`.

- [ ] **Step 1: Add the constants**

```dart
const Duration kSignedUrlTtl = Duration(seconds: 60);
const Duration kPaymentPollInterval = Duration(seconds: 5);
const Duration kPaymentPollTimeout = Duration(minutes: 2);
```

`matterFileAllowedExtensions` sits beside `matterFileAllowedMimeTypes` and both are consumed by the picker. Add `userRoleToAssignableServerName` beside `userRoleFromServerName`.

- [ ] **Step 2: Replace duplicates**

Replace the three 60-second TTLs, the two payment poll literals, the picker's extension list, the settings locale list (`AppLocalizations.supportedLocales`), the theme's hardcoded `'ar'` check (use a named constant or `supportedLocaleCodes`), and both role reverse maps.

- [ ] **Step 3: Run the tests**

Run: `flutter test test/features/storage test/features/billing test/features/home test/data test/features/orgs`
Expected: PASS.

- [ ] **Step 4: Stage and report**

No commit.

---

## Phase 4 — Failure copy localization

### Task 16: Failure-copy inventory and key generation

**Files:**
- Create: `tool/error_copy_inventory.dart`, `docs/l10n/error_copy_inventory_2026-10-24.tsv`
- Read: the 175 occurrences listed by the census

**Interfaces:**
- Produces: TSV `literal<TAB>suggested_key<TAB>occurrences<TAB>files`, consumed by Tasks 17-22.

- [ ] **Step 1: Write the extractor**

```dart
import 'dart:io';

final RegExp namedArg = RegExp(
  r"(userMessage|deniedMessage|validationMessage|unavailableMessage|failedMessage)"
  r"\s*:\s*'((?:[^'\\]|\\.)*)'",
);

String keyFor(String literal) {
  final List<String> words = literal
      .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .take(8)
      .toList();
  final String pascal = words
      .map((String w) => w[0].toUpperCase() + w.substring(1))
      .join();
  return 'err${pascal.isEmpty ? 'Message' : pascal}';
}

void main() {
  final Map<String, List<String>> hits = <String, List<String>>{};
  for (final File file in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))) {
    final String path = file.path.replaceAll('\\', '/');
    if (path.contains('app_localizations') || path.contains('app_message_key')) {
      continue;
    }
    final String content = file.readAsStringSync();
    for (final RegExpMatch match in namedArg.allMatches(content)) {
      final String literal = match.group(2)!;
      final int line = '\n'.allMatches(content.substring(0, match.start)).length + 1;
      hits.putIfAbsent(literal, () => <String>[]).add('$path:$line');
    }
  }
  final Map<String, int> used = <String, int>{};
  final List<String> literals = hits.keys.toList()..sort();
  print('literal\tkey\tcount\tfiles');
  for (final String literal in literals) {
    final String base = keyFor(literal);
    final int n = (used[base] ?? 0) + 1;
    used[base] = n;
    final String key = n == 1 ? base : '$base$n';
    final String escaped = literal.replaceAll('\t', ' ').replaceAll('\n', ' ');
    print('$escaped\t$key\t${hits[literal]!.length}\t${hits[literal]!.join(',')}');
  }
}
```

- [ ] **Step 2: Run it and inspect**

```powershell
dart run tool/error_copy_inventory.dart > docs/l10n/error_copy_inventory_2026-10-24.tsv
(Get-Content docs/l10n/error_copy_inventory_2026-10-24.tsv | Measure-Object -Line).Lines
```

Expected: a row per distinct literal; the occurrence column sums to 175. Any unmatched interpolated string is listed under `# UNPARSED` for manual handling.

- [ ] **Step 3: Stage and report**

No commit.

---

### Task 17: `AppMessageKey`, `AppError.messageKey`, and the mapper

**Files:**
- Create: `lib/core/errors/app_message_key.dart`, `lib/l10n/app_message_l10n.dart`, `test/l10n/app_message_l10n_test.dart`
- Modify: `lib/core/errors/app_error.dart`, `lib/shared/widgets/view_state_view.dart:33`

**Interfaces:**
- Produces: `AppMessageKey` enum; `AppError.messageKey`, `.messageArgs`; `String appMessage(AppLocalizations, AppMessageKey, {Map<String, Object?> args})`.

- [ ] **Step 1: Add the key enum from the TSV**

Generate one enum value per TSV row, in the TSV order. Add a compile-time `allAppMessageKeys` list.

- [ ] **Step 2: Extend `AppError`**

```dart
const AppError({
  required this.code,
  required this.userMessage,
  this.messageKey,
  this.messageArgs = const <String, Object?>{},
  this.technicalMessage,
  this.context = const <String, Object?>{},
  this.kind = AppErrorKind.unknown,
});

final AppMessageKey? messageKey;
final Map<String, Object?> messageArgs;
```

Add `messageKey` to `props`; keep `messageArgs` out of `props` (presentation-only). Keep `userMessage` in `toLogMap` for diagnostics.

- [ ] **Step 3: Write the exhaustive mapper with one pilot key**

```dart
String appMessage(
  AppLocalizations l10n,
  AppMessageKey key, {
  Map<String, Object?> args = const <String, Object?>{},
}) => switch (key) {
  AppMessageKey.errYouDoNotHavePermissionToViewTheseTasks =>
    l10n.errYouDoNotHavePermissionToViewTheseTasks,
};
```

Add the pilot ARB keys in EN/AR/TR. Run `flutter gen-l10n` after each batch.

- [ ] **Step 4: Fix the render leak**

```dart
label: error.messageKey == null
    ? l10n.stateError
    : appMessage(l10n, error.messageKey!, args: error.messageArgs),
```

Add `stateError` to all three ARBs if absent.

- [ ] **Step 5: Write the pilot test (completeness moves to Task 23)**

```dart
test('pilot key has copy in EN, AR, and TR', () {
  for (final locale in const ['en', 'ar', 'tr']) {
    final l10n = lookupAppLocalizations(Locale(locale));
    expect(
      appMessage(
        l10n,
        AppMessageKey.errYouDoNotHavePermissionToViewTheseTasks,
      ),
      isNotEmpty,
      reason: locale,
    );
  }
});
```

The exhaustive `allAppMessageKeys` loop is added in Task 23, after every batch has added its keys. Task 17 must leave the suite green.

- [ ] **Step 6: Run the test and the view-state tests**

Run: `flutter test test/l10n/app_message_l10n_test.dart test/shared/widgets`
Expected: PASS.

- [ ] **Step 7: Stage and report**

No commit.

---

### Tasks 18-22: Wire failure keys by feature batch

Each task follows the same five steps. Add keys to all three ARBs, regenerate, wire gateway constructions to `messageKey`, run the batch tests.

**Batch 18 — approvals + compliance**
Files: `lib/data/approvals/**`, `lib/data/compliance/**`, `lib/features/approvals/**`, `lib/features/compliance/**`, plus `app_en/ar/tr.arb`.

**Batch 19 — tasks + booking + messaging**
Files: `lib/data/tasks/**`, `lib/data/booking/**`, `lib/data/messaging/**`, matching features.

**Batch 20 — discovery + admin + orgs**
Files: `lib/data/discovery/**`, `lib/data/admin/**`, `lib/data/orgs/**`, matching features.

**Batch 21 — storage + billing + notifications**
Files: `lib/data/storage/**`, `lib/data/billing/**`, `lib/data/notifications/**`, matching features.

**Batch 22 — research + video + auth + shared**
Files: `lib/data/research/**`, `lib/data/video/**`, `lib/data/auth/**`, `lib/features/research/**`, `lib/features/video/**`, `lib/shared/**`.

For each batch:

- [ ] **Step 1: Add the batch's TSV rows to `AppMessageKey` and the mapper.**
- [ ] **Step 2: Add EN/Arabic/Turkish ARB entries.** Arabic uses MSA and the existing ARB terminology; Turkish uses formal `siz`. Mark AR/TR with `"description": "[REVIEW] machine-drafted; human review required before release"`. Sample:
  - EN: `You do not have permission to view these tasks.`
  - AR: `ليس لديك إذن لعرض هذه المهام.`
  - TR: `Bu görevleri görüntüleme izniniz yok.`
- [ ] **Step 3: Run `flutter gen-l10n`.**
- [ ] **Step 4: Wire every construction in the batch to `messageKey`, keeping the English `userMessage`.**
- [ ] **Step 5: Run the batch tests.**
- [ ] **Step 6: Stage and report.**

No commit.

---

### Task 23: Translation review doc and parity

**Files:**
- Create: `docs/l10n/translation_review_2026-10-24.md`
- Modify: `test/l10n/app_localizations_test.dart` (append to the existing parity pattern)

- [ ] **Step 1: Generate the review table**

List every key with EN, AR, TR, and a `REVIEW` checkbox. Include the glossary: brand `LegalHub` stays Latin; identities stay Latin; use existing ARB terms for matter/approval/booking.

- [ ] **Step 2: Add the exhaustive completeness and parity assertions**

```dart
test('every key has a non-empty message in EN, AR, and TR', () {
  for (final locale in const ['en', 'ar', 'tr']) {
    final l10n = lookupAppLocalizations(Locale(locale));
    for (final key in allAppMessageKeys) {
      expect(appMessage(l10n, key), isNotEmpty, reason: '$locale $key');
    }
  }
});
```

Assert the set of `AppMessageKey` values equals the set of `err*` ARB keys and that AR/TR descriptions contain `[REVIEW]`.

- [ ] **Step 3: Run the l10n tests**

Run: `flutter test test/l10n`
Expected: PASS.

- [ ] **Step 4: Stage and report**

No commit.

---

## Phase 5 — Demo corpus and posture gating

### Task 24: Centralize the demo corpus

**Files:**
- Create: `lib/shared/demo/demo_corpus.dart`, `test/shared/demo/demo_corpus_test.dart`
- Modify: all 22 fake gateways and `lib/shared/demo_labels.dart` (references only)
- Read first: `lib/data/orgs/fake_organization_demo.dart`, `lib/data/auth/fake_auth_gateway.dart`, `lib/features/matters/data/fake_matter_gateway.dart`

**Interfaces:**
- Produces: `DemoCorpus.organizationId`, `.ownerId`, `.attorneyIds`, `.matterIds`, `.matterTitles`, `.demoEmail`.

- [ ] **Step 1: Extract the values**

Read the fakes and record the canonical values. Resolve the `demo-org` vs `org-demo` drift by choosing the value used by the org/matter/task/video fakes and updating the outliers. Add the six duplicated matter-title maps to `DemoCorpus.matterTitles`.

- [ ] **Step 2: Write the test**

```dart
test('demo corpus is internally consistent', () {
  expect(DemoCorpus.organizationId, isNotEmpty);
  expect(DemoCorpus.matterTitles, hasLength(5));
  expect(DemoCorpus.matterIds, hasLength(5));
  expect(DemoCorpus.matterIds.toSet(), hasLength(5));
});
```

- [ ] **Step 3: Migrate the fakes and run their tests**

Run: `flutter test test/data/orgs test/features/matters test/features/tasks test/features/video test/features/documents test/features/messaging test/features/storage`
Expected: PASS. Update literals only; keep assertions.

- [ ] **Step 4: Stage and report**

No commit.

---

### Task 25: Gate home Recent Activity

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart:88-97`, `lib/features/home/presentation/home_activity_cards.dart`, `lib/l10n/app_en.arb`, `app_ar.arb`, `app_tr.arb`
- Test: `test/features/home/home_screen_test.dart`, `test/features/home/widgets/home_cards_test.dart`

**Interfaces:**
- Consumes: `backendIsLocalOnly`.
- Produces: localized `homeActivityEmpty`.

- [ ] **Step 1: Write the failing configured-posture test**

Pump `HomeScreen` with a `BackendPosture(isLocalOnly: false)` registration and assert the fake case title is absent and `homeActivityEmpty` is present.

- [ ] **Step 2: Implement the gate**

```dart
final bool localOnly = backendIsLocalOnly;
// ...
if (localOnly)
  SliverList(delegate: SliverChildListDelegate(_homeActivityCards(context)))
else
  const SliverToBoxAdapter(child: _HomeActivityEmpty()),
```

Add `_HomeActivityEmpty` with `l10n.homeActivityEmpty`.

- [ ] **Step 3: Add the ARB key in three locales and regenerate**

- [ ] **Step 4: Run the home tests**

Run: `flutter test test/features/home`
Expected: PASS.

- [ ] **Step 5: Stage and report**

No commit.

---

### Task 26: Posture-aware demo labels

**Files:**
- Modify: `lib/shared/demo_labels.dart` (convert functions to a `DemoLabels` class), `lib/features/notifications/presentation/notification_feed_screen.dart:42`, `notification_feed_tile.dart`, all remaining `demo_*` call sites
- Test: `test/shared/demo_labels_test.dart`, `test/features/notifications/notification_feed_screen_test.dart`

**Interfaces:**
- Produces: `DemoLabels(AppLocalizations l10n, {required bool localOnly})` with methods mirroring the 13 existing functions: `.notificationType`, `.notificationSummary`, `.matterTitle`, `.attorneyBio`, `.threadTitle`, `.messageBody`, `.authorName`, `.documentTitle`, `.fileName`, `.alertTitle`, `.taskTitle`, `.corpusTitle`, `.sourceDetail`.

- [ ] **Step 1: Write the failing configured test**

With `localOnly: false`, assert `labels.notificationSummary('invoice_status', 'Server invoice paid')` returns `'Server invoice paid'`, not the demo copy.

- [ ] **Step 2: Implement the class**

Every method returns the server value when `!localOnly`; when `localOnly`, use the existing switch.

- [ ] **Step 3: Migrate call sites**

Pass `localOnly` down from the screen root (already available in the notification feed). For screens without it, read `backendIsLocalOnly` at build.

- [ ] **Step 4: Move the 30 rendered demo values**

Approvals (8), compliance (6), discovery headlines (5), audit summaries (11): use existing `demo_labels`/ARB keys or add gated keys. Do not translate identities.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/shared test/features/notifications test/features/approvals test/features/compliance test/features/discovery test/features/admin test/features/orgs`
Expected: PASS.

- [ ] **Step 6: Stage and report**

No commit.

---

### Task 27: Remaining unconditional demo copy

**Files:**
- Modify: `lib/features/home/domain/home_entries.dart:152-159,232-239,264,300`, `lib/features/search/presentation/search_surface.dart:102-105,120-126`, `lib/features/research/presentation/ai_research_idle_or_no_match.dart:27`
- Test: matching feature tests

**Interfaces:**
- Consumes: `HomeEntry.subtitleFor(localOnly:)` already existing.

- [ ] **Step 1: Add `configuredSubtitle` to the two server-backed entries**

Discovery and research entries must render real copy when `localOnly` is false.

- [ ] **Step 2: Gate the search and research notes**

Use `backendIsLocalOnly` at the widget root; configured builds get the neutral/no-query copy.

- [ ] **Step 3: Run the tests**

Run: `flutter test test/features/home test/features/search test/features/research`
Expected: PASS.

- [ ] **Step 4: Stage and report**

No commit.

---

## Phase 6 — Close-out

### Task 28: Full gates and inventory reconciliation

- [ ] **Step 1: Run the format gate**

```powershell
dart format --output=none --set-exit-if-changed lib test tool
```

Expected: exit 0. If files are dirty, run `dart format <files>` and re-run.

- [ ] **Step 2: Run the analyzer and full suite**

```powershell
flutter analyze
flutter test --reporter expanded 2>&1 | Tee-Object final_test.log
Select-String -Path final_test.log -Pattern '\+(\d+)' | Select-Object -Last 1
```

Expected: zero analyze issues; `All tests passed!`; final count = baseline + new tests. Explain every delta.

- [ ] **Step 3: Reconcile the ledger**

Update `docs/hardcoded_values_inventory_2026-10-24.md`: every row `done`, `deferred` (reason), or `leave` (reason). Update the README/ledger test count if it changed.

- [ ] **Step 4: Verify the six behavior changes**

Run the dedicated tests in one command:

```powershell
flutter test test/app/deep_link test/features/approvals test/core/contracts test/l10n test/features/home test/features/research test/core/async
```

Confirm each behavior change has a passing test.

- [ ] **Step 5: Stage and report**

No commit.

---

### Task 29: Owner review package

- [ ] **Step 1: Produce the diff summary**

```powershell
git status --porcelain
git diff --stat
git diff --name-only
```

- [ ] **Step 2: Report per wave**

For each wave: files touched, gate results, behavior-change proof, deviations, and any deferred item with reason.

- [ ] **Step 3: Stop for owner GO**

Do not commit or push. Await explicit approval.

---

## Self-Review Notes

- **Spec coverage:** every spec §3 home has a task; §5 behavior changes map to Tasks 9, 8, 11, 17-23, 25, 14; §6 gates map to Task 28; §7 risks are enforced by the global constraints and per-task gates.
- **No placeholders:** repetitive edits name exact files, patterns, and constants. The 175 error literals are produced by Task 16's deterministic extractor; the plan does not pretend to know them.
- **Type consistency:** `AppMessageKey`, `appMessage`, `DeepLinkConfig`, `SupabaseTables/Rpcs`, `DemoLabels`, and `server_limits` names are used identically across tasks.
- **Deliberate omission:** pagination UI/`p_offset` is not in any task, matching the spec.
