import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/library/supabase_library_user_data_api.dart';
import 'package:legalhub/data/row_reader.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/library_user_data_errors.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'package:legalhub/features/library/domain/reading_history_entry.dart';

/// Per-user library data backed by the Supabase provider (ADR-0010).
///
/// Row mapping only: the nine RPCs already enforce ownership, caps and the
/// quote/offset agreement server-side, so this class never re-checks a rule it
/// cannot be trusted to enforce. What it does own is the failure vocabulary —
/// a cap is not a validation error and neither is an outage, and collapsing all
/// three into one message would tell a reader the wrong thing.
class SupabaseLibraryUserDataGateway implements LibraryUserDataGateway {
  SupabaseLibraryUserDataGateway(this._api);

  final SupabaseLibraryUserDataApi _api;

  @override
  Future<Result<bool>> toggleBookmark(String articleId, {String? note}) async {
    try {
      return Result<bool>.success(await _api.toggleBookmark(articleId, note));
    } on SupabaseLibraryUserDataException catch (e) {
      return Result<bool>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<bool>.failure(_drift(e));
    }
  }

  @override
  Future<Result<List<LegalBookmark>>> listBookmarks({
    String? articleId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.listBookmarks(
        articleId: articleId,
        limit: limit,
        offset: offset,
      );
      return Result<List<LegalBookmark>>.success(
        List<LegalBookmark>.unmodifiable(rows.map(_bookmarkFromRow)),
      );
    } on SupabaseLibraryUserDataException catch (e) {
      return Result<List<LegalBookmark>>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<List<LegalBookmark>>.failure(_drift(e));
    }
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
    try {
      return Result<String>.success(
        await _api.createHighlight(
          articleId: articleId,
          startOffset: startOffset,
          endOffset: endOffset,
          quote: quote,
          color: highlightColorWire(color),
          note: note,
        ),
      );
    } on SupabaseLibraryUserDataException catch (e) {
      return Result<String>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<String>.failure(_drift(e));
    }
  }

  @override
  Future<Result<void>> updateHighlight(
    String id, {
    HighlightColorSlot? color,
    String? note,
  }) async {
    try {
      await _api.updateHighlight(
        id,
        color: color == null ? null : highlightColorWire(color),
        note: note,
      );
      return const Result<void>.success(null);
    } on SupabaseLibraryUserDataException catch (e) {
      return Result<void>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<void>.failure(_drift(e));
    }
  }

  @override
  Future<Result<void>> deleteHighlight(String id) async {
    try {
      await _api.deleteHighlight(id);
      return const Result<void>.success(null);
    } on SupabaseLibraryUserDataException catch (e) {
      return Result<void>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<void>.failure(_drift(e));
    }
  }

  @override
  Future<Result<List<LegalHighlight>>> listHighlights({
    String? articleId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.listHighlights(
        articleId: articleId,
        limit: limit,
        offset: offset,
      );
      return Result<List<LegalHighlight>>.success(
        List<LegalHighlight>.unmodifiable(rows.map(_highlightFromRow)),
      );
    } on SupabaseLibraryUserDataException catch (e) {
      return Result<List<LegalHighlight>>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<List<LegalHighlight>>.failure(_drift(e));
    }
  }

  @override
  Future<Result<void>> recordReading(String articleId) async {
    try {
      await _api.recordReading(articleId);
      return const Result<void>.success(null);
    } on SupabaseLibraryUserDataException catch (e) {
      return Result<void>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<void>.failure(_drift(e));
    }
  }

