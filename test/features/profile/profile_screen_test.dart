import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/profile/presentation/profile_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// ProfileScreen is a pure projection of AuthCubit state: no new cubit, no
// gateway calls of its own (the Phase 2 account-deletion action resolves the
// organization gateway from the locator, like the invite sheet). These tests
// pin that projection — authenticated identity render, empty
// (unauthenticated), error + retry via ViewStateView, the reauthRequired
// edge (localized expired-session message, never stale identity), AR
// localization resolution, and the delete-account flow. AuthCubit itself is
// covered by test/features/auth/auth_cubit_test.dart; it is not re-tested
// here.
void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;
  late FakeOrganizationGateway orgGateway;

  setUp(() async {
    await resetServiceLocator();
    orgGateway = FakeOrganizationGateway();
    serviceLocator.registerLazySingleton<OrganizationGateway>(() => orgGateway);
    configureDependencies();
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(
      gateway,
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
    );
  });

  tearDown(() async {
    await authCubit.close();
    await gateway.dispose();
    await resetServiceLocator();
  });

  Widget pumpScreen({Locale locale = const Locale('en')}) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: authCubit),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfileScreen(),
      ),
    );
  }

  testWidgets('renders the session identity when authenticated', (
    tester,
  ) async {
    await authCubit.startDemoSession();
    final Session session = authCubit.state.session!;

    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    final String expectedExpiry = DateFormat.yMMMd(
      'en',
    ).add_jm().format(session.expiresAt);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Demo user'), findsOneWidget);
    expect(find.text('demo-user'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);
    expect(find.text(expectedExpiry), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Account ID'), findsOneWidget);
    expect(find.text('Role'), findsOneWidget);
    expect(find.text('Session expires'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('cancelling the delete confirm keeps the session', (
    tester,
  ) async {
    await authCubit.startDemoSession();

    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsOneWidget);
    // P3.4: the audit-survives note is stated in the confirm copy — retained
    // by law, never promised as data recovery.
    expect(
      find.text(
        'Your data is deleted; audit records of your activity are retained.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // The session is untouched: identity still renders.
    expect(find.text('Demo user'), findsOneWidget);
    expect(authCubit.state.status, AuthStatus.authenticated);
  });

  testWidgets('delete confirm resolves Arabic copy incl. the audit note', (
    tester,
  ) async {
    await authCubit.startDemoSession();

    await tester.pumpWidget(pumpScreen(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف الحساب'));
    await tester.pumpAndSettle();

    expect(find.text('هل تريد حذف حسابك؟'), findsOneWidget);
    expect(
      find.text('تُحذف بياناتك، مع الإبقاء على سجلات التدقيق الخاصة بنشاطك.'),
      findsOneWidget,
    );
    // The dialog actions also resolve in AR; cancel keeps the session.
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(authCubit.state.status, AuthStatus.authenticated);
  });

  testWidgets('confirming deletes the account and signs out', (tester) async {
    await authCubit.startDemoSession();

    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // The identity is gone server-side and the session ended: the screen
    // falls back to the unauthenticated empty state.
    expect(find.text('Demo user'), findsNothing);
    expect(authCubit.state.status, AuthStatus.unauthenticated);
  });

  testWidgets('a failed deletion surfaces the localized error and signs out', (
    tester,
  ) async {
    await resetServiceLocator();
    serviceLocator.registerLazySingleton<OrganizationGateway>(
      () => _FailingDeleteOrgGateway(),
    );
    configureDependencies();
    await authCubit.startDemoSession();

    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Typed failure surfaces localized and non-sensitive; the session stays
    // alive because nothing was deleted.
    expect(
      find.text("You don't have permission to perform this action."),
      findsOneWidget,
    );
    expect(authCubit.state.status, AuthStatus.authenticated);
    expect(find.text('Demo user'), findsOneWidget);
  });

  testWidgets('shows the empty state when unauthenticated', (tester) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    expect(find.text('Nothing to show'), findsOneWidget);
    expect(find.text('Demo user'), findsNothing);
  });

  testWidgets('shows the error state and retry when restore fails', (
    tester,
  ) async {
    final FailingAuthGateway failingGateway = FailingAuthGateway();
    final AuthCubit failingCubit = AuthCubit(
      failingGateway,
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
    );
    addTearDown(failingCubit.close);

    await failingCubit.restore();
    expect(failingCubit.state.status, AuthStatus.error);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthCubit>.value(value: failingCubit),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backend unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Demo user'), findsNothing);

    // Retry re-runs restore() against the same failing gateway; the error
    // surface must persist (no stale identity, no crash).
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Backend unavailable'), findsOneWidget);
  });

  testWidgets(
    'shows the localized expired-session message when reauth is required',
    (tester) async {
      final ExpiredSessionGateway expiredGateway = ExpiredSessionGateway();
      final AuthCubit expiredCubit = AuthCubit(
        expiredGateway,
        InMemoryErrorReporter(),
        FakeMembershipRepository(),
      );
      addTearDown(expiredCubit.close);

      await expiredCubit.restore();
      expect(expiredCubit.state.status, AuthStatus.reauthRequired);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AuthCubit>.value(value: expiredCubit),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Session expired. Please sign in again.'),
        findsOneWidget,
      );
      expect(find.text('Demo user'), findsNothing);
      // restore() cannot resurrect an expired session: no Retry affordance in
      // this branch (finding #3).
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets('resolves Arabic localization', (tester) async {
    await authCubit.startDemoSession();

    await tester.pumpWidget(pumpScreen(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الملف'), findsOneWidget);
    expect(find.text('الاسم'), findsOneWidget);
    expect(find.text('الشريك'), findsOneWidget);
    expect(find.text('Demo user'), findsOneWidget);
  });
}

/// Test-only failing gateway (precedent: sign_in_error_test.dart). restore()
/// always fails with providerUnavailable so AuthCubit reaches the error state
/// and the profile error surface can be exercised.
class FailingAuthGateway implements AuthGateway {
  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  bool get recoveryPending => false;

  @override
  Future<AuthOutcome<Session>> restore() async {
    return const AuthOutcome<Session>.failure(
      AuthFailure(
        kind: AuthFailureKind.providerUnavailable,
        message: 'Backend unavailable',
      ),
    );
  }

  @override
  Future<AuthOutcome<Session>> startDemoSession() async {
    return const AuthOutcome<Session>.failure(
      AuthFailure(kind: AuthFailureKind.providerUnavailable),
    );
  }

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async {
    return const AuthOutcome<Session>.failure(
      AuthFailure(kind: AuthFailureKind.providerUnavailable),
    );
  }

  @override
  Future<void> signOut() async {}
}

/// Test-only gateway that fails account deletion, to pin the failure path.
class _FailingDeleteOrgGateway implements OrganizationGateway {
  @override
  Future<OrgOutcome<OrganizationSummary>> createOrganization({
    required String name,
  }) async => const OrgOutcome<OrganizationSummary>.failure(
    OrgFailure(kind: OrgFailureKind.denied),
  );

  @override
  Future<OrgOutcome<List<OrgMember>>> listMembers({
    required String organizationId,
  }) async => const OrgOutcome<List<OrgMember>>.failure(
    OrgFailure(kind: OrgFailureKind.denied),
  );

  @override
  Future<OrgOutcome<InviteResult>> inviteMember({
    required String organizationId,
    required String email,
    required UserRole role,
  }) async => const OrgOutcome<InviteResult>.failure(
    OrgFailure(kind: OrgFailureKind.denied),
  );

  @override
  Future<OrgOutcome<void>> changeMemberRole({
    required String organizationId,
    required String userId,
    required UserRole role,
  }) async =>
      const OrgOutcome<void>.failure(OrgFailure(kind: OrgFailureKind.denied));

  @override
  Future<OrgOutcome<void>> suspendMember({
    required String organizationId,
    required String userId,
  }) async =>
      const OrgOutcome<void>.failure(OrgFailure(kind: OrgFailureKind.denied));

  @override
  Future<OrgOutcome<void>> reactivateMember({
    required String organizationId,
    required String userId,
  }) async =>
      const OrgOutcome<void>.failure(OrgFailure(kind: OrgFailureKind.denied));

  @override
  Future<OrgOutcome<void>> removeMember({
    required String organizationId,
    required String userId,
  }) async =>
      const OrgOutcome<void>.failure(OrgFailure(kind: OrgFailureKind.denied));

  @override
  Future<OrgOutcome<String>> resendInvitation({
    required String invitationId,
  }) async => const OrgOutcome<String>.failure(
    OrgFailure(kind: OrgFailureKind.invalidInvitation),
  );

  @override
  Future<OrgOutcome<void>> revokeInvitation({
    required String invitationId,
  }) async => const OrgOutcome<void>.failure(
    OrgFailure(kind: OrgFailureKind.invalidInvitation),
  );

  @override
  Future<OrgOutcome<void>> deleteMyAccount() async {
    return const OrgOutcome<void>.failure(
      OrgFailure(kind: OrgFailureKind.denied),
    );
  }

  @override
  Future<OrgOutcome<String>> acceptInvitation({required String token}) async =>
      const OrgOutcome<String>.failure(
        OrgFailure(kind: OrgFailureKind.invalidInvitation),
      );

  @override
  Future<OrgOutcome<List<AuditEntry>>> readOrgAudit({
    required String organizationId,
  }) async => const OrgOutcome<List<AuditEntry>>.failure(
    OrgFailure(kind: OrgFailureKind.denied),
  );
}

/// Test-only expired-session gateway: restore() reports sessionExpired so
/// AuthCubit reaches reauthRequired and the screen must surface the
/// localized expired message instead of stale identity.
class ExpiredSessionGateway implements AuthGateway {
  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  bool get recoveryPending => false;

  @override
  Future<AuthOutcome<Session>> restore() async {
    return const AuthOutcome<Session>.failure(
      AuthFailure(kind: AuthFailureKind.sessionExpired),
    );
  }

  @override
  Future<AuthOutcome<Session>> startDemoSession() async {
    return const AuthOutcome<Session>.failure(
      AuthFailure(kind: AuthFailureKind.sessionExpired),
    );
  }

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async {
    return const AuthOutcome<Session>.failure(
      AuthFailure(kind: AuthFailureKind.sessionExpired),
    );
  }

  @override
  Future<void> signOut() async {}
}
