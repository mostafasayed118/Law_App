import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/orgs/data/fake_organization_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_item.dart';
import 'package:legalhub/features/tasks/presentation/task_board_cubit.dart';
import 'package:legalhub/features/tasks/presentation/task_create_sheet.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late _StubTaskGateway taskGateway;
  late _StubMatterGateway matterGateway;
  late TaskBoardCubit cubit;

  setUp(() {
    taskGateway = _StubTaskGateway();
    matterGateway = _StubMatterGateway();
    cubit = TaskBoardCubit(
      taskGateway,
      matterGateway,
      FakeOrganizationGateway(),
    );
  });

  tearDown(() => cubit.close());

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showTaskCreateSheet(context, cubit: cubit),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('TaskCreateSheet', () {
    testWidgets('validates the title before calling the gateway', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsOneWidget);
      expect(taskGateway.createCalls, isEmpty);
    });

    testWidgets('loads the matters and preselects the first one', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.text('Task title'), findsOneWidget);
      expect(find.text('Matter'), findsOneWidget);
      expect(find.text('Demo acquisition review'), findsOneWidget);
    });

    testWidgets('creates the task and pops on success', (tester) async {
      taskGateway.createResults.add(
        Result<TaskItem>.success(_task(id: 'task-9')),
      );
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField), '  Draft checklist ');
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();

      expect(taskGateway.createCalls, hasLength(1));
      expect(taskGateway.createCalls.single.matterId, 'matter-1');
      expect(taskGateway.createCalls.single.title, 'Draft checklist');
      expect(find.text('Create task'), findsNothing);
    });

    testWidgets('renders a localized inline error on failure', (tester) async {
      taskGateway.createResults.add(
        Result<TaskItem>.failure(
          const AppError(
            code: 'task_create_denied',
            userMessage: 'provider copy',
            kind: AppErrorKind.denied,
          ),
        ),
      );
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField), 'Draft checklist');
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();

      expect(
        find.text('You do not have permission to do that.'),
        findsOneWidget,
      );
      expect(find.text('Create task'), findsOneWidget);
    });

    testWidgets('shows the honest empty state when no matters exist', (
      tester,
    ) async {
      matterGateway.result = const Result<List<Matter>>.success(<Matter>[]);
      await openSheet(tester);

      expect(
        find.text('No matters are available to create a task on.'),
        findsOneWidget,
      );
      expect(find.text('Create task'), findsNothing);
    });

    testWidgets('shows the matter load error with retry', (tester) async {
      matterGateway.result = const Result<List<Matter>>.failure(
        AppError(code: 'matters_failed', userMessage: 'offline'),
      );
      await openSheet(tester);

      expect(
        find.text('Unable to load matters. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Create task'), findsNothing);
    });

    testWidgets(
      'a thrown matter read shows the retry arm, not a stuck spinner (N1)',
      (tester) async {
        matterGateway.throws = true;
        await openSheet(tester);

        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          find.text('Unable to load matters. Please try again.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
      },
    );
  });
}

TaskItem _task({required String id}) {
  return TaskItem(
    id: id,
    organizationId: 'org-demo',
    matterId: 'matter-1',
    title: 'Draft checklist',
    matterRef: 'Demo acquisition review',
    status: TaskStatus.todo,
    dueAt: DateTime.utc(2026, 9, 30),
  );
}

class _StubMatterGateway extends FakeMatterGateway {
  Result<List<Matter>>? result;
  bool throws = false;

  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    if (throws) {
      throw StateError('matters gateway blew up');
    }
    final Result<List<Matter>>? stub = result;
    if (stub != null) {
      return stub;
    }
    return super.fetchMatters();
  }
}

class _StubTaskGateway implements TaskBoardGateway {
  final List<Result<TaskItem>> createResults = <Result<TaskItem>>[];
  final List<_CreateCall> createCalls = <_CreateCall>[];

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
    createCalls.add(_CreateCall(matterId: matterId, title: title));
    return createResults.removeAt(0);
  }

  @override
  Future<Result<TaskItem>> advanceTask(String taskId, TaskStatus to) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<TaskItem>> assignTask(String taskId, String? assigneeId) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<TaskItem>> acknowledgeTask(String taskId) async {
    throw UnimplementedError();
  }
}

class _CreateCall {
  const _CreateCall({required this.matterId, required this.title});

  final String matterId;
  final String title;
}
