import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_auth_api.dart';

/// Initializes the app-level Supabase client with build-time config.
///
/// Lives in the data layer so `main.dart` (app bootstrap) never imports
/// provider types. The URL + anon public key come from `SupabaseEnv`
/// (`--dart-define-from-file=.env`); the anon-key guard in [SupabaseEnv]
/// must have run before this is called so a service-role key is refused
/// before any provider is wired (Batch 3.3).
Future<void> initializeSupabase({
  required String url,
  required String anonKey,
}) {
  // supabase_flutter ^2.16 renamed the param to publishableKey (the anon
  // public key); the env var keeps the dashboard's "anon public" naming.
  return Supabase.initialize(url: url, publishableKey: anonKey);
}

/// [SupabaseAuthApi] backed by the GoTrue auth client.
///
/// This is the **only** file that imports provider types. It maps
/// [Session] → [SupabaseAuthSnapshot], deliberately dropping access tokens,
/// refresh tokens, and provider objects at the seam (contract §5, §2.6).
class SupabaseAuthApiImpl implements SupabaseAuthApi {
  SupabaseAuthApiImpl(this._client) {
    _subscription = _client.onAuthStateChange.listen((AuthState state) {
      _changes.add(_toSnapshot(state.session));
    });
  }

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any client-shaped stub.
  factory SupabaseAuthApiImpl.bind() =>
      SupabaseAuthApiImpl(Supabase.instance.client.auth);

  final GoTrueClient _client;
  final StreamController<SupabaseAuthSnapshot?> _changes =
      StreamController<SupabaseAuthSnapshot?>.broadcast();
  late final StreamSubscription<AuthState> _subscription;

  @override
  SupabaseAuthSnapshot? get currentSnapshot =>
      _toSnapshot(_client.currentSession);

  @override
  Stream<SupabaseAuthSnapshot?> get snapshotChanges => _changes.stream;

  @override
  Future<SupabaseAuthSnapshot?> restore() async =>
      _toSnapshot(_client.currentSession);

  @override
  Future<void> signOut() => _client.signOut();

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }

  SupabaseAuthSnapshot? _toSnapshot(Session? session) {
    final User? user = session?.user;
    if (user == null) {
      return null;
    }
    // A non-null user implies a non-null session (a Session always carries
    // its user), so the bang is sound and reads better than a double-bang.
    final int? expiresAt = session!.expiresAt;
    return SupabaseAuthSnapshot(
      userId: user.id,
      displayName: _displayNameFrom(user),
      expiresAt: expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              expiresAt * Duration.millisecondsPerSecond,
              isUtc: true,
            ),
    );
  }

  /// Display-safe name: `full_name` metadata, then `name`, then the email
  /// local-part. Never the raw email (contract §3.1 privacy note).
  String? _displayNameFrom(User user) {
    final Object? fullName = user.userMetadata?['full_name'];
    if (fullName is String && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    final Object? name = user.userMetadata?['name'];
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
    final String? email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return null;
  }
}
