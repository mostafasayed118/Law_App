/// Opens a provider-hosted checkout URL in the platform browser.
///
/// Kept as a domain seam so the sheet never imports a launcher plugin and
/// tests inject a recording fake. Implementations must accept `https` only.
abstract interface class CheckoutLauncher {
  Future<bool> open(Uri uri);
}
