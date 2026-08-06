import 'package:app_links/app_links.dart';

import 'app_link_source.dart';

/// [AppLinkSource] backed by the `app_links` plugin.
///
/// The only file that imports the provider (same discipline as the Supabase
/// API impls): the listener talks to [AppLinkSource], never to `app_links`.
class AppLinksPluginSource implements AppLinkSource {
  final AppLinks _links = AppLinks();

  @override
  Future<Uri?> getInitialLink() => _links.getInitialLink();

  @override
  Stream<Uri> get onUri => _links.uriLinkStream;
}
