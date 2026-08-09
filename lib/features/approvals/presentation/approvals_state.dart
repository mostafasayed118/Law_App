import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/pending_approval.dart';

/// Immutable state of the pending-approvals surface (v1 queue, 2026-08-09).
class ApprovalsState extends Equatable {
  const ApprovalsState({
    this.approvals = const ViewLoading<List<PendingApproval>>(),
  });

  final ViewState<List<PendingApproval>> approvals;

  ApprovalsState copyWith({ViewState<List<PendingApproval>>? approvals}) {
    return ApprovalsState(approvals: approvals ?? this.approvals);
  }

  @override
  List<Object?> get props => <Object?>[approvals];
}
