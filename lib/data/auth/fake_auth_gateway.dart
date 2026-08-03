import 'dart:async';

import '../../core/auth/auth_gateway.dart';
import '../../core/roles/user_role.dart';

/// Development-only session implementation.
///
/// This class intentionally does not accept or store credentials. It is a
/// seam for presentation tests and bootstrap navigation only; it is not an
/// authentication mechanism and must not be used as production authorization.
///
/// The demo session carries the contract-§5 shape: a stable [Session.userId],
/// organization [Session.memberships] with explicit lifecycle status (no
/// single client-owned `role` on the session), and a [Session.expiresAt]
/// boundary.
class FakeAuthGateway implements AuthGateway {
  Session? _session;
  bool _recoveryPending = false;
  // Sync delivery: events reach listeners in the caller's zone. Without it,
  // a cubit constructed outside a `testWidgets` FakeAsync zone would receive
  // the session on a real-zone microtask the test clock never flushes, and
  // the widget would stay on the loading spinner forever.
  final StreamController<Session?> _changes =
      StreamController<Session?>.broadcast(sync: true);

  /// The demo active membership, shared by the synthetic session.
  static const OrganizationMembership demoMembership = OrganizationMembership(
    organizationId: 'org-demo',
    organizationName: 'Demo Firm',
    role: UserRole.client,
    status: MembershipStatus.active,
  );

  @override
  Session? get currentSession => _session;

  @override
  Stream<Session?> get sessionChanges => _changes.stream;

  @override
  bool get recoveryPending => _recoveryPending;

  /// Marks the demo as in a recovery session (Phase 4.1 test seam): the
  /// demo equivalent of a PKCE session that arrived via a recovery link.
  ///
  /// Like the real gateway, the flag stays set while the recovery session is
  /// current — it clears on [signOut] (the reset flow's exit), mirroring how
  /// a provider recovery session keeps its marker until it is replaced or
  /// signed out.
  void markAsRecoverySession() {
    _recoveryPending = true;
  }

  @override
  Future<AuthOutcome<Session>> restore() async {
    final Session? session = _session;
    if (session == null) {
      return const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.signedOut),
      );
    }
    if (session.isExpired) {
      return const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.sessionExpired),
      );
    }
    return AuthOutcome<Session>.success(session);
  }

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async {
    // The dev fake never accepts or stores the credentials; like
    // startDemoSession it resolves to the demo session so env-less runs and
    // tests exercise the full sign-in submit path without a provider.
    return startDemoSession();
  }

  @override
  Future<AuthOutcome<Session>> startDemoSession() async {
    final Session session = Session(
      userId: 'demo-user',
      displayName: 'Demo user',
      memberships: const <OrganizationMembership>[demoMembership],
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
    );
    _session = session;
    _changes.add(session);
    return AuthOutcome<Session>.success(session);
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _recoveryPending = false;
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
