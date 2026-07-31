import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';

/// A fixed contract-§5 session used by the synthetic fakes so expected states
/// compare equal to emitted states.
Session demoSession() => Session(
  userId: 'demo-user',
  displayName: 'Demo user',
  memberships: const <OrganizationMembership>[
    OrganizationMembership(
      organizationId: 'org-demo',
      organizationName: 'Demo Firm',
      role: UserRole.client,
      status: MembershipStatus.active,
    ),
  ],
  expiresAt: DateTime(2030, 1, 1),
);

void main() {
  group('AuthCubit initial state', () {
    test('starts unauthenticated when there is no current session', () {
      final AuthCubit cubit = AuthCubit(
        _NullSessionGateway(),
        InMemoryErrorReporter(),
      );
      addTearDown(cubit.close);

      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.session, isNull);
    });

    test('starts authenticated when the gateway reports a current session', () {
      final Session session = demoSession();
      final AuthCubit cubit = AuthCubit(
        _PreauthenticatedGateway(session),
        InMemoryErrorReporter(),
      );
      addTearDown(cubit.close);

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.session, session);
    });

    test('starts reauthRequired when the gateway reports an already-expired '
        'session (contract §5 — never a misleading authenticated boot)', () {
      final AuthCubit cubit = AuthCubit(
        _ExpiredSessionGateway(),
        InMemoryErrorReporter(),
      );
      addTearDown(
        cubit.close,
      ); // The expired session is not retained in the state — re-auth is
      // required and the stale session is dropped, matching restore().
      expect(cubit.state.status, AuthStatus.reauthRequired);
      expect(cubit.state.session, isNull);
    });
  });

  group('AuthCubit startDemoSession', () {
    blocTest<AuthCubit, AuthState>(
      'emits [loading, authenticated] with the contract-§5 demo session '
      'without collecting credentials',
      build: () => AuthCubit(FakeAuthGateway(), InMemoryErrorReporter()),
      act: (AuthCubit cubit) => cubit.startDemoSession(),
      expect: () => <dynamic>[
        const AuthState(status: AuthStatus.loading),
        isA<AuthState>()
            .having(
              (AuthState s) => s.status,
              'status',
              AuthStatus.authenticated,
            )
            .having((AuthState s) => s.session?.userId, 'userId', 'demo-user')
            .having(
              (AuthState s) => s.session?.displayName,
              'displayName',
              'Demo user',
            )
            .having(
              (AuthState s) => s.session?.primaryRole,
              'primaryRole',
              UserRole.client,
            )
            .having(
              (AuthState s) => s.session?.activeMembership?.organizationId,
              'organizationId',
              'org-demo',
            )
            .having(
              (AuthState s) => s.session?.isExpired,
              'isExpired',
              isFalse,
            ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [loading, error] and reports the typed failure when the gateway '
      'fails',
      setUp: () => _failingReporter = InMemoryErrorReporter(),
      build: () =>
          AuthCubit(_FailingAuthGateway(_gatewayFailure), _failingReporter),
      act: (AuthCubit cubit) => cubit.startDemoSession(),
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.loading),
        const AuthState(status: AuthStatus.error, error: _gatewayAppError),
      ],
      verify: (_) {
        // The typed failure is mapped to an AppError and reported exactly
        // once; nothing credential-shaped crosses the seam.
        expect(_failingReporter.reports, hasLength(1));
        expect(_failingReporter.reports.single['code'], 'providerUnavailable');
      },
    );

    blocTest<AuthCubit, AuthState>(
      'ignores a duplicate startDemoSession while one is in flight',
      setUp: () => _countingAuthGateway = _CountingAuthGateway(),
      build: () => AuthCubit(_countingAuthGateway, InMemoryErrorReporter()),
      act: (AuthCubit cubit) async {
        // Fire two startDemoSession calls back-to-back without awaiting
        // between them. The guard at auth_cubit.dart must keep the second
        // from emitting or calling the gateway.
        final Future<void> first = cubit.startDemoSession();
        await cubit.startDemoSession();
        await first;
      },
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.loading),
        AuthState(status: AuthStatus.authenticated, session: demoSession()),
      ],
      verify: (_) {
        expect(_countingAuthGateway.calls, 1);
      },
    );
  });

  group('AuthCubit restore (contract §5)', () {
    blocTest<AuthCubit, AuthState>(
      'emits [restoring, unauthenticated] when there is no session',
      build: () => AuthCubit(_NullSessionGateway(), InMemoryErrorReporter()),
      act: (AuthCubit cubit) => cubit.restore(),
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.restoring),
        const AuthState(status: AuthStatus.unauthenticated),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [restoring, authenticated] for a valid current session',
      build: () => AuthCubit(
        _PreauthenticatedGateway(demoSession()),
        InMemoryErrorReporter(),
      ),
      act: (AuthCubit cubit) => cubit.restore(),
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.restoring),
        AuthState(status: AuthStatus.authenticated, session: demoSession()),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [restoring, reauthRequired] for an expired session instead of a '
      'misleading authenticated state',
      build: () => AuthCubit(_ExpiredSessionGateway(), InMemoryErrorReporter()),
      act: (AuthCubit cubit) => cubit.restore(),
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.restoring),
        const AuthState(status: AuthStatus.reauthRequired),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [restoring, error] when the provider is unavailable',
      build: () => AuthCubit(
        _FailingAuthGateway(_gatewayFailure),
        InMemoryErrorReporter(),
      ),
      act: (AuthCubit cubit) => cubit.restore(),
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.restoring),
        const AuthState(status: AuthStatus.error, error: _gatewayAppError),
      ],
    );
  });

  group('AuthCubit signOut', () {
    blocTest<AuthCubit, AuthState>(
      'emits unauthenticated after an established session',
      build: () => AuthCubit(FakeAuthGateway(), InMemoryErrorReporter()),
      act: (AuthCubit cubit) async {
        await cubit.startDemoSession();
        await cubit.signOut();
      },
      expect: () => <dynamic>[
        const AuthState(status: AuthStatus.loading),
        isA<AuthState>()
            .having(
              (AuthState s) => s.status,
              'status',
              AuthStatus.authenticated,
            )
            .having((AuthState s) => s.session?.userId, 'userId', 'demo-user'),
        const AuthState(status: AuthStatus.unauthenticated),
      ],
    );
  });
}

