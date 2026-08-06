/// App deep-link classification for the Phase 4.1 completion slice
/// (D-P34.2 hook — `docs/p4_1_deeplink_recovery_plan_2026-08-07.md`).
library;

/// A classified app deep link.
///
/// Sealed so the consumer (the app-link listener) must handle every case:
/// an accept-invitation share link, a Supabase auth callback (owned by the
/// provider's `detectSessionInUri` observer — this feature must NOT consume
/// it, to avoid double-consuming the PKCE code), or a non-app link.
sealed class AppLinkIntent {
  const AppLinkIntent();
}

/// An accept-invitation share link carrying the one-time token:
/// `com.legalhub.app://accept-invite?token=<one-time-token>`.
///
/// The token is transient in-memory only (contract §8): it travels from the
/// OS intent to the accept screen via the pending store / router `extra` —
/// never the URL surface, never logs. The parser guarantees a non-empty
/// trimmed token.
final class AcceptInviteIntent extends AppLinkIntent {
  const AcceptInviteIntent(this.token);

  final String token;
}

/// A Supabase auth callback URI (`com.legalhub.app://auth/v1/callback` —
/// recovery/sign-in links). supabase_flutter's `detectSessionInUri` observer
/// owns these; the app-link listener classifies them so it can leave them
/// alone (the recovery half of Phase 4.1 is already shipped and routed via
/// the `passwordRecovery` auth event).
final class RecoveryIntent extends AppLinkIntent {
  const RecoveryIntent();
}

/// A URI this feature does not handle (foreign scheme/host, or an
/// accept-invite link with a missing/empty token).
final class NoAppLinkIntent extends AppLinkIntent {
  const NoAppLinkIntent();
}

/// Classifies an incoming `Uri` into an [AppLinkIntent].
///
/// Pure and dependency-free so it is trivially unit-testable: scheme →
/// host/path/query rules only, no platform code. The registered app scheme
/// must match the Android intent filter, the iOS `CFBundleURLTypes`, and
/// `SupabaseAuthApiImpl`'s `emailRedirectTo` (`com.legalhub.app`).
class AppLinkParser {
  const AppLinkParser();

  /// The registered app scheme (Android manifest + iOS Info.plist + the
  /// Supabase dashboard Redirect URL).
  static const String appScheme = 'com.legalhub.app';

  /// The accept-invitation share-link host.
  static const String acceptInviteHost = 'accept-invite';

  /// The Supabase auth callback host + path prefix. Recovery/sign-in links
  /// land here and are owned by the provider observer.
  static const String authCallbackHost = 'auth';
  static const String authCallbackPathPrefix = '/v1/callback';

  AppLinkIntent parse(Uri uri) {
    if (uri.scheme != appScheme) {
      return const NoAppLinkIntent();
    }
    if (uri.host == acceptInviteHost) {
      final String? token = uri.queryParameters['token'];
      if (token == null || token.trim().isEmpty) {
        // Never mint an empty-token intent: an accept link without its
        // one-time token is not an actionable app link.
        return const NoAppLinkIntent();
      }
      return AcceptInviteIntent(token.trim());
    }
    if (uri.host == authCallbackHost &&
        uri.path.startsWith(authCallbackPathPrefix)) {
      return const RecoveryIntent();
    }
    return const NoAppLinkIntent();
  }
}
