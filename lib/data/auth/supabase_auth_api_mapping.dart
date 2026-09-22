part of 'supabase_auth_api_impl.dart';

/// The Session→snapshot mapping helpers of [SupabaseAuthApiImpl],
/// moved verbatim as library-private top-level functions (they read no
/// instance state, so the class call sites resolve unchanged).
/// Maps a GoTrue [AuthException] to the DTO-free [SupabaseAuthFailureKind]
/// vocabulary, strictly below the seam. Status codes and message fragments
/// are the stable GoTrue surface; everything else is
/// [SupabaseAuthFailureKind.unknown] with the message preserved for
/// diagnostics.
SupabaseAuthFailureKind _failureKindFor(AuthException e) {
  // GoTrue reports the status code as a String (gotrue >= 2.26).
  if (e.statusCode == '429') {
    return SupabaseAuthFailureKind.rateLimited;
  }
  final String message = e.message.toLowerCase();
  if (message.contains('email not confirmed')) {
    return SupabaseAuthFailureKind.emailNotConfirmed;
  }
  if (message.contains('invalid login credentials') ||
      message.contains('token has expired') ||
      message.contains('token is invalid') ||
      message.contains('otp expired') ||
      message.contains('invalid token')) {
    return SupabaseAuthFailureKind.invalidCredentials;
  }
  if (message.contains('already registered')) {
    return SupabaseAuthFailureKind.emailInUse;
  }
  if (message.contains('disabled')) {
    return SupabaseAuthFailureKind.userDisabled;
  }
  return SupabaseAuthFailureKind.unknown;
}

SupabaseAuthSnapshot? _toSnapshot(
  Session? session, {
  bool recoveredViaLink = false,
}) {
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
    // Cold-restore signal: a pending recovery on the user record (the
    // `recovery_sent_at` claim) means the session is a recovery session
    // even when no `passwordRecovery` event replays (e.g. the app was
    // killed between link-open and password change).
    recoveredViaLink: recoveredViaLink || user.recoverySentAt != null,
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
