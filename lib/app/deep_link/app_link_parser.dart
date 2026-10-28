/// App deep-link classification for the Phase 4.1 completion slice
/// (D-P34.2 hook — `docs/p4_1_deeplink_recovery_plan_2026-08-07.md`).
library;

import 'package:legalhub/app/deep_link/deep_link_config.dart';

/// A classified app deep link.
///
/// Sealed so the consumer (the app-link listener) must handle every case:
/// an accept-invitation share link, a Supabase auth callback (owned by the
/// explicit data-layer `AuthCallbackObserver` — this feature must NOT consume
/// it, to avoid double-consuming the PKCE code), or a non-app link.
sealed class AppLinkIntent {
  const AppLinkIntent();
}

/// An accept-invitation share link carrying the one-time token:
/// `<scheme>://accept-invite?token=<one-time-token>`.
///
/// The token is transient in-memory only (contract §8): it travels from the
/// OS intent to the accept screen via the pending store / router `extra` —
/// never the URL surface, never logs. The parser guarantees a non-empty
/// trimmed token.
final class AcceptInviteIntent extends AppLinkIntent {
  const AcceptInviteIntent(this.token);

  final String token;
}

/// A Supabase auth callback URI (`<scheme>://auth/v1/callback` —
/// recovery/sign-in links). The explicit `AuthCallbackObserver` in
/// `lib/features/auth/data/` owns these (it validates the location and exchanges the
/// query-only PKCE code); the app-link listener classifies them so it can
/// leave them alone (the recovery half of Phase 4.1 is already shipped and
/// routed via the `passwordRecovery` auth event).
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
/// `SupabaseAuthApiImpl`'s `emailRedirectTo` for the same flavor — see
/// [DeepLinkConfig].
class AppLinkParser {
  const AppLinkParser({this.config = const DeepLinkConfig.production()});

  /// The build's deep-link identity (custom scheme + verified host).
  final DeepLinkConfig config;

  /// Builds an accept-invitation share link carrying [token]:
  /// `<scheme>://accept-invite?token=<one-time-token>`.
  ///
  /// The produce side of the D-P34.2 deep link, mirroring the consume-side
  /// guarantees: the token is trimmed, and a blank token is rejected (an
  /// accept link without its one-time token is not actionable). The token
  /// is embedded on-demand and must never be persisted or logged (contract
  /// §8). The URI uses [Uri.queryParameters] so any token character is
  /// encoded; round-trips: `parse(acceptInviteUri(t))` is
  /// `AcceptInviteIntent(t)`.
  Uri acceptInviteUri(String token) => config.acceptInviteUri(token);

  AppLinkIntent parse(Uri uri) {
    // Verified https shape first: `https://legalhub.app/accept-invite?...`
    // and `https://legalhub.app/auth/v1/callback...` classify exactly like
    // their custom-scheme twins (OS-verified, not interceptable by a
    // third-party app claiming the scheme). Any other https host stays
    // foreign.
    if (uri.scheme == 'https' && uri.host == config.verifiedHost) {
      return _parsePath(uri);
    }
    if (uri.scheme != config.scheme) {
      return const NoAppLinkIntent();
    }
    return _parsePath(uri);
  }

  AppLinkIntent _parsePath(Uri uri) {
    if (uri.host == DeepLinkConfig.acceptInviteHost ||
        (uri.scheme == 'https' &&
            uri.path == '/${DeepLinkConfig.acceptInviteHost}')) {
      final String? token = uri.queryParameters['token'];
      if (token == null || token.trim().isEmpty) {
        // Never mint an empty-token intent: an accept link without its
        // one-time token is not an actionable app link.
        return const NoAppLinkIntent();
      }
      return AcceptInviteIntent(token.trim());
    }
    if (uri.host == DeepLinkConfig.authHost &&
        uri.path.startsWith(DeepLinkConfig.appCallbackPath)) {
      return const RecoveryIntent();
    }
    if (uri.scheme == 'https' &&
        uri.path.startsWith(
          '/${DeepLinkConfig.authHost}${DeepLinkConfig.appCallbackPath}',
        )) {
      return const RecoveryIntent();
    }
    return const NoAppLinkIntent();
  }
}
