import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_callback.dart';

/// The app's only consumer of auth-callback deep links.
///
/// Supabase's `detectSessionInUri` observer is disabled in
/// `initializeSupabase`; this observer replaces it so the accept rule lives in
/// app code. An incoming URI must classify through [AuthCallbackUri.pkceCode]
/// (registered location + query-only PKCE code, no implicit-flow material);
/// only then is the one-time code exchanged against the PKCE verifier kept in
/// secure storage. Every other URI is ignored without logging — the URI and
/// its code are transient secrets.
///
/// Started once from `SupabaseAuthApiImpl.bind` (the app-level client is a
/// singleton and the gateway / recovery / sign-up APIs share it).
abstract final class AuthCallbackObserver {
  static bool _started = false;

  /// Idempotent: subsequent `bind` calls reuse the running observer.
  static void ensureStarted() {
    if (_started) {
      return;
    }
    _started = true;
    // Mobile only: there is no Flutter web build; `web/` only serves the
    // site-association files. Warm links arrive on the stream; the cold-start
    // link is fetched explicitly because another listener may consume the
    // stream's one-shot replay. A duplicate classification is harmless — the
    // second PKCE exchange fails closed and is swallowed.
    final AppLinks links = AppLinks();
    links.uriLinkStream.listen(
      (Uri uri) => unawaited(_accept(uri)),
      onError: (Object _) {
        // A malformed platform link must never take the app down.
      },
    );
    unawaited(
      links.getInitialLink().then((Uri? uri) {
        if (uri != null) {
          return _accept(uri);
        }
      }),
    );
  }

  static Future<void> _accept(Uri uri) async {
    final String? code = AuthCallbackUri.pkceCode(uri);
    if (code == null) {
      return;
    }
    try {
      // Narrow PKCE exchange: no implicit-flow fallback. The provider binds
      // the code to this device's stored verifier and fires
      // `passwordRecovery` for recovery codes.
      await Supabase.instance.client.auth.exchangeCodeForSession(code);
    } on AuthException {
      // Expired, replayed, or not paired with this device's verifier.
      return;
    } on Object {
      // A transport failure triggered by an OS intent must not crash the app.
      return;
    }
  }
}
