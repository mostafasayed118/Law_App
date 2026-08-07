import 'dart:async';

import 'app_link_parser.dart';
import 'app_link_source.dart';
import 'pending_accept_invite_store.dart';

/// App-level deep-link listener (Phase 4.1 completion — D-P34.2 hook).
///
/// Bridges the OS intent stream to the app: every URI is classified by the
/// [AppLinkParser]; an accept-invitation share link's one-time token is
/// buffered in the [PendingAcceptInviteStore] and the caller is nudged to
/// open the accept surface. Recovery/auth-callback URIs are deliberately
/// **untouched** — supabase_flutter's `detectSessionInUri` observer owns
/// them (double-consuming the PKCE code would break recovery), so this
/// listener only forwards `AcceptInviteIntent`s.
///
/// The one-time token is never written to the URL surface or any log: it
/// travels from the OS intent straight into the in-memory store (contract
/// §8, `docs/p4_1_deeplink_recovery_plan_2026-08-07.md` D-P41.2).
class AppLinkListener {
  // Positional private initializing formals (codebase convention — mirrors
  // `AuthCubit(this._gateway, ...)`), and a plain `void Function()` instead
  // of `VoidCallback` so this file stays Flutter-free like its parser/store
  // siblings.
  AppLinkListener(
    this._links,
    this._parser,
    this._pendingStore,
    this._onAcceptInviteLink,
  );

  final AppLinkSource _links;
  final AppLinkParser _parser;
  final PendingAcceptInviteStore _pendingStore;

  /// Invoked after an accept-invite token is buffered so the app can open
  /// the accept surface (the router may bounce signed-out arrivals; the
  /// token stays pending in the store either way).
  final void Function() _onAcceptInviteLink;

  StreamSubscription<Uri>? _subscription;

  /// Begins listening: subscribes to warm-start URIs *first*, then consumes
  /// the cold-start link (the plugin holds it until requested). This is the
  /// app_links-documented order — subscribing after `await getInitialLink`
  /// would drop a warm URI arriving in that window (broadcast stream, no
  /// replay) and, worse, never subscribe at all if the initial-link fetch
  /// threw. The two channels never overlap, so no link is double-processed.
  Future<void> start() async {
    _subscription = _links.onUri.listen(_handle);
    final Uri? initial = await _links.getInitialLink();
    _handle(initial);
  }

  void _handle(Uri? uri) {
    if (uri == null) {
      return;
    }
    switch (_parser.parse(uri)) {
      case AcceptInviteIntent(:final String token):
        _pendingStore.setPendingToken(token);
        _onAcceptInviteLink();
      case RecoveryIntent() || NoAppLinkIntent():
        // Untouched: supabase_flutter owns the recovery callback; foreign
        // URIs are not app links.
        break;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
