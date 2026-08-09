import '../../../core/errors/result.dart';
import '../domain/approvals_gateway.dart';
import '../domain/pending_approval.dart';

/// Development-only pending-approvals implementation: a fixed synthetic list
/// of 5 deterministic, fully-redacted, non-PII demo rows (v1 queue,
/// 2026-08-09). The queue is synthetic — no real workflow backs it.
class FakeApprovalsGateway implements ApprovalsGateway {
  static final List<PendingApproval> syntheticApprovals = <PendingApproval>[
    PendingApproval(
      id: 'approval-1',
      entityType: 'invitation',
      reference: 'Demo invite — review',
      status: ApprovalStatus.pending,
      createdAt: DateTime.utc(2026, 8, 2),
    ),
    PendingApproval(
      id: 'approval-2',
      entityType: 'membership',
      reference: 'Demo role change',
      status: ApprovalStatus.pending,
      createdAt: DateTime.utc(2026, 8, 3),
    ),
    PendingApproval(
      id: 'approval-3',
      entityType: 'document',
      reference: 'Demo engagement letter',
      status: ApprovalStatus.approved,
      createdAt: DateTime.utc(2026, 8, 4),
    ),
    PendingApproval(
      id: 'approval-4',
      entityType: 'invitation',
      reference: 'Sample invite — expired',
      status: ApprovalStatus.denied,
      createdAt: DateTime.utc(2026, 8, 5),
    ),
    PendingApproval(
      id: 'approval-5',
      entityType: 'membership',
      reference: 'Demo suspension review',
      status: ApprovalStatus.pending,
      createdAt: DateTime.utc(2026, 8, 6),
    ),
  ];

  @override
  Future<Result<List<PendingApproval>>> fetchApprovals() async {
    return Result<List<PendingApproval>>.success(syntheticApprovals);
  }
}
