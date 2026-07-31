import 'package:equatable/equatable.dart';

/// Provider-neutral snapshot of the authenticated user that crosses the
/// [SupabaseAuthApi] seam.
///
/// Deliberately carries **no tokens**: access and refresh tokens live only
/// inside the provider implementation and never appear on this type
/// (contract §5, auth_tenant_authorization_contract.md §2.6). Every field is
/// display/session-safe: a stable [userId], a display name, and an expiry
/// boundary.
class SupabaseAuthSnapshot extends Equatable {
  const SupabaseAuthSnapshot({
    required this.userId,
    this.displayName,
    this.expiresAt,
  });

  /// Stable provider user id (contract §3.1: never an email address).
  final String userId;

  /// Display-safe name for greetings and headers; may be absent.
  final String? displayName;

  /// Expiry boundary, or null when the provider reports none. A null or
  /// past value must never map to an unbounded authenticated session.
  final DateTime? expiresAt;

  @override
  List<Object?> get props => <Object?>[userId, displayName, expiresAt];
}

/// Minimal auth surface the [SupabaseAuthGateway] depends on.
///
/// Keeping this interface free of GoTrue DTOs is what guarantees provider
/// types cannot leak upward: every consumer above this seam sees only
/// [SupabaseAuthSnapshot].
abstract interface class SupabaseAuthApi {
  /// The current session snapshot, or null when signed out.
  SupabaseAuthSnapshot? get currentSnapshot;

  /// Emits the snapshot on every auth-state change (null on sign-out).
  Stream<SupabaseAuthSnapshot?> get snapshotChanges;

  /// Re-reads the provider session (after `Supabase.initialize` has already
  /// restored any persisted session from local storage).
  Future<SupabaseAuthSnapshot?> restore();

  Future<void> signOut();

  Future<void> dispose();
}
