import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/features/orgs/domain/organization_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_item.dart';
import 'package:legalhub/l10n/app_localizations.dart';

import 'task_board_cubit.dart';
import 'task_error_messages.dart';

/// Opens the assign/unassign bottom sheet for [task].
///
/// [cubit] is the board's own [TaskBoardCubit], re-provided around the modal
/// the same way the invite sheet re-provides its roster cubit. Resolves to
/// `true` when the assignment changed (the cubit patched the row), otherwise
/// null/false.
Future<bool?> showTaskAssignSheet(
  BuildContext context, {
  required TaskBoardCubit cubit,
  required TaskItem task,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => BlocProvider<TaskBoardCubit>.value(
      value: cubit,
      child: TaskAssignSheet(task: task),
    ),
  );
}

/// Assign/unassign sheet.
///
/// Loads the matter-scoped assignable roster through
/// [TaskBoardCubit.loadAssignableMembers] (active members of the matter's org,
/// platform owner excluded). The "Unassigned" option sends a null assignee.
/// When the row's current assignee is no longer in the active roster, a
/// neutral disabled row names that state instead of silently dropping the
/// selection.
class TaskAssignSheet extends StatefulWidget {
  const TaskAssignSheet({required this.task, super.key});

  final TaskItem task;

  @override
  State<TaskAssignSheet> createState() => _TaskAssignSheetState();
}

class _TaskAssignSheetState extends State<TaskAssignSheet> {
  bool _loading = true;
  OrgOutcome<List<AssignableMember>>? _membersOutcome;
  String? _selectedId;
  bool _submitting = false;
  AppError? _submitError;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.task.assigneeId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  Future<void> _loadMembers() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _membersOutcome = null;
      _submitError = null;
    });
    OrgOutcome<List<AssignableMember>>? outcome;
    try {
      outcome = await context.read<TaskBoardCubit>().loadAssignableMembers(
        widget.task.matterId,
      );
    } catch (_) {
      // A thrown roster read lands on the existing failure + retry arm
      // instead of leaving the sheet on its spinner forever.
      outcome = const OrgOutcome<List<AssignableMember>>.failure(
        OrgFailure(kind: OrgFailureKind.unknown),
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _membersOutcome = outcome;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final AppError? error = await context.read<TaskBoardCubit>().assignTask(
        widget.task.id,
        _selectedId,
      );
      if (!mounted) {
        return;
      }
      if (error == null) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _submitError = error);
    } catch (_) {
      // A thrown write must re-enable the button, not leave it spinning.
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError = const AppError(
          code: 'task_assign_failed',
          userMessage: 'Unable to save the assignment. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.taskAssignTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              ..._buildBody(context, l10n),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return const <Widget>[LinearProgressIndicator()];
    }
    final OrgOutcome<List<AssignableMember>>? outcome = _membersOutcome;
    if (outcome is! OrgSuccess<List<AssignableMember>>) {
      return <Widget>[
        Text(
          l10n.taskAssignMembersError,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        OutlinedButton(onPressed: _loadMembers, child: Text(l10n.retry)),
      ];
    }
    final List<AssignableMember> members = outcome.value;
    final String? currentId = widget.task.assigneeId;
    final bool currentUnavailable =
        currentId != null &&
        !members.any((AssignableMember member) => member.userId == currentId);
    return <Widget>[
      DropdownButtonFormField<String?>(
        initialValue: _selectedId,
        decoration: InputDecoration(
          labelText: l10n.taskAssignMemberLabel,
          border: const OutlineInputBorder(),
        ),
        items: <DropdownMenuItem<String?>>[
          DropdownMenuItem<String?>(
            value: null,
            child: Text(l10n.taskAssignUnassigned),
          ),
          if (currentUnavailable)
            DropdownMenuItem<String?>(
              value: currentId,
              enabled: false,
              child: Text(l10n.taskAssigneeUnavailable),
            ),
          for (final AssignableMember member in members)
            DropdownMenuItem<String?>(
              value: member.userId,
              child: Text(member.displayName),
            ),
        ],
        onChanged: (String? value) {
          setState(() => _selectedId = value);
        },
      ),
      const SizedBox(height: LegalHubTheme.spaceMd),
      if (_submitError != null) ...<Widget>[
        Text(
          taskErrorMessage(l10n, _submitError!),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
      ],
      FilledButton.icon(
        onPressed: _submitting ? null : _submit,
        icon: _submitting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add, size: 18),
        label: Text(l10n.taskAssignSubmit),
      ),
    ];
  }
}
