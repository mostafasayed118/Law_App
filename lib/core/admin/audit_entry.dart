import 'package:equatable/equatable.dart';

/// A single redacted audit-trail row as returned by the owner-only audit
/// RPCs (`read_platform_audit`, `read_org_audit`).
///
/// Metadata-only by contract §8: the server returns `redacted_summary` +
/// `correlation_id` (never credentials or content), and this VO carries
/// exactly those fields. [actorUserId] and [organizationId] are present on
/// the platform variant (cross-org read) and null on the org variant.
class AuditEntry extends Equatable {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.outcome,
    this.resourceType,
    this.resourceId,
    this.correlationId,
    required this.redactedSummary,
    required this.serverTimestamp,
    this.actorUserId,
    this.organizationId,
  });

  final int id;
  final String action;
  final String outcome;
  final String? resourceType;
  final String? resourceId;
  final String? correlationId;
  final String redactedSummary;
  final DateTime serverTimestamp;

  /// Platform-variant only (the cross-org read adds the actor identity).
  final String? actorUserId;

  /// Platform-variant only (the cross-org read adds the org the row
  /// belongs to).
  final String? organizationId;

  @override
  List<Object?> get props => <Object?>[
    id,
    action,
    outcome,
    resourceType,
    resourceId,
    correlationId,
    redactedSummary,
    serverTimestamp,
    actorUserId,
    organizationId,
  ];
}
