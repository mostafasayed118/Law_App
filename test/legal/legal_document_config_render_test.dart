import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legal_config.dart';
import 'package:legalhub/features/legal/presentation/legal_document_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// F-T6-01: the operator identity must be verifiable inside the app, not only
/// in the hostable policy drafts. Kept in its own file because mounting two
/// LegalDocumentScreen widgets with rootBundle-backed futures in one test
/// file leaves the second FutureBuilder waiting in the widget-test harness.
void main() {
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
        reason:
            'LegalConfig value "$value" must be visible in the legal screen',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
