import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/highlight_offsets.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'article_user_data_state.dart';

/// Owns the signed-in reader's data for one open article (ADR-0010).
///
/// Three responsibilities, all article-scoped: whether it is bookmarked, the
/// highlights drawn over its body, and creating/editing/deleting those
/// highlights.
///
/// The bookmark toggle is optimistic. A tap flips the control immediately and
/// the server's answer is reconciled afterwards; a failure puts the switch back
/// and raises [ArticleUserDataState.lastError] so the surface can say why. A
/// pessimistic toggle — spinner, then flip — makes a 200 ms round trip feel like
/// a broken button.
class ArticleUserDataCubit extends Cubit<ArticleUserDataState> {
  ArticleUserDataCubit(this._gateway) : super(const ArticleUserDataState());

  final LibraryUserDataGateway _gateway;

  String? _articleId;
  bool _loading = false;

  /// Loads the bookmark state and the article's highlights together.
  ///
  /// [load] is idempotent per article: re-entering the same article refetches
  /// (a highlight may have been added on another device), but concurrent calls
  /// collapse into one.
  Future<void> load(String articleId) async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    _articleId = articleId;
    if (state.highlights is! ViewLoading<List<LegalHighlight>>) {
      emit(
        state.copyWith(highlights: const ViewLoading<List<LegalHighlight>>()),
      );
    }

    final Result<List<LegalBookmark>> bookmarks;
    final Result<List<LegalHighlight>> highlights;
    try {
      // Started together: two independent reads, one round trip each.
      final Future<Result<List<LegalBookmark>>> bookmarkFuture = _gateway
          .listBookmarks(articleId: articleId, limit: 1);
      final Future<Result<List<LegalHighlight>>> highlightFuture = _gateway
          .listHighlights(articleId: articleId);
      bookmarks = await bookmarkFuture;
      highlights = await highlightFuture;
    } finally {
      _loading = false;
    }
    if (isClosed) {
      return;
    }

    final bool bookmarked = switch (bookmarks) {
      Success<List<LegalBookmark>>(value: final List<LegalBookmark> rows) =>
        rows.isNotEmpty,
      Failure<List<LegalBookmark>>() => false,
    };

    switch (highlights) {
      case Success<List<LegalHighlight>>(
        value: final List<LegalHighlight> rows,
      ):
        emit(
          state.copyWith(
            bookmarked: bookmarked,
            highlights: ViewSuccess<List<LegalHighlight>>(rows),
          ),
        );
      case Failure<List<LegalHighlight>>(error: final AppError error):
        emit(
          state.copyWith(
            bookmarked: bookmarked,
            highlights: viewStateForFailure<List<LegalHighlight>>(error),
          ),
        );
    }
  }

  /// Flips the bookmark, optimistically.
  Future<void> toggleBookmark() async {
    final String? articleId = _articleId;
    if (articleId == null || isClosed || state.bookmarkBusy) {
      return;
    }
    final bool previous = state.bookmarked;
    emit(
      state.copyWith(
        bookmarked: !previous,
        bookmarkBusy: true,
        clearError: true,
      ),
    );

    final Result<bool> result = await _gateway.toggleBookmark(articleId);
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<bool>(value: final bool now):
        emit(state.copyWith(bookmarked: now, bookmarkBusy: false));
      case Failure<bool>(error: final AppError error):
        // Roll back to what the server still believes.
        emit(
          state.copyWith(
            bookmarked: previous,
            bookmarkBusy: false,
            lastError: error,
          ),
        );
    }
  }

  /// Creates a highlight over a selection.
  ///
  /// [startUtf16] and [endUtf16] are Flutter's UTF-16 selection offsets; they
  /// are converted to rune offsets here, because the server counts characters
  /// and the two differ once an astral character appears in the article.
  Future<bool> createHighlight({
    required String body,
    required int startUtf16,
    required int endUtf16,
    required HighlightColorSlot color,
    String? note,
  }) async {
    final String? articleId = _articleId;
    if (articleId == null || isClosed) {
      return false;
    }
    final int start = runeOffsetOf(body, startUtf16);
    final int end = runeOffsetOf(body, endUtf16);
    if (end <= start) {
      return false;
    }

    final Result<String> result = await _gateway.createHighlight(
      articleId: articleId,
      startOffset: start,
      endOffset: end,
      quote: substringByRunes(body, start, end),
      color: color,
      note: note,
    );
    if (isClosed) {
      return false;
    }
    switch (result) {
      case Success<String>():
        await load(articleId);
        return true;
      case Failure<String>(error: final AppError error):
        emit(state.copyWith(lastError: error));
        return false;
    }
  }

  Future<void> updateHighlight(
    String id, {
    HighlightColorSlot? color,
    String? note,
  }) async {
    final Result<void> result = await _gateway.updateHighlight(
      id,
      color: color,
      note: note,
    );
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<void>():
        final String? articleId = _articleId;
        if (articleId != null) {
          await load(articleId);
        }
      case Failure<void>(error: final AppError error):
        emit(state.copyWith(lastError: error));
    }
  }

  Future<void> deleteHighlight(String id) async {
    final Result<void> result = await _gateway.deleteHighlight(id);
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<void>():
        final String? articleId = _articleId;
        if (articleId != null) {
          await load(articleId);
        }
      case Failure<void>(error: final AppError error):
        emit(state.copyWith(lastError: error));
    }
  }

  /// Consumes the pending error so a `BlocListener` shows one snackbar, not one
  /// per rebuild.
  void acknowledgeError() {
    if (!isClosed && state.lastError != null) {
      emit(state.copyWith(clearError: true));
    }
  }

  /// Records the read once the reader has actually settled on the article.
  ///
  /// Deliberately silent: a failed history write must never surface as an error
  /// to someone who is simply reading. It is a bookkeeping write, and the
  /// caller logs it through the redacting reporter.
  Future<void> recordReading() async {
    final String? articleId = _articleId;
    if (articleId == null || isClosed) {
      return;
    }
    await _gateway.recordReading(articleId);
  }
}
