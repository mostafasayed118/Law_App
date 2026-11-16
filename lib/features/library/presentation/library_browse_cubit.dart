import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'library_browse_state.dart';

/// Owns the library index: the document list and its category filter.
///
/// [load] reads the list for the active category; [setCategory] switches the
/// chip and reloads. The screen never calls the gateway directly — it renders
/// [LibraryBrowseState] and dispatches intents.
class LibraryBrowseCubit extends Cubit<LibraryBrowseState> {
  LibraryBrowseCubit(this._gateway) : super(const LibraryBrowseState());

  final LibraryGateway _gateway;

  /// In-flight guard. The initial state IS loading, so a naive
  /// `if (loading) return` would abort the first load.
  bool _loading = false;

  /// The category the current list was fetched with, so a settled load can
  /// detect that the chip moved on while it was in flight.
  LegalCategory? _loadedCategory;
  bool _hasLoaded = false;

  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    final LegalCategory? category = state.category;
    if (state.documents is! ViewLoading<List<LegalDocument>>) {
      emit(state.copyWith(documents: const ViewLoading<List<LegalDocument>>()));
    }
    final Result<List<LegalDocument>> result;
    try {
      result = await _gateway.listDocuments(category: category);
    } finally {
      // Reset on throw too: a blown read must not wedge the retry guard.
      _loading = false;
    }
    if (isClosed) {
      return;
    }
    _loadedCategory = category;
    _hasLoaded = true;
    switch (result) {
      case Success<List<LegalDocument>>(value: final List<LegalDocument> docs):
        emit(
          state.copyWith(
            documents: docs.isEmpty
                ? const ViewEmpty<List<LegalDocument>>()
                : ViewSuccess<List<LegalDocument>>(docs),
          ),
        );
      case Failure<List<LegalDocument>>(error: final AppError error):
        emit(
          state.copyWith(
            documents: viewStateForFailure<List<LegalDocument>>(error),
          ),
        );
    }
    // The chip moved while this read was in flight: fetch the new one.
    if (_hasLoaded && state.category != _loadedCategory) {
      await load();
    }
  }

  /// Activates a taxonomy chip, or null for "All". Reloads when the selection
  /// actually changes; re-tapping the active chip is a no-op.
  Future<void> setCategory(LegalCategory? category) async {
    if (isClosed || state.category == category) {
      return;
    }
    emit(state.copyWith(category: category));
    await load();
  }
}
