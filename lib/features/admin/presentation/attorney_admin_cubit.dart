import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_admin_gateway.dart';
import 'attorney_admin_state.dart';

/// Owns the platform-admin attorney directory (design §2).
///
/// [load] reads every profile (active and inactive). Every write is an
/// owner-only audited RPC through [AttorneyAdminGateway]; on success the list
/// reloads so the surface shows the server's own state, and on failure the
/// typed [AppError] stays on [AttorneyAdminState.actionError] for the form to
/// render. The server re-asserts the owner gate, so a denial is rendered as
/// the unauthorized arm, never an empty success.
class AttorneyAdminCubit extends Cubit<AttorneyAdminState> {
  AttorneyAdminCubit(this._gateway) : super(const AttorneyAdminState());

  final AttorneyAdminGateway _gateway;
  bool _loading = false;

  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.attorneys is! ViewLoading<List<Attorney>>) {
      emit(state.copyWith(attorneys: const ViewLoading<List<Attorney>>()));
    }
    final Result<List<Attorney>> result = await _gateway.fetchAll();
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
            clearActionError: true,
          ),
        );
      case Failure<List<Attorney>>(error: final AppError error):
        emit(
          state.copyWith(attorneys: viewStateForFailure<List<Attorney>>(error)),
        );
    }
  }

  Future<bool> create(AttorneyDraft draft) {
    return _write(() async => (await _gateway.create(draft)).errorOrNull);
  }

  Future<bool> update(String id, AttorneyDraft draft) {
    return _write(() async => (await _gateway.update(id, draft)).errorOrNull);
  }

  Future<bool> deactivate(String id) {
    return _write(() async => (await _gateway.deactivate(id)).errorOrNull);
  }

  /// Runs one write, then reloads on success. Returns true when the write
  /// landed. A write while another is in flight is ignored (false).
  Future<bool> _write(Future<AppError?> Function() run) async {
    if (isClosed || state.pending) {
      return false;
    }
    emit(state.copyWith(pending: true, clearActionError: true));
    final AppError? error = await run();
    if (isClosed) {
      return false;
    }
    if (error != null) {
      emit(state.copyWith(pending: false, actionError: error));
      return false;
    }
    emit(state.copyWith(pending: false));
    await load();
    return true;
  }
}
