import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:legalhub/shared/widgets/form_sheet_scaffold.dart';

import 'video_cubit.dart';
import 'video_error_messages.dart';

/// Opens the schedule-session bottom sheet.
///
/// [cubit] is the list's own [VideoCubit] — re-provided around the sheet
/// because a modal's context sits under the Navigator, not under the caller's
/// provider scope. Resolves to `true` when a session was created (the cubit
/// has already re-read the list), otherwise null/false.
Future<bool?> showVideoCreateSheet(
  BuildContext context, {
  required VideoCubit cubit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => BlocProvider<VideoCubit>.value(
      value: cubit,
      child: const VideoCreateSheet(),
    ),
  );
}

/// Schedule a consultation: optional matter, required date and time.
///
/// The matter picker reuses the matter list gateway through
/// [VideoCubit.loadMatters]; a failed matter read is shown inline with a
/// retry and never blocks creation (the matter is optional). The active
/// organization id is a routing hint — the create RPC re-derives membership
/// and the matter gate in-function.
class VideoCreateSheet extends StatefulWidget {
  const VideoCreateSheet({super.key});

  @override
  State<VideoCreateSheet> createState() => _VideoCreateSheetState();
}

class _VideoCreateSheetState extends State<VideoCreateSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _loadingMatters = true;
  Result<List<Matter>>? _mattersResult;
  String? _selectedMatterId;
  DateTime? _scheduledAt;
  bool _dateMissing = false;
  bool _dateInPast = false;
  bool _submitting = false;
  AppError? _submitError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMatters());
  }

  Future<void> _loadMatters() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingMatters = true;
      _mattersResult = null;
    });
    Result<List<Matter>>? result;
    try {
      result = await context.read<VideoCubit>().loadMatters();
    } catch (_) {
      // A thrown picker read lands on the existing failure + retry arm
      // instead of leaving the sheet on its spinner forever.
      result = const Result<List<Matter>>.failure(
        AppError(
          code: 'matters_failed',
          userMessage: 'Unable to load matters.',
        ),
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingMatters = false;
      _mattersResult = result;
    });
  }

  Future<void> _pickSchedule() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _scheduledAt ?? now.add(const Duration(days: 1));
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _dateMissing = false;
      _dateInPast = false;
    });
  }

  Future<void> _submit() async {
    final bool hasOrganization =
        serviceLocator<ActiveOrgStore>().activeOrganizationId != null;
    if (!hasOrganization) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_scheduledAt == null) {
      setState(() => _dateMissing = true);
      return;
    }
    if (_scheduledAt!.isBefore(DateTime.now())) {
      setState(() => _dateInPast = true);
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final AppError? error = await context.read<VideoCubit>().create(
        matterId: _selectedMatterId,
        scheduledAt: _scheduledAt,
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
          code: 'video_create_failed',
          userMessage: 'Unable to schedule the session. Please try again.',
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
    final bool hasOrganization =
        serviceLocator<ActiveOrgStore>().activeOrganizationId != null;
    return FormSheetScaffold(
      title: l10n.videoCreateTitle,
      body: <Widget>[
        if (!hasOrganization) ...<Widget>[
          Text(
            l10n.videoCreateNoOrg,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
        ],
        _buildForm(l10n),
      ],
      actions: <Widget>[
        FilledButton(
          onPressed: _submitting || !hasOrganization ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.videoCreateSubmit),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_loadingMatters)
            const LinearProgressIndicator()
          else ...<Widget>[
            if (_mattersResult case Failure<List<Matter>>()) ...<Widget>[
              Text(
                l10n.videoCreateMattersError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
              OutlinedButton(onPressed: _loadMatters, child: Text(l10n.retry)),
              const SizedBox(height: LegalHubTheme.spaceMd),
            ],
            _matterDropdown(l10n, _matters),
            const SizedBox(height: LegalHubTheme.spaceMd),
          ],
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickSchedule,
            icon: const Icon(Icons.event),
            label: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _scheduledAt == null
                    ? l10n.videoCreateDateLabel
                    : formatMediumDateTime(l10n, _scheduledAt!),
              ),
            ),
          ),
          if (_dateMissing || _dateInPast) ...<Widget>[
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              _dateInPast
                  ? l10n.videoCreateDateFuture
                  : l10n.videoCreateDateRequired,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          if (_submitError != null) ...<Widget>[
            const SizedBox(height: LegalHubTheme.spaceMd),
            Text(
              videoErrorMessage(l10n, _submitError!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: LegalHubTheme.spaceMd),
        ],
      ),
    );
  }

  List<Matter> get _matters => switch (_mattersResult) {
    Success<List<Matter>>(value: final List<Matter> matters) => matters,
    _ => const <Matter>[],
  };

  Widget _matterDropdown(AppLocalizations l10n, List<Matter> matters) {
    final DemoLabels labels = DemoLabels(l10n, localOnly: backendIsLocalOnly);
    return DropdownButtonFormField<String?>(
      initialValue: _selectedMatterId,
      decoration: InputDecoration(
        labelText: l10n.videoCreateMatterLabel,
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<String?>>[
        DropdownMenuItem<String?>(child: Text(l10n.videoCreateMatterNone)),
        for (final Matter matter in matters)
          DropdownMenuItem<String?>(
            value: matter.id,
            child: Text(labels.matterTitle(matter.title)),
          ),
      ],
      onChanged: _submitting
          ? null
          : (String? value) => setState(() => _selectedMatterId = value),
    );
  }
}
