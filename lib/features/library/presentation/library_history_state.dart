import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/reading_history_entry.dart';

/// State of the reading-history list (ADR-0010).
///
/// - [history] — the rows, newest read first.
/// - [clearing] — true while the destructive action is in flight, so the
///   confirmation dialog's button cannot be double-tapped into two deletes.
/// - [lastError] — a failed clear, for the surface to announce once.
class LibraryHistoryState extends Equatable {
  const LibraryHistoryState({
    this.history = const ViewLoading<List<ReadingHistoryEntry>>(),
    this.clearing = false,
    this.lastError,
  });

  final ViewState<List<ReadingHistoryEntry>> history;
  final bool clearing;
  final AppError? lastError;

  LibraryHistoryState copyWith({
    ViewState<List<ReadingHistoryEntry>>? history,
    bool? clearing,
    AppError? lastError,
    bool clearError = false,
  }) {
    return LibraryHistoryState(
      history: history ?? this.history,
      clearing: clearing ?? this.clearing,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => <Object?>[history, clearing, lastError];
}
