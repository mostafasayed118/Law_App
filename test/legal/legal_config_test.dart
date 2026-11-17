import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legal_config.dart';
import 'package:legalhub/features/legal/presentation/legal_document_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Pins the owner-confirmed LegalConfig values and proves the privacy screen
/// renders them through the existing localisation path (no new formatting).
void main() {
  test('owner-confirmed config values are filled and configured', () {
    expect(LegalConfig.operatorName, 'AL-3TAR');
    expect(LegalConfig.contactEmail, 'al3rar401@gmail.com');
    expect(LegalConfig.lastUpdated, '2026-11-17');
    expect(LegalConfig.governingLaw, 'Laws of Egypt');
    expect(LegalConfig.isConfigured, isTrue);
    for (final String value in <String>[
      LegalConfig.operatorName,
      LegalConfig.contactEmail,
      LegalConfig.lastUpdated,
      LegalConfig.governingLaw,
    ]) {
      expect(value.trim(), isNotEmpty);
      expect(value.startsWith('REPLACE_'), isFalse);
    }
  });

  testWidgets('privacy screen renders the filled last-updated date', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LegalDocumentScreen(kind: LegalDocumentKind.privacy),
      ),
    );
    await tester.pumpAndSettle();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(LegalDocumentScreen)),
    );
    expect(find.text(l10n.legalLastUpdated('2026-11-17')), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // F-T6-01: the operator identity must be verifiable in-app, not only in docs.
  testWidgets('privacy screen renders operator, contact and governing law', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LegalDocumentScreen(kind: LegalDocumentKind.privacy),
      ),
    );
    await tester.pumpAndSettle();

    for (final String value in <String>[
      LegalConfig.operatorName,
      LegalConfig.contactEmail,
      LegalConfig.governingLaw,
    ]) {
      expect(
        find.text(value),
        findsOneWidget,
        reason: 'LegalConfig value "$value" must be visible in the legal screen',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
