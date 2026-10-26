import 'package:legalhub/core/errors/result.dart';
import 'pending_approval.dart';

/// The create intent for one org-scoped approval request (design §3).
///
/// [organizationId] is the ACTIVE organization the client is scoped to on the
/// wire; the server re-derives membership and the matter gate in-function.
class ApprovalDraft {
  const ApprovalDraft({
    required this.organizationId,
    required this.title,
    required this.kind,
    this.matterId,
    this.description,
  });

  final String organizationId;
  final String? matterId;
  final String title;
  final ApprovalKind kind;
  final String? description;
}

/// Org-scoped approval-request integration boundary (design §3).
///
/// Reads are the `list_approval_requests` RPC scoped to one organization;
/// writes go through the three audited RPCs (`create_approval_request`,
/// `decide_approval_request`, `cancel_approval_request`). The server is the
/// authority for every gate; refusals arrive as typed [Failure]s, never as a
/// fabricated success.
abstract interface class ApprovalsGateway {
  /// The organization's requests, optionally narrowed to [status] server-side.
  Future<Result<List<PendingApproval>>> fetchApprovals({
    ApprovalStatus? status,
  });

  /// Creates a request through `create_approval_request`; returns its id.
  Future<Result<String>> create(ApprovalDraft draft);

  /// Decides a pending request through `decide_approval_request`.
  Future<Result<void>> decide(String id, {required bool approve, String? note});

  /// Cancels a pending request through `cancel_approval_request`.
  Future<Result<void>> cancel(String id);
}
