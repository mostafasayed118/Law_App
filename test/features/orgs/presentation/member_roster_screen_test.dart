import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/orgs/presentation/member_roster_screen.dart';
import 'package:legalhub/features/orgs/presentation/org_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// A gateway emitting a fixed [Session] with the demo org membership so the
/// roster test can pin partner vs non-partner presentation.
class _RoleAuthGateway implements AuthGateway {
  _RoleAuthGateway(this._session);

  final Session _session;

  @override
  Session? get currentSession => _session;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  bool get recoveryPending => false;

  @override
  Future<AuthOutcome<Session>> restore() async {
    return AuthOutcome<Session>.success(_session);
  }

  @override
  Future<AuthOutcome<Session>> startDemoSession() async {
    return AuthOutcome<Session>.success(_session);
  }

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async {
    return AuthOutcome<Session>.success(_session);
  }

  @override
  Future<void> signOut() async {}
}

/// Hydration repository mirroring the role session (P3.2 Task 8):
/// `restore()` replaces [Session.memberships] with the repository result, so
/// the partner/client pin must answer with exactly the session's memberships.
class _MatchingHydrationRepository implements MembershipRepository {
  _MatchingHydrationRepository(this.memberships);

  final List<OrganizationMembership> memberships;

  @override
  Future<MembershipHydrationResult> loadMemberships({
    required String userId,
  }) async => HydrationSucceeded(memberships);
}

Session sessionFor(UserRole role) => Session(
  userId: FakeOrganizationGateway.demoUserId,
  displayName: 'Demo user',
  memberships: <OrganizationMembership>[
    OrganizationMembership(
      organizationId: 'org-demo',
      organizationName: 'Demo Firm',
      role: role,
      status: MembershipStatus.active,
    ),
  ],
  expiresAt: DateTime.now().add(const Duration(hours: 8)),
);

