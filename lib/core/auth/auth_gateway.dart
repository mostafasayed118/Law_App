import 'auth_outcome.dart';
import 'session.dart';

export 'auth_outcome.dart';
export 'session.dart';

/// Authentication integration boundary.
///
/// The domain boundary returns an application [Session] via [AuthOutcome] —
/// never raw Supabase DTOs, access tokens, refresh tokens, or provider
/// exceptions (contract §5). Bootstrap has no provider implementation; the
/// demo [startDemoSession] is the synthetic seam used by presentation.
abstract interface class AuthGateway {
  Session? get currentSession;
  Stream<Session?> get sessionChanges;

  /// Contract-§5 restore: re-check the provider session. Resolves to
  /// authenticated, signed-out (no session), expired (reauthRequired), or
  /// unavailable — never a misleading empty success.
  Future<AuthOutcome<Session>> restore();

  /// Credential sign-in (contract §5). Resolves to authenticated or a typed
  /// failure (invalidCredentials, userDisabled, providerUnavailable) — never
  /// a raw provider exception. The dev fake resolves to the demo session
  /// without accepting or storing the credentials; a configured provider
  /// signs in with them.
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  });

  /// Bootstrap-only demo path — not an authentication mechanism and must not
  /// be used as production authorization.
  Future<AuthOutcome<Session>> startDemoSession();

  Future<void> signOut();
}
