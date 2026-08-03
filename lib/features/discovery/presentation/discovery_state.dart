import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/attorney.dart';

/// Immutable state of the attorney-discovery search surface (Phase 6, 6.1).
///
/// - [attorneys] — the profile-list load lifecycle, using the shared
///   [ViewState] vocabulary (loading / success / empty / error+retry).
/// - [query] — the free-text search filter (client-side, D-A5).
/// - [practiceArea] — the active practice-area filter chip, or null for "All".
/// - [visibleAttorneys] — the client-side filtered projection the screen
///   renders: the loaded list narrowed by [practiceArea] and [query]
///   (case-insensitive match on name or the practice-area **token**). The
///   token-level match is a deliberate D-A5 choice: area narrowing happens via
///   the chips (typed enum), so the free-text query matches the English enum
///   name (e.g. "corporate"), not localized labels. Empty until the list is
///   loaded.
class DiscoveryState extends Equatable {
  const DiscoveryState({
    this.attorneys = const ViewLoading<List<Attorney>>(),
    this.query = '',
    this.practiceArea,
  });

  final ViewState<List<Attorney>> attorneys;
  final String query;
  final PracticeArea? practiceArea;

  List<Attorney> get visibleAttorneys => switch (attorneys) {
    ViewSuccess<List<Attorney>>(data: final List<Attorney> list) => _filter(
      list,
    ),
    ViewLoading() ||
    ViewEmpty() ||
    ViewError() ||
    ViewOffline() ||
    ViewUnauthorized() => const <Attorney>[],
  };

  List<Attorney> _filter(List<Attorney> all) {
    final String needle = query.trim().toLowerCase();
    return all
        .where((Attorney attorney) {
          if (practiceArea != null && attorney.practiceArea != practiceArea) {
            return false;
          }
          if (needle.isEmpty) {
            return true;
          }
          return attorney.name.toLowerCase().contains(needle) ||
              attorney.practiceArea.name.contains(needle);
        })
        .toList(growable: false);
  }

  /// Sentinel distinguishing "not provided" from "explicitly null" so
  /// [practiceArea] can be cleared (back to "All") through copyWith.
  static const Object _unset = Object();

  DiscoveryState copyWith({
    ViewState<List<Attorney>>? attorneys,
    String? query,
    Object? practiceArea = _unset,
  }) {
    return DiscoveryState(
      attorneys: attorneys ?? this.attorneys,
      query: query ?? this.query,
      practiceArea: identical(practiceArea, _unset)
          ? this.practiceArea
          : practiceArea as PracticeArea?,
    );
  }

  @override
  List<Object?> get props => <Object?>[attorneys, query, practiceArea];
}
