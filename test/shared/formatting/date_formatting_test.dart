import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';

// E6 extraction pins: the centralized yMMMd helper must produce the same
// locale-aware output the 12 inlined DateFormat.yMMMd(l10n.localeName) sites
// produced, in English and Arabic. initializeDateFormatting loads the intl
// date symbols that widget tests get via the localizations delegates.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ar');
  });

  group('formatMediumDate (yMMMd)', () {
    test('formats an English date with the yMMMd pattern', () {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
      final DateTime date = DateTime.utc(2026, 8, 10);

      expect(formatMediumDate(l10n, date), 'Aug 10, 2026');
    });

    test('formats an Arabic date with the Arabic month name', () {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
      final DateTime date = DateTime.utc(2026, 8, 10);

      final String formatted = formatMediumDate(l10n, date);
      // The Arabic yMMMd pattern renders the Arabic month name (August =
      // أغسطس), never the English fallback.
      expect(formatted, contains('أغسطس'));
      expect(formatted, isNot(contains('Aug')));
    });

    test('is identical to the pre-extraction DateFormat.yMMMd call', () {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
      final DateTime date = DateTime.utc(2026, 3, 5);

      expect(formatMediumDate(l10n, date), 'Mar 5, 2026');
    });
  });

  group('formatMediumDateTime (yMMMd + jm)', () {
    test('adds the locale time, byte-identical to the pre-extraction call', () {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
      final DateTime date = DateTime.utc(2026, 8, 10, 15, 45);

      // The pre-extraction shape was DateFormat.yMMMd(locale).add_jm();
      // assert the helper is byte-identical (the intl output carries a
      // narrow no-break space before PM, which a hand-written literal
      // would not match).
      final String expected = DateFormat.yMMMd(
        l10n.localeName,
      ).add_jm().format(date);
      expect(formatMediumDateTime(l10n, date), expected);
      expect(formatMediumDateTime(l10n, date), contains('3:45'));
      expect(formatMediumDateTime(l10n, date), contains('PM'));
    });
  });
}
