import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/data/fake_library_user_data_gateway.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'package:legalhub/features/library/domain/reading_history_entry.dart';
import 'package:legalhub/features/library/presentation/library_saved_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/library_user_data_stub.dart';

/// The saved screen is the only place all three per-user lists meet, so it is
/// where the empty states, the stale marker and the destructive action are
/// checked together.
void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpSaved(
    WidgetTester tester, {
    StubLibraryUserDataGateway? gateway,
  }) async {
    await resetServiceLocator();
    serviceLocator.registerLazySingleton<LibraryUserDataGateway>(
      () => gateway ?? FakeLibraryUserDataGateway(),
    );
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LibrarySavedScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  LegalBookmark bookmark() => LegalBookmark(
    id: 'bm-1',
    articleId: 'legal-art-1-1',
    documentId: 'legal-doc-1',
    documentTitleAr: 'قانون تجريبي للإيجارات (نموذج)',
    articleNumber: '1',
    note: 'ملاحظة',
    articleSample: true,
    documentSample: true,
    createdAt: DateTime.utc(2026, 11, 16),
  );

  LegalHighlight highlight({bool stale = false}) => LegalHighlight(
    id: 'hl-1',
    articleId: 'legal-art-1-1',
    documentId: 'legal-doc-1',
    documentTitleAr: 'قانون تجريبي للإيجارات (نموذج)',
    articleNumber: '1',
    startOffset: 0,
    endOffset: 5,
    quote: 'ينظم',
    color: HighlightColorSlot.blue,
    isStale: stale,
    articleSample: true,
    documentSample: true,
    createdAt: DateTime.utc(2026, 11, 16),
  );

  ReadingHistoryEntry historyRow() => ReadingHistoryEntry(
    id: 'hx-1',
    articleId: 'legal-art-1-1',
    documentId: 'legal-doc-1',
    documentTitleAr: 'قانون تجريبي للإيجارات (نموذج)',
    articleNumber: '1',
    lastReadAt: DateTime.utc(2026, 11, 16),
    readCount: 3,
    articleSample: true,
    documentSample: true,
  );

  group('saved screen', () {
    testWidgets(
      'opens on the bookmarks tab with three tabs and a helpful empty state',
      (WidgetTester tester) async {
        await pumpSaved(tester);

        expect(find.text('Bookmarks'), findsOneWidget);
        expect(find.text('Highlights'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(
          find.text(
            'No saved articles yet. Bookmark an article to find it here.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders a saved bookmark with its note and sample badge', (
      WidgetTester tester,
    ) async {
      await pumpSaved(
        tester,
        gateway: StubLibraryUserDataGateway(
          bookmarks: Success<List<LegalBookmark>>(<LegalBookmark>[bookmark()]),
        ),
      );

      expect(find.text('قانون تجريبي للإيجارات (نموذج)'), findsOneWidget);
      expect(find.text('ملاحظة'), findsOneWidget);
      expect(find.text('Sample content'), findsOneWidget);
    });

    testWidgets('the highlights tab shows the quote and flags a stale row', (
      WidgetTester tester,
    ) async {
      await pumpSaved(
        tester,
        gateway: StubLibraryUserDataGateway(
          highlights: Success<List<LegalHighlight>>(<LegalHighlight>[
            highlight(stale: true),
          ]),
        ),
      );

      await tester.tap(find.text('Highlights'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ينظم'), findsWidgets);
      expect(find.text('Highlighted text has changed'), findsOneWidget);
    });

    testWidgets('the history tab shows the read count', (
      WidgetTester tester,
    ) async {
      await pumpSaved(
        tester,
        gateway: StubLibraryUserDataGateway(
          history: Success<List<ReadingHistoryEntry>>(<ReadingHistoryEntry>[
            historyRow(),
          ]),
        ),
      );

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('clearing history asks first, then empties the list', (
      WidgetTester tester,
    ) async {
      final StubLibraryUserDataGateway gateway = StubLibraryUserDataGateway(
        history: Success<List<ReadingHistoryEntry>>(<ReadingHistoryEntry>[
          historyRow(),
        ]),
        clearResult: const Success<int>(1),
      );
      await pumpSaved(tester, gateway: gateway);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();

      // The confirmation is the destructive guard; without it this is a
      // one-tap data loss.
      expect(
        find.text('Clear your reading history? This cannot be undone.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Clear history'));
      await tester.pumpAndSettle();

      expect(gateway.clearCalls, 1);
      expect(find.text('No reading history yet.'), findsOneWidget);
    });
  });
}
