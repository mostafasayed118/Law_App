import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's real fonts into the test renderer so screenshot/golden
/// captures show text and icons instead of the test placeholder glyphs.
///
/// The app fonts are bundled assets. Icons are not asset-bundled; the
/// framework ships `MaterialIcons-Regular.otf` inside the Flutter SDK, so it
/// is loaded from `FLUTTER_ROOT` when available. Missing SDK/font files are
/// tolerated: the capture still renders, just with placeholder glyphs.
Future<void> loadRenderFonts() async {
  Future<void> load(String family, String asset) async {
    final FontLoader loader = FontLoader(family)
      ..addFont(rootBundle.load(asset));
    await loader.load();
  }

  await load('NotoSans', 'assets/fonts/noto_sans/NotoSans-Variable.ttf');
  await load(
    'NotoNaskhArabic',
    'assets/fonts/noto_naskh_arabic/NotoNaskhArabic-Variable.ttf',
  );
  await load(
    'PlayfairDisplay',
    'assets/fonts/playfair_display/PlayfairDisplay-Variable.ttf',
  );
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    return;
  }
  final File icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/'
    'MaterialIcons-Regular.otf',
  );
  if (!icons.existsSync()) {
    return;
  }
  final FontLoader iconLoader = FontLoader('MaterialIcons')
    ..addFont(
      Future<ByteData>.value(
        ByteData.sublistView(Uint8List.fromList(icons.readAsBytesSync())),
      ),
    );
  await iconLoader.load();
}
