import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/app/legalhub_motion.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/legal_search_hit.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'library_search_state.dart';

/// Debounced full-text search over the legal library (ADR-0009).
///
/// [updateQuery] stores the field value verbatim and schedules a search after
/// [searchDebounce]; [submit] runs immediately (the keyboard's search action
/// should not feel laggy). An empty query clears the results back to the
/// no-query arm without a round trip — the server treats an empty query as
/// "nothing asked", and so does this cubit.
class LibrarySearchCubit extends Cubit<LibrarySearchState> {
  LibrarySearchCubit(this._gateway) : super(const LibrarySearchState());

  /// Typing pause before a query is sent. Matches the directory's debounce so
  /// search feels the same across the app.
  static const Duration searchDebounce = LegalHubMotion.debounce;

  final LibraryGateway _gateway;

  bool _loading = false;
  String _loadedQuery = '';
  LegalCategory? _loadedCategory;
  Timer? _debounce;

  void updateQuery(String query) {
    if (isClosed || query == state.query) {
      return;
    }
    emit(state.copyWith(query: query));
    if (query.trim().isEmpty) {
      _debounce?.cancel();
      _loadedQuery = '';
      emit(state.copyWith(results: const ViewEmpty<List<LegalSearchHit>>()));
      return;
    }
    _scheduleSearch();
  }

  /// Sets the optional category filter and re-runs the current query.
  Future<void> setCategory(LegalCategory? category) async {
    if (isClosed || state.category == category) {
      return;
    }
    emit(state.copyWith(category: category));
    _debounce?.cancel();
    await _run();
  }

  /// Runs the search now, bypassing the debounce.
  Future<void> submit() async {
    _debounce?.cancel();
    await _run();
  }

  Future<void> _run() async {
    if (isClosed || _loading) {
      return;
    }
    final String query = state.query.trim();
    if (query.isEmpty) {
      emit(state.copyWith(results: const ViewEmpty<List<LegalSearchHit>>()));
      return;
    }
    _loading = true;
    if (state.results is! ViewLoading<List<LegalSearchHit>>) {
      emit(state.copyWith(results: const ViewLoading<List<LegalSearchHit>>()));
    }
    final Result<List<LegalSearchHit>> result;
    try {
      result = await _gateway.search(query: query, category: state.category);
    } finally {
      _loading = false;
    }
    if (isClosed) {
      return;
    }
    _loadedQuery = query;
    _loadedCategory = state.category;
    switch (result) {
      case Success<List<LegalSearchHit>>(
        value: final List<LegalSearchHit> hits,
      ):
        emit(
          state.copyWith(
            results: hits.isEmpty
                ? const ViewEmpty<List<LegalSearchHit>>()
                : ViewSuccess<List<LegalSearchHit>>(hits),
          ),
        );
      case Failure<List<LegalSearchHit>>(error: final AppError error):
        emit(
          state.copyWith(
            results: viewStateForFailure<List<LegalSearchHit>>(error),
          ),
        );
    }
    // The field or the chip moved while this read was in flight: run the
    // newer query rather than leaving stale results on screen.
    if (state.query.trim() != _loadedQuery ||
        state.category != _loadedCategory) {
      _scheduleSearch();
    }
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (isClosed) {
        return;
      }
      if (state.query.trim() == _loadedQuery &&
          state.category == _loadedCategory) {
        return;
      }
      _run();
    });
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
