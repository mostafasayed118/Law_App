import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'library_bookmarks_state.dart';

/// The reader's saved bookmarks, newest first (ADR-0010).
class LibraryBookmarksCubit extends Cubit<LibraryBookmarksState> {
  LibraryBookmarksCubit(this._gateway) : super(const LibraryBookmarksState());

  final LibraryUserDataGateway _gateway;
  bool _loading = false;

  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.bookmarks is! ViewLoading<List<LegalBookmark>>) {
      emit(state.copyWith(bookmarks: const ViewLoading<List<LegalBookmark>>()));
    }
    final Result<List<LegalBookmark>> result;
    try {
      result = await _gateway.listBookmarks();
    } finally {
      _loading = false;
    }
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<LegalBookmark>>(value: final List<LegalBookmark> rows):
        emit(
          state.copyWith(
            bookmarks: rows.isEmpty
                ? const ViewEmpty<List<LegalBookmark>>()
                : ViewSuccess<List<LegalBookmark>>(rows),
          ),
        );
      case Failure<List<LegalBookmark>>(error: final AppError error):
        emit(
          state.copyWith(
            bookmarks: viewStateForFailure<List<LegalBookmark>>(error),
          ),
        );
    }
  }
}
