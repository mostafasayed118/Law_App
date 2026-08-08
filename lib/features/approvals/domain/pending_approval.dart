import 'package:equatable/equatable.dart';

/// Lifecycle of a pending-approval row (v1 queue, 2026-08-09).
enum ApprovalStatus { pending, approved, denied }

/// A pending-approval row (v1 queue; `legalhub_specification.md` §6
/// `pending_approvals_queue`, v1). **Redacted/synthetic only**: entity type,
/// generic reference, status, and created date — never content or
/// credentials (the §8 discipline). No real matter/doc data.
class PendingApproval extends Equatable {
  const PendingApproval({
    required this.id,
    required this.entityType,
    required this.reference,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String entityType;
  final String reference;
  final ApprovalStatus status;
  final DateTime createdAt;

  @override
  List<Object?> get props => <Object?>[
    id,
    entityType,
    reference,
    status,
    createdAt,
  ];
}