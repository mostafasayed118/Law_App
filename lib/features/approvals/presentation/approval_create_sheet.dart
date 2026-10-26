import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/contracts/server_limits.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/approvals/domain/approvals_gateway.dart';
import 'package:legalhub/features/approvals/domain/pending_approval.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';

import 'approval_error_messages.dart';
import 'approval_labels.dart';
import 'approvals_cubit.dart';

/// Opens the create-request bottom sheet.
///
/// [cubit] is the list's own [ApprovalsCubit] — re-provided around the sheet
/// because a modal's context sits under the Navigator, not under the caller's
/// provider scope. Resolves to `true` when a request was created (the cubit
/// has already re-read the list), otherwise null/false.
Future<bool?> showApprovalCreateSheet(
  BuildContext context, {
  required ApprovalsCubit cubit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => BlocProvider<ApprovalsCubit>.value(
      value: cubit,
      child: const ApprovalCreateSheet(),
    ),
  );
}

/// Create-approval-request sheet: title, kind, optional matter, optional
/// description (design §3 Task 6).
///
/// The matter picker reuses the matter list gateway through
/// [ApprovalsCubit.loadMatters]; a failed matter read is shown inline with a
/// retry and never blocks creation (the matter is optional). The active
/// organization id is a routing hint — the create RPC re-derives membership
/// and the matter gate in-function.
class ApprovalCreateSheet extends StatefulWidget {
  const ApprovalCreateSheet({super.key});

  @override
  State<ApprovalCreateSheet> createState() => _ApprovalCreateSheetState();
}

class _ApprovalCreateSheetState extends State<ApprovalCreateSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();

  ApprovalKind _kind = ApprovalKind.conflict;
  bool _loadingMatters = true;
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
    _description.dispose();
    super.dispose();
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
        .read<ApprovalsCubit>()
        .loadMatters();
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingMatters = false;
      _mattersResult = result;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? organizationId =
        serviceLocator<ActiveOrgStore>().activeOrganizationId;
    if (organizationId == null) {
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final AppError? error = await context.read<ApprovalsCubit>().create(
      ApprovalDraft(
        organizationId: organizationId,
        matterId: _selectedMatterId,
        title: _title.text,
        kind: _kind,
        description: _description.text,
      ),
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
                l10n.approvalCreateTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              if (!hasOrganization) ...<Widget>[
                Text(
                  l10n.approvalCreateNoOrg,
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
          TextFormField(
            controller: _title,
            enabled: !_submitting,
            maxLength: kTitleMaxLength,
            decoration: InputDecoration(
              labelText: l10n.approvalCreateTitleLabel,
              hintText: l10n.approvalCreateTitleHint,
              border: const OutlineInputBorder(),
            ),
            validator: (String? value) => _validateTitle(l10n, value),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          DropdownButtonFormField<ApprovalKind>(
            initialValue: _kind,
            decoration: InputDecoration(
              labelText: l10n.approvalCreateKindLabel,
              border: const OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<ApprovalKind>>[
              for (final ApprovalKind kind in ApprovalKind.values)
                DropdownMenuItem<ApprovalKind>(
                  value: kind,
                  child: Text(approvalKindLabel(l10n, kind)),
                ),
            ],
            onChanged: _submitting
                ? null
                : (ApprovalKind? value) {
                    if (value != null) {
                      setState(() => _kind = value);
                    }
                  },
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          if (_loadingMatters)
            const LinearProgressIndicator()
          else ...<Widget>[
            if (_mattersResult case Failure<List<Matter>>()) ...<Widget>[
              Text(
                l10n.approvalCreateMattersError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
              OutlinedButton(onPressed: _loadMatters, child: Text(l10n.retry)),
              const SizedBox(height: LegalHubTheme.spaceMd),
            ],
            _matterDropdown(l10n, _matters),
            const SizedBox(height: LegalHubTheme.spaceMd),
          ],
          TextFormField(
            controller: _description,
            enabled: !_submitting,
            maxLines: 4,
            maxLength: kDescriptionMaxLength,
            decoration: InputDecoration(
              labelText: l10n.approvalCreateDescriptionLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (String? value) {
              if ((value ?? '').length > kDescriptionMaxLength) {
                return l10n.approvalCreateDescriptionTooLong;
              }
              return null;
            },
          ),
          if (_submitError != null) ...<Widget>[
            Text(
              approvalErrorMessage(l10n, _submitError!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
          ],
          FilledButton(
            onPressed: _submitting || !enabled ? null : _submit,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.approvalCreateSubmit),
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
    final DemoLabels labels = DemoLabels(l10n, localOnly: backendIsLocalOnly);
    return DropdownButtonFormField<String?>(
      initialValue: _selectedMatterId,
      decoration: InputDecoration(
        labelText: l10n.approvalCreateMatterLabel,
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<String?>>[
        DropdownMenuItem<String?>(child: Text(l10n.approvalCreateMatterNone)),
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

  String? _validateTitle(AppLocalizations l10n, String? value) {
    final String text = (value ?? '').trim();
    if (text.length < 2) {
      return l10n.approvalCreateTitleTooShort;
    }
    if (text.length > kTitleMaxLength) {
      return l10n.approvalCreateTitleTooLong;
    }
    return null;
  }
}
