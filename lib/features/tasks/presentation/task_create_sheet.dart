import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/demo_labels.dart';
import '../../../shared/forms/validators.dart';
import '../../../shared/widgets/widgets.dart';
import '../../matters/domain/matter.dart';
import 'task_board_cubit.dart';
import 'task_error_messages.dart';

/// Opens the create-task bottom sheet.
///
/// [cubit] is the board's own [TaskBoardCubit] — re-provided around the sheet
/// because a modal's context sits under the Navigator, not under the caller's
/// provider scope. Resolves to `true` when a task was created (the cubit has
/// already patched the board), otherwise null/false.
Future<bool?> showTaskCreateSheet(
  BuildContext context, {
  required TaskBoardCubit cubit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => BlocProvider<TaskBoardCubit>.value(
      value: cubit,
      child: const TaskCreateSheet(),
    ),
  );
}

/// Create-task sheet (title + matter only).
///
/// No assignee or due-date field at creation: the server's create RPC accepts
/// an optional assignee, but the task-writes slice keeps creation minimal and
/// assignment is its own row action. The matter list loads through
/// [TaskBoardCubit.loadMatters]; loading, empty, and failure states are
/// honest (never a fabricated matter). Submit is disabled while loading or
/// in flight, and a failure renders localized inline copy.
class TaskCreateSheet extends StatefulWidget {
  const TaskCreateSheet({super.key});

  @override
  State<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends State<TaskCreateSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();

  bool _loading = true;
  Result<List<Matter>>? _mattersResult;
  String? _selectedMatterId;
  bool _submitting = false;
  AppError? _submitError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMatters());
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadMatters() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _mattersResult = null;
      _submitError = null;
      _selectedMatterId = null;
    });
    final Result<List<Matter>> result = await context
        .read<TaskBoardCubit>()
        .loadMatters();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _mattersResult = result;
      if (result case Success<List<Matter>>(
        value: final List<Matter> matters,
      ) when matters.isNotEmpty) {
        _selectedMatterId = matters.first.id;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? matterId = _selectedMatterId;
    if (matterId == null) {
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final AppError? error = await context.read<TaskBoardCubit>().createTask(
      matterId: matterId,
      title: _title.text,
    );
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _submitError = error;
    });
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
                l10n.taskCreateTitle,
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
    final Result<List<Matter>>? result = _mattersResult;
    if (result is Failure<List<Matter>>) {
      return <Widget>[
        Text(
          l10n.taskCreateMattersError,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        OutlinedButton(onPressed: _loadMatters, child: Text(l10n.retry)),
      ];
    }
    final List<Matter> matters = result is Success<List<Matter>>
        ? result.value
        : const <Matter>[];
    if (matters.isEmpty) {
      return <Widget>[
        Text(
          l10n.taskCreateNoMatters,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ];
    }
    return <Widget>[
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LegalHubTextField(
              controller: _title,
              label: l10n.taskCreateTitleLabel,
              hint: l10n.taskCreateTitleHint,
              validator: (String? value) =>
                  LegalHubValidators.required(l10n, value),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            DropdownButtonFormField<String>(
              initialValue: _selectedMatterId,
              decoration: InputDecoration(
                labelText: l10n.taskCreateMatterLabel,
                hintText: l10n.taskCreateMatterHint,
                border: const OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<String>>[
                for (final Matter matter in matters)
                  DropdownMenuItem<String>(
                    value: matter.id,
                    child: Text(demoMatterTitle(l10n, matter.title)),
                  ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _selectedMatterId = value);
                }
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
                  : const Icon(Icons.add, size: 18),
              label: Text(l10n.taskCreateSubmit),
            ),
          ],
        ),
      ),
    ];
  }
}
