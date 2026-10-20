import 'package:url_launcher/url_launcher.dart';

import '../../features/storage/domain/uri_opener.dart';

/// [UriOpener] backed by `package:url_launcher`.
///
/// This is the only file that imports the launcher plugin. Only `https` URIs
/// are accepted (the signed-URL posture); anything else is refused without
/// touching the platform.
class UrlLauncherUriOpener implements UriOpener {
  const UrlLauncherUriOpener();

  @override
  Future<bool> open(Uri uri) async {
    if (uri.scheme != 'https') {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
