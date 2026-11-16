import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/legal_search_hit.dart';
import 'package:legalhub/features/library/domain/library_errors.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'package:legalhub/features/library/presentation/library_search_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

import '../../support/library_gateway_stub.dart';

void main() {
  tearDown(resetServiceLocator);

  const LegalSearchHit hit = LegalSearchHit(
    articleId: 'legal-art-1-1',
    documentId: 'legal-doc-1',
    documentTitleAr: 'قانون تجريبي للإيجارات (نموذج)',
    category: LegalCategory.civil,
    status: LegalStatus.inForce,
    articleNumber: '1',
    snippet: 'ينظم هذا النموذج عقد [[الايجار]] بين الأطراف.',
    articleSample: true,
    documentSample: true,
  );

  Future<void> pumpSearch(
    WidgetTester tester, {
    LibraryGateway? gateway,
    String initialQuery = '',
  }) async {
    if (gateway == null) {
      configureDependencies();
    } else {
      await resetServiceLocator();
      serviceLocator.registerLazySingleton<LibraryGateway>(() => gateway);
    }
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LibrarySearchScreen(initialQuery: initialQuery),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('library search', () {
    testWidgets('opens on the no-query arm, not a spinner or an error', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester);

      expect(find.text('Type a word to search the articles.'), findsOneWidget);
    });

    testWidgets('a seeded query runs immediately and renders hits', (
      WidgetTester tester,
    ) async {
      await pumpSearch(
        tester,
        gateway: StubLibraryGateway(
          hits: const Success<List<LegalSearchHit>>(<LegalSearchHit>[hit]),
        ),
        initialQuery: 'ايجار',
      );

      expect(find.textContaining('قانون تجريبي للإيجارات'), findsOneWidget);
      // The sample badge is on the hit, not only on its document screen.
      expect(find.text('Sample content'), findsOneWidget);
    });

    testWidgets('typing then submitting runs the search', (
      WidgetTester tester,
    ) async {
      final StubLibraryGateway gateway = StubLibraryGateway(
        hits: const Success<List<LegalSearchHit>>(<LegalSearchHit>[hit]),
      );
      await pumpSearch(tester, gateway: gateway);

      await tester.enterText(find.byType(TextField), 'ايجار');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(gateway.requestedQueries, contains('ايجار'));
      expect(find.text('Sample content'), findsOneWidget);
    });

    testWidgets('no hits renders the no-results copy, distinct from no query', (
      WidgetTester tester,
    ) async {
      await pumpSearch(
        tester,
        gateway: StubLibraryGateway(
          hits: const Success<List<LegalSearchHit>>(<LegalSearchHit>[]),
        ),
        initialQuery: 'zzzz',
      );

      expect(find.text('No articles match this search.'), findsOneWidget);
      expect(find.text('Type a word to search the articles.'), findsNothing);
    });

    testWidgets('a failed search renders its own error copy', (
      WidgetTester tester,
    ) async {
      await pumpSearch(
        tester,
        gateway: StubLibraryGateway(
          hits: const Failure<List<LegalSearchHit>>(
            AppError(code: LibraryErrors.unavailableCode, userMessage: 'down'),
          ),
        ),
        initialQuery: 'ايجار',
      );

      expect(find.text('Unable to search the library.'), findsOneWidget);
    });
  });
}
