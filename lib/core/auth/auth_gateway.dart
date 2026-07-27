import '../errors/result.dart';
import '../roles/user_role.dart';

class Session {
  const Session({
    required this.id,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String displayName;
  final UserRole role;
}

/// Authentication integration boundary. This bootstrap deliberately has no
/// credential methods and no Supabase implementation.
abstract interface class AuthGateway {
  Session? get currentSession;
  Stream<Session?> get sessionChanges;
  Future<Result<Session>> startDemoSession();
  Future<void> signOut();
}
