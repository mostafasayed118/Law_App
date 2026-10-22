import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/pending_approval.dart';

/// Immutable state of the approvals surface (design §3).
///
/// [status] is the active server-side filter (null = all); [approvals] is the
/// current list arm.
class ApprovalsState extends Equatable {
  const ApprovalsState({
    this.approvals = const ViewLoading<List<PendingApproval>>(),
    this.status,
  });

  final ViewState<List<PendingApproval>> approvals;
  final ApprovalStatus? status;

  ApprovalsState copyWith({
    ViewState<List<PendingApproval>>? approvals,
    Object? status = _unset,
  }) {
    return ApprovalsState(
      approvals: approvals ?? this.approvals,
      status: identical(status, _unset)
          ? this.status
          : status as ApprovalStatus?,
    );
  }

  static const Object _unset = Object();

  @override
  List<Object?> get props => <Object?>[approvals, status];
}
