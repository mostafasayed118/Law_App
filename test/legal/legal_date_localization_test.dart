import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legal_config.dart';
import 'package:legalhub/features/legal/presentation/legal_document_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:material_ui/material_ui.dart';

/// RED: the legal screen must render LegalConfig.lastUpdated through the
/// locale's medium date format, never the stored ISO string.
void main() {
  testWidgets('legal last-updated date is localized in en, ar and tr', (
    WidgetTester tester,
  ) async {
    for (final String code in <String>['en', 'ar', 'tr']) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LegalDocumentScreen(kind: LegalDocumentKind.privacy),
        ),
      );
      await tester.pumpAndSettle();

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      final String localized = formatMediumDate(
        l10n,
        DateTime.parse(LegalConfig.lastUpdated),
      );
      expect(
        find.text(l10n.legalLastUpdated(LegalConfig.lastUpdated)),
        findsNothing,
        reason: '$code must not render the raw ISO date',
      );
      expect(find.text(l10n.legalLastUpdated(localized)), findsOneWidget);
    }
  });
}
