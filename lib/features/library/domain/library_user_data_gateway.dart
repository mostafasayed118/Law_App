import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/reading_history_entry.dart';

/// The reader's own library data: bookmarks, highlights, history (ADR-0010).
///
/// Deliberately separate from [LibraryGateway]. The corpus gateway is read-only
/// and identical for every user; this one is mutable and scoped to the caller.
/// Merging them would have put a `toggleBookmark` next to `listDocuments` in an
/// interface that the browse cubit also implements against — the wrong shape for
/// both.
///
/// Nothing here takes a user id: identity is the session, resolved server-side
/// (RPCs) or by the fake's single demo user.
abstract interface class LibraryUserDataGateway {
  // --- bookmarks -----------------------------------------------------------

  /// Adds the bookmark if absent, removes it if present. Returns the new state
  /// (`true` = now bookmarked). The note applies only when adding.
  Future<Result<bool>> toggleBookmark(String articleId, {String? note});

  /// The caller's bookmarks, newest first.
  Future<Result<List<LegalBookmark>>> listBookmarks({
    int limit = 50,
    int offset = 0,
  });

  // --- highlights ----------------------------------------------------------

  /// Creates a highlight over `[startOffset, endOffset)` of the article body.
  ///
  /// Offsets are RUNE offsets, and [quote] must equal the text at that range or
  /// the server rejects the call — that check is what keeps a stale offset out
  /// of the table. Returns the new highlight id.
  Future<Result<String>> createHighlight({
    required String articleId,
    required int startOffset,
    required int endOffset,
    required String quote,
    required HighlightColorSlot color,
    String? note,
  });

  /// Updates the colour and/or note. A `null` [note] leaves the existing note
  /// untouched; an empty string clears it.
  Future<Result<void>> updateHighlight(
    String id, {
    HighlightColorSlot? color,
    String? note,
  });

  Future<Result<void>> deleteHighlight(String id);

  /// The caller's highlights, newest first, optionally for one article.
  ///
  /// [LegalHighlight.isStale] is computed by the server against the article's
  /// current body hash.
  Future<Result<List<LegalHighlight>>> listHighlights({
    String? articleId,
    int limit = 50,
    int offset = 0,
  });

  // --- history -------------------------------------------------------------

  /// Records one read of [articleId]; the server upserts, increments the count
  /// and prunes the history to its cap.
  Future<Result<void>> recordReading(String articleId);

  /// Most recently read first.
  Future<Result<List<ReadingHistoryEntry>>> listHistory({
    int limit = 50,
    int offset = 0,
  });

  /// Clears the caller's history and returns how many rows were removed.
  Future<Result<int>> clearHistory();
}
