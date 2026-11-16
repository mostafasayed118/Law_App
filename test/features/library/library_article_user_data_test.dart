import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/data/fake_library_gateway.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'package:legalhub/features/library/presentation/library_article_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

import '../../support/library_user_data_stub.dart';

/// The reader's per-user layer as the user actually meets it: a bookmark icon
/// that flips on tap, highlights painted behind their words, and an honest
/// treatment for a highlight whose text has since changed.
void main() {
  tearDown(resetServiceLocator);

  LegalBookmark bookmarkFor(String articleId) => LegalBookmark(
    id: 'bm-1',
    articleId: articleId,
    documentId: 'legal-doc-1',
    documentTitleAr: 'قانون تجريبي للإيجارات (نموذج)',
    articleNumber: '3',
    articleSample: true,
    documentSample: true,
    createdAt: DateTime.utc(2026, 11, 16),
  );

  LegalHighlight highlightFor(String articleId, {required bool stale}) =>
      LegalHighlight(
        id: stale ? 'hl-stale' : 'hl-1',
        articleId: articleId,
        documentId: 'legal-doc-1',
        documentTitleAr: 'قانون تجريبي للإيجارات (نموذج)',
        articleNumber: '3',
        startOffset: 0,
        endOffset: 6,
        quote: 'تحدد الا',
        color: HighlightColorSlot.green,
        isStale: stale,
        articleSample: true,
        documentSample: true,
        createdAt: DateTime.utc(2026, 11, 16),
      );

  Future<StubLibraryUserDataGateway> pumpArticle(
    WidgetTester tester, {
    bool bookmarked = false,
    List<LegalHighlight> highlights = const <LegalHighlight>[],
  }) async {
    const String articleId = 'legal-art-1-3';
    final StubLibraryUserDataGateway userData = StubLibraryUserDataGateway(
      bookmarked: bookmarked,
      bookmarks: Success<List<LegalBookmark>>(
        bookmarked
            ? <LegalBookmark>[bookmarkFor(articleId)]
            : <LegalBookmark>[],
      ),
      highlights: Success<List<LegalHighlight>>(highlights),
    );

    await resetServiceLocator();
    serviceLocator.registerLazySingleton<LibraryGateway>(
      FakeLibraryGateway.new,
    );
    serviceLocator.registerLazySingleton<LibraryUserDataGateway>(
      () => userData,
    );

    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LibraryArticleScreen(articleId: articleId),
      ),
    );
    await tester.pumpAndSettle();
    return userData;
  }

  group('bookmark control', () {
    testWidgets('is present with a label and reflects the saved state', (
      WidgetTester tester,
    ) async {
      await pumpArticle(tester, bookmarked: true);

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byTooltip('Remove from saved'), findsOneWidget);
    });

    testWidgets('flips optimistically on tap', (WidgetTester tester) async {
      final StubLibraryUserDataGateway gateway = await pumpArticle(tester);

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pump();

      // The optimistic flip happens before the stub answers.
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      await tester.pumpAndSettle();
      expect(gateway.toggleCalls, 1);
    });
  });

  group('highlights in the body', () {
    testWidgets('a live highlight renders without the stale notice', (
      WidgetTester tester,
    ) async {
      await pumpArticle(
        tester,
        highlights: <LegalHighlight>[
          highlightFor('legal-art-1-3', stale: false),
        ],
      );

      expect(find.text('Highlighted text has changed'), findsNothing);
      // The body is still selectable text, not a replaced widget.
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('a stale highlight is announced and not drawn', (
      WidgetTester tester,
    ) async {
      await pumpArticle(
        tester,
        highlights: <LegalHighlight>[
          highlightFor('legal-art-1-3', stale: true),
        ],
      );

      expect(find.text('Highlighted text has changed'), findsOneWidget);
      // The saved quote is shown so the reader still sees what they marked.
      expect(find.textContaining('تحدد الا'), findsWidgets);
    });
  });
}
