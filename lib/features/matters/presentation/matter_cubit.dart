import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'matter_state.dart';

/// Owns the matter dashboard list surface (Phase 7, slice 7.1).
///
/// [load] fetches the synthetic list on screen open (the screen wires it
/// after first frame, matching the roster/discovery pattern); [setStatus]
/// narrows the list client-side (owner decision D-M5) — the filtering is a
/// pure state projection ([MatterState.visibleMatters]), so no server search
/// RPC exists. Widgets render [MatterState] and dispatch intents; they never
/// call the gateway directly.
class MatterCubit extends Cubit<MatterState> {
  MatterCubit(this._gateway) : super(const MatterState());

  final MatterGateway _gateway;

  /// In-flight guard. The initial state IS loading (like
  /// [DiscoveryCubit.load]), so the flag — not a state check — distinguishes
  /// "loading in flight" from "not loaded yet"; duplicate calls while a load
  /// is in flight are ignored.
  bool _loading = false;

  /// Loads the synthetic matter list. The initial state is already loading,
  /// so the first open never re-emits a redundant loading frame; a retry
  /// after an error re-enters loading. An empty list maps to [ViewEmpty]; a
  /// failure to [ViewError] with the draft filter untouched.
  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.matters is! ViewLoading<List<Matter>>) {
      emit(state.copyWith(matters: const ViewLoading<List<Matter>>()));
    }
    final Result<List<Matter>> result;
    try {
      result = await _gateway.fetchMatters();
    } finally {
      // Reset on throw too: a blown read must not wedge the retry guard.
      _loading = false;
    }
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<Matter>>(value: final List<Matter> matters):
        emit(
          state.copyWith(
            matters: matters.isEmpty
                ? const ViewEmpty<List<Matter>>()
                : ViewSuccess<List<Matter>>(matters),
          ),
        );
      case Failure<List<Matter>>(error: final AppError error):
        emit(state.copyWith(matters: viewStateForFailure<List<Matter>>(error)));
    }
  }

  /// Activates a lifecycle-status filter chip, or null for "All".
  void setStatus(MatterStatus? status) {
    if (isClosed) {
      return;
    }
    emit(state.copyWith(status: status));
  }
}
