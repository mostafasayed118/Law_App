import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'library_highlights_state.dart';

/// Every highlight the reader owns, newest first (ADR-0010).
class LibraryHighlightsCubit extends Cubit<LibraryHighlightsState> {
  LibraryHighlightsCubit(this._gateway) : super(const LibraryHighlightsState());

  final LibraryUserDataGateway _gateway;
  bool _loading = false;

  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.highlights is! ViewLoading<List<LegalHighlight>>) {
      emit(
        state.copyWith(highlights: const ViewLoading<List<LegalHighlight>>()),
      );
    }
    final Result<List<LegalHighlight>> result;
    try {
      result = await _gateway.listHighlights();
    } finally {
      _loading = false;
    }
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<LegalHighlight>>(
        value: final List<LegalHighlight> rows,
      ):
        emit(
          state.copyWith(
            highlights: rows.isEmpty
                ? const ViewEmpty<List<LegalHighlight>>()
                : ViewSuccess<List<LegalHighlight>>(rows),
          ),
        );
      case Failure<List<LegalHighlight>>(error: final AppError error):
        emit(
          state.copyWith(
            highlights: viewStateForFailure<List<LegalHighlight>>(error),
          ),
        );
    }
  }
}
