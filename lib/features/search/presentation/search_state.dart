import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/search_results.dart';

/// Immutable state of the unified search surface (Phase 11, slice 11.0).
///
/// - [results] — the grouped-search lifecycle, on the shared [ViewState]
///   vocabulary: initial/idle and in-flight are [ViewLoading]; a completed
///   search is [ViewSuccess]; a search with no matches anywhere is
///   [ViewEmpty]; a failure is [ViewError]. An **empty query** (blank or
///   whitespace-only) also lands on [ViewEmpty] — with zero gateway calls —
///   so [isNoQuery] tells the surface to render the no-query state instead
///   of results (D-S4).
/// - [query] — the last submitted query, stored verbatim (never trimmed;
///   trimming happens in the cubit's guard so typing is never fought).
class SearchState extends Equatable {
  const SearchState({
    this.results = const ViewLoading<SearchResults>(),
    this.query = '',
  });

  final ViewState<SearchResults> results;

  final String query;

  /// True when the submitted query is blank/whitespace-only — the surface
  /// renders the no-query state, not results (D-S4).
  bool get isNoQuery => query.trim().isEmpty;

  SearchState copyWith({ViewState<SearchResults>? results, String? query}) {
    return SearchState(
      results: results ?? this.results,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => <Object?>[results, query];
}
