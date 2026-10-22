import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../../matters/domain/matter.dart';
import '../../matters/domain/matter_gateway.dart';
import '../domain/approvals_gateway.dart';
import '../domain/pending_approval.dart';
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

  bool _acting = false;

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
  /// length before submitting); an empty description becomes null.
  Future<AppError?> create(ApprovalDraft draft) async {
    if (isClosed || _acting) {
      return null;
    }
    _acting = true;
    final Result<String> result = await _gateway.create(
      ApprovalDraft(
        organizationId: draft.organizationId,
        matterId: draft.matterId,
        title: draft.title.trim(),
        kind: draft.kind,
        description: _trimOrNull(draft.description),
      ),
    );
    _acting = false;
    if (isClosed) {
      return null;
    }
    switch (result) {
      case Success<String>():
        await load();
        return null;
      case Failure<String>(error: final AppError error):
        return error;
    }
  }

  /// Decides a pending request. Returns null on success, the failure's
  /// [AppError] otherwise; a success re-reads the filtered list.
  Future<AppError?> decide(String id, {required bool approve, String? note}) {
    return _runWrite(
      () => _gateway.decide(id, approve: approve, note: _trimOrNull(note)),
    );
  }

  /// Cancels a pending request. Returns null on success, the failure's
  /// [AppError] otherwise; a success re-reads the filtered list.
  Future<AppError?> cancel(String id) {
    return _runWrite(() => _gateway.cancel(id));
  }

  Future<AppError?> _runWrite(Future<Result<void>> Function() write) async {
    if (isClosed || _acting) {
      return null;
    }
    _acting = true;
    final Result<void> result = await write();
    _acting = false;
    if (isClosed) {
      return null;
    }
    switch (result) {
      case Success<void>():
        await load();
        return null;
      case Failure<void>(error: final AppError error):
        return error;
    }
  }

  String? _trimOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
