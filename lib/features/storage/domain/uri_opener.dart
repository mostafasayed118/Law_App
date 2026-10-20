/// Platform seam for opening an external URI.
///
/// The implementation is the only thing that knows about the launcher plugin;
/// domain and presentation code depend on this interface.
abstract interface class UriOpener {
  /// Opens [uri] externally and reports whether a handler accepted it.
  Future<bool> open(Uri uri);
}
