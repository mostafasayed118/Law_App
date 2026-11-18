// Re-applies the Flutter 3.50 design-widget delegate imports to the generated
// localization library after `flutter pub get` / `flutter gen-l10n`.
//
// WHY: Flutter 3.50 deprecates the in-SDK `package:flutter/material.dart` and
// `package:flutter/cupertino.dart` delegates. `GlobalMaterialLocalizations` and
// `GlobalCupertinoLocalizations` now come from the standalone `material_ui` and
// `cupertino_ui` packages. Flutter's own gen-l10n template still emits the old
// `package:flutter_localizations/flutter_localizations.dart` import, so CI
// silently reverted the manual import swap on every checkout and `flutter
// analyze` then failed with two deprecated_member_use diagnostics.
//
// The swap cannot live in lib/l10n/app_localizations.dart: that file is
// generated and overwritten by gen-l10n. This script is checked in, idempotent,
// and fails loudly when the expected generated block is absent, so a future
// Flutter template change cannot pass silently.
//
// Run from the repo root: dart run tool/fix_l10n_delegate_imports.dart
import 'dart:io';

const String generatedBlock = '''
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;''';

const String fixedBlock = '''
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;''';

void main() {
  const String path = 'lib/l10n/app_localizations.dart';
  final File file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('l10n fix-up FAILED: $path does not exist');
    exit(1);
  }

  String text = file.readAsStringSync().replaceAll('\r\n', '\n');
  if (!text.contains('GlobalMaterialLocalizations.delegate') ||
      !text.contains('GlobalCupertinoLocalizations.delegate')) {
    stderr.writeln(
      'l10n fix-up FAILED: $path no longer references the expected global '
      'delegates; review the Flutter 3.50 migration before proceeding',
    );
    exit(1);
  }

  if (text.contains(
    "import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;",
  )) {
    stdout.writeln(
      'l10n fix-up: delegate imports already correct (idempotent)',
    );
    return;
  }

  if (!text.contains(generatedBlock)) {
    stderr.writeln(
      'l10n fix-up FAILED: expected generated import block not found in $path; '
      'refusing to guess a replacement',
    );
    exit(1);
  }

  text = text.replaceFirst(generatedBlock, fixedBlock);
  file.writeAsStringSync(text, flush: true);
  stdout.writeln('l10n fix-up: rewrote delegate imports in $path');
}
