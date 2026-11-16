import 'package:legalhub/core/errors/result.dart';

/// The signed-in reader's own account mutations (ADR-0011).
///
/// Deliberately narrow: display name and account deletion. Avatar upload and
/// email change are out of scope, and neither takes a user id — identity comes
/// from the session on both sides of the seam.
abstract interface class AccountGateway {
  /// Updates the display name. Validation is server-side as well as here; the
  /// fake mirrors the same bounds so the UI cannot ship a flow the RPC refuses.
  Future<Result<void>> updateDisplayName(String displayName);

  /// Deletes the account.
  ///
  /// The RPC is SECURITY DEFINER, so an authenticated anon-key client can
  /// complete it. It hard-deletes the identity, removes the caller's own
  /// storage objects and metadata, and cascades profiles, memberships and
  /// library rows. It does NOT remove objects owned by other people or
  /// provider-side data — the confirmation screen must say exactly that.
  Future<Result<void>> deleteAccount();
}
