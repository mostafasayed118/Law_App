import 'dart:async';

import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'package:legalhub/features/library/domain/reading_history_entry.dart';

/// A scriptable [LibraryUserDataGateway] for the per-user cubit tests.
///
/// Returns canned [Result]s, records the calls it received, and can be held open
/// with [gate] so a test can assert what a cubit emits while a write is still in
/// flight — the optimistic bookmark toggle is exactly that kind of race.
class StubLibraryUserDataGateway implements LibraryUserDataGateway {
  StubLibraryUserDataGateway({
    this.bookmarked = false,
    this.bookmarks = const Success<List<LegalBookmark>>(<LegalBookmark>[]),
    this.highlights = const Success<List<LegalHighlight>>(<LegalHighlight>[]),
    this.history = const Success<List<ReadingHistoryEntry>>(
      <ReadingHistoryEntry>[],
    ),
    this.toggleResult,
    this.createResult = const Success<String>('hl-new'),
    this.updateResult = const Success<void>(null),
    this.deleteResult = const Success<void>(null),
    this.recordResult = const Success<void>(null),
    this.clearResult = const Success<int>(0),
  });

  bool bookmarked;
  Result<List<LegalBookmark>> bookmarks;
  Result<List<LegalHighlight>> highlights;
  Result<List<ReadingHistoryEntry>> history;

  Result<bool>? toggleResult;
  Result<String> createResult;
  Result<void> updateResult;
  Result<void> deleteResult;
  Result<void> recordResult;
  Result<int> clearResult;

  Completer<void>? gate;

  int toggleCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int recordCalls = 0;
  int clearCalls = 0;
  int listBookmarkCalls = 0;
  int listHighlightCalls = 0;

  String? lastBookmarkArticleId;
  String? lastHighlightArticleId;
  int? lastStart;
  int? lastEnd;
  String? lastQuote;
  HighlightColorSlot? lastColor;
  String? lastNote;
  String? lastUpdatedId;
  String? lastDeletedId;

  Future<void> _wait() async {
    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }
  }

  @override
  Future<Result<bool>> toggleBookmark(String articleId, {String? note}) async {
    toggleCalls++;
    lastBookmarkArticleId = articleId;
    lastNote = note;
    await _wait();
    final Result<bool> result = toggleResult ?? Success<bool>(!bookmarked);
    if (result is Success<bool>) {
      bookmarked = result.value;
    }
    return result;
  }

  @override
  Future<Result<List<LegalBookmark>>> listBookmarks({
    String? articleId,
    int limit = 50,
    int offset = 0,
  }) async {
    listBookmarkCalls++;
    await _wait();
    if (articleId == null) {
      return bookmarks;
    }
    // Mirror the server's filter so the reader's "is this one bookmarked" path
    // is exercised rather than assumed.
    return switch (bookmarks) {
      Success<List<LegalBookmark>>(value: final List<LegalBookmark> rows) =>
        Success<List<LegalBookmark>>(
          rows
              .where((LegalBookmark b) => b.articleId == articleId)
              .toList(growable: false),
        ),
      Failure<List<LegalBookmark>>(error: final error) =>
        Failure<List<LegalBookmark>>(error),
    };
  }

  @override
  Future<Result<String>> createHighlight({
    required String articleId,
    required int startOffset,
    required int endOffset,
    required String quote,
    required HighlightColorSlot color,
    String? note,
  }) async {
    createCalls++;
    lastHighlightArticleId = articleId;
    lastStart = startOffset;
    lastEnd = endOffset;
    lastQuote = quote;
    lastColor = color;
    lastNote = note;
    await _wait();
    return createResult;
  }

  @override
  Future<Result<void>> updateHighlight(
    String id, {
    HighlightColorSlot? color,
    String? note,
  }) async {
    updateCalls++;
    lastUpdatedId = id;
    lastColor = color;
    lastNote = note;
    await _wait();
    return updateResult;
  }

  @override
  Future<Result<void>> deleteHighlight(String id) async {
    deleteCalls++;
    lastDeletedId = id;
    await _wait();
    return deleteResult;
  }

  @override
  Future<Result<List<LegalHighlight>>> listHighlights({
    String? articleId,
    int limit = 50,
    int offset = 0,
  }) async {
    listHighlightCalls++;
    await _wait();
    if (articleId == null) {
      return highlights;
    }
    return switch (highlights) {
      Success<List<LegalHighlight>>(value: final List<LegalHighlight> rows) =>
        Success<List<LegalHighlight>>(
          rows
              .where((LegalHighlight h) => h.articleId == articleId)
              .toList(growable: false),
        ),
      Failure<List<LegalHighlight>>(error: final error) =>
        Failure<List<LegalHighlight>>(error),
    };
  }

  @override
  Future<Result<void>> recordReading(String articleId) async {
    recordCalls++;
    lastHighlightArticleId = articleId;
    await _wait();
    return recordResult;
  }

  @override
  Future<Result<List<ReadingHistoryEntry>>> listHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    await _wait();
    return history;
  }

  @override
  Future<Result<int>> clearHistory() async {
    clearCalls++;
    await _wait();
    return clearResult;
  }
}
