import 'package:equatable/equatable.dart';

import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/legal_search_hit.dart';

/// Immutable state of the library search surface (ADR-0009).
///
/// - [results] — the hit lifecycle. The initial value is [ViewEmpty] rather
///   than loading: opening the surface with no query has not asked the server
///   anything, and showing a spinner would claim a request that never happened.
/// - [query] — the raw field value; trimmed at the gateway boundary.
/// - [category] — the optional taxonomy filter carried with the query.
class LibrarySearchState extends Equatable {
  const LibrarySearchState({
    this.results = const ViewEmpty<List<LegalSearchHit>>(),
    this.query = '',
    this.category,
  });

  final ViewState<List<LegalSearchHit>> results;
  final String query;
  final LegalCategory? category;

  /// True when the user has typed something worth searching for.
  bool get hasQuery => query.trim().isNotEmpty;

  static const Object _unset = Object();

  LibrarySearchState copyWith({
    ViewState<List<LegalSearchHit>>? results,
    String? query,
    Object? category = _unset,
  }) {
    return LibrarySearchState(
      results: results ?? this.results,
      query: query ?? this.query,
      category: identical(category, _unset)
          ? this.category
          : category as LegalCategory?,
    );
  }

  @override
  List<Object?> get props => <Object?>[results, query, category];
}
