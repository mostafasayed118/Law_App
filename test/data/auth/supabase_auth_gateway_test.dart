import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/data/auth/supabase_auth_api.dart';
import 'package:legalhub/data/auth/supabase_auth_gateway.dart';

/// Hand-rolled fake of the [SupabaseAuthApi] seam (codebase convention:
/// fakes over mocks for the auth boundary). Snapshot values are controlled
/// per test; no GoTrue types appear anywhere in the gateway tests.
class _FakeSupabaseAuthApi implements SupabaseAuthApi {
  _FakeSupabaseAuthApi(this.currentSnapshot);

  final StreamController<SupabaseAuthSnapshot?> _changes =
      StreamController<SupabaseAuthSnapshot?>.broadcast();

  @override
  SupabaseAuthSnapshot? currentSnapshot;

  int restoreCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<SupabaseAuthSnapshot?> get snapshotChanges => _changes.stream;

  @override
  Future<SupabaseAuthSnapshot?> restore() async {
    restoreCalls++;
    return currentSnapshot;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentSnapshot = null;
    _changes.add(null);
  }

  @override
  Future<void> dispose() async => _changes.close();

  void emit(SupabaseAuthSnapshot? snapshot) {
    currentSnapshot = snapshot;
    _changes.add(snapshot);
  }
}

void main() {
  group('SupabaseAuthGateway.restore', () {
    test('resolves a valid snapshot to an authenticated Session', () async {
      final DateTime expiresAt = DateTime.now().add(const Duration(hours: 8));
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi(
        SupabaseAuthSnapshot(
          userId: 'u-1',
          displayName: 'Amira Hassan',
          expiresAt: expiresAt,
        ),
      );
      final SupabaseAuthGateway gateway = SupabaseAuthGateway(api);
      addTearDown(gateway.dispose);

      final AuthOutcome<Session> outcome = await gateway.restore();

      expect(outcome.isSuccess, isTrue);
      final Session session = outcome.valueOrNull!;
      expect(session.userId, 'u-1');
      expect(session.displayName, 'Amira Hassan');
      // Zero tables in the dev project: no memberships to map yet.
      expect(session.memberships, isEmpty);
      expect(session.expiresAt, expiresAt);
      expect(session.isExpired, isFalse);
      expect(api.restoreCalls, 1);
    });

    test('resolves signed-out to AuthFailed(signedOut)', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi(null);
      final SupabaseAuthGateway gateway = SupabaseAuthGateway(api);
      addTearDown(gateway.dispose);

      final AuthOutcome<Session> outcome = await gateway.restore();

      expect(outcome.isSuccess, isFalse);
      expect(outcome.failureOrNull?.kind, AuthFailureKind.signedOut);
      expect(api.restoreCalls, 1);
    });

    test('resolves an expired snapshot to sessionExpired', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi(
        SupabaseAuthSnapshot(
          userId: 'u-1',
          displayName: 'Amira',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      final SupabaseAuthGateway gateway = SupabaseAuthGateway(api);
      addTearDown(gateway.dispose);

      final AuthOutcome<Session> outcome = await gateway.restore();

      expect(outcome.failureOrNull?.kind, AuthFailureKind.sessionExpired);
    });

    test(
      'a missing expiry maps to an already-expired session (never unbounded)',
      () async {
        final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi(
          const SupabaseAuthSnapshot(userId: 'u-1', displayName: 'Amira'),
        );
        final SupabaseAuthGateway gateway = SupabaseAuthGateway(api);
        addTearDown(gateway.dispose);

        final AuthOutcome<Session> outcome = await gateway.restore();

        expect(outcome.failureOrNull?.kind, AuthFailureKind.sessionExpired);
      },
    );
  });

  group('SupabaseAuthGateway token non-leak', () {
    test(
      'the seam snapshot surface is exactly userId/displayName/expiresAt',
      () {
        const SupabaseAuthSnapshot snapshot = SupabaseAuthSnapshot(
          userId: 'u-1',
          displayName: 'Amira',
          expiresAt: null,
        );

        // Pins the seam surface: no accessToken/refreshToken can be added to
        // the snapshot without this test failing (contract §2.6 redaction).
        expect(snapshot.props, <Object?>['u-1', 'Amira', null]);
      },
    );

    test('AuthFailure carries only kind and a non-sensitive message', () {
      const AuthFailure failure = AuthFailure(
        kind: AuthFailureKind.membershipDenied,
        message: 'Demo sessions are not available with a real provider.',
      );

      expect(failure.props, <Object?>[
        AuthFailureKind.membershipDenied,
        'Demo sessions are not available with a real provider.',
      ]);
    });
  });

  group('SupabaseAuthGateway sessionChanges', () {
    test('forwards provider changes as domain sessions', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi(null);
      final SupabaseAuthGateway gateway = SupabaseAuthGateway(api);
      addTearDown(gateway.dispose);

      final List<Session?> seen = <Session?>[];
      final StreamSubscription<Session?> subscription = gateway.sessionChanges
          .listen(seen.add);
      addTearDown(() => subscription.cancel());

      api.emit(
        SupabaseAuthSnapshot(
          userId: 'u-2',
          displayName: 'Mona',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(seen.single?.userId, 'u-2');
      expect(seen.single?.displayName, 'Mona');

      api.emit(null);
      await Future<void>.delayed(Duration.zero);

      expect(seen.last, isNull);
    });
  });

  group('SupabaseAuthGateway signOut', () {
    test('signs out through the provider and clears the session', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi(
        SupabaseAuthSnapshot(
          userId: 'u-1',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final SupabaseAuthGateway gateway = SupabaseAuthGateway(api);
      addTearDown(gateway.dispose);

      await gateway.signOut();

      expect(api.signOutCalls, 1);
      expect(gateway.currentSession, isNull);
    });
  });

  group('SupabaseAuthGateway startDemoSession', () {
    test('denies the demo session (membershipDenied) — never fabricates '
        'authority', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi(null);
      final SupabaseAuthGateway gateway = SupabaseAuthGateway(api);
      addTearDown(gateway.dispose);

      final AuthOutcome<Session> outcome = await gateway.startDemoSession();

      expect(outcome.isSuccess, isFalse);
      expect(outcome.failureOrNull?.kind, AuthFailureKind.membershipDenied);
      expect(gateway.currentSession, isNull);
    });
  });
}
