import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/approvals/domain/approvals_gateway.dart';
import 'package:legalhub/features/approvals/domain/pending_approval.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/shared/state/write_gate.dart';
import 'package:legalhub/shared/text/trim.dart';

import 'approvals_state.dart';

/// Owns the org-scoped approvals list and its writes (design §3).
///
/// [load] reads through [ApprovalsGateway] using the active [ApprovalsState.status]
/// filter; [setStatus] switches the filter and re-reads. [loadMatters] feeds
/// the create sheet's optional matter picker. [create] / [decide] / [cancel]
/// return the typed [AppError] on failure and null on success so the sheets
/// can render localized inline copy; a successful write re-reads the list.
class ApprovalsCubit extends Cubit<ApprovalsState> {
  ApprovalsCubit(this._gateway, this._matterGateway)
    : super(const ApprovalsState());

  final ApprovalsGateway _gateway;
  final MatterGateway _matterGateway;

  /// Monotonic request id: a filter switch while a read is in flight must not
  /// be overwritten by the older response (the SearchCubit request-sequence
  /// pattern).
  int _request = 0;

  final WriteGate _writeGate = WriteGate();

  /// The matter choices for the create sheet (the gateway's own failure is
  /// returned, never swallowed into an empty list).
  Future<Result<List<Matter>>> loadMatters() => _matterGateway.fetchMatters();

  Future<void> load() async {
    final int request = ++_request;
    if (state.approvals is! ViewLoading<List<PendingApproval>>) {
      emit(
        state.copyWith(approvals: const ViewLoading<List<PendingApproval>>()),
      );
    }
    final Result<List<PendingApproval>> result = await _gateway.fetchApprovals(
      status: state.status,
    );
    if (isClosed || request != _request) {
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
          state.copyWith(
            approvals: viewStateForFailure<List<PendingApproval>>(error),
          ),
        );
    }
  }

  /// Switches the filter and re-reads. Selecting the active filter is a no-op.
  Future<void> setStatus(ApprovalStatus? status) async {
    if (state.status == status) {
      return;
    }
    emit(state.copyWith(status: status));
    await load();
  }

  /// Creates a request. The title is trimmed here (the sheet validates its
  /// length before submitting); an empty description becomes null. A write
  /// that loses the in-flight race returns [WriteGate.busyError], never null.
  Future<AppError?> create(ApprovalDraft draft) {
    return _writeGate.run<String>(
      isClosed: () => isClosed,
      write: () => _gateway.create(
        ApprovalDraft(
          organizationId: draft.organizationId,
          matterId: draft.matterId,
          title: draft.title.trim(),
          kind: draft.kind,
          description: trimOrNull(draft.description),
        ),
      ),
      onSuccess: load,
    );
  }

  /// Decides a pending request. Returns null on success, the failure's
  /// [AppError] otherwise; a success re-reads the filtered list.
  Future<AppError?> decide(String id, {required bool approve, String? note}) {
    return _writeGate.run<void>(
      isClosed: () => isClosed,
      write: () =>
          _gateway.decide(id, approve: approve, note: trimOrNull(note)),
      onSuccess: load,
    );
  }

  /// Cancels a pending request. Returns null on success, the failure's
  /// [AppError] otherwise; a success re-reads the filtered list.
  Future<AppError?> cancel(String id) {
    return _writeGate.run<void>(
      isClosed: () => isClosed,
      write: () => _gateway.cancel(id),
      onSuccess: load,
    );
  }
}
