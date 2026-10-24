import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'supabase_compliance_api.dart';

/// Compliance-alert gateway backed by the Supabase provider (design §4).
///
/// Raw rows become [ComplianceAlert] VOs, typed
/// [SupabaseComplianceException]s become [AppError]s with the
/// denied/validation/unavailable classification preserved, and provider drift
/// surfaces loudly instead of rendering a wrong alert. The read needs the
/// caller's active organization id, supplied as a resolver so the data layer
/// never imports the app-scoped store.
class SupabaseComplianceGateway implements ComplianceAlertsGateway {
  SupabaseComplianceGateway(this._api, {required this.organizationId});

  final SupabaseComplianceApi _api;
  final String? Function() organizationId;

  @override
  Future<Result<List<ComplianceAlert>>> fetchAlerts({
    AlertStatus? status,
    AlertSeverity? severity,
  }) async {
    final String? organizationId = this.organizationId();
    if (organizationId == null || organizationId.isEmpty) {
      return Result<List<ComplianceAlert>>.failure(
        const AppError(
          code: 'compliance_read_no_org',
          userMessage: 'Select an organization to view compliance alerts.',
        ),
      );
    }
    try {
      final List<Map<String, dynamic>> rows = await _api.listAlerts(
        organizationId: organizationId,
        status: status == null ? null : _serverStatus(status),
        severity: severity == null ? null : _serverSeverity(severity),
      );
      return Result<List<ComplianceAlert>>.success(
        List<ComplianceAlert>.unmodifiable(rows.map(_fromRow)),
      );
    } on SupabaseComplianceException catch (e) {
      return Result<List<ComplianceAlert>>.failure(
        _errorFor(
          e,
          prefix: 'compliance_read',
          deniedMessage:
              'You do not have permission to view compliance alerts.',
          validationMessage:
              'Unable to load compliance alerts. Please try again.',
          unavailableMessage:
              'Compliance alerts are temporarily unavailable. Please try again.',
          failedMessage: 'Unable to load compliance alerts. Please try again.',
        ),
      );
    } on FormatException catch (e) {
      return Result<List<ComplianceAlert>>.failure(_drift(e));
    }
  }

  @override
  Future<Result<String>> create(ComplianceAlertDraft draft) async {
    try {
      final String id = await _api.createAlert(
        organizationId: draft.organizationId,
        matterId: draft.matterId,
        kind: draft.kind.name,
        severity: draft.severity.name,
        title: draft.title,
        description: draft.description,
        dueAt: draft.dueAt,
      );
      return Result<String>.success(id);
    } on SupabaseComplianceException catch (e) {
      return Result<String>.failure(
        _errorFor(
          e,
          prefix: 'compliance_create',
          deniedMessage:
              'Only a partner or compliance officer can create alerts.',
          validationMessage:
              'The alert could not be created. Check the details and try again.',
          unavailableMessage:
              'Creating the alert is temporarily unavailable. Please try again.',
          failedMessage: 'Unable to create the alert. Please try again.',
        ),
      );
    } on FormatException catch (e) {
      return Result<String>.failure(_drift(e));
    }
  }

  @override
  Future<Result<void>> acknowledge(String id) {
    return _write(
      () => _api.acknowledgeAlert(id),
      prefix: 'compliance_acknowledge',
      deniedMessage:
          'Only an active organization member can acknowledge alerts.',
      validationMessage: 'The alert can no longer be acknowledged.',
      unavailableMessage:
          'Acknowledging the alert is temporarily unavailable. Please try again.',
      failedMessage: 'Unable to acknowledge the alert. Please try again.',
    );
  }

  @override
  Future<Result<void>> resolve(String id, {String? note}) {
    return _write(
      () => _api.resolveAlert(id, note: note),
      prefix: 'compliance_resolve',
      deniedMessage: 'Only a partner or compliance officer can resolve alerts.',
      validationMessage: 'The alert can no longer be resolved.',
      unavailableMessage:
          'Resolving the alert is temporarily unavailable. Please try again.',
      failedMessage: 'Unable to resolve the alert. Please try again.',
    );
  }

  Future<Result<void>> _write(
    Future<void> Function() write, {
    required String prefix,
    required String deniedMessage,
    required String validationMessage,
    required String unavailableMessage,
    required String failedMessage,
  }) async {
    try {
      await write();
      return const Result<void>.success(null);
    } on SupabaseComplianceException catch (e) {
      return Result<void>.failure(
        _errorFor(
          e,
          prefix: prefix,
          deniedMessage: deniedMessage,
          validationMessage: validationMessage,
          unavailableMessage: unavailableMessage,
          failedMessage: failedMessage,
        ),
      );
    } on FormatException catch (e) {
      return Result<void>.failure(_drift(e));
    }
  }

