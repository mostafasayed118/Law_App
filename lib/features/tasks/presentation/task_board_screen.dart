import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/task_gateway.dart';
import '../domain/task_item.dart';
import 'task_board_cubit.dart';
import 'task_board_state.dart';

/// Collaboration task-board list screen (v1 queue, 2026-08-09; spec §6
/// `collaboration_task_board`, v1). Read-only demo surface: deterministic
/// synthetic rows with the status shown as **text + icon** (never color
/// alone, INSTRUCTIONS §4.5). No create/edit/close affordances.
class TaskBoardScreen extends StatelessWidget {
  const TaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).tasksTitle)),
      body: BlocProvider<TaskBoardCubit>(
        create: (BuildContext context) =>
            TaskBoardCubit(serviceLocator<TaskBoardGateway>()),
        child: const _TaskSurface(),
      ),
    );
  }
}

class _TaskSurface extends StatefulWidget {
  const _TaskSurface();

  @override
  State<_TaskSurface> createState() => _TaskSurfaceState();
}

class _TaskSurfaceState extends State<_TaskSurface> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<TaskBoardCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return SafeArea(
      child: BlocBuilder<TaskBoardCubit, TaskBoardState>(
        builder: (BuildContext context, TaskBoardState state) {
          final Widget empty = Padding(
            padding: const EdgeInsetsDirectional.only(
              top: LegalHubTheme.spaceMd,
            ),
            child: Text(
              l10n.tasksEmpty,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          );
          return ViewStateList<List<TaskItem>>(
            state: state.tasks,
            onRetry: () => context.read<TaskBoardCubit>().load(),
            itemBuilder: (BuildContext context, List<TaskItem> tasks) =>
                <Widget>[
                  for (final TaskItem task in tasks) ...<Widget>[
                    _TaskTile(task: task),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                  ],
                ],
            empty: empty,
            errorCopy: l10n.tasksError,
            localOnlyNote: l10n.tasksLocalOnlyNote,
          );
        },
      ),
    );
  }
}

/// A read-only task row: status text + icon, never color alone; no actions.
class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (IconData, String) status = switch (task.status) {
      TaskStatus.todo => (Icons.radio_button_unchecked, l10n.taskStatusTodo),
      TaskStatus.inProgress => (Icons.hourglass_top, l10n.taskStatusInProgress),
      TaskStatus.blocked => (Icons.block, l10n.taskStatusBlocked),
      TaskStatus.done => (Icons.check_circle_outline, l10n.taskStatusDone),
    };
    return AppTile(
      leading: Icon(status.$1, size: 20, color: scheme.onSurfaceVariant),
      title: task.title,
      subtitles: <String>['${task.matterRef} · ${status.$2}'],
    );
  }
}
