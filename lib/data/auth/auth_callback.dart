/// The app's only accepted auth-callback deep link (2026-10-24 hardening).
///
/// The provider's own `detectSessionInUri` observer is disabled: gotrue's URL
/// parser accepts implicit-flow session material (`access_token` /
/// `refresh_token`) even on a PKCE client, so "any URI the OS hands the app"
/// must never be allowed to mint a session. This pure classifier narrows the
/// contract to:
///
/// * the registered callback location only —
///   `com.legalhub.app://auth/v1/callback` (the production flavor's custom
///   scheme, which the emailed recovery link targets) or
///   `https://legalhub.app/auth/v1/callback` (the OS-verified App Link /
///   Universal Link); and
/// * a non-empty PKCE `code` in the query string, with no implicit-flow
///   session parameters and no fragment anywhere.
///
/// Dependency-free so the accept/reject rule is unit-testable:
/// `test/data/auth/auth_callback_test.dart`.
class AuthCallbackUri {
  const AuthCallbackUri._();

  /// The custom scheme registered for the production build.
  static const String appScheme = 'com.legalhub.app';

  /// The development flavor's registered scheme. Recovery links built by a
  /// development build target this scheme, so it must classify identically.
  static const String developmentAppScheme = 'com.legalhub.app.dev';

  /// The verified https host (`web/.well-known/assetlinks.json` /
  /// `apple-app-site-association`).
  static const String verifiedHost = 'legalhub.app';

  static const String _authHost = 'auth';
  static const String _appCallbackPath = '/v1/callback';
  static const String _httpsCallbackPath = '/auth/v1/callback';

  /// Implicit-flow material the PKCE exchange must never receive.
  static const Set<String> _implicitSessionParameters = <String>{
    'access_token',
    'refresh_token',
    'provider_token',
    'provider_refresh_token',
  };

  /// The one-time PKCE code carried by [uri], or null when [uri] is not the
  /// exact auth callback or carries implicit-flow session material.
  static String? pkceCode(Uri uri) {
    final bool expectedLocation =
        ((uri.scheme == appScheme || uri.scheme == developmentAppScheme) &&
            uri.host == _authHost &&
            _isCallbackPath(uri.path, _appCallbackPath)) ||
        (uri.scheme == 'https' &&
            uri.host == verifiedHost &&
            _isCallbackPath(uri.path, _httpsCallbackPath));
    if (!expectedLocation) {
      return null;
    }
    // The PKCE callback is query-only. A fragment is implicit-flow material
    // (`#access_token=...`) and is rejected outright.
    if (uri.fragment.isNotEmpty) {
      return null;
    }
    for (final String parameter in _implicitSessionParameters) {
      if (uri.queryParameters.containsKey(parameter)) {
        return null;
      }
    }
    final String? code = uri.queryParameters['code']?.trim();
    if (code == null || code.isEmpty) {
      return null;
    }
    return code;
  }

  static bool _isCallbackPath(String path, String expected) =>
      path == expected || path == '$expected/';
}
