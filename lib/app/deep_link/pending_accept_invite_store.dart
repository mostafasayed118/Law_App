/// App-scoped, in-memory holder for a deep-linked one-time accept token
/// (Phase 4.1 completion — D-P34.2 hook).
///
/// The accept-invitation share link's token arrives through the OS intent
/// (`com.legalhub.app://accept-invite?token=...`) at cold start or while the
/// app runs — possibly before an authenticated accept screen is mounted, or
/// while the user is signed out. This holder buffers the token until the
/// accept screen consumes it. Mirrors the [BookingPrefill] precedent: a
/// transient app-scoped holder, never serialized, never logged (contract
/// §8: tokens are transient in-memory only).
class PendingAcceptInviteStore {
  String? _pendingToken;

  /// Buffers [token], replacing any prior pending token (a newer one-time
  /// invite link supersedes an older one). The [AppLinkParser] guarantees
  /// a non-empty trimmed token before it reaches this store.
  void setPendingToken(String token) {
    _pendingToken = token;
  }

  /// True while a token is waiting to be consumed by the accept screen.
  bool get hasPendingToken => _pendingToken != null;

  /// Consumes-and-clears the pending token; null when none is pending.
  ///
  /// A single consume is the contract: the one-time token must not be
  /// re-delivered on a later screen visit.
  String? takePendingToken() {
    final String? token = _pendingToken;
    _pendingToken = null;
    return token;
  }
}
