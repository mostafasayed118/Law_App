import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/matters/presentation/matter_files_section.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
  final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

  group('fileSizeLabel', () {
    test('formats bytes, KB, and MB with a one-decimal trim', () {
      expect(fileSizeLabel(en, 512), '512 B');
      expect(fileSizeLabel(en, 245760), '240 KB');
      expect(fileSizeLabel(en, 1572864), '1.5 MB');
    });

    test('localizes the unit labels', () {
      expect(fileSizeLabel(ar, 512), '512 بايت');
      expect(fileSizeLabel(ar, 245760), '240 كيلوبايت');
      expect(fileSizeLabel(ar, 1572864), '1.5 ميغابايت');
      expect(fileSizeLabel(tr, 245760), '240 KB');
    });
  });
}
