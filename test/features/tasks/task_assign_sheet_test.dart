import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_item.dart';
import 'package:legalhub/features/tasks/presentation/task_assign_sheet.dart';
import 'package:legalhub/features/tasks/presentation/task_board_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late _StubTaskGateway taskGateway;
  late _StubOrgGateway orgGateway;
  late TaskBoardCubit cubit;

  setUp(() {
    taskGateway = _StubTaskGateway();
    orgGateway = _StubOrgGateway();
    cubit = TaskBoardCubit(taskGateway, FakeMatterGateway(), orgGateway);
  });

  tearDown(() => cubit.close());

  Future<void> openSheet(WidgetTester tester, {String? assigneeId}) async {
    final TaskItem task = _task(assigneeId: assigneeId);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () =>
                  showTaskAssignSheet(context, cubit: cubit, task: task),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('TaskAssignSheet', () {
    testWidgets('loads the roster and preselects the current assignee', (
      tester,
    ) async {
      await openSheet(tester, assigneeId: 'demo-attorney');

      expect(find.text('Assign task'), findsOneWidget);
      expect(orgGateway.matterCalls, <String>['matter-1']);
      expect(find.text('Demo attorney'), findsOneWidget);
    });

    testWidgets('submits a selected member', (tester) async {
      taskGateway.assignResults.add(
        Result<TaskItem>.success(_task(assigneeId: 'demo-user')),
      );
      await openSheet(tester, assigneeId: 'demo-attorney');

      await tester.tap(find.text('Demo attorney'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo user').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save assignment'));
      await tester.pumpAndSettle();

      expect(taskGateway.assigneeCalls, <String?>['demo-user']);
      expect(find.text('Save assignment'), findsNothing);
    });

    testWidgets('the Unassigned option submits a null assignee', (
      tester,
    ) async {
      taskGateway.assignResults.add(Result<TaskItem>.success(_task()));
      await openSheet(tester, assigneeId: 'demo-attorney');

      await tester.tap(find.text('Demo attorney'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unassigned').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save assignment'));
      await tester.pumpAndSettle();

      expect(taskGateway.assigneeCalls, <String?>[null]);
      expect(find.text('Save assignment'), findsNothing);
    });

    testWidgets('renders a localized inline error on failure', (tester) async {
      taskGateway.assignResults.add(
        Result<TaskItem>.failure(
          const AppError(
            code: 'task_assign_unavailable',
            userMessage: 'provider copy',
            kind: AppErrorKind.unavailable,
          ),
        ),
      );
      await openSheet(tester, assigneeId: 'demo-attorney');

      await tester.tap(find.text('Save assignment'));
      await tester.pumpAndSettle();

      expect(
        find.text('This is temporarily unavailable. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Save assignment'), findsOneWidget);
    });

    testWidgets('names an absent current assignee neutrally', (tester) async {
      await openSheet(tester, assigneeId: 'ghost-user');

      expect(find.text('Current assignee unavailable'), findsOneWidget);
    });

    testWidgets('shows the roster load error with retry', (tester) async {
      orgGateway.result = const OrgOutcome<List<AssignableMember>>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
      await openSheet(tester, assigneeId: 'demo-attorney');

      expect(
        find.text('Unable to load members. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Save assignment'), findsNothing);
    });

    testWidgets(
      'a thrown roster read shows the retry arm, not a stuck spinner (N1)',
      (tester) async {
        orgGateway.throws = true;
        await openSheet(tester, assigneeId: 'demo-attorney');

        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          find.text('Unable to load members. Please try again.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
      },
    );
  });
}

TaskItem _task({String? assigneeId}) {
  return TaskItem(
    id: 'task-1',
    organizationId: 'org-demo',
    matterId: 'matter-1',
    title: 'Demo: draft response checklist',
    matterRef: 'Demo acquisition review',
    status: TaskStatus.todo,
    dueAt: DateTime.utc(2026, 8, 15),
    assigneeId: assigneeId,
  );
}

class _StubOrgGateway extends FakeOrganizationGateway {
  OrgOutcome<List<AssignableMember>>? result;
  bool throws = false;
  final List<String> matterCalls = <String>[];

  @override
  Future<OrgOutcome<List<AssignableMember>>> listAssignableMembers({
    required String matterId,
  }) async {
    matterCalls.add(matterId);
    if (throws) {
      throw StateError('roster gateway blew up');
    }
    final OrgOutcome<List<AssignableMember>>? stub = result;
    if (stub != null) {
      return stub;
    }
    return super.listAssignableMembers(matterId: matterId);
  }
}

class _StubTaskGateway implements TaskBoardGateway {
  final List<Result<TaskItem>> assignResults = <Result<TaskItem>>[];
  final List<String?> assigneeCalls = <String?>[];

  @override
  Future<Result<List<TaskItem>>> fetchTasks() async {
    return Result<List<TaskItem>>.success(const <TaskItem>[]);
  }

  @override
  Future<Result<TaskItem>> createTask({
    required String matterId,
    required String title,
    String? assigneeId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<TaskItem>> advanceTask(String taskId, TaskStatus to) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<TaskItem>> assignTask(String taskId, String? assigneeId) async {
    assigneeCalls.add(assigneeId);
    return assignResults.removeAt(0);
  }

  @override
  Future<Result<TaskItem>> acknowledgeTask(String taskId) async {
    throw UnimplementedError();
  }
}
