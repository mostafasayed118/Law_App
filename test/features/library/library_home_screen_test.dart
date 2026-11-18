import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/library_errors.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'package:legalhub/features/library/presentation/library_home_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/layout/two_pane.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/library_gateway_stub.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpLibrary(
    WidgetTester tester, {
    LibraryGateway? gateway,
    Size size = const Size(800, 1800),
  }) async {
    if (gateway == null) {
      configureDependencies();
    } else {
      await resetServiceLocator();
      serviceLocator.registerLazySingleton<LibraryGateway>(() => gateway);
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LibraryHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('library index', () {
    testWidgets('lists the three demo documents and their sample badges', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(tester);

      expect(find.text('Legal Library'), findsOneWidget);
      expect(find.text('قانون تجريبي للإيجارات (نموذج)'), findsOneWidget);
      expect(find.text('لائحة تجريبية لعلاقات العمل (نموذج)'), findsOneWidget);
      expect(find.text('تنظيم تجريبي للسجل التجاري (نموذج)'), findsOneWidget);
      // One badge per sample document.
      expect(find.text('Sample content'), findsNWidgets(3));
      // The demo-posture note is present, not implied.
      expect(find.textContaining('Demo mode'), findsOneWidget);
    });

    testWidgets('a category chip narrows the list', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(tester);

      await tester.tap(find.text('Labour'));
      await tester.pumpAndSettle();

      expect(find.text('لائحة تجريبية لعلاقات العمل (نموذج)'), findsOneWidget);
      expect(find.text('قانون تجريبي للإيجارات (نموذج)'), findsNothing);
    });

    testWidgets('an empty library renders the empty copy', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(
        tester,
        gateway: StubLibraryGateway(
          documents: const Success<List<LegalDocument>>(<LegalDocument>[]),
        ),
      );

      expect(find.text('No documents are available.'), findsOneWidget);
    });

    testWidgets('a failure renders the error copy with a retry', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(
        tester,
        gateway: StubLibraryGateway(
          documents: const Failure<List<LegalDocument>>(
            AppError(code: LibraryErrors.unavailableCode, userMessage: 'down'),
          ),
        ),
      );

      expect(find.text('Unable to load the library.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('the search entry opens the search surface', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(tester);

      expect(find.text('Search articles'), findsOneWidget);
    });

    testWidgets('an expanded window renders the list beside the detail', (
      WidgetTester tester,
    ) async {
      // 1200 > AppBreakpoints.expanded: master/detail, with the first document
      // auto-selected so the pane is never half-empty.
      await pumpLibrary(tester, size: const Size(1200, 1800));

      expect(find.byType(TwoPane), findsOneWidget);
      // The selected document's header renders twice: once as the list row,
      // once as the detail pane's title.
      expect(
        find.text('لائحة تجريبية لعلاقات العمل (نموذج)'),
        findsNWidgets(2),
      );
      expect(
        find.text('Informational only. Not legal advice.'),
        findsOneWidget,
      );
    });
  });
}