  /// Maps one raw `compliance_alerts` row to the [ComplianceAlert] VO.
  ///
  /// Required shapes are asserted explicitly (id, org, title, kind, severity,
  /// status, created_at) so a malformed row surfaces as a typed
  /// `FormatException` rather than a raw cast error across the boundary.
  ComplianceAlert _fromRow(Map<String, dynamic> row) {
    return ComplianceAlert(
      id: _requiredString(row, 'id'),
      organizationId: _requiredString(row, 'organization_id'),
      matterId: _optionalString(row['matter_id']),
      title: _requiredString(row, 'title'),
      description: _optionalString(row['description']),
      kind: _kindOf(row['kind']),
      severity: _severityOf(row['severity']),
      status: _statusOf(row['status']),
      dueAt: _optionalDate(row['due_at']),
      acknowledgedAt: _optionalDate(row['acknowledged_at']),
      resolvedAt: _optionalDate(row['resolved_at']),
      createdAt: _requiredDate(row, 'created_at'),
    );
  }

  AlertSeverity _severityOf(Object? value) => switch (value) {
    'low' => AlertSeverity.low,
    'medium' => AlertSeverity.medium,
    'high' => AlertSeverity.high,
    'critical' => AlertSeverity.critical,
    _ => throw const FormatException(
      'Compliance alert has an unknown severity',
    ),
  };

  AlertStatus _statusOf(Object? value) => switch (value) {
    'open' => AlertStatus.open,
    'acknowledged' => AlertStatus.acknowledged,
    'resolved' => AlertStatus.resolved,
    _ => throw const FormatException('Compliance alert has an unknown status'),
  };

  AlertKind _kindOf(Object? value) => switch (value) {
    'deadline' => AlertKind.deadline,
    'conflict' => AlertKind.conflict,
    'retention' => AlertKind.retention,
    'filing' => AlertKind.filing,
    'other' => AlertKind.other,
    _ => throw const FormatException('Compliance alert has an unknown kind'),
  };

  String _serverStatus(AlertStatus status) => switch (status) {
    AlertStatus.open => 'open',
    AlertStatus.acknowledged => 'acknowledged',
    AlertStatus.resolved => 'resolved',
  };

  String _serverSeverity(AlertSeverity severity) => switch (severity) {
    AlertSeverity.low => 'low',
    AlertSeverity.medium => 'medium',
    AlertSeverity.high => 'high',
    AlertSeverity.critical => 'critical',
  };

  String _requiredString(Map<String, dynamic> row, String field) {
    final Object? value = row[field];
    if (value is! String || value.isEmpty) {
      throw FormatException('Compliance alert has no $field');
    }
    return value;
  }

  DateTime _requiredDate(Map<String, dynamic> row, String field) {
    final Object? value = row[field];
    if (value is! String) {
      throw FormatException('Compliance alert has no $field');
    }
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Compliance alert has an invalid $field');
    }
    return parsed;
  }

  DateTime? _optionalDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw const FormatException('Compliance alert has an invalid date');
    }
    return parsed;
  }

  String? _optionalString(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Maps a seam failure to a redaction-safe [AppError]. Alert content never
  /// crosses into errors; only the provider's own message crosses as the
  /// technical message.
  AppError _errorFor(
    SupabaseComplianceException e, {
    required String prefix,
    required String deniedMessage,
    required String validationMessage,
    required String unavailableMessage,
    required String failedMessage,
  }) {
    return switch (e.kind) {
      SupabaseComplianceFailureKind.denied => AppError(
        code: '${prefix}_denied',
        userMessage: deniedMessage,
        kind: AppErrorKind.denied,
        technicalMessage: e.message,
      ),
      SupabaseComplianceFailureKind.notFound => AppError(
        code: 'compliance_not_found',
        userMessage: 'Compliance alert not found.',
        technicalMessage: e.message,
      ),
      SupabaseComplianceFailureKind.validation => AppError(
        code: '${prefix}_invalid',
        userMessage: validationMessage,
        technicalMessage: e.message,
      ),
      SupabaseComplianceFailureKind.providerUnavailable => AppError(
        code: '${prefix}_unavailable',
        userMessage: unavailableMessage,
        kind: AppErrorKind.unavailable,
        technicalMessage: e.message,
      ),
      SupabaseComplianceFailureKind.unknown => AppError(
        code: '${prefix}_failed',
        userMessage: failedMessage,
        technicalMessage: e.message,
      ),
    };
  }

  /// Provider drift (unexpected row shape) surfaces loudly, never as a
  /// silently wrong alert.
  AppError _drift(FormatException e) => AppError(
    code: 'compliance_read_failed',
    userMessage: 'Unable to load compliance alerts. Please try again.',
    technicalMessage: e.message,
  );
}
