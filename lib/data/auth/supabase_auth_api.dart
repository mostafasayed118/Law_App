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
    this.recoveredViaLink = false,
  });

  /// Stable provider user id (contract §3.1: never an email address).
  final String userId;

  /// Display-safe name for greetings and headers; may be absent.
  final String? displayName;

  /// Expiry boundary, or null when the provider reports none. A null or
  /// past value must never map to an unbounded authenticated session.
  final DateTime? expiresAt;

  /// Whether this session was established by a password-recovery link
  /// (GoTrue's `passwordRecovery` auth event, fired by the PKCE exchange) or
  /// carries a pending recovery (`recovery_sent_at` set on the user). The
  /// consumer surfaces it so a recovery session routes to the reset step
  /// instead of being treated as a normal sign-in (Phase 4.1).
  final bool recoveredViaLink;

  @override
  List<Object?> get props => <Object?>[
    userId,
    displayName,
    expiresAt,
    recoveredViaLink,
  ];
}

/// Typed reasons a credential-based auth operation failed on the
/// [SupabaseAuthApi] seam. DTO-free by construction: GoTrue exception types
/// are mapped below the seam and never appear here (contract §5).
enum SupabaseAuthFailureKind {
  /// The email/password pair was rejected.
  invalidCredentials,

  /// The account exists but email confirmation is pending.
  emailNotConfirmed,

  /// The email is already registered (sign-up only).
  emailInUse,

  /// The account is disabled.
  userDisabled,

  /// The provider rate-limited the operation.
  rateLimited,

  /// The provider or network is unavailable.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A DTO-free, token-free failure crossing the auth API seam.
///
/// Only the [kind] and a non-sensitive [message] leave the impl; passwords,
/// tokens, and PII must never be carried here.
class SupabaseAuthFailure extends Equatable {
  const SupabaseAuthFailure({required this.kind, this.message});

  final SupabaseAuthFailureKind kind;
  final String? message;

  @override
  List<Object?> get props => <Object?>[kind, message];
}

/// Result of a credential-based sign-in / reset-request / verify operation on
/// the auth API seam.
sealed class SupabaseAuthResult {
  const SupabaseAuthResult();
}

/// The operation succeeded. [snapshot] is null for operations that succeed
/// without minting a session (e.g. a password-reset request).
final class SupabaseAuthSuccess extends SupabaseAuthResult {
  const SupabaseAuthSuccess(this.snapshot);

  final SupabaseAuthSnapshot? snapshot;
}

/// The operation failed for a typed reason.
final class SupabaseAuthFailed extends SupabaseAuthResult {
  const SupabaseAuthFailed(this.failure);

  final SupabaseAuthFailure failure;
}

/// Result of a sign-up attempt on the auth API seam.
sealed class SupabaseSignUpResult {
  const SupabaseSignUpResult();
}

/// The account was created but email confirmation is pending — no session was
/// minted. This is the success state on the dev project (email confirmation
/// is enabled, apply evidence §6).
final class SupabaseSignUpPending extends SupabaseSignUpResult {
  const SupabaseSignUpPending();
}

/// The account was created and a session was minted immediately.
final class SupabaseSignUpAuthenticated extends SupabaseSignUpResult {
  const SupabaseSignUpAuthenticated(this.snapshot);

  final SupabaseAuthSnapshot snapshot;
}

/// Sign-up failed for a typed reason.
final class SupabaseSignUpFailed extends SupabaseSignUpResult {
  const SupabaseSignUpFailed(this.failure);

  final SupabaseAuthFailure failure;
}

/// Minimal auth surface the [SupabaseAuthGateway] depends on.
///
/// Keeping this interface free of GoTrue DTOs is what guarantees provider
/// types cannot leak upward: every consumer above this seam sees only
/// [SupabaseAuthSnapshot] and the typed results below.
abstract interface class SupabaseAuthApi {
  /// The current session snapshot, or null when signed out.
  SupabaseAuthSnapshot? get currentSnapshot;

  /// Emits the snapshot on every auth-state change (null on sign-out).
  Stream<SupabaseAuthSnapshot?> get snapshotChanges;

  /// Re-reads the provider session (after `Supabase.initialize` has already
  /// restored any persisted session from local storage).
  Future<SupabaseAuthSnapshot?> restore();

  /// Credential sign-in (P3.1). Failure kinds map provider errors below the
  /// seam: invalid credentials, email-not-confirmed, user-disabled,
  /// rate-limited, or provider-unavailable.
  Future<SupabaseAuthResult> signInWithPassword({
    required String email,
    required String password,
  });

  /// Account creation (P3.1). Success resolves to pending email verification
  /// (dev project) or an authenticated snapshot. [displayName] is sent as
  /// `raw_user_meta_data.display_name` (plus the client-side display-name
  /// sources `full_name`/`name`) so the applied `handle_new_user` trigger
  /// creates the profile row with the real name.
  Future<SupabaseSignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Requests a password-recovery email (P3.1, recovery step 1). The provider
  /// acknowledges generically; the client must not enumerate whether the
  /// account exists. The implementation sends the Phase 4.1 deep-link
  /// redirect with the code-based recovery email (D1 revised).
  Future<SupabaseAuthResult> resetPasswordForEmail(String email);

  /// Verifies an emailed recovery code (P3.1, recovery step 2). Success may
  /// mint a session that [updateUserPassword] reuses.
  Future<SupabaseAuthResult> verifyOtp({
    required String email,
    required String code,
  });

  /// Sets a new password for the current session (P3.1, recovery step 3).
  /// Recovery must not leave the app authenticated: the implementation signs
  /// out after the update so the next launch starts signed-out.
  Future<SupabaseAuthResult> updateUserPassword(String newPassword);

  Future<void> signOut();

  Future<void> dispose();
}
