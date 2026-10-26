import 'package:legalhub/app/flavor.dart';

/// Flavor-scoped deep-link identity: the custom scheme this build answers to
/// plus the verified https host and the auth-callback location shapes.
///
/// The custom scheme is the build's `APPLICATION_ID` ([AppConfig
/// .deepLinkScheme]): production owns `com.legalhub.app`, development owns
/// `com.legalhub.app.dev`, so a dev install cannot intercept production
/// recovery links. The verified https host and both callback shapes are
/// shared across flavors.
class DeepLinkConfig {
  const DeepLinkConfig({
    required this.scheme,
    this.verifiedHost = 'legalhub.app',
    this.acceptedSchemes = const <String>{
      'com.legalhub.app',
      'com.legalhub.app.dev',
    },
  });

  /// The store-facing configuration (un-suffixed application ID).
  const DeepLinkConfig.production()
    : scheme = 'com.legalhub.app',
      verifiedHost = 'legalhub.app',
      acceptedSchemes = const <String>{
        'com.legalhub.app',
        'com.legalhub.app.dev',
      };

  /// The configuration for [config]'s flavor (its [AppConfig.deepLinkScheme]).
  factory DeepLinkConfig.forConfig(AppConfig config) =>
      DeepLinkConfig(scheme: config.deepLinkScheme);

  /// The custom scheme this build registers (Android intent filter /
  /// iOS `CFBundleURLTypes`).
  final String scheme;

  /// The verified https host for OS-verified App Links / Universal Links
  /// (`https://legalhub.app/.well-known/`).
  final String verifiedHost;

  /// Schemes whose auth callbacks classify. Both flavors' schemes stay
  /// accepted so a recovery link minted for either build is recognised.
  final Set<String> acceptedSchemes;

  /// The accept-invitation share-link host.
  static const String acceptInviteHost = 'accept-invite';

  /// The Supabase auth callback host + paths.
  static const String authHost = 'auth';
  static const String appCallbackPath = '/v1/callback';
  static const String httpsCallbackPath = '/auth/v1/callback';

  /// Builds an accept-invitation share link carrying [token]:
  /// `<scheme>://accept-invite?token=<one-time-token>`.
  ///
  /// The token is trimmed and a blank token is rejected: an accept link
  /// without its one-time token is not actionable. The token is embedded
  /// on-demand and must never be persisted or logged (contract §8).
  Uri acceptInviteUri(String token) {
    final String trimmed = token.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(token, 'token', 'must be a non-empty token');
    }
    return Uri(
      scheme: scheme,
      host: acceptInviteHost,
      queryParameters: <String, String>{'token': trimmed},
    );
  }

  /// Builds this build's auth-callback URI:
  /// `<scheme>://auth/v1/callback` (the recovery email's link target).
  Uri authCallbackUri() =>
      Uri(scheme: scheme, host: authHost, path: appCallbackPath);
}
