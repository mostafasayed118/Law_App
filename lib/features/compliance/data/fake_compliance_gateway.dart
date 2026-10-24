import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';

/// Development-only compliance-alerts implementation: an in-memory mutable
/// list of five deterministic non-PII demo alerts.
///
/// The create/acknowledge/resolve calls work in memory so the env-less demo
/// can exercise the real workflow; they never leave the device. A configured
/// build never serves this fake (the service-locator seam flips to
/// [SupabaseComplianceGateway]). No automated legal verification is claimed.
class FakeComplianceGateway implements ComplianceAlertsGateway {
  FakeComplianceGateway() : _rows = List<ComplianceAlert>.of(syntheticAlerts);

  static final List<ComplianceAlert> syntheticAlerts = <ComplianceAlert>[
    ComplianceAlert(
      id: 'alert-1',
      organizationId: 'demo-org',
      title: 'Demo: review pending invitations',
      kind: AlertKind.filing,
      severity: AlertSeverity.low,
      status: AlertStatus.open,
      createdAt: DateTime.utc(2026, 8, 1),
    ),
    ComplianceAlert(
      id: 'alert-2',
      organizationId: 'demo-org',
      title: 'Demo: data-access review due',
      kind: AlertKind.retention,
      severity: AlertSeverity.medium,
      status: AlertStatus.open,
      description: 'Synthetic demo alert — no real compliance event is shown.',
      dueAt: DateTime.utc(2026, 8, 20),
      createdAt: DateTime.utc(2026, 8, 3),
    ),
    ComplianceAlert(
      id: 'alert-3',
      organizationId: 'demo-org',
      title: 'Demo: sample alert — high traffic',
      kind: AlertKind.other,
      severity: AlertSeverity.high,
      status: AlertStatus.acknowledged,
      acknowledgedAt: DateTime.utc(2026, 8, 5),
      createdAt: DateTime.utc(2026, 8, 4),
    ),
    ComplianceAlert(
      id: 'alert-4',
      organizationId: 'demo-org',
      title: 'Demo: retention window expiring',
      kind: AlertKind.retention,
      severity: AlertSeverity.critical,
      status: AlertStatus.open,
      dueAt: DateTime.utc(2026, 8, 15),
      createdAt: DateTime.utc(2026, 8, 5),
    ),
    ComplianceAlert(
      id: 'alert-5',
      organizationId: 'demo-org',
      title: 'Demo: review completed',
      kind: AlertKind.deadline,
      severity: AlertSeverity.low,
      status: AlertStatus.resolved,
      resolvedAt: DateTime.utc(2026, 8, 7),
      createdAt: DateTime.utc(2026, 8, 6),
    ),
  ];

  final List<ComplianceAlert> _rows;

  int _sequence = 0;

  @override
  Future<Result<List<ComplianceAlert>>> fetchAlerts({
    AlertStatus? status,
    AlertSeverity? severity,
  }) async {
    final List<ComplianceAlert> rows = _rows
        .where(
          (ComplianceAlert row) =>
              (status == null || row.status == status) &&
              (severity == null || row.severity == severity),
        )
        .toList(growable: false);
    return Result<List<ComplianceAlert>>.success(
      List<ComplianceAlert>.unmodifiable(rows),
    );
  }

  @override
  Future<Result<String>> create(ComplianceAlertDraft draft) async {
    _sequence += 1;
    final String id = 'alert-new-$_sequence';
    _rows.insert(
      0,
      ComplianceAlert(
        id: id,
        organizationId: draft.organizationId,
        matterId: draft.matterId,
        title: draft.title,
        description: draft.description,
        kind: draft.kind,
        severity: draft.severity,
        status: AlertStatus.open,
        dueAt: draft.dueAt,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return Result<String>.success(id);
  }

  @override
  Future<Result<void>> acknowledge(String id) async {
    final int index = _rows.indexWhere((ComplianceAlert row) => row.id == id);
    if (index < 0) {
      return const Result<void>.failure(_notFound);
    }
    final ComplianceAlert row = _rows[index];
    if (!row.isAcknowledgeable) {
      return const Result<void>.failure(_notOpen);
    }
    _rows[index] = _copy(
      row,
      status: AlertStatus.acknowledged,
      acknowledgedAt: DateTime.now().toUtc(),
    );
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> resolve(String id, {String? note}) async {
    final int index = _rows.indexWhere((ComplianceAlert row) => row.id == id);
    if (index < 0) {
      return const Result<void>.failure(_notFound);
    }
    final ComplianceAlert row = _rows[index];
    if (!row.isResolvable) {
      return const Result<void>.failure(_alreadyResolved);
    }
    _rows[index] = _copy(
      row,
      status: AlertStatus.resolved,
      resolvedAt: DateTime.now().toUtc(),
    );
    return const Result<void>.success(null);
  }

  ComplianceAlert _copy(
    ComplianceAlert row, {
    required AlertStatus status,
    DateTime? acknowledgedAt,
    DateTime? resolvedAt,
  }) {
    return ComplianceAlert(
      id: row.id,
      organizationId: row.organizationId,
      matterId: row.matterId,
      title: row.title,
      description: row.description,
      kind: row.kind,
      severity: row.severity,
      status: status,
      dueAt: row.dueAt,
      acknowledgedAt: acknowledgedAt ?? row.acknowledgedAt,
      resolvedAt: resolvedAt ?? row.resolvedAt,
      createdAt: row.createdAt,
    );
  }

  static const AppError _notFound = AppError(
    code: 'compliance_not_found',
    userMessage: 'Compliance alert not found.',
  );

  static const AppError _notOpen = AppError(
    code: 'compliance_acknowledge_invalid',
    userMessage: 'The alert can no longer be acknowledged.',
  );

  static const AppError _alreadyResolved = AppError(
    code: 'compliance_resolve_invalid',
    userMessage: 'The alert can no longer be resolved.',
  );
}
