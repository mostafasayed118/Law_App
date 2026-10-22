import 'package:equatable/equatable.dart';

/// Severity of a compliance alert (design §4 `low|medium|high|critical`).
///
/// Rendered with text + icon, never color alone (INSTRUCTIONS §4.5).
enum AlertSeverity { low, medium, high, critical }

/// Lifecycle of an org-scoped compliance alert (design §4).
///
/// The server stores `open | acknowledged | resolved`; resolution is terminal.
enum AlertStatus { open, acknowledged, resolved }

/// The alert category (design §4 `kind` enum).
enum AlertKind { deadline, conflict, retention, filing, other }

/// One org-scoped compliance alert (design §4).
///
/// Mirrors `compliance_alerts`: the org/matter scope, kind, severity, status,
/// description, due date, and the acknowledgement/resolution timestamps.
/// **No automated legal verification is claimed** by this record or any
/// surface rendering it.
///
/// [isAcknowledgeable] and [isResolvable] are request-level predicates only;
/// the caller's membership and role are checked by the screen (a navigation
/// hint) and, authoritatively, by the acknowledge/resolve RPCs.
class ComplianceAlert extends Equatable {
  const ComplianceAlert({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.kind,
    required this.severity,
    required this.status,
    required this.createdAt,
    this.matterId,
    this.description,
    this.dueAt,
    this.acknowledgedAt,
    this.resolvedAt,
  });

  final String id;
  final String organizationId;
  final String? matterId;
  final String title;
  final String? description;
  final AlertKind kind;
  final AlertSeverity severity;
  final AlertStatus status;
  final DateTime? dueAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  /// The acknowledge RPC admits an `open` alert only.
  bool get isAcknowledgeable => status == AlertStatus.open;

  /// The resolve RPC admits `open` or `acknowledged`; resolution is terminal.
  bool get isResolvable => status != AlertStatus.resolved;

  @override
  List<Object?> get props => <Object?>[
    id,
    organizationId,
    matterId,
    title,
    description,
    kind,
    severity,
    status,
    dueAt,
    acknowledgedAt,
    resolvedAt,
    createdAt,
  ];
}
