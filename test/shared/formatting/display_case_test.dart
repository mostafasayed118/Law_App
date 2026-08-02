import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/shared/formatting/display_case.dart';

void main() {
  const Locale en = Locale('en');
  const Locale tr = Locale('tr');
  const Locale ar = Locale('ar');

  group('displayUppercase', () {
    test('keeps plain ASCII uppercase under English', () {
      expect(displayUppercase('view all', en), 'VIEW ALL');
      expect(displayUppercase('Active Case', en), 'ACTIVE CASE');
      expect(displayUppercase('EMAIL', en), 'EMAIL');
    });

    test('is a no-op on already-uppercase text', () {
      expect(displayUppercase('VIEW ALL', en), 'VIEW ALL');
      expect(displayUppercase('SKIP', tr), 'SKIP');
    });

    test('maps dotted i to dotted capital I under Turkish', () {
      // 'skip' -> 'SKİP' — Dart's plain toUpperCase would produce 'SKIP'.
      expect(displayUppercase('skip', tr), 'SKİP');
      expect(displayUppercase('ip adresi', tr), 'İP ADRESİ');
    });

    test('maps dotless i (ı) to dotless capital I under Turkish', () {
      // 'ıslak' -> 'ISLAK' — a naive I->İ replace-all would corrupt this.
      expect(displayUppercase('ıslak', tr), 'ISLAK');
    });

    test('leaves Arabic display text untouched', () {
      const String arabic = 'حالة نشطة';
      expect(displayUppercase(arabic, ar), arabic);
      expect(displayUppercase(arabic, en), arabic);
    });

    test('handles mixed-case phrases with Turkish correctly', () {
      expect(displayUppercase('İncele', tr), 'İNCELE');
    });
  });
}
