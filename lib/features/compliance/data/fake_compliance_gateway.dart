import '../../../core/errors/result.dart';
import '../domain/compliance_alert.dart';
import '../domain/compliance_gateway.dart';

/// Development-only compliance-alerts implementation: a fixed synthetic list
/// of 5 deterministic non-PII alerts (v1 queue demo surface, 2026-08-09).
class FakeComplianceGateway implements ComplianceAlertsGateway {
  static final List<ComplianceAlert> syntheticAlerts = <ComplianceAlert>[
    ComplianceAlert(
      id: 'alert-1',
      title: 'Demo: review pending invitations',
      severity: AlertSeverity.info,
      createdAt: DateTime.utc(2026, 8, 1),
    ),
    ComplianceAlert(
      id: 'alert-2',
      title: 'Demo: data-access review due',
      severity: AlertSeverity.attention,
      createdAt: DateTime.utc(2026, 8, 3),
    ),
    ComplianceAlert(
      id: 'alert-3',
      title: 'Demo: sample alert — high traffic',
      severity: AlertSeverity.critical,
      createdAt: DateTime.utc(2026, 8, 4),
    ),
    ComplianceAlert(
      id: 'alert-4',
      title: 'Demo: retention window expiring',
      severity: AlertSeverity.attention,
      createdAt: DateTime.utc(2026, 8, 5),
    ),
    ComplianceAlert(
      id: 'alert-5',
      title: 'Demo: review completed',
      severity: AlertSeverity.info,
      createdAt: DateTime.utc(2026, 8, 6),
    ),
  ];

  @override
  Future<Result<List<ComplianceAlert>>> fetchAlerts() async {
    return Result<List<ComplianceAlert>>.success(syntheticAlerts);
  }
}