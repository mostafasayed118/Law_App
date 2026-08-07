import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/orgs/presentation/invite_member_sheet.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  bool? sheetResult;

  setUp(() async {
    await resetServiceLocator();
    configureDependencies();
    sheetResult = null;
  });

  tearDown(() => resetServiceLocator());

  Widget harness() {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                sheetResult = await showInviteMemberSheet(
                  context,
                  organizationId: FakeOrganizationGateway.demoOrganizationId,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> sendInvite(
    WidgetTester tester, {
    String email = 'new@firm.com',
    String? roleItem,
  }) async {
    await tester.enterText(find.byType(TextFormField), email);
    if (roleItem != null) {
      await tester.tap(find.byType(DropdownButtonFormField<UserRole>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(roleItem).last);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Send Invitation'));
    await tester.tap(find.text('Send Invitation'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the email field, role selector, and send button', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Invite Member'), findsOneWidget);
    expect(find.text('Invite by email'), findsOneWidget);
    expect(find.text('Assign role'), findsOneWidget);
    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Send Invitation'), findsOneWidget);
  });

  testWidgets('rejects an invalid email client-side', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Send Invitation'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Copy token'), findsNothing);
    expect(find.text('Copy invite link'), findsNothing);
  });

  testWidgets('mints an invite and shows the one-time token once', (
    tester,
  ) async {
    await openSheet(tester);

    await sendInvite(tester, email: 'new@firm.com', roleItem: 'Attorney');

    // Token view: the token text and a copy affordance; no invite form.
    expect(find.text('demo-invite-token-1'), findsOneWidget);
    expect(find.text('Copy token'), findsOneWidget);
    expect(find.text('Send Invitation'), findsNothing);
    // The email is echoed for confirmation without leaving the sheet.
    expect(find.textContaining('new@firm.com'), findsWidgets);
  });

  testWidgets('an existing member email surfaces the typed duplicate error', (
    tester,
  ) async {
    // The sheet resolves the gateway from the locator; seed the same
    // instance so the fake sees the existing membership.
    await serviceLocator<OrganizationGateway>().inviteMember(
      organizationId: FakeOrganizationGateway.demoOrganizationId,
      email: 'dup@firm.com',
      role: UserRole.client,
    );
    await openSheet(tester);

    await sendInvite(tester, email: 'dup@firm.com');

    expect(
      find.text('This person is already a member of the organization.'),
      findsOneWidget,
    );
    // Still editable: the form stays and no token is shown.
    expect(find.text('Send Invitation'), findsOneWidget);
    expect(find.text('Copy token'), findsNothing);
  });

  testWidgets('copying the token writes it to the clipboard', (tester) async {
    final List<MethodCall> platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await openSheet(tester);
    await sendInvite(tester, email: 'new@firm.com');

    await tester.tap(find.text('Copy token'));
    await tester.pump();

    final MethodCall setData = platformCalls.firstWhere(
      (MethodCall call) => call.method == 'Clipboard.setData',
    );
    expect(
      (setData.arguments as Map<Object?, Object?>)['text'],
      'demo-invite-token-1',
    );
    expect(find.text('Token copied to clipboard.'), findsOneWidget);
  });

  testWidgets('copying the invite link writes the full deep-link URI', (
    tester,
  ) async {
    final List<MethodCall> platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await openSheet(tester);
    await sendInvite(tester, email: 'new@firm.com');

    await tester.tap(find.text('Copy invite link'));
    await tester.pump();

    final MethodCall setData = platformCalls.firstWhere(
      (MethodCall call) => call.method == 'Clipboard.setData',
    );
    expect(
      (setData.arguments as Map<Object?, Object?>)['text'],
      // The full accept-deep-link URI, built from the parser's own
      // scheme/host constants — not the bare token (D-IS2/§5 data flow).
      'com.legalhub.app://accept-invite?token=demo-invite-token-1',
    );
    expect(find.text('Invite link copied to clipboard.'), findsOneWidget);
  });

  testWidgets(
    'link and token buttons copy distinct payloads with distinct snackbars',
    (tester) async {
      final List<MethodCall> platformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await openSheet(tester);
      await sendInvite(tester, email: 'new@firm.com');

      // Link button first.
      await tester.tap(find.text('Copy invite link'));
      await tester.pump();
      expect(
        (platformCalls
                .firstWhere(
                  (MethodCall call) => call.method == 'Clipboard.setData',
                )
                .arguments
            as Map<Object?, Object?>)['text'],
        'com.legalhub.app://accept-invite?token=demo-invite-token-1',
      );
      expect(find.text('Invite link copied to clipboard.'), findsOneWidget);

      // Clear the first snackbar so the queued token snackbar can surface
      // (ScaffoldMessenger queues rather than stacks); settle so the exit
      // animation completes before the second tap.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await tester.pumpAndSettle();

      // The bare-token copy is untouched (regression): same seam, bare token.
      await tester.tap(find.text('Copy token'));
      await tester.pump();
      final List<MethodCall> setDataCalls = platformCalls
          .where((MethodCall call) => call.method == 'Clipboard.setData')
          .toList();
      expect(setDataCalls.length, 2);
      expect(
        (setDataCalls.last.arguments as Map<Object?, Object?>)['text'],
        'demo-invite-token-1',
      );
      expect(find.text('Token copied to clipboard.'), findsOneWidget);
    },
  );

  testWidgets('dismissing after delivery resolves the sheet with true', (
    tester,
  ) async {
    await openSheet(tester);
    await sendInvite(tester, email: 'new@firm.com');

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(sheetResult, isTrue);
  });

  testWidgets('dismissing without inviting resolves the sheet with null', (
    tester,
  ) async {
    await openSheet(tester);

    // Swipe/scrim dismiss: tapping outside the sheet closes it without an
    // invitation.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(sheetResult, isNull);
  });

  testWidgets('role selector offers only assignable roles', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byType(DropdownButtonFormField<UserRole>));
    await tester.pumpAndSettle();

    // The three server-assignable roles are offered; nothing outside the
    // assignable set (e.g., an owner/admin entry) can be minted client-side.
    // "Client" appears twice: the selected value and the menu item.
    expect(find.text('Client'), findsAtLeastNWidgets(1));
    expect(find.text('Attorney'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);
    expect(find.text('Owner'), findsNothing);
  });
}
