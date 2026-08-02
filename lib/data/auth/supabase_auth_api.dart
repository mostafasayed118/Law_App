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

/// Typed, provider-neutral reasons a Supabase auth call can fail.
enum SupabaseAuthFailureKind {
  /// The supplied credentials were rejected by the provider.
  invalidCredentials,

  /// The email already has a registered account.
  emailInUse,

  /// The account is disabled.
  userDisabled,

  /// The provider rate-limited the request.
  rateLimited,

  /// An unspecified failure.
  unknown,
}

/// A provider-neutral auth failure crossing the [SupabaseAuthApi] seam.
///
/// The provider exception (GoTrue `AuthException`) is mapped to this type
/// inside [SupabaseAuthApiImpl], the only file allowed to import provider
/// types — no consumer above the seam ever sees a provider exception or DTO.
class SupabaseAuthException implements Exception {
  const SupabaseAuthException({required this.kind, this.message});

  final SupabaseAuthFailureKind kind;
  final String? message;

  @override
  String toString() => 'SupabaseAuthException($kind)';
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

  /// Signs in with email + password. Returns the snapshot of the new
  /// session, or throws [SupabaseAuthException] on provider rejection.
  Future<SupabaseAuthSnapshot?> signInWithPassword({
    required String email,
    required String password,
  });

  /// Creates an account with email + password and display metadata (full
  /// name, phone). No session is minted on this project: email confirmation
  /// is enabled, so sign-up ends at the verification boundary. Throws
  /// [SupabaseAuthException] on provider rejection.
  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, String> metadata,
  });

  Future<void> signOut();

  Future<void> dispose();
}
