import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/data/fake_library_gateway.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/legal_article.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/library_user_data_errors.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'package:legalhub/features/library/domain/reading_history_entry.dart';

/// Development-only per-user library data (ADR-0010).
///
/// In memory and single-user: the fake represents one demo reader, so there is no
/// cross-user path to model. Everything else mirrors the server exactly, because
/// a fake that is more permissive than the RPC would let the UI ship a flow the
/// server rejects:
///
/// - the four caps (`bookmark`, `highlight per article`, `highlight per user`,
///   `history`);
/// - quote/offset agreement against the article body, including the rune-offset
///   coordinate system;
/// - toggle idempotence and note trimming;
/// - history upsert with `read_count` and pruning to the newest 100;
/// - staleness by fingerprint, so amending a body in a test flips `isStale`.
///
/// Ids are synthetic (`bm-1`, `hl-1`) — no synthetic id can reach a backend.
class FakeLibraryUserDataGateway implements LibraryUserDataGateway {
  FakeLibraryUserDataGateway();

  static const int bookmarkCap = 500;
  static const int highlightsPerArticleCap = 50;
  static const int highlightsPerUserCap = 2000;
  static const int historyCap = 100;
  static const int maxPage = 50;

  final Map<String, _BookmarkRow> _bookmarks = <String, _BookmarkRow>{};
  final Map<String, _HighlightRow> _highlights = <String, _HighlightRow>{};
  final Map<String, _HistoryRow> _history = <String, _HistoryRow>{};

  int _sequence = 0;
  int _nextId = 1;

  /// Overrides for a test that needs an amended body without touching the shared
  /// synthetic corpus.
  final Map<String, String> _bodyOverrides = <String, String>{};

  int get bookmarkCount => _bookmarks.length;
  int get highlightCount => _highlights.length;
  int get historyCount => _history.length;

  /// Replaces an article body, so a test can simulate an amendment.
  void overrideArticleBody(String articleId, String body) {
    _bodyOverrides[articleId] = body;
  }

  // --- bookmarks -----------------------------------------------------------

  @override
  Future<Result<bool>> toggleBookmark(String articleId, {String? note}) async {
    if (_articleById(articleId) == null) {
      return const Result<bool>.failure(LibraryUserDataErrors.unavailable);
    }
    if (note != null && note.length > 500) {
      return const Result<bool>.failure(
        LibraryUserDataErrors.highlightRejected,
      );
    }

    final String? existing = _bookmarkIdFor(articleId);
    if (existing != null) {
      _bookmarks.remove(existing);
      return const Result<bool>.success(false);
    }

    if (_bookmarks.length >= bookmarkCap) {
      return const Result<bool>.failure(
        LibraryUserDataErrors.savedLimitReached,
      );
    }

    final String id = 'bm-${_nextId++}';
    _bookmarks[id] = _BookmarkRow(
      id: id,
      articleId: articleId,
      note: _trimToNull(note),
      createdAt: DateTime.now(),
      sequence: _sequence++,
    );
    return const Result<bool>.success(true);
  }

  @override
  Future<Result<List<LegalBookmark>>> listBookmarks({
    String? articleId,
    int limit = 50,
    int offset = 0,
  }) async {
    final List<_BookmarkRow> rows =
        _bookmarks.values
            .where(
              (_BookmarkRow row) =>
                  articleId == null || row.articleId == articleId,
            )
            .toList(growable: false)
          ..sort(
            (_BookmarkRow a, _BookmarkRow b) =>
                b.sequence.compareTo(a.sequence),
          );
    return Result<List<LegalBookmark>>.success(
      List<LegalBookmark>.unmodifiable(
        _page(rows, limit: limit, offset: offset).map(_toBookmark),
      ),
    );
  }

  // --- highlights ----------------------------------------------------------

