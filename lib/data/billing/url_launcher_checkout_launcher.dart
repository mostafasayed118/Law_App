import 'package:legalhub/features/billing/domain/checkout_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

/// [CheckoutLauncher] backed by `package:url_launcher`.
///
/// The only billing file that imports the launcher plugin. Only `https` URIs
/// are accepted; anything else is refused without touching the platform.
class UrlLauncherCheckoutLauncher implements CheckoutLauncher {
  const UrlLauncherCheckoutLauncher();

  @override
  Future<bool> open(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}
