import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/profile/presentation/profile_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// ProfileScreen is a pure projection of AuthCubit state: no new cubit, no
// gateway calls of its own. These tests pin that projection — authenticated
// identity render, empty (unauthenticated), error + retry via ViewStateView,
// the reauthRequired edge (localized expired-session message, never stale
// identity), and AR localization resolution. AuthCubit itself is covered by
// test/features/auth/auth_cubit_test.dart; it is not re-tested here.
void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;

  setUp(() {
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(gateway, InMemoryErrorReporter());
  });

  tearDown(() async {
    await authCubit.close();
    await gateway.dispose();
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
    expect(find.text('Client'), findsOneWidget);
    expect(find.text(expectedExpiry), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Account ID'), findsOneWidget);
    expect(find.text('Role'), findsOneWidget);
    expect(find.text('Session expires'), findsOneWidget);
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
    expect(find.text('العميل'), findsOneWidget);
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

/// Test-only expired-session gateway: restore() reports sessionExpired so
/// AuthCubit reaches reauthRequired and the screen must surface the
/// localized expired message instead of stale identity.
class ExpiredSessionGateway implements AuthGateway {
  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

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
