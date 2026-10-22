import 'package:equatable/equatable.dart';

import '../../../core/practice_area.dart';
import '../../../core/state/view_state.dart';
import '../domain/attorney.dart';

/// Immutable state of the attorney-discovery surfaces (design §2).
///
/// - [attorneys] — the list load lifecycle, using the shared [ViewState]
///   vocabulary (loading / success / empty / error+retry).
/// - [profile] — the detail load lifecycle for `/discovery/:id`.
/// - [query] — the free-text search query; sent to the gateway debounced and
///   also projected locally so typing stays instant.
/// - [practiceArea] — the active practice-area chip, or null for "All".
/// - [visibleAttorneys] — the loaded page narrowed locally by [practiceArea]
///   and [query]. The server already applies [query]; the local pass keeps
///   the practice-area chips exact and preserves the pre-server-pass
///   behavior for the fake and for the current page.
class DiscoveryState extends Equatable {
  const DiscoveryState({
    this.attorneys = const ViewLoading<List<Attorney>>(),
    this.profile = const ViewLoading<Attorney>(),
    this.query = '',
    this.practiceArea,
  });

  final ViewState<List<Attorney>> attorneys;
  final ViewState<Attorney> profile;
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

  /// [visibleAttorneys] as a [ViewState], for the lazy list surface.
  ViewState<List<Attorney>> get visibleAttorneysState => switch (attorneys) {
    ViewSuccess<List<Attorney>>() => ViewSuccess<List<Attorney>>(
      visibleAttorneys,
    ),
    final ViewState<List<Attorney>> other => other,
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
              (attorney.practiceArea?.name.contains(needle) ?? false) ||
              (attorney.headline?.toLowerCase().contains(needle) ?? false) ||
              (attorney.city?.toLowerCase().contains(needle) ?? false) ||
              attorney.specialties.any(
                (String value) => value.toLowerCase().contains(needle),
              ) ||
              attorney.languages.any(
                (String value) => value.toLowerCase().contains(needle),
              );
        })
        .toList(growable: false);
  }

  /// Sentinel distinguishing "not provided" from "explicitly null" so
  /// [practiceArea] can be cleared (back to "All") through copyWith.
  static const Object _unset = Object();

  DiscoveryState copyWith({
    ViewState<List<Attorney>>? attorneys,
    ViewState<Attorney>? profile,
    String? query,
    Object? practiceArea = _unset,
  }) {
    return DiscoveryState(
      attorneys: attorneys ?? this.attorneys,
      profile: profile ?? this.profile,
      query: query ?? this.query,
      practiceArea: identical(practiceArea, _unset)
          ? this.practiceArea
          : practiceArea as PracticeArea?,
    );
  }

  @override
  List<Object?> get props => <Object?>[attorneys, profile, query, practiceArea];
}
