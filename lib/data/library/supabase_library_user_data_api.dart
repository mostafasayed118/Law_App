/// Provider-neutral seam for per-user library data (ADR-0010).
///
/// Rows and scalars out, a typed [SupabaseLibraryUserDataException] on failure.
/// Colour travels as the raw enum name so the seam stays wire-typed and the
/// gateway owns the translation.
library;

/// Typed reasons a per-user library call can fail.
enum SupabaseLibraryUserDataFailureKind {
  /// The caller is not permitted (no session, no EXECUTE grant).
  denied,

  /// The row does not exist, or does not belong to the caller. The server
  /// deliberately cannot tell those two apart.
  notFound,

  /// The server refused the input: bad offsets, a quote that no longer matches,
  /// a blank quote, an over-length note.
  validation,

  /// A hard cap was hit (bookmarks, highlights per article, highlights per
  /// user). Distinct from [validation] because it is not a bug in the caller.
  limitReached,

  /// The provider is unavailable.
  unavailable,

  /// An unspecified failure.
  unknown,
}

class SupabaseLibraryUserDataException implements Exception {
  const SupabaseLibraryUserDataException({
    required this.kind,
    required this.message,
  });

  final SupabaseLibraryUserDataFailureKind kind;
  final String message;

  @override
  String toString() =>
      'SupabaseLibraryUserDataException(${kind.name}): $message';
}

abstract interface class SupabaseLibraryUserDataApi {
  /// Adds or removes the bookmark; returns the new state.
  Future<bool> toggleBookmark(String articleId, String? note);

  Future<List<Map<String, dynamic>>> listBookmarks({
    int limit = 50,
    int offset = 0,
  });

  /// Returns the new highlight id.
  Future<String> createHighlight({
    required String articleId,
    required int startOffset,
    required int endOffset,
    required String quote,
    required String color,
    String? note,
  });

  Future<void> updateHighlight(String id, {String? color, String? note});

  Future<void> deleteHighlight(String id);

  Future<List<Map<String, dynamic>>> listHighlights({
    String? articleId,
    int limit = 50,
    int offset = 0,
  });

  Future<void> recordReading(String articleId);

  Future<List<Map<String, dynamic>>> listHistory({
    int limit = 50,
    int offset = 0,
  });

  /// Returns the number of rows removed.
  Future<int> clearHistory();
}
