import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/library/supabase_library_user_data_api.dart';
import 'package:legalhub/features/library/data/supabase_library_user_data_gateway.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/library_user_data_errors.dart';
import 'package:legalhub/features/library/domain/reading_history_entry.dart';

/// Row → domain mapping and the failure vocabulary. The rows below are shaped
/// exactly like the RPC result columns in migration 33, so a column rename in SQL
/// fails here rather than on a device.
void main() {
  group('bookmarks', () {
    test('toggle returns the boolean the server sent', () async {
      final _StubApi api = _StubApi(toggled: true);
      final Result<bool> result = await SupabaseLibraryUserDataGateway(
        api,
      ).toggleBookmark('a1', note: 'hi');

      expect((result as Success<bool>).value, isTrue);
      expect(api.lastArticleId, 'a1');
      expect(api.lastNote, 'hi');
    });

    test(
      'maps a bookmark row including the sample flags and the note',
      () async {
        final _StubApi api = _StubApi(
          bookmarks: <Map<String, dynamic>>[
            <String, dynamic>{
              'bookmark_id': '11111111-1111-4111-8111-111111111111',
              'article_id': '22222222-2222-4222-8222-222222222222',
              'document_id': '33333333-3333-4333-8333-333333333333',
              'document_title_ar': 'عنوان',
              'article_number': '5 مكرر',
              'heading_ar': 'الأجرة',
              'note': '  ملاحظة  ',
              'article_sample': true,
              'document_sample': false,
              'created_at': '2026-11-16T10:00:00Z',
              'total_count': 1,
            },
          ],
        );
        final LegalBookmark row =
            ((await SupabaseLibraryUserDataGateway(api).listBookmarks())
                    as Success<List<LegalBookmark>>)
                .value
                .single;

        expect(row.articleNumber, '5 مكرر');
        expect(row.note, 'ملاحظة');
        expect(row.isSample, isTrue);
        expect(row.createdAt.toUtc(), DateTime.utc(2026, 11, 16, 10));
      },
    );
  });

  group('highlights', () {
    test('create sends the wire colour and returns the id', () async {
      final _StubApi api = _StubApi(createdId: 'hl-1');
      final Result<String> result = await SupabaseLibraryUserDataGateway(api)
          .createHighlight(
            articleId: 'a1',
            startOffset: 3,
            endOffset: 9,
            quote: 'نص',
            color: HighlightColorSlot.blue,
          );

      expect((result as Success<String>).value, 'hl-1');
      expect(api.lastColor, 'blue');
      expect(api.lastStart, 3);
      expect(api.lastEnd, 9);
    });

    test('maps a highlight row with is_stale and the colour slot', () async {
      final _StubApi api = _StubApi(
        highlights: <Map<String, dynamic>>[
          <String, dynamic>{
            'highlight_id': '11111111-1111-4111-8111-111111111111',
            'article_id': '22222222-2222-4222-8222-222222222222',
            'document_id': '33333333-3333-4333-8333-333333333333',
            'document_title_ar': 'عنوان',
            'article_number': '3',
            'start_offset': 4,
            'end_offset': 10,
            'quote': 'ايجار',
            'color': 'green',
            'note': null,
            'is_stale': true,
            'article_sample': true,
            'document_sample': true,
            'created_at': '2026-11-16T10:00:00Z',
            'total_count': 1,
          },
        ],
      );
      final LegalHighlight row =
          ((await SupabaseLibraryUserDataGateway(api).listHighlights())
                  as Success<List<LegalHighlight>>)
              .value
              .single;

      expect(row.color, HighlightColorSlot.green);
      expect(row.isStale, isTrue);
      expect(row.startOffset, 4);
      expect(row.endOffset, 10);
      expect(row.length, 6);
    });

    test('an unknown colour is drift, not a wrong dot', () async {
      final _StubApi api = _StubApi(
        highlights: <Map<String, dynamic>>[
          <String, dynamic>{
            'highlight_id': '11111111-1111-4111-8111-111111111111',
            'article_id': '22222222-2222-4222-8222-222222222222',
            'document_id': '33333333-3333-4333-8333-333333333333',
            'document_title_ar': 'عنوان',
            'article_number': '1',
            'start_offset': 0,
            'end_offset': 2,
            'quote': 'ab',
            'color': 'chartreuse',
            'is_stale': false,
            'article_sample': false,
            'document_sample': false,
            'created_at': '2026-11-16T10:00:00Z',
          },
        ],
      );
      final Result<List<LegalHighlight>> result =
          await SupabaseLibraryUserDataGateway(api).listHighlights();
      expect(
        (result as Failure<List<LegalHighlight>>).error.kind,
        AppErrorKind.unavailable,
      );
    });

    test(
      'update forwards colour and note, and a null note stays null',
      () async {
        final _StubApi api = _StubApi();
        await SupabaseLibraryUserDataGateway(
          api,
        ).updateHighlight('hl-1', color: HighlightColorSlot.pink);
        expect(api.lastColor, 'pink');
        expect(api.lastNote, isNull);

        await SupabaseLibraryUserDataGateway(
          api,
        ).updateHighlight('hl-1', note: '');
        expect(api.lastNote, '');
      },
    );
  });

  group('history', () {
    test('maps a history row and its read count', () async {
      final _StubApi api = _StubApi(
        history: <Map<String, dynamic>>[
          <String, dynamic>{
            'history_id': '11111111-1111-4111-8111-111111111111',
            'article_id': '22222222-2222-4222-8222-222222222222',
            'document_id': '33333333-3333-4333-8333-333333333333',
            'document_title_ar': 'عنوان',
            'article_number': '2',
            'heading_ar': null,
            'last_read_at': '2026-11-16T09:00:00Z',
            'read_count': 7,
            'article_sample': false,
            'document_sample': false,
            'total_count': 1,
          },
        ],
      );
      final ReadingHistoryEntry row =
          ((await SupabaseLibraryUserDataGateway(api).listHistory())
                  as Success<List<ReadingHistoryEntry>>)
              .value
              .single;
      expect(row.readCount, 7);
      expect(row.lastReadAt.toUtc(), DateTime.utc(2026, 11, 16, 9));
    });

    test('clear returns the removed count', () async {
      final _StubApi api = _StubApi(cleared: 12);
      final Result<int> result = await SupabaseLibraryUserDataGateway(
        api,
      ).clearHistory();
      expect((result as Success<int>).value, 12);
    });
  });

  group('failure mapping', () {
    Future<AppError> errorFor(SupabaseLibraryUserDataFailureKind kind) async {
      final _StubApi api = _StubApi(
        failure: SupabaseLibraryUserDataException(kind: kind, message: 'x'),
      );
      final Result<List<LegalBookmark>> result =
          await SupabaseLibraryUserDataGateway(api).listBookmarks();
      return (result as Failure<List<LegalBookmark>>).error;
    }

    test('a cap is its own error, never a generic failure', () async {
      final AppError error = await errorFor(
        SupabaseLibraryUserDataFailureKind.limitReached,
      );
      expect(error.code, LibraryUserDataErrors.savedLimitCode);
      expect(
        error.messageKey,
        LibraryUserDataErrors.savedLimitReached.messageKey,
      );
    });

    test('a rejected selection keeps its own copy', () async {
      final AppError error = await errorFor(
        SupabaseLibraryUserDataFailureKind.validation,
      );
      expect(error.code, LibraryUserDataErrors.highlightRejectedCode);
    });

    test('not-found keeps its own code', () async {
      final AppError error = await errorFor(
        SupabaseLibraryUserDataFailureKind.notFound,
      );
      expect(error.code, LibraryUserDataErrors.notFoundCode);
    });

    test(
      'a denial is marked denied so the UI does not offer a retry',
      () async {
        final AppError error = await errorFor(
          SupabaseLibraryUserDataFailureKind.denied,
        );
        expect(error.kind, AppErrorKind.denied);
      },
    );

    test('an outage is retryable', () async {
      final AppError error = await errorFor(
        SupabaseLibraryUserDataFailureKind.unavailable,
      );
      expect(error.kind, AppErrorKind.unavailable);
    });
  });
}

