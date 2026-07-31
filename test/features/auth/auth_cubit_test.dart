import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';

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
      final Session session = Session(
        id: 'existing-session',
        displayName: 'Existing user',
        role: UserRole.attorney,
      );
      final AuthCubit cubit = AuthCubit(
        _PreauthenticatedGateway(session),
        InMemoryErrorReporter(),
      );
      addTearDown(cubit.close);

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.session, session);
    });
  });

  group('AuthCubit startDemoSession', () {
    blocTest<AuthCubit, AuthState>(
      'emits [loading, authenticated] for a local demo session without '
      'collecting credentials',
      build: () => AuthCubit(FakeAuthGateway(), InMemoryErrorReporter()),
      act: (AuthCubit cubit) => cubit.startDemoSession(),
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.authenticated,
          session: Session(
            id: 'demo-session',
            displayName: 'Demo user',
            role: UserRole.client,
          ),
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [loading, error] and reports a redacted error when the gateway '
      'fails',
      setUp: () => _failingReporter = InMemoryErrorReporter(),
      build: () => AuthCubit(
        _FailingAuthGateway(_gatewayFailure),
        _failingReporter,
      ),
      act: (AuthCubit cubit) => cubit.startDemoSession(),
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.loading),
        AuthState(status: AuthStatus.error, error: _gatewayFailure),
      ],
      verify: (_) {
        // Privacy-by-design guard: the email-shaped PII in the error context
        // must reach the reporter masked, never in clear text.
        expect(_failingReporter.reports, hasLength(1));
        final Map<String, Object?> context =
            _failingReporter.reports.single['context']!
                as Map<String, Object?>;
        expect(context['email'], '[REDACTED]');
      },
    );

    blocTest<AuthCubit, AuthState>(
      'ignores a duplicate startDemoSession while one is in flight',
      setUp: () => _countingAuthGateway = _CountingAuthGateway(),
      build: () => AuthCubit(_countingAuthGateway, InMemoryErrorReporter()),
      act: (AuthCubit cubit) async {
        // Fire two startDemoSession calls back-to-back without awaiting
        // between them. The guard at auth_cubit.dart:20 must keep the second
        // from emitting or calling the gateway.
        final Future<void> first = cubit.startDemoSession();
        await cubit.startDemoSession();
        await first;
      },
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.authenticated,
          session: Session(
            id: 'demo-session',
            displayName: 'Demo user',
            role: UserRole.client,
          ),
        ),
      ],
      verify: (_) {
        expect(_countingAuthGateway.calls, 1);
      },
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
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.authenticated,
          session: Session(
            id: 'demo-session',
            displayName: 'Demo user',
            role: UserRole.client,
          ),
        ),
        const AuthState(status: AuthStatus.unauthenticated),
      ],
    );
  });
}

const AppError _gatewayFailure = AppError(
  code: 'unavailable',
  userMessage: 'Unavailable',
  context: <String, Object?>{'email': 'person@example.com'},
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
  Future<Result<Session>> startDemoSession() async =>
      Result<Session>.success(
        const Session(
          id: 'demo-session',
          displayName: 'Demo user',
          role: UserRole.client,
        ),
      );

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
  Future<Result<Session>> startDemoSession() async =>
      Result<Session>.success(session);

  @override
  Future<void> signOut() async {}
}

class _FailingAuthGateway implements AuthGateway {
  _FailingAuthGateway(this.error);

  final AppError error;

  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  Future<Result<Session>> startDemoSession() async =>
      Result<Session>.failure(error);

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
  Future<Result<Session>> startDemoSession() async {
    calls += 1;
    // Delay so the in-flight call overlaps the second startDemoSession.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return Result<Session>.success(
      const Session(
        id: 'demo-session',
        displayName: 'Demo user',
        role: UserRole.client,
      ),
    );
  }

  @override
  Future<void> signOut() async {}
}
