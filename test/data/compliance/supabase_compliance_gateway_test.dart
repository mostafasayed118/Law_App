import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/compliance/data/supabase_compliance_api.dart';
import 'package:legalhub/features/compliance/data/supabase_compliance_gateway.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';

void main() {
  group('SupabaseComplianceGateway (design §4)', () {
    late _StubComplianceApi api;
    late SupabaseComplianceGateway gateway;

    setUp(() {
      api = _StubComplianceApi();
      gateway = SupabaseComplianceGateway(api, organizationId: () => 'org-1');
    });

    test('fetch maps a full row and passes the org + empty filters', () async {
      api.listRows = <Map<String, dynamic>>[
        _row(
          status: 'acknowledged',
          severity: 'high',
          kind: 'filing',
          description: 'Review the filing window.',
          dueAt: '2026-10-30T09:00:00Z',
          acknowledgedAt: '2026-10-22T08:00:00Z',
        ),
      ];

      final Result<List<ComplianceAlert>> result = await gateway.fetchAlerts();

      expect(result, isA<Success<List<ComplianceAlert>>>());
      final ComplianceAlert alert =
          (result as Success<List<ComplianceAlert>>).value.single;
      expect(alert.id, 'a1');
      expect(alert.organizationId, 'org-1');
      expect(alert.title, 'Filing review');
      expect(alert.description, 'Review the filing window.');
      expect(alert.kind, AlertKind.filing);
      expect(alert.severity, AlertSeverity.high);
      expect(alert.status, AlertStatus.acknowledged);
      expect(alert.dueAt, DateTime.utc(2026, 10, 30, 9));
      expect(alert.acknowledgedAt, DateTime.utc(2026, 10, 22, 8));
      expect(alert.resolvedAt, isNull);
      expect(alert.isAcknowledgeable, isFalse);
      expect(alert.isResolvable, isTrue);
      expect(api.lastListOrganizationId, 'org-1');
      expect(api.lastListStatus, isNull);
      expect(api.lastListSeverity, isNull);
    });

    test(
      'fetch maps every status and severity and translates the filters',
      () async {
        api.listRows = <Map<String, dynamic>>[
          _row(status: 'open', severity: 'low'),
          _row(id: 'a2', status: 'acknowledged', severity: 'medium'),
          _row(id: 'a3', status: 'resolved', severity: 'critical'),
        ];

        final Result<List<ComplianceAlert>> result = await gateway.fetchAlerts(
          status: AlertStatus.resolved,
          severity: AlertSeverity.critical,
        );

        final List<ComplianceAlert> rows =
            (result as Success<List<ComplianceAlert>>).value;
        expect(rows.map((ComplianceAlert row) => row.status), <AlertStatus>[
          AlertStatus.open,
          AlertStatus.acknowledged,
          AlertStatus.resolved,
        ]);
        expect(rows.map((ComplianceAlert row) => row.severity), <AlertSeverity>[
          AlertSeverity.low,
          AlertSeverity.medium,
          AlertSeverity.critical,
        ]);
        expect(api.lastListStatus, 'resolved');
        expect(api.lastListSeverity, 'critical');
        expect(rows.first.isAcknowledgeable, isTrue);
        expect(rows.last.isResolvable, isFalse);
      },
    );

    test('fetch without an active organization fails honestly', () async {
      final SupabaseComplianceGateway unbound = SupabaseComplianceGateway(
        api,
        organizationId: () => null,
      );

      final Result<List<ComplianceAlert>> result = await unbound.fetchAlerts();

      expect(result, isA<Failure<List<ComplianceAlert>>>());
      expect(
        (result as Failure<List<ComplianceAlert>>).error.code,
        'compliance_read_no_org',
      );
      expect(api.listCalls, 0);
    });

    test('a denied read keeps the denied classification', () async {
      api.error = const SupabaseComplianceException(
        kind: SupabaseComplianceFailureKind.denied,
        message: 'permission denied',
      );

      final Result<List<ComplianceAlert>> result = await gateway.fetchAlerts();

      final AppError error = (result as Failure<List<ComplianceAlert>>).error;
      expect(error.code, 'compliance_read_denied');
      expect(error.kind, AppErrorKind.denied);
    });

    test('an unknown severity surfaces as provider drift, not a row', () async {
      api.listRows = <Map<String, dynamic>>[_row(severity: 'severe')];

      final Result<List<ComplianceAlert>> result = await gateway.fetchAlerts();

      final AppError error = (result as Failure<List<ComplianceAlert>>).error;
      expect(error.code, 'compliance_read_failed');
      expect(error.technicalMessage, contains('unknown severity'));
    });

    test('create sends the draft fields and returns the new id', () async {
      final Result<String> result = await gateway.create(
        const ComplianceAlertDraft(
          organizationId: 'org-1',
          title: 'Retention review',
          kind: AlertKind.retention,
          severity: AlertSeverity.medium,
          description: 'Check the retention window.',
          dueAt: null,
        ),
      );

      expect(result, isA<Success<String>>());
      expect((result as Success<String>).value, 'new-id');
      expect(api.createdOrganizationId, 'org-1');
      expect(api.createdTitle, 'Retention review');
      expect(api.createdKind, 'retention');
      expect(api.createdSeverity, 'medium');
      expect(api.createdDescription, 'Check the retention window.');
      expect(api.createdDueAt, isNull);
    });

    test('create forwards the due date', () async {
      final DateTime dueAt = DateTime.utc(2026, 10, 31);

      await gateway.create(
        ComplianceAlertDraft(
          organizationId: 'org-1',
          title: 'Deadline review',
          kind: AlertKind.deadline,
          severity: AlertSeverity.high,
          dueAt: dueAt,
        ),
      );

      expect(api.createdDueAt, dueAt);
    });

    test('create maps a denial to the role-specific copy', () async {
      api.error = const SupabaseComplianceException(
        kind: SupabaseComplianceFailureKind.denied,
        message: 'permission denied',
      );

      final Result<String> result = await gateway.create(
        const ComplianceAlertDraft(
          organizationId: 'org-1',
          title: 'Retention review',
          kind: AlertKind.retention,
          severity: AlertSeverity.medium,
        ),
      );

      final AppError error = (result as Failure<String>).error;
      expect(error.code, 'compliance_create_denied');
      expect(error.userMessage, contains('partner or compliance officer'));
      expect(error.kind, AppErrorKind.denied);
    });

    test('acknowledge succeeds and resolves the id', () async {
      final Result<void> result = await gateway.acknowledge('a1');

      expect(result, isA<Success<void>>());
      expect(api.acknowledgedId, 'a1');
    });

    test('acknowledge maps a terminal state to a validation error', () async {
      api.error = const SupabaseComplianceException(
        kind: SupabaseComplianceFailureKind.validation,
        message: 'compliance alert is already acknowledged',
      );

      final Result<void> result = await gateway.acknowledge('a1');

      final AppError error = (result as Failure<void>).error;
      expect(error.code, 'compliance_acknowledge_invalid');
      expect(error.userMessage, contains('no longer be acknowledged'));
    });

    test('resolve forwards the note and succeeds', () async {
      final Result<void> result = await gateway.resolve(
        'a1',
        note: 'Closed after review.',
      );

      expect(result, isA<Success<void>>());
      expect(api.resolvedId, 'a1');
      expect(api.resolvedNote, 'Closed after review.');
    });

    test('resolve maps a missing alert to a not-found error', () async {
      api.error = const SupabaseComplianceException(
        kind: SupabaseComplianceFailureKind.notFound,
        message: 'compliance alert not found',
      );

      final Result<void> result = await gateway.resolve('missing');

      final AppError error = (result as Failure<void>).error;
      expect(error.code, 'compliance_not_found');
      expect(error.userMessage, 'Compliance alert not found.');
    });
  });
}

