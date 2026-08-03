import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
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

  Widget harness(AuthCubit authCubit) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: authCubit),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OrganizationHubScreen(),
      ),
    );
  }

  testWidgets('shows the create-org form when there is no active membership', (
    tester,
  ) async {
    final AuthCubit authCubit = AuthCubit(
      _FixedAuthGateway(sessionWith()),
      InMemoryErrorReporter(),
    );
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
    final AuthCubit authCubit = AuthCubit(
      _FixedAuthGateway(
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
      ),
      InMemoryErrorReporter(),
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

  testWidgets('creating an organization from the hub switches to the roster', (
    tester,
  ) async {
    final AuthCubit authCubit = AuthCubit(
      _FixedAuthGateway(sessionWith()),
      InMemoryErrorReporter(),
    );
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
  });
}
