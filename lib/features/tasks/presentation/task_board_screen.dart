import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
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
          return switch (state.tasks) {
            ViewLoading() => const Padding(
              padding: EdgeInsetsDirectional.all(LegalHubTheme.spaceXl),
              child: Center(child: CircularProgressIndicator()),
            ),
            ViewEmpty() => ListView(
              padding: const EdgeInsetsDirectional.all(
                LegalHubTheme.marginMobile,
              ),
              children: <Widget>[
                empty,
                const SizedBox(height: LegalHubTheme.spaceLg),
                Text(
                  l10n.tasksLocalOnlyNote,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            ViewError() => ListView(
              padding: const EdgeInsetsDirectional.all(
                LegalHubTheme.marginMobile,
              ),
              children: <Widget>[
                Text(
                  l10n.tasksError,
                  style: text.bodyMedium?.copyWith(color: scheme.error),
                ),
                TextButton(
                  onPressed: () => context.read<TaskBoardCubit>().load(),
                  child: Text(l10n.retry),
                ),
              ],
            ),
            ViewOffline() || ViewUnauthorized() => empty,
            ViewSuccess<List<TaskItem>>(data: final List<TaskItem> tasks) =>
              ListView(
                padding: const EdgeInsetsDirectional.all(
                  LegalHubTheme.marginMobile,
                ),
                children: <Widget>[
                  for (final TaskItem task in tasks) ...<Widget>[
                    _TaskTile(task: task),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                  ],
                  const SizedBox(height: LegalHubTheme.spaceLg),
                  Text(
                    l10n.tasksLocalOnlyNote,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          };
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
    final TextTheme text = Theme.of(context).textTheme;
    final (IconData, String) status = switch (task.status) {
      TaskStatus.todo => (Icons.radio_button_unchecked, l10n.taskStatusTodo),
      TaskStatus.inProgress => (Icons.hourglass_top, l10n.taskStatusInProgress),
      TaskStatus.blocked => (Icons.block, l10n.taskStatusBlocked),
      TaskStatus.done => (Icons.check_circle_outline, l10n.taskStatusDone),
    };
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Row(
          children: <Widget>[
            Icon(status.$1, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: LegalHubTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    task.title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.matterRef} · ${status.$2}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
