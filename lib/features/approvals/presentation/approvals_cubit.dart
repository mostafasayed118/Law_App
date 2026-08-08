import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/approvals_gateway.dart';
import '../domain/pending_approval.dart';
import 'approvals_state.dart';

/// Owns the pending-approvals list (v1 queue, 2026-08-09).
///
/// [load] fetches the deterministic synthetic list on screen open (the
/// vault/messaging pattern). **Read-only** — there is no approve/deny action
/// anywhere on this surface (the real workflows are deferred).
class ApprovalsCubit extends Cubit<ApprovalsState> {
  ApprovalsCubit(this._gateway) : super(const ApprovalsState());

  final ApprovalsGateway _gateway;

  bool _loading = false;

  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.approvals is! ViewLoading<List<PendingApproval>>) {
      emit(
        state.copyWith(approvals: const ViewLoading<List<PendingApproval>>()),
      );
    }
    final Result<List<PendingApproval>> result =
        await _gateway.fetchApprovals();
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<PendingApproval>>(
        value: final List<PendingApproval> approvals,
      ):
        emit(
          state.copyWith(
            approvals: approvals.isEmpty
                ? const ViewEmpty<List<PendingApproval>>()
                : ViewSuccess<List<PendingApproval>>(approvals),
          ),
        );
      case Failure<List<PendingApproval>>(error: final AppError error):
        emit(
          state.copyWith(approvals: ViewError<List<PendingApproval>>(error)),
        );
    }
  }
}