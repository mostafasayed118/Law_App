import 'package:equatable/equatable.dart';

/// Lifecycle of an org-scoped approval request (design §3).
///
/// The server stores `pending | approved | rejected | cancelled`; the client
/// names the rejected arm [denied] (the v1 queue's vocabulary) and the
/// Supabase row mapper translates `rejected` into it.
enum ApprovalStatus { pending, approved, denied, cancelled }

/// The request category (design §3 `kind` enum).
enum ApprovalKind { conflict, waiver, filing, expense, other }

/// One org-scoped approval request (design §3).
///
/// Mirrors `approval_requests`: title/kind/status/description plus the
/// decision trail. `matter_id`, `requested_by`, `decided_by` and the decision
/// fields are nullable by schema. [isDecidable] is a request-level predicate
/// only — the caller's role and requester identity are checked by the screen
/// (a navigation hint) and, authoritatively, by the decide RPC.
class PendingApproval extends Equatable {
  const PendingApproval({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.kind,
    required this.status,
    required this.createdAt,
    this.matterId,
    this.description,
    this.requestedBy,
    this.decidedBy,
    this.decidedAt,
    this.decisionNote,
  });

  final String id;
  final String organizationId;
  final String? matterId;
  final String title;
  final String? description;
  final ApprovalKind kind;
  final ApprovalStatus status;
  final String? requestedBy;
  final String? decidedBy;
  final DateTime? decidedAt;
  final String? decisionNote;
  final DateTime createdAt;

  /// Whether the request is still open to a decision or a cancellation
  /// (server-side: only a `pending` request may transition).
  bool get isDecidable => status == ApprovalStatus.pending;

  @override
  List<Object?> get props => <Object?>[
    id,
    organizationId,
    matterId,
    title,
    description,
    kind,
    status,
    requestedBy,
    decidedBy,
    decidedAt,
    decisionNote,
    createdAt,
  ];
}
