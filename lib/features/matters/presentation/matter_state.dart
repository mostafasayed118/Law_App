import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/matter.dart';

/// Immutable state of the matter dashboard list surface (Phase 7, 7.1).
///
/// - [matters] — the matter-list load lifecycle, using the shared [ViewState]
///   vocabulary (loading / success / empty / error+retry).
/// - [status] — the active lifecycle-status filter chip, or null for "All".
/// - [visibleMatters] — the client-side filtered projection the screen
///   renders: the loaded list narrowed by [status] (D-M5 — status filter
///   only; no free-text search in this slice). Empty until the list loads.
class MatterState extends Equatable {
  const MatterState({
    this.matters = const ViewLoading<List<Matter>>(),
    this.status,
  });

  final ViewState<List<Matter>> matters;
  final MatterStatus? status;

  List<Matter> get visibleMatters => switch (matters) {
    ViewSuccess<List<Matter>>(data: final List<Matter> list) =>
      status == null
          ? list
          : list
                .where((Matter matter) => matter.status == status)
                .toList(growable: false),
    ViewLoading() ||
    ViewEmpty() ||
    ViewError() ||
    ViewOffline() ||
    ViewUnauthorized() => const <Matter>[],
  };

  /// Sentinel distinguishing "not provided" from "explicitly null" so
  /// [status] can be cleared (back to "All") through copyWith.
  static const Object _unset = Object();

  MatterState copyWith({
    ViewState<List<Matter>>? matters,
    Object? status = _unset,
  }) {
    return MatterState(
      matters: matters ?? this.matters,
      status: identical(status, _unset) ? this.status : status as MatterStatus?,
    );
  }

  @override
  List<Object?> get props => <Object?>[matters, status];
}
