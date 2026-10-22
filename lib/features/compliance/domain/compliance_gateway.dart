import '../../../core/errors/result.dart';
import 'compliance_alert.dart';

/// The create intent for one org-scoped compliance alert (design §4).
///
/// [organizationId] is the ACTIVE organization the client is scoped to on the
/// wire; the server re-derives membership and the partner/compliance-officer
/// gate in-function.
class ComplianceAlertDraft {
  const ComplianceAlertDraft({
    required this.organizationId,
    required this.title,
    required this.kind,
    required this.severity,
    this.matterId,
    this.description,
    this.dueAt,
  });

  final String organizationId;
  final String? matterId;
  final String title;
  final AlertKind kind;
  final AlertSeverity severity;
  final String? description;
  final DateTime? dueAt;
}

/// Org-scoped compliance-alert integration boundary (design §4).
///
/// Reads are the `list_compliance_alerts` RPC scoped to one organization;
/// writes go through the audited create/acknowledge/resolve RPCs. The server
/// is the authority for every gate; refusals arrive as typed [Failure]s,
/// never as a fabricated success. No automated legal verification is claimed.
abstract interface class ComplianceAlertsGateway {
  /// The organization's alerts, newest first, optionally narrowed to
  /// [status] and/or [severity] server-side.
  Future<Result<List<ComplianceAlert>>> fetchAlerts({
    AlertStatus? status,
    AlertSeverity? severity,
  });

  /// Creates an alert through `create_compliance_alert`; returns its id.
  Future<Result<String>> create(ComplianceAlertDraft draft);

  /// Acknowledges an open alert through `acknowledge_compliance_alert`.
  Future<Result<void>> acknowledge(String id);

  /// Resolves an open/acknowledged alert through `resolve_compliance_alert`.
  Future<Result<void>> resolve(String id, {String? note});
}
