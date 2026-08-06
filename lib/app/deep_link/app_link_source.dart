/// Injectable deep-link source boundary for [AppLinkListener].
///
/// Kept as a plain interface so tests inject a stub stream and the adapter
/// (the only file importing the `app_links` provider) is confined to the
/// data layer — the same discipline as the Supabase API seams.
library;

abstract interface class AppLinkSource {
  /// The URI that launched the app, when there was one (cold start).
  Future<Uri?> getInitialLink();

  /// URIs arriving while the app is running (warm start).
  Stream<Uri> get onUri;
}