const AuthFailure _gatewayFailure = AuthFailure(
  kind: AuthFailureKind.providerUnavailable,
  message: 'Unavailable',
);

const AppError _gatewayAppError = AppError(
  code: 'providerUnavailable',
  userMessage: 'Unavailable',
);

// Holds instances across the blocTest build/verify boundary so the tests can
// assert behavior without reaching into the Cubit's private fields.
late InMemoryErrorReporter _failingReporter;
late _CountingAuthGateway _countingAuthGateway;

class _NullSessionGateway implements AuthGateway {
  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  Future<AuthOutcome<Session>> restore() async =>
      const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.signedOut),
      );

  @override
  Future<AuthOutcome<Session>> startDemoSession() async =>
      AuthOutcome<Session>.success(demoSession());

  @override
  Future<void> signOut() async {}
}

class _PreauthenticatedGateway implements AuthGateway {
  _PreauthenticatedGateway(this.session);

  final Session session;

  @override
  Session? get currentSession => session;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  Future<AuthOutcome<Session>> restore() async =>
      AuthOutcome<Session>.success(session);

  @override
  Future<AuthOutcome<Session>> startDemoSession() async =>
      AuthOutcome<Session>.success(session);

  @override
  Future<void> signOut() async {}
}

class _ExpiredSessionGateway implements AuthGateway {
  @override
  Session? get currentSession => Session(
    userId: 'expired-user',
    displayName: 'Expired user',
    memberships: const <OrganizationMembership>[
      OrganizationMembership(
        organizationId: 'org-demo',
        organizationName: 'Demo Firm',
        role: UserRole.client,
        status: MembershipStatus.active,
      ),
    ],
    expiresAt: DateTime(2020, 1, 1),
  );

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  Future<AuthOutcome<Session>> restore() async =>
      const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.sessionExpired),
      );

  @override
  Future<AuthOutcome<Session>> startDemoSession() async =>
      AuthOutcome<Session>.success(demoSession());

  @override
  Future<void> signOut() async {}
}

class _FailingAuthGateway implements AuthGateway {
  _FailingAuthGateway(this.failure);

  final AuthFailure failure;

  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  Future<AuthOutcome<Session>> restore() async =>
      AuthOutcome<Session>.failure(failure);

  @override
  Future<AuthOutcome<Session>> startDemoSession() async =>
      AuthOutcome<Session>.failure(failure);

  @override
  Future<void> signOut() async {}
}

class _CountingAuthGateway implements AuthGateway {
  int calls = 0;

  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  Future<AuthOutcome<Session>> restore() async =>
      AuthOutcome<Session>.success(demoSession());

  @override
  Future<AuthOutcome<Session>> startDemoSession() async {
    calls += 1;
    // Delay so the in-flight call overlaps the second startDemoSession.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return AuthOutcome<Session>.success(demoSession());
  }

  @override
  Future<void> signOut() async {}
}
