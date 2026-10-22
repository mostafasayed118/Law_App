import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/approvals/supabase_approval_api.dart';
import 'package:legalhub/data/approvals/supabase_approval_gateway.dart';
import 'package:legalhub/features/approvals/domain/approvals_gateway.dart';
import 'package:legalhub/features/approvals/domain/pending_approval.dart';

void main() {
  group('SupabaseApprovalGateway (design §3)', () {
    late _StubApprovalApi api;
    late SupabaseApprovalGateway gateway;

    setUp(() {
      api = _StubApprovalApi();
      gateway = SupabaseApprovalGateway(api, organizationId: () => 'org-1');
    });

    test(
      'fetch maps a rejected row to denied and keeps the decision trail',
      () async {
        api.listRows = <Map<String, dynamic>>[
          _row(
            status: 'rejected',
            description: 'Conflict waiver for a new matter.',
            decidedAt: '2026-10-02T14:30:00Z',
            decidedBy: 'u-partner',
            note: 'Outside the engagement scope.',
          ),
        ];

        final Result<List<PendingApproval>> result = await gateway
            .fetchApprovals();

        expect(result, isA<Success<List<PendingApproval>>>());
        final PendingApproval approval =
            (result as Success<List<PendingApproval>>).value.single;
        expect(approval.id, 'a1');
        expect(approval.organizationId, 'org-1');
        expect(approval.title, 'Matter waiver');
        expect(approval.description, 'Conflict waiver for a new matter.');
        expect(approval.kind, ApprovalKind.conflict);
        expect(approval.status, ApprovalStatus.denied);
        expect(approval.requestedBy, 'u-requester');
        expect(approval.decidedBy, 'u-partner');
        expect(approval.decidedAt, DateTime.utc(2026, 10, 2, 14, 30));
        expect(approval.decisionNote, 'Outside the engagement scope.');
        expect(approval.isDecidable, isFalse);
        expect(api.lastListOrganizationId, 'org-1');
        expect(api.lastListStatus, isNull);
      },
    );

    test('fetch maps every status and translates the denied filter', () async {
      api.listRows = <Map<String, dynamic>>[
        _row(status: 'pending'),
        _row(id: 'a2', status: 'approved'),
        _row(id: 'a3', status: 'cancelled'),
      ];

      final Result<List<PendingApproval>> result = await gateway.fetchApprovals(
        status: ApprovalStatus.denied,
      );

      final List<PendingApproval> rows =
          (result as Success<List<PendingApproval>>).value;
      expect(rows.map((PendingApproval row) => row.status), <ApprovalStatus>[
        ApprovalStatus.pending,
        ApprovalStatus.approved,
        ApprovalStatus.cancelled,
      ]);
      expect(api.lastListStatus, 'rejected');
      expect(rows.first.isDecidable, isTrue);
    });

    test('fetch without an active organization fails honestly', () async {
      final SupabaseApprovalGateway unbound = SupabaseApprovalGateway(
        api,
        organizationId: () => null,
      );

      final Result<List<PendingApproval>> result = await unbound
          .fetchApprovals();

      final AppError error = (result as Failure<List<PendingApproval>>).error;
      expect(error.code, 'approval_read_no_org');
      expect(api.listCalls, 0);
    });

    test('fetch maps a denial to approval_read_denied', () async {
      api.failure = const SupabaseApprovalException(
        kind: SupabaseApprovalFailureKind.denied,
        message: 'permission denied',
      );

      final Result<List<PendingApproval>> result = await gateway
          .fetchApprovals();

      final AppError error = (result as Failure<List<PendingApproval>>).error;
      expect(error.code, 'approval_read_denied');
      expect(error.kind, AppErrorKind.denied);
    });

    test('fetch maps provider-unavailable to the retryable kind', () async {
      api.failure = const SupabaseApprovalException(
        kind: SupabaseApprovalFailureKind.providerUnavailable,
        message: 'connection refused',
      );

      final Result<List<PendingApproval>> result = await gateway
          .fetchApprovals();

      final AppError error = (result as Failure<List<PendingApproval>>).error;
      expect(error.code, 'approval_read_unavailable');
      expect(error.kind, AppErrorKind.unavailable);
    });

    test(
      'an unknown server status is provider drift, never a wrong row',
      () async {
        api.listRows = <Map<String, dynamic>>[_row(status: 'archived')];

        final Result<List<PendingApproval>> result = await gateway
            .fetchApprovals();

        final AppError error = (result as Failure<List<PendingApproval>>).error;
        expect(error.code, 'approval_read_failed');
      },
    );

    test('create sends the draft fields and returns the new id', () async {
      final Result<String> result = await gateway.create(
        const ApprovalDraft(
          organizationId: 'org-1',
          matterId: 'matter-1',
          title: 'Filing approval',
          kind: ApprovalKind.filing,
          description: 'Needs partner sign-off.',
        ),
      );

      expect((result as Success<String>).value, 'approval-created');
      expect(api.lastCreateOrganizationId, 'org-1');
      expect(api.lastCreateMatterId, 'matter-1');
      expect(api.lastCreateTitle, 'Filing approval');
      expect(api.lastCreateKind, 'filing');
      expect(api.lastCreateDescription, 'Needs partner sign-off.');
    });

    test('create maps validation and denial distinctly', () async {
      api.failure = const SupabaseApprovalException(
        kind: SupabaseApprovalFailureKind.validation,
        message: 'new row violates check constraint',
      );

      Result<String> result = await gateway.create(
        const ApprovalDraft(
          organizationId: 'org-1',
          title: 'A',
          kind: ApprovalKind.other,
        ),
      );
      AppError error = (result as Failure<String>).error;
      expect(error.code, 'approval_create_invalid');

      api.failure = const SupabaseApprovalException(
        kind: SupabaseApprovalFailureKind.denied,
        message: 'permission denied',
      );
      result = await gateway.create(
        const ApprovalDraft(
          organizationId: 'org-1',
          title: 'Valid title',
          kind: ApprovalKind.other,
        ),
      );
      error = (result as Failure<String>).error;
      expect(error.code, 'approval_create_denied');
      expect(error.kind, AppErrorKind.denied);
    });

    test('decide maps approve/reject to the server decision', () async {
      Result<void> result = await gateway.decide(
        'a1',
        approve: true,
        note: 'Looks good.',
      );
      expect(result, isA<Success<void>>());
      expect(api.lastDecideId, 'a1');
      expect(api.lastDecision, 'approved');
      expect(api.lastDecideNote, 'Looks good.');

      result = await gateway.decide(
        'a1',
        approve: false,
        note: 'Out of scope.',
      );
      expect(api.lastDecision, 'rejected');
      expect(api.lastDecideNote, 'Out of scope.');
    });

    test('decide maps the rejection-note validation refusal', () async {
      api.failure = const SupabaseApprovalException(
        kind: SupabaseApprovalFailureKind.validation,
        message: 'a rejection note is required',
      );

      final Result<void> result = await gateway.decide('a1', approve: false);

      final AppError error = (result as Failure<void>).error;
      expect(error.code, 'approval_decide_invalid');
    });

    test('decide maps not-found and denial to their codes', () async {
      api.failure = const SupabaseApprovalException(
        kind: SupabaseApprovalFailureKind.notFound,
        message: 'approval request not found',
      );

      Result<void> result = await gateway.decide('a1', approve: true);
      expect((result as Failure<void>).error.code, 'approval_not_found');

      api.failure = const SupabaseApprovalException(
        kind: SupabaseApprovalFailureKind.denied,
        message: 'permission denied',
      );
      result = await gateway.decide('a1', approve: true);
      final AppError error = (result as Failure<void>).error;
      expect(error.code, 'approval_decide_denied');
      expect(error.kind, AppErrorKind.denied);
    });

    test('cancel calls the RPC and maps a validation refusal', () async {
      final Result<void> result = await gateway.cancel('a1');

      expect(result, isA<Success<void>>());
      expect(api.lastCancelledId, 'a1');

      api.failure = const SupabaseApprovalException(
        kind: SupabaseApprovalFailureKind.validation,
        message: 'approval request is not pending',
      );
      final Result<void> second = await gateway.cancel('a1');
      expect((second as Failure<void>).error.code, 'approval_cancel_invalid');
    });
  });
}

