import 'dart:async';

import '../../core/auth/auth_gateway.dart';
import '../../core/errors/result.dart';
import '../../core/roles/user_role.dart';

/// Development-only session implementation.
///
/// This class intentionally does not accept or store credentials. It is a
/// seam for presentation tests and bootstrap navigation only; it is not an
/// authentication mechanism and must not be used as production authorization.
class FakeAuthGateway implements AuthGateway {
  Session? _session;
  final StreamController<Session?> _changes =
      StreamController<Session?>.broadcast();

  @override
  Session? get currentSession => _session;

  @override
  Stream<Session?> get sessionChanges => _changes.stream;

  @override
  Future<Result<Session>> startDemoSession() async {
    final Session session = const Session(
      id: 'demo-session',
      displayName: 'Demo user',
      role: UserRole.client,
    );
    _session = session;
    _changes.add(session);
    return Result<Session>.success(session);
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
