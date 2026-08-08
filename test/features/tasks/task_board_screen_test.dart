import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/tasks/data/fake_task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_item.dart';
import 'package:legalhub/features/tasks/presentation/task_board_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpTasks(WidgetTester tester) async {
    configureDependencies();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TaskBoardScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('task board screen (v1 queue 2026-08-09)', () {
    testWidgets('lists the synthetic tasks from the fake', (tester) async {
      await pumpTasks(tester);

      expect(find.text('Task board'), findsWidgets);
      for (final TaskItem task in FakeTaskGateway.syntheticTasks) {
        expect(find.text(task.title), findsOneWidget);
      }
    });

    testWidgets('renders status labels as text (never color alone)', (
      tester,
    ) async {
      await pumpTasks(tester);

      expect(find.text('Demo acquisition review · To do'), findsOneWidget);
      expect(
        find.text('Commercial lease consultation · In progress'),
        findsNWidgets(2),
      );
      expect(find.text('Family status consultation · Blocked'), findsOneWidget);
      expect(find.text('Startup formation advisory · Done'), findsOneWidget);
    });

    testWidgets('empty state renders the localized copy', (tester) async {
      await _registerStub(<Result<List<TaskItem>>>[
        Result<List<TaskItem>>.success(const <TaskItem>[]),
      ]);
      await pumpTasks(tester);

      expect(find.text('No tasks are available.'), findsOneWidget);
    });

    testWidgets('failure renders error + retry reissues', (tester) async {
      await _registerStub(<Result<List<TaskItem>>>[
        Result<List<TaskItem>>.failure(_loadFailure),
        Result<List<TaskItem>>.success(FakeTaskGateway.syntheticTasks),
      ]);
      await pumpTasks(tester);

      expect(find.text('Unable to load tasks.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load tasks.'), findsNothing);
      expect(
        find.text(FakeTaskGateway.syntheticTasks.first.title),
        findsOneWidget,
      );
    });

    testWidgets('renders the local-only demo note', (tester) async {
      await pumpTasks(tester);

      expect(
        find.text(
          'Demo mode — synthetic tasks only. No real case work is listed.',
        ),
        findsOneWidget,
      );
    });
  });
}

final AppError _loadFailure = AppError(
  code: 'tasks_failed',
  userMessage: 'Could not load tasks',
);

Future<void> _registerStub(List<Result<List<TaskItem>>> results) async {
  await resetServiceLocator();
  serviceLocator.registerLazySingleton<TaskBoardGateway>(
    () => _StubTaskGateway(results),
  );
}

class _StubTaskGateway implements TaskBoardGateway {
  _StubTaskGateway(this.results);

  final List<Result<List<TaskItem>>> results;

  @override
  Future<Result<List<TaskItem>>> fetchTasks() async {
    return results.removeAt(0);
  }
}
