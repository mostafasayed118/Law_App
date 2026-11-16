import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/library_user_data_errors.dart';
import 'package:legalhub/features/library/presentation/article_user_data_cubit.dart';
import 'package:legalhub/features/library/presentation/article_user_data_state.dart';

import '../../support/library_user_data_stub.dart';

/// The optimistic toggle is the only place in the library where the UI leads the
/// server, so the rollback path is tested harder than the happy path.
void main() {
  LegalBookmark bookmarkFor(String articleId) {
    return LegalBookmark(
      id: 'bm-1',
      articleId: articleId,
      documentId: 'doc-1',
      documentTitleAr: 'عنوان',
      articleNumber: '1',
      articleSample: true,
      documentSample: true,
      createdAt: DateTime.utc(2026, 11, 16),
    );
  }

  LegalHighlight highlightFor(String articleId, {bool stale = false}) {
    return LegalHighlight(
      id: 'hl-1',
      articleId: articleId,
      documentId: 'doc-1',
      documentTitleAr: 'عنوان',
      articleNumber: '1',
      startOffset: 0,
      endOffset: 4,
      quote: 'نص',
      color: HighlightColorSlot.yellow,
      isStale: stale,
      articleSample: true,
      documentSample: true,
      createdAt: DateTime.utc(2026, 11, 16),
    );
  }

  group('load', () {
    blocTest<ArticleUserDataCubit, ArticleUserDataState>(
      'reads the bookmark state and the highlights for the article',
      build: () => ArticleUserDataCubit(
        StubLibraryUserDataGateway(
          bookmarks: Success<List<LegalBookmark>>(<LegalBookmark>[
            bookmarkFor('a1'),
          ]),
          highlights: Success<List<LegalHighlight>>(<LegalHighlight>[
            highlightFor('a1'),
          ]),
        ),
      ),
      act: (ArticleUserDataCubit cubit) => cubit.load('a1'),
      expect: () => <ArticleUserDataState>[
        ArticleUserDataState(
          bookmarked: true,
          highlights: ViewSuccess<List<LegalHighlight>>(<LegalHighlight>[
            highlightFor('a1'),
          ]),
        ),
      ],
    );

    blocTest<ArticleUserDataCubit, ArticleUserDataState>(
      'an article with no bookmark and no highlight loads as false + empty list',
      build: () => ArticleUserDataCubit(StubLibraryUserDataGateway()),
      act: (ArticleUserDataCubit cubit) => cubit.load('a1'),
      expect: () => <ArticleUserDataState>[
        const ArticleUserDataState(
          bookmarked: false,
          highlights: ViewSuccess<List<LegalHighlight>>(<LegalHighlight>[]),
        ),
      ],
    );

    blocTest<ArticleUserDataCubit, ArticleUserDataState>(
      'a failed highlight read keeps its typed arm but still reports the bookmark',
      build: () => ArticleUserDataCubit(
        StubLibraryUserDataGateway(
          bookmarks: Success<List<LegalBookmark>>(<LegalBookmark>[
            bookmarkFor('a1'),
          ]),
          highlights: const Failure<List<LegalHighlight>>(
            AppError(
              code: LibraryUserDataErrors.unavailableCode,
              userMessage: 'down',
              kind: AppErrorKind.unavailable,
            ),
          ),
        ),
      ),
      act: (ArticleUserDataCubit cubit) => cubit.load('a1'),
      expect: () => <ArticleUserDataState>[
        const ArticleUserDataState(
          bookmarked: true,
          highlights: ViewOffline<List<LegalHighlight>>(),
        ),
      ],
    );

    test('stale highlights are separated from the drawable ones', () {
      final ArticleUserDataState state = ArticleUserDataState(
        highlights: ViewSuccess<List<LegalHighlight>>(<LegalHighlight>[
          highlightFor('a1'),
          highlightFor('a1', stale: true),
        ]),
      );
      expect(state.drawableHighlights, hasLength(1));
      expect(state.staleHighlights, hasLength(1));
      expect(state.staleHighlights.single.isStale, isTrue);
    });
  });

  group('toggleBookmark', () {
    test(
      'flips optimistically before the server answers, then settles',
      () async {
        final StubLibraryUserDataGateway gateway = StubLibraryUserDataGateway();
        final ArticleUserDataCubit cubit = ArticleUserDataCubit(gateway);
        addTearDown(cubit.close);
        await cubit.load('a1');

        final Completer<void> gate = Completer<void>();
        gateway.gate = gate;

        final Future<void> pending = cubit.toggleBookmark();
        // Optimistic: the control has already moved while the write is in flight.
        expect(cubit.state.bookmarked, isTrue);
        expect(cubit.state.bookmarkBusy, isTrue);

        gate.complete();
        await pending;
        expect(cubit.state.bookmarked, isTrue);
        expect(cubit.state.bookmarkBusy, isFalse);
      },
    );

    test(
      'a failed toggle rolls the control back and raises the error',
      () async {
        final StubLibraryUserDataGateway gateway = StubLibraryUserDataGateway(
          toggleResult: const Failure<bool>(
            AppError(
              code: LibraryUserDataErrors.savedLimitCode,
              userMessage: 'cap',
            ),
          ),
        );
        final ArticleUserDataCubit cubit = ArticleUserDataCubit(gateway);
        addTearDown(cubit.close);
        await cubit.load('a1');

        await cubit.toggleBookmark();

        expect(cubit.state.bookmarked, isFalse, reason: 'rolled back');
        expect(cubit.state.bookmarkBusy, isFalse);
        expect(
          cubit.state.lastError?.code,
          LibraryUserDataErrors.savedLimitCode,
        );
      },
    );

    test('a tap while a tap is in flight is ignored', () async {
      final StubLibraryUserDataGateway gateway = StubLibraryUserDataGateway();
      final ArticleUserDataCubit cubit = ArticleUserDataCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load('a1');

      final Completer<void> gate = Completer<void>();
      gateway.gate = gate;
      final Future<void> first = cubit.toggleBookmark();
      final Future<void> second = cubit.toggleBookmark();
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(gateway.toggleCalls, 1);
    });

    test('acknowledgeError clears the pending message', () async {
      final StubLibraryUserDataGateway gateway = StubLibraryUserDataGateway(
        toggleResult: const Failure<bool>(
          AppError(code: 'x', userMessage: 'y'),
        ),
      );
      final ArticleUserDataCubit cubit = ArticleUserDataCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load('a1');
      await cubit.toggleBookmark();

      expect(cubit.state.lastError, isNotNull);
      cubit.acknowledgeError();
      expect(cubit.state.lastError, isNull);
    });
  });

  group('createHighlight', () {
    test('converts UTF-16 selection offsets to rune offsets', () async {
      final StubLibraryUserDataGateway gateway = StubLibraryUserDataGateway();
      final ArticleUserDataCubit cubit = ArticleUserDataCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load('a1');

      // '😀abc': UTF-16 0..3 is '😀a', which is rune 0..2.
      final bool ok = await cubit.createHighlight(
        body: '😀abc',
        startUtf16: 0,
        endUtf16: 3,
        color: HighlightColorSlot.blue,
      );

      expect(ok, isTrue);
      expect(gateway.lastStart, 0);
      expect(gateway.lastEnd, 2);
      expect(gateway.lastQuote, '😀a');
    });

    test('an empty selection does not call the server', () async {
      final StubLibraryUserDataGateway gateway = StubLibraryUserDataGateway();
      final ArticleUserDataCubit cubit = ArticleUserDataCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load('a1');

      final bool ok = await cubit.createHighlight(
        body: 'abc',
        startUtf16: 2,
        endUtf16: 2,
        color: HighlightColorSlot.yellow,
      );

      expect(ok, isFalse);
      expect(gateway.createCalls, 0);
    });

    test('a rejected selection surfaces the typed error', () async {
      final StubLibraryUserDataGateway gateway = StubLibraryUserDataGateway(
        createResult: const Failure<String>(
          AppError(
            code: LibraryUserDataErrors.highlightRejectedCode,
            userMessage: 'no',
          ),
        ),
      );
      final ArticleUserDataCubit cubit = ArticleUserDataCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load('a1');

      final bool ok = await cubit.createHighlight(
        body: 'abcd',
        startUtf16: 0,
        endUtf16: 2,
        color: HighlightColorSlot.yellow,
      );

      expect(ok, isFalse);
      expect(
        cubit.state.lastError?.code,
        LibraryUserDataErrors.highlightRejectedCode,
      );
    });
  });

  group('recordReading', () {
    test('records once per call and stays silent on failure', () async {
      final StubLibraryUserDataGateway gateway = StubLibraryUserDataGateway(
        recordResult: const Failure<void>(
          AppError(code: 'x', userMessage: 'silent'),
        ),
      );
      final ArticleUserDataCubit cubit = ArticleUserDataCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load('a1');

      await cubit.recordReading();

      expect(gateway.recordCalls, 1);
      expect(
        cubit.state.lastError,
        isNull,
        reason: 'a bookkeeping failure must never interrupt reading',
      );
    });
  });
}