Map<String, dynamic> _row({
  String id = 'a1',
  String status = 'open',
  String severity = 'low',
  String kind = 'deadline',
  String? description,
  String? dueAt,
  String? acknowledgedAt,
  String? resolvedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'organization_id': 'org-1',
    'matter_id': null,
    'kind': kind,
    'severity': severity,
    'title': 'Filing review',
    'description': description,
    'status': status,
    'due_at': dueAt,
    'acknowledged_by': null,
    'acknowledged_at': acknowledgedAt,
    'resolved_by': null,
    'resolved_at': resolvedAt,
    'created_by': 'u-partner',
    'created_at': '2026-10-21T10:00:00Z',
  };
}

class _StubComplianceApi implements SupabaseComplianceApi {
  List<Map<String, dynamic>> listRows = <Map<String, dynamic>>[];
  SupabaseComplianceException? error;

  int listCalls = 0;
  String? lastListOrganizationId;
  String? lastListStatus;
  String? lastListSeverity;

  String? createdOrganizationId;
  String? createdTitle;
  String? createdKind;
  String? createdSeverity;
  String? createdDescription;
  DateTime? createdDueAt;

  String? acknowledgedId;
  String? resolvedId;
  String? resolvedNote;

  @override
  Future<List<Map<String, dynamic>>> listAlerts({
    required String organizationId,
    String? status,
    String? severity,
  }) async {
    listCalls += 1;
    lastListOrganizationId = organizationId;
    lastListStatus = status;
    lastListSeverity = severity;
    _throwIfErrored();
    return listRows;
  }

  @override
  Future<String> createAlert({
    required String organizationId,
    String? matterId,
    required String kind,
    required String severity,
    required String title,
    String? description,
    DateTime? dueAt,
  }) async {
    createdOrganizationId = organizationId;
    createdTitle = title;
    createdKind = kind;
    createdSeverity = severity;
    createdDescription = description;
    createdDueAt = dueAt;
    _throwIfErrored();
    return 'new-id';
  }

  @override
  Future<void> acknowledgeAlert(String id) async {
    acknowledgedId = id;
    _throwIfErrored();
  }

  @override
  Future<void> resolveAlert(String id, {String? note}) async {
    resolvedId = id;
    resolvedNote = note;
    _throwIfErrored();
  }

  void _throwIfErrored() {
    final SupabaseComplianceException? failure = error;
    if (failure != null) {
      throw failure;
    }
  }
}
