import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/active_org_store.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/demo_labels.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../matters/domain/matter.dart';
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
    final Result<List<Matter>> result = await context
        .read<VideoCubit>()
        .loadMatters();
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
    setState(() {
      _submitting = true;
      _submitError = null;
    });
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
    setState(() {
      _submitting = false;
      _submitError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool hasOrganization =
        serviceLocator<ActiveOrgStore>().activeOrganizationId != null;
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
                l10n.videoCreateTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              if (!hasOrganization) ...<Widget>[
                Text(
                  l10n.videoCreateNoOrg,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: LegalHubTheme.spaceMd),
              ],
              _buildForm(l10n, enabled: hasOrganization),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n, {required bool enabled}) {
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
          if (_dateMissing) ...<Widget>[
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              l10n.videoCreateDateRequired,
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
          FilledButton(
            onPressed: _submitting || !enabled ? null : _submit,
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
      ),
    );
  }

  List<Matter> get _matters => switch (_mattersResult) {
    Success<List<Matter>>(value: final List<Matter> matters) => matters,
    _ => const <Matter>[],
  };

  Widget _matterDropdown(AppLocalizations l10n, List<Matter> matters) {
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
            child: Text(demoMatterTitle(l10n, matter.title)),
          ),
      ],
      onChanged: _submitting
          ? null
          : (String? value) => setState(() => _selectedMatterId = value),
    );
  }
}
