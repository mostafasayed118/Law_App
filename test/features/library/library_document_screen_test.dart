import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/data/fake_library_gateway.dart';
import 'package:legalhub/features/library/domain/legal_document_detail.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'package:legalhub/features/library/presentation/library_document_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/library_gateway_stub.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpDocument(
    WidgetTester tester, {
    LibraryGateway? gateway,
    String documentId = 'legal-doc-1',
  }) async {
    if (gateway == null) {
      configureDependencies();
    } else {
      await resetServiceLocator();
      serviceLocator.registerLazySingleton<LibraryGateway>(() => gateway);
    }
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LibraryDocumentScreen(documentId: documentId),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('document reader', () {
    testWidgets('renders the header, the sample badge and the disclaimer', (
      WidgetTester tester,
    ) async {
      await pumpDocument(tester);

      expect(find.text('قانون تجريبي للإيجارات (نموذج)'), findsOneWidget);
      expect(find.text('Sample content'), findsOneWidget);
      expect(
        find.text('Informational only. Not legal advice.'),
        findsOneWidget,
      );
    });

    testWidgets('lists every article, including the "5 مكرر" number', (
      WidgetTester tester,
    ) async {
      await pumpDocument(tester);

      expect(find.text('Articles'), findsOneWidget);
      for (final String number in <String>['1', '2', '3', '4', '5', '5 مكرر']) {
        expect(
          find.text('Article $number'),
          findsOneWidget,
          reason: 'article $number should be listed',
        );
      }
    });

    testWidgets(
      'a document with no articles says so instead of rendering blank',
      (WidgetTester tester) async {
        final LegalDocumentDetail emptyDetail = LegalDocumentDetail(
          document: FakeLibraryGateway.syntheticDocuments.first,
          articles: const <Never>[],
          articleTotal: 0,
        );
        await pumpDocument(
          tester,
          gateway: StubLibraryGateway(
            documentDetail: Success<LegalDocumentDetail>(emptyDetail),
          ),
        );

        expect(find.text('This document has no articles yet.'), findsOneWidget);
      },
    );

    testWidgets('a not-found id renders the empty arm', (
      WidgetTester tester,
    ) async {
      await pumpDocument(tester, documentId: 'legal-doc-missing');

      expect(find.text('Unable to load this document.'), findsNothing);
      expect(find.text('Nothing to show'), findsOneWidget);
    });

    testWidgets('a server failure renders the document error copy', (
      WidgetTester tester,
    ) async {
      await pumpDocument(
        tester,
        gateway: StubLibraryGateway(
          documentDetail: const Failure<LegalDocumentDetail>(
            AppError(code: 'legal_library_unavailable', userMessage: 'down'),
          ),
        ),
      );

      expect(find.text('Unable to load this document.'), findsOneWidget);
    });
  });
}
