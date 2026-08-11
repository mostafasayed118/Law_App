import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/orgs/presentation/active_org_store.dart';
import 'package:legalhub/features/orgs/presentation/organization_hub_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// A gateway emitting a fixed [Session] so the hub can be pinned with and
/// without an active membership.
class _FixedAuthGateway implements AuthGateway {
  _FixedAuthGateway(this._session);

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

/// Hydration repository mirroring the test's own session (P3.2 Task 8):
/// hydration replaces [Session.memberships] with the repository result, so
/// a custom-session test must answer with exactly those memberships.
class _MatchingHydrationRepository implements MembershipRepository {
  _MatchingHydrationRepository(this.memberships);

  final List<OrganizationMembership> memberships;

  @override
  Future<MembershipHydrationResult> loadMemberships({
    required String userId,
  }) async => HydrationSucceeded(memberships);
}

/// Answers honestly-empty on the first read (restore) and the created org's
/// membership on the second (the P3.3 Slice C hydrate the hub fires after
/// create-org success) — pinning that the created org joins the session
/// without re-authenticating.
class _SequencedHydrationRepository implements MembershipRepository {
  int calls = 0;

  @override
  Future<MembershipHydrationResult> loadMemberships({
    required String userId,
  }) async {
    calls += 1;
    if (calls == 1) {
      return const HydrationSucceeded(<OrganizationMembership>[]);
    }
    return const HydrationSucceeded(<OrganizationMembership>[
      OrganizationMembership(
        organizationId: 'org-2',
        organizationName: 'Nova Legal',
        role: UserRole.partner,
        status: MembershipStatus.active,
      ),
    ]);
  }
}

Session sessionWith({List<OrganizationMembership> memberships = const []}) =>
    Session(
      userId: 'user-1',
      displayName: 'Ada',
      memberships: memberships,
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
    );

void main() {
  setUp(() async {
    await resetServiceLocator();
    configureDependencies();
  });

  tearDown(() => resetServiceLocator());

  Widget harness(AuthCubit authCubit, {RoleCapability? capabilities}) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: authCubit),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OrganizationHubScreen(capabilities: capabilities),
      ),
    );
  }

  /// Builds the cubit with a repository that answers the session's own
  /// memberships, so `restore()` hydration keeps the pinned surface.
  AuthCubit hubCubit(Session session) => AuthCubit(
    _FixedAuthGateway(session),
    InMemoryErrorReporter(),
    _MatchingHydrationRepository(session.memberships),
  );

  testWidgets('shows the create-org form when there is no active membership', (
    tester,
  ) async {
    final AuthCubit authCubit = hubCubit(sessionWith());
    addTearDown(authCubit.close);
    await authCubit.restore();

    await tester.pumpWidget(harness(authCubit));
    await tester.pumpAndSettle();

    expect(find.text('Create Organization'), findsWidgets);
    expect(find.text('Demo Firm'), findsNothing);
  });

  testWidgets('renders the roster when the session has an active membership', (
    tester,
  ) async {
    final AuthCubit authCubit = hubCubit(
      sessionWith(
        memberships: <OrganizationMembership>[
          OrganizationMembership(
            organizationId: 'org-demo',
            organizationName: 'Demo Firm',
            role: UserRole.partner,
            status: MembershipStatus.active,
          ),
        ],
      ),
    );
    addTearDown(authCubit.close);
    await authCubit.restore();

    await tester.pumpWidget(harness(authCubit));
    await tester.pumpAndSettle();

    // The hub routes straight to the roster for the active membership.
    expect(find.text('Demo Firm'), findsOneWidget);
    expect(find.text('Demo user'), findsOneWidget);
    expect(find.text('Create Organization'), findsNothing);
  });

  testWidgets('creating an organization refreshes the session membership (P3.3 '
      'Slice C — hub hydrate trigger)', (tester) async {
    final _SequencedHydrationRepository repository =
        _SequencedHydrationRepository();
    final AuthCubit authCubit = AuthCubit(
      _FixedAuthGateway(sessionWith()),
      InMemoryErrorReporter(),
      repository,
    );
    addTearDown(authCubit.close);
    await authCubit.restore();

    await tester.pumpWidget(harness(authCubit));
    await tester.pumpAndSettle();
    expect(find.text('Create Organization'), findsWidgets);
    expect(authCubit.state.session?.memberships, isEmpty);

    await tester.enterText(find.byType(TextFormField), 'Nova Legal');
    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Create Organization'),
    );
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Create Organization'),
    );
    await tester.pumpAndSettle();

    // The hub's hydrate() trigger refreshed the session: the created org
    // now appears in Session.memberships (the repository was consulted a
    // second time), so the roster AppBar resolves its name instead of the
    // fallback title.
    expect(authCubit.state.session?.memberships, hasLength(1));
    expect(
      authCubit.state.session?.memberships.single.organizationName,
      'Nova Legal',
    );
    expect(repository.calls, 2);
    expect(find.text('Nova Legal'), findsWidgets);
    expect(find.text('Members'), findsNothing);
    expect(find.text('Demo user'), findsOneWidget);
    expect(find.text('Create Organization'), findsNothing);
  });

  testWidgets('creating an organization from the hub switches to the roster', (
    tester,
  ) async {
    final AuthCubit authCubit = hubCubit(sessionWith());
    addTearDown(authCubit.close);
    await authCubit.restore();

    await tester.pumpWidget(harness(authCubit));
    await tester.pumpAndSettle();
    expect(find.text('Create Organization'), findsWidgets);

    await tester.enterText(find.byType(TextFormField), 'Nova Legal');
    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Create Organization'),
    );
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Create Organization'),
    );
    await tester.pumpAndSettle();

    // The hub switched to the roster of the new organization: the creator
    // appears as its only (partner) member. The title falls back to the
    // localized roster label because the created org is not in the session.
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Demo user'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Create Organization'), findsNothing);
    // A single-membership (or just-created) session offers no switcher.
    expect(find.byType(DropdownButton<String>), findsNothing);
  });

  testWidgets('offers an org switcher only with multiple memberships', (
    tester,
  ) async {
    final AuthCubit authCubit = hubCubit(
      sessionWith(
        memberships: <OrganizationMembership>[
          OrganizationMembership(
            organizationId: 'org-demo',
            organizationName: 'Demo Firm',
            role: UserRole.partner,
            status: MembershipStatus.active,
          ),
        ],
      ),
    );
    addTearDown(authCubit.close);
    await authCubit.restore();

    await tester.pumpWidget(harness(authCubit));
    await tester.pumpAndSettle();

    expect(find.text('Demo Firm'), findsOneWidget);
    expect(find.text('Organization'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
  });

  testWidgets('switching the active org renders the selected roster', (
    tester,
  ) async {
    // Seed the dev fake with a second org so the switched roster has data.
    final OrganizationGateway orgGateway =
        serviceLocator<OrganizationGateway>();
    final OrgOutcome<OrganizationSummary> created = await orgGateway
        .createOrganization(name: 'Second Firm');
    final AuthCubit authCubit = hubCubit(
      sessionWith(
        memberships: <OrganizationMembership>[
          OrganizationMembership(
            organizationId: 'org-demo',
            organizationName: 'Demo Firm',
            role: UserRole.partner,
            status: MembershipStatus.active,
          ),
          OrganizationMembership(
            organizationId: created.valueOrNull!.id,
            organizationName: 'Second Firm',
            role: UserRole.attorney,
            status: MembershipStatus.active,
          ),
        ],
      ),
    );
    addTearDown(authCubit.close);
    await authCubit.restore();

    await tester.pumpWidget(harness(authCubit));
    await tester.pumpAndSettle();

    // The switcher strip is present and defaults to the server-derived
    // active membership.
    expect(find.text('Organization'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.text('Demo Firm'), findsWidgets);
    expect(find.text('Demo user'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second Firm').last);
    await tester.pumpAndSettle();

    // The roster now renders the selected org's members; the selection is a
    // local UI context only (never transmitted), and the strip stays.
    expect(find.text('Second Firm'), findsWidgets);
    expect(find.text('Demo user'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsOneWidget);

    // AC-4 (Phase 7 slice 7.0): the switcher writes the selection into the
    // ActiveOrgStore (D-08 — client-side context, never an authority).
    expect(
      serviceLocator<ActiveOrgStore>().activeOrganizationId,
      created.valueOrNull!.id,
    );
  });

  group('audit entry gating (partner org-audit slice 2026-08-09)', () {
    AuthCubit partnerHubCubit() => hubCubit(
      sessionWith(
        memberships: <OrganizationMembership>[
          OrganizationMembership(
            organizationId: 'org-demo',
            organizationName: 'Demo Firm',
            role: UserRole.partner,
            status: MembershipStatus.active,
          ),
        ],
      ),
    );

    testWidgets('renders the Audit trail entry when canViewAudit is granted', (
      tester,
    ) async {
      final AuthCubit authCubit = partnerHubCubit();
      addTearDown(authCubit.close);
      await authCubit.restore();

      await tester.pumpWidget(
        harness(
          authCubit,
          capabilities: const RoleCapability(
            canViewHome: true,
            canViewSettings: true,
            canBookConsultation: true,
            canViewAttorneyDiscovery: true,
            canViewMatters: true,
            canViewDocuments: true,
            canViewMessages: true,
            canViewFiles: true,
            canViewAudit: true,
            canViewNotifications: true,
            canViewAlerts: true,
            canViewTasks: true,
            canViewApprovals: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View audit trail'), findsOneWidget);
    });

    testWidgets('hides the entry when canViewAudit is not granted (nav hint '
        'only)', (tester) async {
      final AuthCubit authCubit = partnerHubCubit();
      addTearDown(authCubit.close);
      await authCubit.restore();

      await tester.pumpWidget(
        harness(
          authCubit,
          capabilities: const RoleCapability(
            canViewHome: true,
            canViewSettings: true,
            canBookConsultation: true,
            canViewAttorneyDiscovery: true,
            canViewMatters: true,
            canViewDocuments: true,
            canViewMessages: true,
            canViewFiles: true,
            canViewAudit: false,
            canViewNotifications: true,
            canViewAlerts: true,
            canViewTasks: true,
            canViewApprovals: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View audit trail'), findsNothing);
    });

    testWidgets('hides the entry when no capability projection is supplied', (
      tester,
    ) async {
      final AuthCubit authCubit = partnerHubCubit();
      addTearDown(authCubit.close);
      await authCubit.restore();

      await tester.pumpWidget(harness(authCubit));
      await tester.pumpAndSettle();

      expect(find.text('View audit trail'), findsNothing);
    });
  });
}
