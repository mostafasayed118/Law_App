import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/demo_labels.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/task_gateway.dart';
import '../domain/task_item.dart';
import 'task_board_cubit.dart';
import 'task_board_state.dart';

part 'task_tile.dart';

/// Collaboration task-board list screen (v1 queue, 2026-08-09; spec §6
/// `collaboration_task_board`, v1). Deterministic synthetic rows with the
/// status shown as **text + icon** (never color alone, INSTRUCTIONS §4.5).
///
/// The task-writes slice (Gate 3 spec 2026-09-27) adds the row-level
/// affordances (advance one legal step, acknowledge) plus an inline
/// action-error banner (the sendError precedent) that clears on the next
/// write attempt. No create/assign affordances yet — those gateway methods
/// are implemented and unit-tested, the pickers arrive in a follow-up.
class TaskBoardScreen extends StatelessWidget {
  const TaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tasksTitle)),
      // The shared cubit-scoped list shell (audit 2026-09-21, M-10).
      body: CubitListSurface<TaskBoardCubit, TaskBoardState, TaskItem>(
        createCubit: () => TaskBoardCubit(serviceLocator<TaskBoardGateway>()),
        project: (TaskBoardState state) => state.tasks,
        load: (TaskBoardCubit cubit) => cubit.load(),
        header: <Widget>[
          BlocBuilder<TaskBoardCubit, TaskBoardState>(
            buildWhen: (TaskBoardState previous, TaskBoardState current) =>
                previous.actionError != current.actionError,
            builder: (BuildContext context, TaskBoardState state) {
              if (state.actionError == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: LegalHubTheme.spaceSm,
                ),
                child: Text(
                  state.actionError!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            },
          ),
        ],
        tileBuilder: (BuildContext context, TaskItem task) =>
            _TaskTile(task: task),
        empty: (BuildContext context, TaskBoardState state) => Padding(
          padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
          child: Text(
            l10n.tasksEmpty,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        errorCopy: l10n.tasksError,
        localOnlyNote: l10n.tasksLocalOnlyNote,
      ),
    );
  }
}