void main() {
  late FakeOrganizationGateway orgGateway;
  late OrgCubit orgCubit;
  late FakeAuthGateway demoAuth;

  setUp(() async {
    orgGateway = FakeOrganizationGateway();
    // The invite sheet resolves the gateway from the locator; register the
    // same instance the roster's OrgCubit uses so both sides share one fake.
    await resetServiceLocator();
    serviceLocator.registerLazySingleton<OrganizationGateway>(() => orgGateway);
    configureDependencies();
    orgCubit = OrgCubit(orgGateway);
    demoAuth = FakeAuthGateway();
  });

  tearDown(() async {
    await orgCubit.close();
    await demoAuth.dispose();
    await resetServiceLocator();
  });

  Widget harness({
    required AuthCubit authCubit,
    String organizationId = FakeOrganizationGateway.demoOrganizationId,
    Locale locale = const Locale('en'),
  }) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<OrgCubit>.value(value: orgCubit),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MemberRosterScreen(organizationId: organizationId),
      ),
    );
  }

  Future<AuthCubit> partnerAuth() async {
    final Session session = sessionFor(UserRole.partner);
    final AuthCubit auth = AuthCubit(
      _RoleAuthGateway(session),
      InMemoryErrorReporter(),
      _MatchingHydrationRepository(session.memberships),
    );
    addTearDown(auth.close);
    await auth.restore();
    return auth;
  }

  Future<AuthCubit> clientAuth() async {
    final Session session = sessionFor(UserRole.client);
    final AuthCubit auth = AuthCubit(
      _RoleAuthGateway(session),
      InMemoryErrorReporter(),
      _MatchingHydrationRepository(session.memberships),
    );
    addTearDown(auth.close);
    await auth.restore();
    return auth;
  }

  group('MemberRosterScreen rendering', () {
    testWidgets('renders member rows with role and status chips', (
      tester,
    ) async {
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      expect(find.text('Demo Firm'), findsOneWidget);
      expect(find.text('Demo user'), findsOneWidget);
      expect(find.text('Partner'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('shows invited rows for pending invites', (tester) async {
      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'new@firm.com',
        role: UserRole.attorney,
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      expect(find.text('new@firm.com'), findsOneWidget);
      expect(find.text('Attorney'), findsWidgets);
      expect(find.text('INVITED'), findsOneWidget);
    });

    testWidgets('suspended members are visually distinct', (tester) async {
      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'new@firm.com',
        role: UserRole.attorney,
      );
      await orgGateway.suspendMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: 'new@firm.com',
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      expect(find.text('SUSPENDED'), findsOneWidget);
      final double opacity = tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.text('new@firm.com'),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(opacity, 0.55);
    });

    testWidgets('removed members are visually distinct', (tester) async {
      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'new@firm.com',
        role: UserRole.attorney,
      );
      await orgGateway.removeMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: 'new@firm.com',
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      expect(find.text('REMOVED'), findsOneWidget);
      final double opacity = tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.text('new@firm.com'),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(opacity, 0.55);
    });

    testWidgets('surfaces a roster failure with a retry action', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(authCubit: await partnerAuth(), organizationId: 'org-unknown'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("You don't have permission to perform this action."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      // Retry re-issues the same load; the fake still denies the unknown org.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.text("You don't have permission to perform this action."),
        findsOneWidget,
      );
    });
  });

  group('MemberRosterScreen partner surface', () {
    testWidgets('partner sees the invite entry point and management menu', (
      tester,
    ) async {
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      expect(find.text('Invite Member'), findsOneWidget);
      expect(find.byType(PopupMenuButton<OrgMemberAction>), findsOneWidget);
    });

    testWidgets('suspend on the last active partner surfaces lastPartner', (
      tester,
    ) async {
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<OrgMemberAction>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suspend'));
      await tester.pumpAndSettle();

      expect(
        find.text('The organization must keep at least one active partner.'),
        findsOneWidget,
      );
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('remove is hidden for your own row', (tester) async {
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<OrgMemberAction>));
      await tester.pumpAndSettle();

      expect(find.text('Remove'), findsNothing);
      expect(find.text('Suspend'), findsOneWidget);
    });

    testWidgets('changing a member role updates the roster', (tester) async {
      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'attorney@firm.com',
        role: UserRole.attorney,
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      final Finder attorneyRow = find.widgetWithText(
        ListTile,
        'attorney@firm.com',
      );
      await tester.tap(
        find.descendant(
          of: attorneyRow,
          matching: find.byType(PopupMenuButton<OrgMemberAction>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partner').last);
      await tester.pumpAndSettle();

      // Both the self row and the promoted member now render Partner chips.
      expect(find.text('Partner'), findsNWidgets(2));
    });

    testWidgets('inviting from the FAB reloads the roster with the new row', (
      tester,
    ) async {
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Invite Member'));
      await tester.pumpAndSettle();
      expect(find.text('Invite by email'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'fresh@firm.com');
      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();

      // The token is shown once inside the sheet; dismissing it reloads the
      // roster so the pending invited row appears.
      expect(find.text('Copy token'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('fresh@firm.com'), findsOneWidget);
      expect(find.text('INVITED'), findsOneWidget);
    });
    testWidgets('reactivating a suspended member restores the ACTIVE chip', (
      tester,
    ) async {
      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'attorney@firm.com',
        role: UserRole.attorney,
      );
      await orgGateway.suspendMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: 'attorney@firm.com',
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();
      expect(find.text('SUSPENDED'), findsOneWidget);

      final Finder attorneyRow = find.widgetWithText(
        ListTile,
        'attorney@firm.com',
      );
      await tester.tap(
        find.descendant(
          of: attorneyRow,
          matching: find.byType(PopupMenuButton<OrgMemberAction>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reactivate'));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE'), findsNWidgets(2));
      expect(find.text('SUSPENDED'), findsNothing);
    });

    testWidgets('removing a member marks the row as REMOVED', (tester) async {
      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'attorney@firm.com',
        role: UserRole.attorney,
      );
      // Lifecycle actions target real members only, so move the invite to a
      // suspended member first.
      await orgGateway.suspendMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: 'attorney@firm.com',
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      final Finder attorneyRow = find.widgetWithText(
        ListTile,
        'attorney@firm.com',
      );
      await tester.tap(
        find.descendant(
          of: attorneyRow,
          matching: find.byType(PopupMenuButton<OrgMemberAction>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      // Destructive removal requires explicit confirmation (roadmap slice
      // 1.4): the dialog names the target, and the action fires only on the
      // confirm button.
      expect(find.text('Remove member?'), findsOneWidget);
      expect(
        find.text('Remove attorney@firm.com from this organization?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('REMOVED'), findsOneWidget);
      expect(find.text('attorney@firm.com'), findsOneWidget);
    });

    testWidgets('cancelling the remove confirmation keeps the member', (
      tester,
    ) async {
      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'attorney@firm.com',
        role: UserRole.attorney,
      );
      await orgGateway.suspendMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: 'attorney@firm.com',
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      final Finder attorneyRow = find.widgetWithText(
        ListTile,
        'attorney@firm.com',
      );
      await tester.tap(
        find.descendant(
          of: attorneyRow,
          matching: find.byType(PopupMenuButton<OrgMemberAction>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Remove member?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The member is untouched: still suspended, not removed.
      expect(find.text('SUSPENDED'), findsOneWidget);
      expect(find.text('attorney@firm.com'), findsOneWidget);
      expect(find.text('REMOVED'), findsNothing);
    });

    testWidgets('dismissing the remove dialog leaves the member untouched', (
      tester,
    ) async {
      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'attorney@firm.com',
        role: UserRole.attorney,
      );
      await orgGateway.suspendMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: 'attorney@firm.com',
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      final Finder attorneyRow = find.widgetWithText(
        ListTile,
        'attorney@firm.com',
      );
      await tester.tap(
        find.descendant(
          of: attorneyRow,
          matching: find.byType(PopupMenuButton<OrgMemberAction>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove member?'), findsOneWidget);

      // Barrier dismiss pops the dialog with null; _confirmRemove's
      // `confirmed != true` guard treats it as cancel.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('SUSPENDED'), findsOneWidget);
      expect(find.text('attorney@firm.com'), findsOneWidget);
      expect(find.text('REMOVED'), findsNothing);
    });

    testWidgets('invited rows offer role changes and the invite lifecycle', (
      tester,
    ) async {
      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'attorney@firm.com',
        role: UserRole.attorney,
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      final Finder attorneyRow = find.widgetWithText(
        ListTile,
        'attorney@firm.com',
      );
      await tester.tap(
        find.descendant(
          of: attorneyRow,
          matching: find.byType(PopupMenuButton<OrgMemberAction>),
        ),
      );
      await tester.pumpAndSettle();

      // Lifecycle actions (suspend/remove/revoke) apply to members; invited
      // rows get the invite lifecycle instead: role picker + resend + revoke.
      // `.last` disambiguates the menu items from the self-row chip.
      expect(find.text('Suspend'), findsNothing);
      expect(find.text('Remove'), findsNothing);
      expect(find.text('Reactivate'), findsNothing);
      expect(find.text('Partner').last, findsOneWidget);
      expect(find.text('Client').last, findsOneWidget);
      expect(find.text('Resend invitation'), findsOneWidget);
      expect(find.text('Revoke invitation'), findsOneWidget);
    });

    testWidgets('revoking an invite removes the row and confirms', (
      tester,
    ) async {
      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'attorney@firm.com',
        role: UserRole.attorney,
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();
      expect(find.text('attorney@firm.com'), findsOneWidget);

      final Finder attorneyRow = find.widgetWithText(
        ListTile,
        'attorney@firm.com',
      );
      await tester.tap(
        find.descendant(
          of: attorneyRow,
          matching: find.byType(PopupMenuButton<OrgMemberAction>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke invitation'));
      await tester.pumpAndSettle();

      // The revoked invite leaves the pending roster and the success
      // confirmation surfaces.
      expect(find.text('attorney@firm.com'), findsNothing);
      expect(find.text('Invitation revoked.'), findsOneWidget);
    });

    testWidgets('resending an invite shows the fresh token once', (
      tester,
    ) async {
      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'attorney@firm.com',
        role: UserRole.attorney,
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      final Finder attorneyRow = find.widgetWithText(
        ListTile,
        'attorney@firm.com',
      );
      await tester.tap(
        find.descendant(
          of: attorneyRow,
          matching: find.byType(PopupMenuButton<OrgMemberAction>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resend invitation'));
      await tester.pumpAndSettle();

      expect(find.textContaining('demo-invite-token-resend-'), findsOneWidget);
      expect(find.text('Copy token'), findsOneWidget);
    });

    testWidgets('resend token dialog copies the token to the clipboard', (
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

      await orgGateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'attorney@firm.com',
        role: UserRole.attorney,
      );
      await tester.pumpWidget(harness(authCubit: await partnerAuth()));
      await tester.pumpAndSettle();

      final Finder attorneyRow = find.widgetWithText(
        ListTile,
        'attorney@firm.com',
      );
      await tester.tap(
        find.descendant(
          of: attorneyRow,
          matching: find.byType(PopupMenuButton<OrgMemberAction>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resend invitation'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy token'));
      await tester.pumpAndSettle();

      expect(find.text('Token copied to clipboard.'), findsOneWidget);
      final MethodCall clipboardCall = platformCalls.singleWhere(
        (MethodCall call) => call.method == 'Clipboard.setData',
      );
      expect(
        (clipboardCall.arguments as Map<Object?, Object?>)['text'],
        startsWith('demo-invite-token-resend-'),
      );
    });
  });

  group('MemberRosterScreen non-partner surface', () {
    testWidgets('client sees the roster but no management actions', (
      tester,
    ) async {
      await tester.pumpWidget(harness(authCubit: await clientAuth()));
      await tester.pumpAndSettle();

      expect(find.text('Demo user'), findsOneWidget);
      expect(find.text('Invite Member'), findsNothing);
      expect(find.byType(PopupMenuButton<OrgMemberAction>), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('MemberRosterScreen localization', () {
    testWidgets('renders Arabic roster strings', (tester) async {
      await tester.pumpWidget(
        harness(authCubit: await partnerAuth(), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      // The org name comes from the session (data, not localized); the chips
      // resolve through the AR translations.
      expect(find.text('Demo Firm'), findsOneWidget);
      expect(find.text('الشريك'), findsOneWidget);
      expect(find.text('نشط'), findsOneWidget);
    });

    testWidgets('renders Turkish roster strings', (tester) async {
      await tester.pumpWidget(
        harness(authCubit: await partnerAuth(), locale: const Locale('tr')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Demo Firm'), findsOneWidget);
      expect(find.text('Ortak'), findsOneWidget);
      expect(find.text('AKTİF'), findsOneWidget);
    });
  });
}
