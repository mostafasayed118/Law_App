import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/approvals/domain/approvals_gateway.dart';
import 'package:legalhub/features/approvals/domain/pending_approval.dart';
import 'package:legalhub/features/approvals/presentation/approvals_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  group('approvals screen (design §3)', () {
    testWidgets('lists the organization requests with kind + status', (
      tester,
    ) async {
      await pumpApprovals(
        tester,
        gateway: _StubApprovalsGateway(
          rows: <PendingApproval>[
            _row(id: 'a1', title: 'New matter waiver'),
            _row(
              id: 'a2',
              title: 'Court filing',
              kind: ApprovalKind.filing,
              status: ApprovalStatus.approved,
            ),
          ],
        ),
      );

      expect(find.text('Approvals'), findsOneWidget);
      expect(find.text('New matter waiver'), findsOneWidget);
      expect(find.text('Waiver · Pending'), findsOneWidget);
      expect(find.text('Court filing'), findsOneWidget);
      expect(find.text('Filing · Approved'), findsOneWidget);
    });

    testWidgets('filter chips re-read with the selected status', (
      tester,
    ) async {
      final _StubApprovalsGateway gateway = _StubApprovalsGateway(
        rows: <PendingApproval>[
          _row(id: 'a1', title: 'Pending request'),
          _row(
            id: 'a2',
            title: 'Approved request',
            status: ApprovalStatus.approved,
          ),
        ],
      );
      await pumpApprovals(tester, gateway: gateway);

      await tester.tap(find.widgetWithText(FilterChip, 'Approved'));
      await tester.pumpAndSettle();

      expect(gateway.requestedStatuses.last, ApprovalStatus.approved);
      expect(find.text('Approved request'), findsOneWidget);
      expect(find.text('Pending request'), findsNothing);
    });

    testWidgets('empty state renders the filtered copy', (tester) async {
      await pumpApprovals(
        tester,
        gateway: _StubApprovalsGateway(rows: <PendingApproval>[]),
      );

      expect(find.text('No approvals match this filter.'), findsOneWidget);
    });

    testWidgets('failure renders error + retry reissues', (tester) async {
      final _StubApprovalsGateway gateway = _StubApprovalsGateway(
        rows: <PendingApproval>[_row(id: 'a1', title: 'Recovered request')],
        fetchQueue: <Result<List<PendingApproval>>>[
          Result<List<PendingApproval>>.failure(_loadFailure),
        ],
      );
      await pumpApprovals(tester, gateway: gateway);

      expect(find.text('Unable to load approvals.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load approvals.'), findsNothing);
      expect(find.text('Recovered request'), findsOneWidget);
    });

    testWidgets('create validates the title and submits the draft', (
      tester,
    ) async {
      final _StubApprovalsGateway gateway = _StubApprovalsGateway(
        rows: <PendingApproval>[],
      );
      await pumpApprovals(tester, gateway: gateway);

      await tester.tap(find.text('New request'));
      await tester.pumpAndSettle();

      expect(find.text('New approval request'), findsOneWidget);

      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();
      expect(find.text('Title must be at least 2 characters.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'A');
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();
      expect(find.text('Title must be at least 2 characters.'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).first,
        'New matter waiver',
      );
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();

      expect(gateway.createdDrafts, hasLength(1));
      expect(gateway.createdDrafts.single.title, 'New matter waiver');
      expect(gateway.createdDrafts.single.organizationId, 'org-1');
      expect(gateway.createdDrafts.single.matterId, isNull);
      expect(find.text('Request submitted.'), findsOneWidget);
      expect(find.text('New matter waiver'), findsOneWidget);
    });

    testWidgets(
      'create submits the selected kind with the optional matter picker',
      (tester) async {
        final _StubApprovalsGateway gateway = _StubApprovalsGateway(
          rows: <PendingApproval>[],
        );
        await pumpApprovals(tester, gateway: gateway);

        await tester.tap(find.text('New request'));
        await tester.pumpAndSettle();

        expect(find.text('No matter'), findsOneWidget);

        await tester.enterText(
          find.byType(TextFormField).first,
          'Expense approval',
        );
        await tester.tap(find.byType(DropdownButtonFormField<ApprovalKind>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Expense').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Submit request'));
        await tester.pumpAndSettle();

        expect(gateway.createdDrafts, hasLength(1));
        expect(gateway.createdDrafts.single.kind, ApprovalKind.expense);
        expect(gateway.createdDrafts.single.matterId, isNull);
      },
    );

    testWidgets('partner approves a pending request', (tester) async {
      final _StubApprovalsGateway gateway = _StubApprovalsGateway(
        rows: <PendingApproval>[
          _row(id: 'a1', title: 'New matter waiver', requestedBy: 'u-client'),
        ],
      );
      await pumpApprovals(
        tester,
        gateway: gateway,
        canDecide: true,
        currentUserId: 'u-partner',
      );

      await tester.tap(find.text('New matter waiver'));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(gateway.decideCalls, 1);
      expect(gateway.lastApprove, isTrue);
      expect(find.text('Request approved.'), findsOneWidget);
      expect(find.text('Waiver · Approved'), findsOneWidget);
    });

    testWidgets('a denied decision renders the typed denial, no success', (
      tester,
    ) async {
      final _StubApprovalsGateway gateway = _StubApprovalsGateway(
        rows: <PendingApproval>[
          _row(id: 'a1', title: 'New matter waiver', requestedBy: 'u-client'),
        ],
        decideError: const AppError(
          code: 'approval_decide_denied',
          userMessage: 'Only a partner can decide this request.',
          kind: AppErrorKind.denied,
        ),
      );
      await pumpApprovals(
        tester,
        gateway: gateway,
        canDecide: true,
        currentUserId: 'u-partner',
      );

      await tester.tap(find.text('New matter waiver'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(
        find.text('You do not have permission to do that.'),
        findsOneWidget,
      );
      expect(find.text('Request approved.'), findsNothing);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Waiver · Pending'), findsOneWidget);
    });

    testWidgets('rejecting without a note is blocked before the gateway', (
      tester,
    ) async {
      final _StubApprovalsGateway gateway = _StubApprovalsGateway(
        rows: <PendingApproval>[
          _row(id: 'a1', title: 'New matter waiver', requestedBy: 'u-client'),
        ],
      );
      await pumpApprovals(
        tester,
        gateway: gateway,
        canDecide: true,
        currentUserId: 'u-partner',
      );

      await tester.tap(find.text('New matter waiver'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(
        find.text('Add a note of at least 2 characters to reject.'),
        findsOneWidget,
      );
      expect(gateway.decideCalls, 0);

      await tester.enterText(find.byType(TextField), 'Not approved');
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(gateway.decideCalls, 1);
      expect(gateway.lastApprove, isFalse);
      expect(gateway.lastNote, 'Not approved');
      expect(find.text('Request rejected.'), findsOneWidget);
    });

    testWidgets('the requester can cancel but cannot decide', (tester) async {
      final _StubApprovalsGateway gateway = _StubApprovalsGateway(
        rows: <PendingApproval>[
          _row(id: 'a1', title: 'New matter waiver', requestedBy: 'u-me'),
        ],
      );
      await pumpApprovals(tester, gateway: gateway, currentUserId: 'u-me');

      await tester.tap(find.text('New matter waiver'));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Cancel request'), findsOneWidget);

      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this request?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Cancel request'));
      await tester.pumpAndSettle();

      expect(gateway.cancelledId, 'a1');
      expect(find.text('Request cancelled.'), findsOneWidget);
      expect(find.text('Waiver · Cancelled'), findsOneWidget);
    });

    testWidgets('a non-partner non-requester sees a read-only detail sheet', (
      tester,
    ) async {
      await pumpApprovals(
        tester,
        gateway: _StubApprovalsGateway(
          rows: <PendingApproval>[
            _row(id: 'a1', title: 'New matter waiver', requestedBy: 'u-client'),
          ],
        ),
        currentUserId: 'u-other',
      );

      await tester.tap(find.text('New matter waiver'));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Cancel request'), findsNothing);
    });

    testWidgets('a decided request shows the decision note and time', (
      tester,
    ) async {
      await pumpApprovals(
        tester,
        gateway: _StubApprovalsGateway(
          rows: <PendingApproval>[
            _row(
              id: 'a1',
              title: 'New matter waiver',
              status: ApprovalStatus.denied,
              decidedAt: DateTime.utc(2026, 10, 2, 14, 30),
              decisionNote: 'Outside the engagement scope.',
            ),
          ],
        ),
        canDecide: true,
        currentUserId: 'u-partner',
      );

      await tester.tap(find.text('New matter waiver'));
      await tester.pumpAndSettle();

      expect(find.text('Decision note'), findsOneWidget);
      expect(find.text('Outside the engagement scope.'), findsOneWidget);
      expect(find.textContaining('Decided:'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
    });
  });
}

final AppError _loadFailure = AppError(
  code: 'approvals_failed',
  userMessage: 'Could not load approvals',
);

PendingApproval _row({
  required String id,
  required String title,
  ApprovalKind kind = ApprovalKind.waiver,
  ApprovalStatus status = ApprovalStatus.pending,
  String? requestedBy = 'u-client',
  DateTime? decidedAt,
  String? decisionNote,
}) {
  return PendingApproval(
    id: id,
    organizationId: 'org-1',
    title: title,
    kind: kind,
    status: status,
    requestedBy: requestedBy,
    decidedAt: decidedAt,
    decisionNote: decisionNote,
    createdAt: DateTime.utc(2026, 10, 1),
  );
}

Future<void> pumpApprovals(
  WidgetTester tester, {
  required ApprovalsGateway gateway,
  bool canDecide = false,
  String? currentUserId,
}) async {
  serviceLocator.registerLazySingleton<ApprovalsGateway>(() => gateway);
  configureDependencies();
  serviceLocator<ActiveOrgStore>().select('org-1');
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ApprovalsScreen(canDecide: canDecide, currentUserId: currentUserId),
    ),
  );
  await tester.pumpAndSettle();
}

class _StubApprovalsGateway implements ApprovalsGateway {
  _StubApprovalsGateway({
    required this.rows,
    this.fetchQueue = const <Result<List<PendingApproval>>>[],
    this.decideError,
  });

  final List<PendingApproval> rows;
  final List<Result<List<PendingApproval>>> fetchQueue;
  final AppError? decideError;

  final List<ApprovalStatus?> requestedStatuses = <ApprovalStatus?>[];
  final List<ApprovalDraft> createdDrafts = <ApprovalDraft>[];

  int decideCalls = 0;
  bool? lastApprove;
  String? lastNote;
  String? cancelledId;

  @override
  Future<Result<List<PendingApproval>>> fetchApprovals({
    ApprovalStatus? status,
  }) async {
    requestedStatuses.add(status);
    if (fetchQueue.isNotEmpty) {
      return fetchQueue.removeAt(0);
    }
    return Result<List<PendingApproval>>.success(
      status == null
          ? List<PendingApproval>.of(rows)
          : rows.where((PendingApproval row) => row.status == status).toList(),
    );
  }

  @override
  Future<Result<String>> create(ApprovalDraft draft) async {
    createdDrafts.add(draft);
    rows.insert(
      0,
      PendingApproval(
        id: 'created-${createdDrafts.length}',
        organizationId: draft.organizationId,
        matterId: draft.matterId,
        title: draft.title,
        description: draft.description,
        kind: draft.kind,
        status: ApprovalStatus.pending,
        requestedBy: 'u-client',
        createdAt: DateTime.utc(2026, 10, 3),
      ),
    );
    return Result<String>.success('created-${createdDrafts.length}');
  }

  @override
  Future<Result<void>> decide(
    String id, {
    required bool approve,
    String? note,
  }) async {
    decideCalls += 1;
    lastApprove = approve;
    lastNote = note;
    final AppError? error = decideError;
    if (error != null) {
      return Result<void>.failure(error);
    }
    final int index = rows.indexWhere((PendingApproval row) => row.id == id);
    rows[index] = PendingApproval(
      id: rows[index].id,
      organizationId: rows[index].organizationId,
      title: rows[index].title,
      kind: rows[index].kind,
      status: approve ? ApprovalStatus.approved : ApprovalStatus.denied,
      requestedBy: rows[index].requestedBy,
      decidedAt: DateTime.utc(2026, 10, 4),
      decisionNote: note,
      createdAt: rows[index].createdAt,
    );
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> cancel(String id) async {
    cancelledId = id;
    final int index = rows.indexWhere((PendingApproval row) => row.id == id);
    rows[index] = PendingApproval(
      id: rows[index].id,
      organizationId: rows[index].organizationId,
      title: rows[index].title,
      kind: rows[index].kind,
      status: ApprovalStatus.cancelled,
      requestedBy: rows[index].requestedBy,
      createdAt: rows[index].createdAt,
    );
    return const Result<void>.success(null);
  }
}
