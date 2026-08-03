import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/practice_area.dart';
import '../../../core/state/view_state.dart';
import '../domain/attorney.dart';
import '../domain/attorney_gateway.dart';
import 'discovery_state.dart';

/// Owns the attorney-discovery search surface (Phase 6, slice 6.1).
///
/// [load] fetches the synthetic list on screen open (the screen wires it after
/// first frame, matching the roster pattern); [updateQuery] and
/// [setPracticeArea] narrow the list client-side (owner decision D-A5) — the
/// filtering is a pure state projection ([DiscoveryState.visibleAttorneys]), so
/// no server search RPC exists. Widgets render [DiscoveryState] and dispatch
/// intents; they never call the gateway directly.
class DiscoveryCubit extends Cubit<DiscoveryState> {
  DiscoveryCubit(this._gateway) : super(const DiscoveryState());

  final AttorneyGateway _gateway;

  /// In-flight guard. Unlike [OrgCubit.loadRoster]'s state-based guard, the
  /// initial state here IS loading, so a naive `if (loading) return` would
  /// abort the very first load — the flag distinguishes "loading in flight"
  /// from "not loaded yet".
  bool _loading = false;

  /// Loads the synthetic attorney list. The initial state is already loading,
  /// so the first open never re-emits a redundant loading frame; a retry after
  /// an error re-enters loading. Duplicate calls while a load is in flight are
  /// ignored (same discipline as [OrgCubit.loadRoster]/[BookingCubit.confirm]).
  /// An empty list maps to [ViewEmpty]; a failure to [ViewError] with the
  /// draft filters untouched.
  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.attorneys is! ViewLoading<List<Attorney>>) {
      emit(state.copyWith(attorneys: const ViewLoading<List<Attorney>>()));
    }
    final Result<List<Attorney>> result = await _gateway.fetchAttorneys();
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<Attorney>>(value: final List<Attorney> attorneys):
        emit(
          state.copyWith(
            attorneys: attorneys.isEmpty
                ? const ViewEmpty<List<Attorney>>()
                : ViewSuccess<List<Attorney>>(attorneys),
          ),
        );
      case Failure<List<Attorney>>(error: final AppError error):
        emit(state.copyWith(attorneys: ViewError<List<Attorney>>(error)));
    }
  }

  /// Stores the free-text search query verbatim (no trim here — trimming
  /// happens in the state's filter projection so typing is never fought).
  void updateQuery(String query) {
    if (isClosed) {
      return;
    }
    emit(state.copyWith(query: query));
  }

  /// Activates a practice-area filter chip, or null for "All".
  void setPracticeArea(PracticeArea? area) {
    if (isClosed) {
      return;
    }
    emit(state.copyWith(practiceArea: area));
  }
}
