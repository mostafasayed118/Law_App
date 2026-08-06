import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
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
      role: UserRole.partner,
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
        FakeMembershipRepository(),
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
        FakeMembershipRepository(),
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
        FakeMembershipRepository(),
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
      build: () => AuthCubit(
        FakeAuthGateway(),
        InMemoryErrorReporter(),
        FakeMembershipRepository(),
      ),
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
              UserRole.partner,
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
      build: () => AuthCubit(
        _FailingAuthGateway(_gatewayFailure),
        _failingReporter,
        FakeMembershipRepository(),
      ),
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
      build: () => AuthCubit(
        _countingAuthGateway,
        InMemoryErrorReporter(),
        FakeMembershipRepository(),
      ),
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

  group('AuthCubit signIn (contract §5 credential path)', () {
    blocTest<AuthCubit, AuthState>(
      'emits [loading, authenticated] with the demo session on the dev fake',
      build: () => AuthCubit(
        FakeAuthGateway(),
        InMemoryErrorReporter(),
        FakeMembershipRepository(),
      ),
      act: (AuthCubit cubit) =>
          cubit.signIn(email: 'amira@example.com', password: 'any-password'),
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
              (AuthState s) => s.session?.primaryRole,
              'primaryRole',
              UserRole.partner,
            ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [loading, error] and reports the typed failure when credentials '
      'are rejected',
      setUp: () => _failingReporter = InMemoryErrorReporter(),
      build: () => AuthCubit(
        _FailingAuthGateway(_gatewayFailure),
        _failingReporter,
        FakeMembershipRepository(),
      ),
      act: (AuthCubit cubit) =>
          cubit.signIn(email: 'amira@example.com', password: 'wrong-password'),
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.loading),
        const AuthState(status: AuthStatus.error, error: _gatewayAppError),
      ],
      verify: (_) {
        expect(_failingReporter.reports, hasLength(1));
        expect(_failingReporter.reports.single['code'], 'providerUnavailable');
      },
    );

    blocTest<AuthCubit, AuthState>(
      'ignores a duplicate signIn while one is in flight',
      setUp: () => _countingAuthGateway = _CountingAuthGateway(),
      build: () => AuthCubit(
        _countingAuthGateway,
        InMemoryErrorReporter(),
        FakeMembershipRepository(),
      ),
      act: (AuthCubit cubit) async {
        final Future<void> first = cubit.signIn(
          email: 'amira@example.com',
          password: 'any-password',
        );
        await cubit.signIn(
          email: 'amira@example.com',
          password: 'any-password',
        );
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
      build: () => AuthCubit(
        _NullSessionGateway(),
        InMemoryErrorReporter(),
        FakeMembershipRepository(),
      ),
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
        FakeMembershipRepository(),
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
      build: () => AuthCubit(
        _ExpiredSessionGateway(),
        InMemoryErrorReporter(),
        FakeMembershipRepository(),
      ),
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
        FakeMembershipRepository(),
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
      build: () => AuthCubit(
        FakeAuthGateway(),
        InMemoryErrorReporter(),
        FakeMembershipRepository(),
      ),
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

  group('AuthCubit provider stream callback (Phase 4.1)', () {
    blocTest<AuthCubit, AuthState>(
      'applies a provider-initiated session that bypasses explicit calls',
      setUp: () => _streamGateway = FakeAuthGateway(),
      build: () => AuthCubit(
        _streamGateway,
        InMemoryErrorReporter(),
        FakeMembershipRepository(),
      ),
      act: (AuthCubit cubit) async {
        // The deep-link PKCE exchange never goes through signIn/restore: the
        // session lands on the gateway stream, which the cubit now consumes.
        await _streamGateway.startDemoSession();
      },
      expect: () => <dynamic>[
        isA<AuthState>()
            .having(
              (AuthState s) => s.status,
              'status',
              AuthStatus.authenticated,
            )
            .having((AuthState s) => s.session?.userId, 'userId', 'demo-user'),
      ],
    );

    test('surfaces recoveryPending for a recovery session', () async {
      final FakeAuthGateway gateway = FakeAuthGateway();
      final AuthCubit cubit = AuthCubit(
        gateway,
        InMemoryErrorReporter(),
        FakeMembershipRepository(),
      );
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      expect(cubit.recoveryPending, isFalse);

      // The provider PKCE exchange for a recovery link fires a session
      // carrying the recovery marker (supabase_flutter observer path).
      gateway.markAsRecoverySession();
      await cubit.startDemoSession();

      expect(cubit.recoveryPending, isTrue);
      expect(cubit.state.isAuthenticated, isTrue);

      await cubit.signOut();

      expect(cubit.recoveryPending, isFalse);
    });
  });

  group('AuthCubit membership hydration (P3.2 Task 8)', () {
    blocTest<AuthCubit, AuthState>(
      'hydrates memberships after a successful sign-in (loading held until '
      'hydration resolves)',
      setUp: () => _hydrationRepository = _HydrationRepository(
        result: const HydrationSucceeded(<OrganizationMembership>[
          OrganizationMembership(
            organizationId: 'org-a',
            organizationName: 'Firm A',
            role: UserRole.partner,
            status: MembershipStatus.active,
          ),
          OrganizationMembership(
            organizationId: 'org-b',
            organizationName: 'Firm B',
            role: UserRole.attorney,
            status: MembershipStatus.active,
          ),
        ]),
      ),
      build: () => AuthCubit(
        _NullSessionGateway(),
        InMemoryErrorReporter(),
        _hydrationRepository,
      ),
      act: (AuthCubit cubit) => cubit.startDemoSession(),
      expect: () => <dynamic>[
        const AuthState(status: AuthStatus.loading),
        isA<AuthState>()
            .having(
              (AuthState s) => s.status,
              'status',
              AuthStatus.authenticated,
            )
            .having(
              (AuthState s) => s.session?.memberships.length,
              'hydrated memberships',
              2,
            )
            .having(
              (AuthState s) => s.session?.primaryRole,
              'primaryRole',
              UserRole.partner,
            ),
      ],
      verify: (_) {
        // The repository is consulted exactly once, for the caller's id.
        expect(_hydrationRepository.calls, 1);
        expect(_hydrationRepository.userIds, <String>['demo-user']);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'keeps the honest empty when the provider reports no memberships',
      setUp: () => _hydrationRepository = _HydrationRepository(
        result: const HydrationSucceeded(<OrganizationMembership>[]),
      ),
      build: () => AuthCubit(
        _NullSessionGateway(),
        InMemoryErrorReporter(),
        _hydrationRepository,
      ),
      act: (AuthCubit cubit) => cubit.startDemoSession(),
      expect: () => <dynamic>[
        const AuthState(status: AuthStatus.loading),
        isA<AuthState>()
            .having(
              (AuthState s) => s.status,
              'status',
              AuthStatus.authenticated,
            )
            .having(
              (AuthState s) => s.session?.memberships,
              'memberships',
              isEmpty,
            ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'reports a hydration failure but keeps the session authenticated',
      setUp: () {
        _failingReporter = InMemoryErrorReporter();
        _hydrationRepository = _HydrationRepository(
          result: const HydrationFailed(
            MembershipHydrationFailureKind.providerUnavailable,
          ),
        );
      },
      build: () => AuthCubit(
        _NullSessionGateway(),
        _failingReporter,
        _hydrationRepository,
      ),
      act: (AuthCubit cubit) => cubit.startDemoSession(),
      expect: () => <dynamic>[
        const AuthState(status: AuthStatus.loading),
        isA<AuthState>()
            .having(
              (AuthState s) => s.status,
              'status',
              AuthStatus.authenticated,
            )
            .having(
              (AuthState s) => s.session?.memberships,
              'memberships',
              isEmpty,
            ),
      ],
      verify: (_) {
        // Diagnostic channel (Task 8 review input 2): the typed failure is
        // reported exactly once, never thrown, never a session
        // invalidation.
        expect(_failingReporter.reports, hasLength(1));
        expect(
          _failingReporter.reports.single['code'],
          'membershipHydrationFailed',
        );
      },
    );

    blocTest<AuthCubit, AuthState>(
      'never hydrates an expired session (AC-3 — reauth, not hydration)',
      setUp: () => _hydrationRepository = _HydrationRepository(),
      build: () => AuthCubit(
        _ExpiredSessionGateway(),
        InMemoryErrorReporter(),
        _hydrationRepository,
      ),
      act: (AuthCubit cubit) => cubit.restore(),
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.restoring),
        const AuthState(status: AuthStatus.reauthRequired),
      ],
      verify: (_) {
        // Expiry is honored before hydration (AC-3): the repository is
        // never consulted for an expired session.
        expect(_hydrationRepository.calls, 0);
      },
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
late FakeAuthGateway _streamGateway;
late _HydrationRepository _hydrationRepository;

class _NullSessionGateway implements AuthGateway {
  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  bool get recoveryPending => false;

  @override
  Future<AuthOutcome<Session>> restore() async =>
      const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.signedOut),
      );

  @override
  Future<AuthOutcome<Session>> startDemoSession() async =>
      AuthOutcome<Session>.success(demoSession());

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async => AuthOutcome<Session>.success(demoSession());

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
  bool get recoveryPending => false;

  @override
  Future<AuthOutcome<Session>> restore() async =>
      AuthOutcome<Session>.success(session);

  @override
  Future<AuthOutcome<Session>> startDemoSession() async =>
      AuthOutcome<Session>.success(session);

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async => AuthOutcome<Session>.success(session);

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
        role: UserRole.partner,
        status: MembershipStatus.active,
      ),
    ],
    expiresAt: DateTime(2020, 1, 1),
  );

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  bool get recoveryPending => false;

  @override
  Future<AuthOutcome<Session>> restore() async =>
      const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.sessionExpired),
      );

  @override
  Future<AuthOutcome<Session>> startDemoSession() async =>
      AuthOutcome<Session>.success(demoSession());

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async => AuthOutcome<Session>.success(demoSession());

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
  bool get recoveryPending => false;

  @override
  Future<AuthOutcome<Session>> restore() async =>
      AuthOutcome<Session>.failure(failure);

  @override
  Future<AuthOutcome<Session>> startDemoSession() async =>
      AuthOutcome<Session>.failure(failure);

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async => AuthOutcome<Session>.failure(failure);

  @override
  Future<void> signOut() async {}
}

/// Configurable membership-hydration stub for the Task 8 cubit tests:
/// records calls/userIds and returns a canned typed result.
class _HydrationRepository implements MembershipRepository {
  _HydrationRepository({
    this.result = const HydrationSucceeded(<OrganizationMembership>[]),
  });

  MembershipHydrationResult result;
  int calls = 0;
  final List<String> userIds = <String>[];

  @override
  Future<MembershipHydrationResult> loadMemberships({
    required String userId,
  }) async {
    calls += 1;
    userIds.add(userId);
    return result;
  }
}

class _CountingAuthGateway implements AuthGateway {
  int calls = 0;

  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  bool get recoveryPending => false;

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
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async {
    calls += 1;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return AuthOutcome<Session>.success(demoSession());
  }

  @override
  Future<void> signOut() async {}
}