/// Hand-written stub: the gateway is the unit under test, and a mock would only
/// re-assert that mocktail works.
class _StubApi implements SupabaseLibraryUserDataApi {
  _StubApi({
    this.toggled = false,
    this.bookmarks = const <Map<String, dynamic>>[],
    this.createdId = 'hl-stub',
    this.highlights = const <Map<String, dynamic>>[],
    this.history = const <Map<String, dynamic>>[],
    this.cleared = 0,
    this.failure,
  });

  final bool toggled;
  final List<Map<String, dynamic>> bookmarks;
  final String createdId;
  final List<Map<String, dynamic>> highlights;
  final List<Map<String, dynamic>> history;
  final int cleared;
  final SupabaseLibraryUserDataException? failure;

  String? lastArticleId;
  String? lastNote;
  String? lastColor;
  int? lastStart;
  int? lastEnd;

  void _maybeThrow() {
    if (failure != null) {
      throw failure!;
    }
  }

  @override
  Future<bool> toggleBookmark(String articleId, String? note) async {
    lastArticleId = articleId;
    lastNote = note;
    _maybeThrow();
    return toggled;
  }

  @override
  Future<List<Map<String, dynamic>>> listBookmarks({
    String? articleId,
    int limit = 50,
    int offset = 0,
  }) async {
    _maybeThrow();
    return bookmarks;
  }

  @override
  Future<String> createHighlight({
    required String articleId,
    required int startOffset,
    required int endOffset,
    required String quote,
    required String color,
    String? note,
  }) async {
    lastArticleId = articleId;
    lastStart = startOffset;
    lastEnd = endOffset;
    lastColor = color;
    lastNote = note;
    _maybeThrow();
    return createdId;
  }

  @override
  Future<void> updateHighlight(String id, {String? color, String? note}) async {
    lastColor = color;
    lastNote = note;
    _maybeThrow();
  }

  @override
  Future<void> deleteHighlight(String id) async {
    _maybeThrow();
  }

  @override
  Future<List<Map<String, dynamic>>> listHighlights({
    String? articleId,
    int limit = 50,
    int offset = 0,
  }) async {
    _maybeThrow();
    return highlights;
  }

  @override
  Future<void> recordReading(String articleId) async {
    lastArticleId = articleId;
    _maybeThrow();
  }

  @override
  Future<List<Map<String, dynamic>>> listHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    _maybeThrow();
    return history;
  }

  @override
  Future<int> clearHistory() async {
    _maybeThrow();
    return cleared;
  }
}
