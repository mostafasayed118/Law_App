import 'dart:async';

import '../../core/auth/auth_gateway.dart';
import 'supabase_auth_api.dart';

/// [AuthGateway] backed by the Supabase provider via [SupabaseAuthApi].
///
/// Contract-§5 mapping happens here: [SupabaseAuthSnapshot] → domain
/// [Session]. The gateway never sees raw GoTrue DTOs or tokens — the
/// [SupabaseAuthApi] seam already stripped them.
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._api) {
    _session = _toSession(_api.currentSnapshot);
    _subscription = _api.snapshotChanges.listen((
      SupabaseAuthSnapshot? snapshot,
    ) {
      _session = _toSession(snapshot);
      _changes.add(_session);
    });
  }

  final SupabaseAuthApi _api;
  final StreamController<Session?> _changes =
      StreamController<Session?>.broadcast();
  late final StreamSubscription<SupabaseAuthSnapshot?> _subscription;

  Session? _session;

  @override
  Session? get currentSession => _session;

  @override
  Stream<Session?> get sessionChanges => _changes.stream;

  @override
  Future<AuthOutcome<Session>> restore() async {
    final SupabaseAuthSnapshot? snapshot = await _api.restore();
    if (snapshot == null) {
      return const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.signedOut),
      );
    }
    final Session session = _toSession(snapshot)!;
    if (session.isExpired) {
      return const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.sessionExpired),
      );
    }
    // Keep the gateway's own state consistent with what restore() found,
    // even when the provider stream has not re-emitted (async restore).
    _session = session;
    return AuthOutcome<Session>.success(session);
  }

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final SupabaseAuthSnapshot? snapshot = await _api.signInWithPassword(
        email: email,
        password: password,
      );
      if (snapshot == null) {
        return const AuthOutcome<Session>.failure(
          AuthFailure(
            kind: AuthFailureKind.unknown,
            message: 'Sign-in returned no session.',
          ),
        );
      }
      final Session session = _toSession(snapshot)!;
      if (session.isExpired) {
        return const AuthOutcome<Session>.failure(
          AuthFailure(kind: AuthFailureKind.sessionExpired),
        );
      }
      _session = session;
      return AuthOutcome<Session>.success(session);
    } on SupabaseAuthException catch (e) {
      // Provider-neutral mapping: the typed kind and a non-sensitive message
      // leave the seam; the GoTrue exception never does (contract §5).
      return AuthOutcome<Session>.failure(
        AuthFailure(kind: _mapFailureKind(e.kind), message: e.message),
      );
    }
  }

  AuthFailureKind _mapFailureKind(SupabaseAuthFailureKind kind) {
    return switch (kind) {
      SupabaseAuthFailureKind.invalidCredentials =>
        AuthFailureKind.invalidCredentials,
      SupabaseAuthFailureKind.userDisabled => AuthFailureKind.userDisabled,
      SupabaseAuthFailureKind.rateLimited ||
      SupabaseAuthFailureKind.unknown => AuthFailureKind.providerUnavailable,
      // Unreachable on the sign-in path (sign-up surfaces it); kept
      // exhaustive so a future kind addition fails loudly.
      SupabaseAuthFailureKind.emailInUse => AuthFailureKind.unknown,
    };
  }

  @override
  Future<AuthOutcome<Session>> startDemoSession() async {
    // A real provider must never mint a demo session (contract §5: the demo
    // path is bootstrap-only). Deny rather than fabricate an authority.
    return const AuthOutcome<Session>.failure(
      AuthFailure(
        kind: AuthFailureKind.membershipDenied,
        message: 'Demo sessions are not available with a real provider.',
      ),
    );
  }

  @override
  Future<void> signOut() async {
    await _api.signOut();
    _session = null;
    _changes.add(null);
  }

  Session? _toSession(SupabaseAuthSnapshot? snapshot) {
    if (snapshot == null) {
      return null;
    }
    // A missing expiry must never map to an unbounded authenticated session:
    // epoch 0 reads as already-expired → restore resolves to reauthRequired.
    final DateTime expiresAt =
        snapshot.expiresAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return Session(
      userId: snapshot.userId,
      displayName: snapshot.displayName ?? 'User',
      // The dev project has zero tables; organization memberships load is a
      // later data slice. Empty is honest, not a placeholder.
      memberships: const <OrganizationMembership>[],
      expiresAt: expiresAt,
    );
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
    await _api.dispose();
  }
}