Map<String, dynamic> _row({
  String id = 'a1',
  String status = 'pending',
  String kind = 'conflict',
  String? description,
  String? decidedAt,
  String? decidedBy,
  String? note,
}) {
  return <String, dynamic>{
    'id': id,
    'organization_id': 'org-1',
    'matter_id': null,
    'title': 'Matter waiver',
    'description': description,
    'kind': kind,
    'status': status,
    'requested_by': 'u-requester',
    'decided_by': decidedBy,
    'decided_at': decidedAt,
    'decision_note': note,
    'created_at': '2026-10-01T09:00:00Z',
    'updated_at': '2026-10-01T09:00:00Z',
  };
}

class _StubApprovalApi implements SupabaseApprovalApi {
  List<Map<String, dynamic>> listRows = <Map<String, dynamic>>[];
  SupabaseApprovalException? failure;

  int listCalls = 0;
  String? lastListOrganizationId;
  String? lastListStatus;

  String? lastCreateOrganizationId;
  String? lastCreateMatterId;
  String? lastCreateTitle;
  String? lastCreateKind;
  String? lastCreateDescription;

  String? lastDecideId;
  String? lastDecision;
  String? lastDecideNote;

  String? lastCancelledId;

  @override
  Future<List<Map<String, dynamic>>> listApprovals({
    required String organizationId,
    String? status,
  }) async {
    listCalls += 1;
    lastListOrganizationId = organizationId;
    lastListStatus = status;
    final SupabaseApprovalException? error = failure;
    if (error != null) {
      throw error;
    }
    return listRows;
  }

  @override
  Future<String> createApproval({
    required String organizationId,
    String? matterId,
    required String title,
    required String kind,
    String? description,
  }) async {
    lastCreateOrganizationId = organizationId;
    lastCreateMatterId = matterId;
    lastCreateTitle = title;
    lastCreateKind = kind;
    lastCreateDescription = description;
    final SupabaseApprovalException? error = failure;
    if (error != null) {
      throw error;
    }
    return 'approval-created';
  }

  @override
  Future<void> decideApproval(
    String id, {
    required String decision,
    String? note,
  }) async {
    lastDecideId = id;
    lastDecision = decision;
    lastDecideNote = note;
    final SupabaseApprovalException? error = failure;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> cancelApproval(String id) async {
    lastCancelledId = id;
    final SupabaseApprovalException? error = failure;
    if (error != null) {
      throw error;
    }
  }
}