  @override
  Future<Result<String>> createHighlight({
    required String articleId,
    required int startOffset,
    required int endOffset,
    required String quote,
    required HighlightColorSlot color,
    String? note,
  }) async {
    final LegalArticle? article = _articleById(articleId);
    if (article == null) {
      return const Result<String>.failure(
        LibraryUserDataErrors.highlightRejected,
      );
    }
    final String body = _bodyFor(articleId);

    if (startOffset < 0 || endOffset <= startOffset) {
      return const Result<String>.failure(
        LibraryUserDataErrors.highlightRejected,
      );
    }
    if (endOffset - startOffset > 1000) {
      return const Result<String>.failure(
        LibraryUserDataErrors.highlightRejected,
      );
    }
    if (quote.trim().isEmpty) {
      return const Result<String>.failure(
        LibraryUserDataErrors.highlightRejected,
      );
    }
    if (note != null && note.length > 1000) {
      return const Result<String>.failure(
        LibraryUserDataErrors.highlightRejected,
      );
    }

    // The server's guard, mirrored: the span must still point at the quote.
    final String actual = _substringByRunes(body, startOffset, endOffset);
    if (actual != quote) {
      return const Result<String>.failure(
        LibraryUserDataErrors.highlightRejected,
      );
    }

    final int forArticle = _highlights.values
        .where((_HighlightRow row) => row.articleId == articleId)
        .length;
    if (forArticle >= highlightsPerArticleCap) {
      return const Result<String>.failure(
        LibraryUserDataErrors.savedLimitReached,
      );
    }
    if (_highlights.length >= highlightsPerUserCap) {
      return const Result<String>.failure(
        LibraryUserDataErrors.savedLimitReached,
      );
    }

    final String id = 'hl-${_nextId++}';
    _highlights[id] = _HighlightRow(
      id: id,
      articleId: articleId,
      startOffset: startOffset,
      endOffset: endOffset,
      quote: quote,
      bodyFingerprint: _fingerprint(body),
      color: color,
      note: _trimToNull(note),
      createdAt: DateTime.now(),
      sequence: _sequence++,
    );
    return Result<String>.success(id);
  }

