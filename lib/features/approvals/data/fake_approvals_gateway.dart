import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/approvals/domain/approvals_gateway.dart';
import 'package:legalhub/features/approvals/domain/pending_approval.dart';

/// Development-only approvals implementation: an in-memory mutable list of
/// five synthetic, fully-redacted demo rows.
///
/// The create/decide/cancel calls work in memory so the env-less demo can
/// exercise the real workflow; they never leave the device. A configured
/// build never serves this fake (the service-locator seam flips to
/// [SupabaseApprovalGateway]).
class FakeApprovalsGateway implements ApprovalsGateway {
  FakeApprovalsGateway() : _rows = List<PendingApproval>.of(syntheticApprovals);

  static final List<PendingApproval> syntheticApprovals = <PendingApproval>[
    PendingApproval(
      id: 'approval-1',
      organizationId: 'demo-org',
      title: 'Demo conflict check — new intake',
      kind: ApprovalKind.conflict,
      status: ApprovalStatus.pending,
      requestedBy: 'demo-user',
      createdAt: DateTime.utc(2026, 8, 2),
    ),
    PendingApproval(
      id: 'approval-2',
      organizationId: 'demo-org',
      title: 'Demo engagement waiver',
      kind: ApprovalKind.waiver,
      status: ApprovalStatus.pending,
      description: 'Synthetic demo request — no real client or case data.',
      requestedBy: 'demo-user',
      createdAt: DateTime.utc(2026, 8, 3),
    ),
    PendingApproval(
      id: 'approval-3',
      organizationId: 'demo-org',
      title: 'Demo court filing approval',
      kind: ApprovalKind.filing,
      status: ApprovalStatus.approved,
      requestedBy: 'demo-user',
      decidedBy: 'demo-partner',
      decidedAt: DateTime.utc(2026, 8, 4),
      decisionNote: 'Demo decision — approved.',
      createdAt: DateTime.utc(2026, 8, 4),
    ),
    PendingApproval(
      id: 'approval-4',
      organizationId: 'demo-org',
      title: 'Demo expense approval',
      kind: ApprovalKind.expense,
      status: ApprovalStatus.denied,
      requestedBy: 'demo-user',
      decidedBy: 'demo-partner',
      decidedAt: DateTime.utc(2026, 8, 5),
      decisionNote: 'Demo decision — rejected.',
      createdAt: DateTime.utc(2026, 8, 5),
    ),
    PendingApproval(
      id: 'approval-5',
      organizationId: 'demo-org',
      title: 'Demo conflict check — opposing counsel',
      kind: ApprovalKind.conflict,
      status: ApprovalStatus.pending,
      requestedBy: 'demo-user',
      createdAt: DateTime.utc(2026, 8, 6),
    ),
  ];

  final List<PendingApproval> _rows;

  int _sequence = 0;

  @override
  Future<Result<List<PendingApproval>>> fetchApprovals({
    ApprovalStatus? status,
  }) async {
    final List<PendingApproval> rows = status == null
        ? List<PendingApproval>.unmodifiable(_rows)
        : List<PendingApproval>.unmodifiable(
            _rows.where((PendingApproval row) => row.status == status),
          );
    return Result<List<PendingApproval>>.success(rows);
  }

  @override
  Future<Result<String>> create(ApprovalDraft draft) async {
    _sequence += 1;
    final String id = 'approval-new-$_sequence';
    _rows.insert(
      0,
      PendingApproval(
        id: id,
        organizationId: draft.organizationId,
        matterId: draft.matterId,
        title: draft.title,
        description: draft.description,
        kind: draft.kind,
        status: ApprovalStatus.pending,
        requestedBy: 'demo-user',
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return Result<String>.success(id);
  }

  @override
  Future<Result<void>> decide(
    String id, {
    required bool approve,
    String? note,
  }) async {
    final int index = _rows.indexWhere((PendingApproval row) => row.id == id);
    if (index < 0) {
      return const Result<void>.failure(_notFound);
    }
    final PendingApproval row = _rows[index];
    if (row.status != ApprovalStatus.pending) {
      return const Result<void>.failure(_notPending);
    }
    final String? trimmed = _trimOrNull(note);
    if (!approve && (trimmed == null || trimmed.length < 2)) {
      return const Result<void>.failure(_rejectionNoteRequired);
    }
    _rows[index] = PendingApproval(
      id: row.id,
      organizationId: row.organizationId,
      matterId: row.matterId,
      title: row.title,
      description: row.description,
      kind: row.kind,
      status: approve ? ApprovalStatus.approved : ApprovalStatus.denied,
      requestedBy: row.requestedBy,
      decidedBy: 'demo-partner',
      decidedAt: DateTime.now().toUtc(),
      decisionNote: trimmed,
      createdAt: row.createdAt,
    );
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> cancel(String id) async {
    final int index = _rows.indexWhere((PendingApproval row) => row.id == id);
    if (index < 0) {
      return const Result<void>.failure(_notFound);
    }
    final PendingApproval row = _rows[index];
    if (row.status != ApprovalStatus.pending) {
      return const Result<void>.failure(_notPending);
    }
    _rows[index] = PendingApproval(
      id: row.id,
      organizationId: row.organizationId,
      matterId: row.matterId,
      title: row.title,
      description: row.description,
      kind: row.kind,
      status: ApprovalStatus.cancelled,
      requestedBy: row.requestedBy,
      createdAt: row.createdAt,
    );
    return const Result<void>.success(null);
  }

  String? _trimOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static const AppError _notFound = AppError(
    code: 'approval_not_found',
    userMessage: 'Approval request not found.',
  );

  static const AppError _notPending = AppError(
    code: 'approval_decide_invalid',
    userMessage: 'The request is no longer pending.',
  );

  static const AppError _rejectionNoteRequired = AppError(
    code: 'approval_decide_invalid',
    userMessage: 'A rejection note is required.',
  );
}