  @override
  Future<Result<List<ReadingHistoryEntry>>> listHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.listHistory(
        limit: limit,
        offset: offset,
      );
      return Result<List<ReadingHistoryEntry>>.success(
        List<ReadingHistoryEntry>.unmodifiable(rows.map(_historyFromRow)),
      );
    } on SupabaseLibraryUserDataException catch (e) {
      return Result<List<ReadingHistoryEntry>>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<List<ReadingHistoryEntry>>.failure(_drift(e));
    }
  }

  @override
  Future<Result<int>> clearHistory() async {
    try {
      return Result<int>.success(await _api.clearHistory());
    } on SupabaseLibraryUserDataException catch (e) {
      return Result<int>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<int>.failure(_drift(e));
    }
  }

  // --- row mapping ---------------------------------------------------------

  LegalBookmark _bookmarkFromRow(Map<String, dynamic> row) {
    return LegalBookmark(
      id: requiredString(row, 'bookmark_id'),
      articleId: requiredString(row, 'article_id'),
      documentId: requiredString(row, 'document_id'),
      documentTitleAr: requiredString(row, 'document_title_ar'),
      articleNumber: requiredString(row, 'article_number'),
      headingAr: optionalString(row['heading_ar']),
      note: optionalString(row['note']),
      articleSample: row['article_sample'] == true,
      documentSample: row['document_sample'] == true,
      createdAt: requiredDate(row, 'created_at'),
    );
  }

  LegalHighlight _highlightFromRow(Map<String, dynamic> row) {
    return LegalHighlight(
      id: requiredString(row, 'highlight_id'),
      articleId: requiredString(row, 'article_id'),
      documentId: requiredString(row, 'document_id'),
      documentTitleAr: requiredString(row, 'document_title_ar'),
      articleNumber: requiredString(row, 'article_number'),
      startOffset: _intOrNull(row['start_offset']) ?? 0,
      endOffset: _intOrNull(row['end_offset']) ?? 0,
      quote: requiredString(row, 'quote', allowWhitespaceOnly: true),
      color: highlightColorFromWire(requiredString(row, 'color')),
      note: optionalString(row['note']),
      isStale: row['is_stale'] == true,
      articleSample: row['article_sample'] == true,
      documentSample: row['document_sample'] == true,
      createdAt: requiredDate(row, 'created_at'),
    );
  }

  ReadingHistoryEntry _historyFromRow(Map<String, dynamic> row) {
    return ReadingHistoryEntry(
      id: requiredString(row, 'history_id'),
      articleId: requiredString(row, 'article_id'),
      documentId: requiredString(row, 'document_id'),
      documentTitleAr: requiredString(row, 'document_title_ar'),
      articleNumber: requiredString(row, 'article_number'),
      headingAr: optionalString(row['heading_ar']),
      lastReadAt: requiredDate(row, 'last_read_at'),
      readCount: _intOrNull(row['read_count']) ?? 1,
      articleSample: row['article_sample'] == true,
      documentSample: row['document_sample'] == true,
    );
  }

  int? _intOrNull(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  // --- failures ------------------------------------------------------------

  AppError _errorFor(SupabaseLibraryUserDataException e) {
    switch (e.kind) {
      case SupabaseLibraryUserDataFailureKind.notFound:
        return LibraryUserDataErrors.highlightNotFound;
      case SupabaseLibraryUserDataFailureKind.limitReached:
        return LibraryUserDataErrors.savedLimitReached;
      case SupabaseLibraryUserDataFailureKind.validation:
        return LibraryUserDataErrors.highlightRejected;
      case SupabaseLibraryUserDataFailureKind.denied:
        return AppError(
          code: LibraryUserDataErrors.unavailableCode,
          userMessage: 'Unable to load your saved items. Please try again.',
          messageKey: LibraryUserDataErrors.unavailable.messageKey,
          technicalMessage: e.message,
          kind: AppErrorKind.denied,
        );
      case SupabaseLibraryUserDataFailureKind.unavailable:
      case SupabaseLibraryUserDataFailureKind.unknown:
        return AppError(
          code: LibraryUserDataErrors.unavailableCode,
          userMessage: 'Unable to load your saved items. Please try again.',
          messageKey: LibraryUserDataErrors.unavailable.messageKey,
          technicalMessage: e.message,
          kind: AppErrorKind.unavailable,
        );
    }
  }

  AppError _drift(FormatException e) => AppError(
    code: LibraryUserDataErrors.unavailableCode,
    userMessage: 'Unable to load your saved items. Please try again.',
    messageKey: LibraryUserDataErrors.unavailable.messageKey,
    technicalMessage: e.message,
    kind: AppErrorKind.unavailable,
  );
}
