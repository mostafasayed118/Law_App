import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/features/auth/domain/auth_gateway.dart';
import 'package:legalhub/features/auth/domain/auth_state.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/orgs/data/fake_membership_repository.dart';
import 'package:legalhub/features/orgs/data/fake_organization_gateway.dart';

/// Contract-§5 session used by the synthetic gateways.
Session _session() => Session(
  userId: 'google-user',
  displayName: 'Google user',
  memberships: const <OrganizationMembership>[],
  expiresAt: DateTime(2030, 1, 1),
);

/// Stub gateway whose Google launch result is fixed and whose session stream
/// stays empty: these tests observe only the launch leg of the two-legged
/// OAuth flow (the session leg is the provider stream, covered by the gateway
/// and callback tests).
class _GoogleLaunchGateway implements AuthGateway {
  _GoogleLaunchGateway({required this.launchResult});

  final bool launchResult;
  int launchCalls = 0;

  @override
  Future<bool> startGoogleSignIn() async {
    launchCalls++;
    return launchResult;
  }

  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  bool get recoveryPending => false;

  @override
  bool get supportsDemoSession => false;

  @override
  Future<AuthOutcome<Session>> restore() async =>
      const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.signedOut),
      );

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async => const AuthOutcome<Session>.failure(
    AuthFailure(kind: AuthFailureKind.providerUnavailable),
  );

  @override
  Future<AuthOutcome<Session>> startDemoSession() async =>
      const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.membershipDenied),
      );

  @override
  Future<void> signOut() async {}
}

/// Already-authenticated stub: Google must be a no-op, not a state churn.
class _AuthenticatedGateway implements AuthGateway {
  _AuthenticatedGateway(this._session);

  final Session _session;
  int launchCalls = 0;

  @override
  Future<bool> startGoogleSignIn() async {
    launchCalls++;
    return false;
  }

  @override
  Session? get currentSession => _session;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  bool get recoveryPending => false;

  @override
  bool get supportsDemoSession => false;

  @override
  Future<AuthOutcome<Session>> restore() async =>
      AuthOutcome<Session>.success(_session);

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async => AuthOutcome<Session>.success(_session);

  @override
  Future<AuthOutcome<Session>> startDemoSession() async =>
      const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.membershipDenied),
      );

  @override
  Future<void> signOut() async {}
}

AuthCubit _cubit(AuthGateway gateway) => AuthCubit(
  gateway,
  InMemoryErrorReporter(),
  FakeMembershipRepository(),
  FakeOrganizationGateway(),
);

void main() {
  group('AuthCubit.signInWithGoogle — browser hand-off', () {
    test(
      'a launched browser returns to the signed-out surface, not an error',
      () async {
        final _GoogleLaunchGateway gateway = _GoogleLaunchGateway(
          launchResult: true,
        );
        final AuthCubit cubit = _cubit(gateway);
        addTearDown(cubit.close);

        await cubit.signInWithGoogle();

        expect(gateway.launchCalls, 1);
        // The session only exists after the callback code is exchanged; a
        // successful launch must not leave the screen spinning or claim a login.
        expect(cubit.state.status, AuthStatus.unauthenticated);
        expect(cubit.state.session, isNull);
      },
    );

    test(
      'a refused launch lands on the provider-unavailable error state',
      () async {
        final _GoogleLaunchGateway gateway = _GoogleLaunchGateway(
          launchResult: false,
        );
        final AuthCubit cubit = _cubit(gateway);
        addTearDown(cubit.close);

        await cubit.signInWithGoogle();

        expect(gateway.launchCalls, 1);
        expect(cubit.state.status, AuthStatus.error);
        expect(
          cubit.state.error?.code,
          AuthFailureKind.providerUnavailable.name,
        );
      },
    );

    test('is a no-op while a session is already authenticated', () async {
      final _AuthenticatedGateway gateway = _AuthenticatedGateway(_session());
      final AuthCubit cubit = _cubit(gateway);
      addTearDown(cubit.close);

      await cubit.signInWithGoogle();

      expect(gateway.launchCalls, 0);
      expect(cubit.state.status, AuthStatus.authenticated);
    });
  });
}
