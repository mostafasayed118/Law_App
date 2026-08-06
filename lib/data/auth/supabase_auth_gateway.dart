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
    _recoveryPending = _api.currentSnapshot?.recoveredViaLink ?? false;
    _subscription = _api.snapshotChanges.listen((
      SupabaseAuthSnapshot? snapshot,
    ) {
      _session = _toSession(snapshot);
      _recoveryPending = snapshot?.recoveredViaLink ?? false;
      _changes.add(_session);
    });
  }

  final SupabaseAuthApi _api;
  final StreamController<Session?> _changes =
      StreamController<Session?>.broadcast();
  late final StreamSubscription<SupabaseAuthSnapshot?> _subscription;

  Session? _session;
  bool _recoveryPending = false;

  @override
  Session? get currentSession => _session;

  @override
  Stream<Session?> get sessionChanges => _changes.stream;

  @override
  bool get recoveryPending => _recoveryPending;

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
    _recoveryPending = snapshot.recoveredViaLink;
    return AuthOutcome<Session>.success(session);
  }

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async {
    final SupabaseAuthResult result = await _api.signInWithPassword(
      email: email,
      password: password,
    );
    switch (result) {
      case SupabaseAuthSuccess(snapshot: final SupabaseAuthSnapshot? snapshot):
        if (snapshot == null) {
          return const AuthOutcome<Session>.failure(
            AuthFailure(kind: AuthFailureKind.signedOut),
          );
        }
        final Session? session = _toSession(snapshot);
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
        _session = session;
        _changes.add(session);
        return AuthOutcome<Session>.success(session);
      case SupabaseAuthFailed(failure: final SupabaseAuthFailure failure):
        return AuthOutcome<Session>.failure(_mapFailure(failure));
    }
  }

  /// Maps the DTO-free API failure to the domain [AuthFailure] vocabulary.
  /// [SupabaseAuthFailureKind.emailInUse] cannot occur on sign-in; it is
  /// mapped defensively to [AuthFailureKind.invalidCredentials]. An unknown
  /// provider failure surfaces as provider-unavailable (the established
  /// sign-in error surface).
  AuthFailure _mapFailure(SupabaseAuthFailure failure) {
    final AuthFailureKind kind = switch (failure.kind) {
      SupabaseAuthFailureKind.invalidCredentials =>
        AuthFailureKind.invalidCredentials,
      SupabaseAuthFailureKind.emailNotConfirmed =>
        AuthFailureKind.emailNotConfirmed,
      SupabaseAuthFailureKind.userDisabled => AuthFailureKind.userDisabled,
      SupabaseAuthFailureKind.rateLimited => AuthFailureKind.rateLimited,
      SupabaseAuthFailureKind.emailInUse => AuthFailureKind.invalidCredentials,
      SupabaseAuthFailureKind.providerUnavailable =>
        AuthFailureKind.providerUnavailable,
      SupabaseAuthFailureKind.unknown => AuthFailureKind.providerUnavailable,
    };
    return AuthFailure(kind: kind, message: failure.message);
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
    _recoveryPending = false;
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
