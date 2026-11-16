import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'package:legalhub/features/library/domain/reading_history_entry.dart';
import 'library_history_state.dart';

/// The reader's recent articles, and the one destructive action in the library
/// (ADR-0010).
class LibraryHistoryCubit extends Cubit<LibraryHistoryState> {
  LibraryHistoryCubit(this._gateway) : super(const LibraryHistoryState());

  final LibraryUserDataGateway _gateway;
  bool _loading = false;

  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.history is! ViewLoading<List<ReadingHistoryEntry>>) {
      emit(
        state.copyWith(history: const ViewLoading<List<ReadingHistoryEntry>>()),
      );
    }
    final Result<List<ReadingHistoryEntry>> result;
    try {
      result = await _gateway.listHistory();
    } finally {
      _loading = false;
    }
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<ReadingHistoryEntry>>(
        value: final List<ReadingHistoryEntry> rows,
      ):
        emit(
          state.copyWith(
            history: rows.isEmpty
                ? const ViewEmpty<List<ReadingHistoryEntry>>()
                : ViewSuccess<List<ReadingHistoryEntry>>(rows),
          ),
        );
      case Failure<List<ReadingHistoryEntry>>(error: final AppError error):
        emit(
          state.copyWith(
            history: viewStateForFailure<List<ReadingHistoryEntry>>(error),
          ),
        );
    }
  }

  /// Clears the history. The caller has already confirmed; this method never
  /// asks again, and it re-reads afterwards so the list reflects the server
  /// rather than an optimistic guess about a destructive action.
  Future<void> clear() async {
    if (isClosed || state.clearing) {
      return;
    }
    emit(state.copyWith(clearing: true, clearError: true));
    final Result<int> result = await _gateway.clearHistory();
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<int>():
        emit(
          state.copyWith(
            clearing: false,
            history: const ViewEmpty<List<ReadingHistoryEntry>>(),
          ),
        );
      case Failure<int>(error: final AppError error):
        emit(state.copyWith(clearing: false, lastError: error));
    }
  }

  void acknowledgeError() {
    if (!isClosed && state.lastError != null) {
      emit(state.copyWith(clearError: true));
    }
  }
}
