/// Provider-neutral seam for changing the signed-in user's password.
///
/// Deliberately separate from [AuthGateway]: that interface has many test
/// implementers, and a password change is a settings action rather than an
/// authentication transition. Adding a tenth member there would have forced
/// edits across unrelated fakes for no benefit.
library;

enum PasswordChangeFailureKind {
  /// The provider requires a recent login for this sensitive action.
  reauthRequired,

  /// No session, no network, or the provider is unavailable.
  unavailable,

  /// An unspecified failure.
  unknown,
}

class PasswordChangeException implements Exception {
  const PasswordChangeException(this.kind, {this.message});

  final PasswordChangeFailureKind kind;
  final String? message;

  @override
  String toString() => 'PasswordChangeException(${kind.name}): $message';
}

abstract interface class PasswordApi {
  /// Updates the password on the current session WITHOUT signing out. The
  /// password-recovery path signs out on purpose; a signed-in change must not.
  Future<void> changePassword(String newPassword);
}