  @override
  Future<Result<void>> updateHighlight(
    String id, {
    HighlightColorSlot? color,
    String? note,
  }) async {
    final _HighlightRow? row = _highlights[id];
    if (row == null) {
      return const Result<void>.failure(
        LibraryUserDataErrors.highlightNotFound,
      );
    }
    if (note != null && note.length > 1000) {
      return const Result<void>.failure(
        LibraryUserDataErrors.highlightRejected,
      );
    }
    if (color != null) {
      row.color = color;
    }
    // A null note leaves it untouched; an empty string clears it.
    if (note != null) {
      row.note = _trimToNull(note);
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> deleteHighlight(String id) async {
    if (!_highlights.containsKey(id)) {
      return const Result<void>.failure(
        LibraryUserDataErrors.highlightNotFound,
      );
    }
    _highlights.remove(id);
    return const Result<void>.success(null);
  }

  @override
  Future<Result<List<LegalHighlight>>> listHighlights({
    String? articleId,
    int limit = 50,
    int offset = 0,
  }) async {
    final List<_HighlightRow> rows =
        _highlights.values
            .where(
              (_HighlightRow row) =>
                  articleId == null || row.articleId == articleId,
            )
            .toList(growable: false)
          ..sort(
            (_HighlightRow a, _HighlightRow b) =>
                b.sequence.compareTo(a.sequence),
          );
    return Result<List<LegalHighlight>>.success(
      List<LegalHighlight>.unmodifiable(
        _page(rows, limit: limit, offset: offset).map(_toHighlight),
      ),
    );
  }

  // --- history -------------------------------------------------------------

  @override
  Future<Result<void>> recordReading(String articleId) async {
    if (_articleById(articleId) == null) {
      return const Result<void>.failure(LibraryUserDataErrors.unavailable);
    }
    final _HistoryRow? existing = _history[articleId];
    if (existing != null) {
      existing
        ..readCount += 1
        ..lastReadAt = DateTime.now()
        ..sequence = _sequence++;
    } else {
      _history[articleId] = _HistoryRow(
        id: 'hx-${_nextId++}',
        articleId: articleId,
        lastReadAt: DateTime.now(),
        readCount: 1,
        sequence: _sequence++,
      );
    }

    if (_history.length > historyCap) {
      final List<_HistoryRow> ordered = _history.values.toList(growable: false)
        ..sort(
          (_HistoryRow a, _HistoryRow b) => b.sequence.compareTo(a.sequence),
        );
      for (final _HistoryRow stale in ordered.skip(historyCap)) {
        _history.remove(stale.articleId);
      }
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<List<ReadingHistoryEntry>>> listHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final List<_HistoryRow> rows = _history.values.toList(
      growable: false,
    )..sort((_HistoryRow a, _HistoryRow b) => b.sequence.compareTo(a.sequence));
    return Result<List<ReadingHistoryEntry>>.success(
      List<ReadingHistoryEntry>.unmodifiable(
        _page(rows, limit: limit, offset: offset).map(_toHistory),
      ),
    );
  }

  @override
  Future<Result<int>> clearHistory() async {
    final int removed = _history.length;
    _history.clear();
    return Result<int>.success(removed);
  }

  // --- mapping and helpers -------------------------------------------------

  LegalBookmark _toBookmark(_BookmarkRow row) {
    final LegalArticle article = _articleById(row.articleId)!;
    final LegalDocument document = _documentById(article.documentId)!;
    return LegalBookmark(
      id: row.id,
      articleId: article.id,
      documentId: document.id,
      documentTitleAr: document.titleAr,
      articleNumber: article.articleNumber,
      headingAr: article.headingAr,
      note: row.note,
      articleSample: article.isSample,
      documentSample: document.isSample,
      createdAt: row.createdAt,
    );
  }

  LegalHighlight _toHighlight(_HighlightRow row) {
    final LegalArticle article = _articleById(row.articleId)!;
    final LegalDocument document = _documentById(article.documentId)!;
    return LegalHighlight(
      id: row.id,
      articleId: article.id,
      documentId: document.id,
      documentTitleAr: document.titleAr,
      articleNumber: article.articleNumber,
      startOffset: row.startOffset,
      endOffset: row.endOffset,
      quote: row.quote,
      color: row.color,
      note: row.note,
      isStale: row.bodyFingerprint != _fingerprint(_bodyFor(article.id)),
      articleSample: article.isSample,
      documentSample: document.isSample,
      createdAt: row.createdAt,
    );
  }

  ReadingHistoryEntry _toHistory(_HistoryRow row) {
    final LegalArticle article = _articleById(row.articleId)!;
    final LegalDocument document = _documentById(article.documentId)!;
    return ReadingHistoryEntry(
      id: row.id,
      articleId: article.id,
      documentId: document.id,
      documentTitleAr: document.titleAr,
      articleNumber: article.articleNumber,
      headingAr: article.headingAr,
      lastReadAt: row.lastReadAt,
      readCount: row.readCount,
      articleSample: article.isSample,
      documentSample: document.isSample,
    );
  }

  String? _bookmarkIdFor(String articleId) {
    for (final _BookmarkRow row in _bookmarks.values) {
      if (row.articleId == articleId) {
        return row.id;
      }
    }
    return null;
  }

  LegalArticle? _articleById(String id) {
    for (final LegalArticle article in FakeLibraryGateway.syntheticArticles) {
      if (article.id == id) {
        return article;
      }
    }
    return null;
  }

  LegalDocument? _documentById(String id) {
    for (final LegalDocument document
        in FakeLibraryGateway.syntheticDocuments) {
      if (document.id == id) {
        return document;
      }
    }
    return null;
  }

  String _bodyFor(String articleId) =>
      _bodyOverrides[articleId] ?? _articleById(articleId)!.bodyAr;

  static String? _trimToNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The fake's stand-in for `md5(body_ar)`: only has to change when the text
  /// changes, and to stay stable for the life of the process.
  static String _fingerprint(String text) {
    int hash = 0x811C9DC5;
    for (final int unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _substringByRunes(String text, int start, int end) {
    final List<int> runes = text.runes.toList(growable: false);
    final int s = start.clamp(0, runes.length);
    final int e = end.clamp(s, runes.length);
    return String.fromCharCodes(runes.sublist(s, e));
  }

  List<T> _page<T>(List<T> rows, {required int limit, required int offset}) {
    final int safeLimit = limit.clamp(1, maxPage);
    final int safeOffset = offset < 0 ? 0 : offset;
    if (safeOffset >= rows.length) {
      return <T>[];
    }
    return rows.sublist(
      safeOffset,
      (safeOffset + safeLimit).clamp(0, rows.length),
    );
  }
}

class _BookmarkRow {
  _BookmarkRow({
    required this.id,
    required this.articleId,
    required this.note,
    required this.createdAt,
    required this.sequence,
  });

  final String id;
  final String articleId;
  final String? note;
  final DateTime createdAt;
  final int sequence;
}

class _HighlightRow {
  _HighlightRow({
    required this.id,
    required this.articleId,
    required this.startOffset,
    required this.endOffset,
    required this.quote,
    required this.bodyFingerprint,
    required this.color,
    required this.note,
    required this.createdAt,
    required this.sequence,
  });

  final String id;
  final String articleId;
  final int startOffset;
  final int endOffset;
  final String quote;
  final String bodyFingerprint;
  HighlightColorSlot color;
  String? note;
  final DateTime createdAt;
  final int sequence;
}

class _HistoryRow {
  _HistoryRow({
    required this.id,
    required this.articleId,
    required this.lastReadAt,
    required this.readCount,
    required this.sequence,
  });

  final String id;
  final String articleId;
  DateTime lastReadAt;
  int readCount;
  int sequence;
}
