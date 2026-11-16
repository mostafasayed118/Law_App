import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/data/fake_library_gateway.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'package:legalhub/features/library/presentation/library_article_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

import '../../support/library_gateway_stub.dart';

void main() {
  tearDown(resetServiceLocator);

  LegalArticleDetail detailAt({
    String? previous,
    String? next,
    bool documentSample = true,
  }) {
    return LegalArticleDetail(
      article: FakeLibraryGateway.syntheticArticles[2],
      documentTitleAr: 'قانون تجريبي للإيجارات (نموذج)',
      documentSample: documentSample,
      articleTotal: 6,
      previousArticleId: previous,
      nextArticleId: next,
    );
  }

  Future<void> pumpArticle(
    WidgetTester tester, {
    LibraryGateway? gateway,
    String articleId = 'legal-art-1-3',
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
        home: LibraryArticleScreen(articleId: articleId),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('article reader', () {
    testWidgets('renders the article body, its number and the position', (
      WidgetTester tester,
    ) async {
      await pumpArticle(tester);

      expect(find.text('Article 3'), findsOneWidget);
      expect(find.text('3 of 6'), findsOneWidget);
      expect(
        find.text(
          'تحدد الأجرة في العقد، ويجوز الاتفاق على مراجعتها سنوياً بنسبة متفق عليها.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sample content'), findsOneWidget);
      expect(
        find.text('Informational only. Not legal advice.'),
        findsOneWidget,
      );
    });

    testWidgets('both neighbour controls are enabled in the middle', (
      WidgetTester tester,
    ) async {
      await pumpArticle(
        tester,
        gateway: StubLibraryGateway(
          articleDetail: Success<LegalArticleDetail>(
            detailAt(previous: 'legal-art-1-2', next: 'legal-art-1-4'),
          ),
        ),
      );

      final Finder previous = find.widgetWithText(
        OutlinedButton,
        'Previous article',
      );
      final Finder next = find.widgetWithText(OutlinedButton, 'Next article');
      expect(tester.widget<OutlinedButton>(previous).onPressed, isNotNull);
      expect(tester.widget<OutlinedButton>(next).onPressed, isNotNull);
    });

    testWidgets('the first article disables Previous and keeps Next', (
      WidgetTester tester,
    ) async {
      await pumpArticle(
        tester,
        gateway: StubLibraryGateway(
          articleDetail: Success<LegalArticleDetail>(
            detailAt(next: 'legal-art-1-2'),
          ),
        ),
      );

      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Previous article'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Next article'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('tapping Next loads the neighbour id', (
      WidgetTester tester,
    ) async {
      final StubLibraryGateway gateway = StubLibraryGateway(
        articleDetail: Success<LegalArticleDetail>(
          detailAt(previous: 'legal-art-1-2', next: 'legal-art-1-4'),
        ),
      );
      await pumpArticle(tester, gateway: gateway);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Next article'));
      await tester.pumpAndSettle();

      expect(gateway.requestedArticleIds, <String>[
        'legal-art-1-3',
        'legal-art-1-4',
      ]);
    });

    testWidgets('a missing article renders the empty arm, not an error', (
      WidgetTester tester,
    ) async {
      await pumpArticle(tester, articleId: 'legal-art-missing');

      // Not-found is not retryable, so the cubit maps it to ViewEmpty.
      expect(find.text('Nothing to show'), findsOneWidget);
      expect(find.text('This article could not be found.'), findsNothing);
    });

    testWidgets('a server failure renders the reader error copy', (
      WidgetTester tester,
    ) async {
      await pumpArticle(
        tester,
        gateway: StubLibraryGateway(
          articleDetail: const Failure<LegalArticleDetail>(
            AppError(code: 'legal_library_unavailable', userMessage: 'down'),
          ),
        ),
      );

      expect(find.text('This article could not be found.'), findsOneWidget);
    });

    testWidgets('an outage keeps the retryable offline arm', (
      WidgetTester tester,
    ) async {
      await pumpArticle(
        tester,
        gateway: StubLibraryGateway(
          articleDetail: const Failure<LegalArticleDetail>(
            AppError(
              code: 'legal_library_unavailable',
              userMessage: 'down',
              kind: AppErrorKind.unavailable,
            ),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);
    });
  });
}
