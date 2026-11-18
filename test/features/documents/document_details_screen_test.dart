import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/documents/presentation/document_details_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpDetails(
    WidgetTester tester, {
    String documentId = 'doc-1',
  }) async {
    configureDependencies();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DocumentDetailsScreen(
          documentId: documentId,
          capabilities: roleCapabilities[UserRole.client]!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the document metadata and no content affordance', (
    tester,
  ) async {
    await pumpDetails(tester);

    expect(find.text('Document details'), findsOneWidget);
    expect(find.text('Demo engagement letter'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Contract'), findsWidgets);
    expect(find.text('Matter'), findsOneWidget);
    expect(find.text('Demo acquisition review'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    // Metadata only (D-V1): no viewer, download, preview, or share.
    expect(find.byIcon(Icons.download), findsNothing);
    expect(find.byIcon(Icons.visibility), findsNothing);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
    expect(find.textContaining('Download'), findsNothing);
    expect(find.textContaining('Preview'), findsNothing);
  });

  testWidgets('unknown document renders the not-found state', (tester) async {
    await pumpDetails(tester, documentId: 'missing');
    expect(find.text('Document not found.'), findsOneWidget);
  });

  testWidgets('survives text scale 2.0 on a narrow surface', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpDetails(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Demo engagement letter'), findsOneWidget);
  });
}
