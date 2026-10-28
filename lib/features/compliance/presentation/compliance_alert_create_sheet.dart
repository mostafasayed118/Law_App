import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/form_sheet_scaffold.dart';

import 'compliance_alert_error_messages.dart';
import 'compliance_alert_labels.dart';
import 'compliance_alerts_cubit.dart';

/// Opens the create-alert bottom sheet.
///
/// [cubit] is the list's own [ComplianceAlertsCubit] — re-provided around the
/// sheet because a modal's context sits under the Navigator, not under the
/// caller's provider scope. Resolves to `true` when an alert was created (the
/// cubit has already re-read the list), otherwise null/false.
Future<bool?> showComplianceAlertCreateSheet(
  BuildContext context, {
  required ComplianceAlertsCubit cubit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) =>
        BlocProvider<ComplianceAlertsCubit>.value(
          value: cubit,
          child: const ComplianceAlertCreateSheet(),
        ),
  );
}

/// Create-compliance-alert sheet: title, kind, severity, optional description
/// (design §4 Task 6).
///
/// The active organization id is a routing hint — the create RPC re-derives
/// membership and the partner/compliance-officer gate in-function. No
/// automated legal verification is claimed.
class ComplianceAlertCreateSheet extends StatefulWidget {
  const ComplianceAlertCreateSheet({super.key});

  @override
  State<ComplianceAlertCreateSheet> createState() =>
      _ComplianceAlertCreateSheetState();
}

class _ComplianceAlertCreateSheetState
    extends State<ComplianceAlertCreateSheet> {
  static const int _titleMaxLength = 160;
  static const int _descriptionMaxLength = 4000;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();

  AlertKind _kind = AlertKind.deadline;
  AlertSeverity _severity = AlertSeverity.medium;
  bool _submitting = false;
  AppError? _submitError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
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
    try {
      final AppError? error = await context
          .read<ComplianceAlertsCubit>()
          .create(
            ComplianceAlertDraft(
              organizationId: organizationId,
              title: _title.text,
              kind: _kind,
              severity: _severity,
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
      setState(() => _submitError = error);
    } catch (_) {
      // A thrown write must re-enable the button, not leave it spinning.
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError = const AppError(
          code: 'compliance_alert_create_failed',
          userMessage: 'Unable to create the alert. Please try again.',
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
      title: l10n.alertCreateTitle,
      body: <Widget>[
        if (!hasOrganization) ...<Widget>[
          Text(
            l10n.alertCreateNoOrg,
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
              : Text(l10n.alertCreateSubmit),
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
          TextFormField(
            controller: _title,
            enabled: !_submitting,
            maxLength: _titleMaxLength,
            decoration: InputDecoration(
              labelText: l10n.alertCreateTitleLabel,
              hintText: l10n.alertCreateTitleHint,
              border: const OutlineInputBorder(),
            ),
            validator: (String? value) => _validateTitle(l10n, value),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          DropdownButtonFormField<AlertKind>(
            initialValue: _kind,
            decoration: InputDecoration(
              labelText: l10n.alertCreateKindLabel,
              border: const OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<AlertKind>>[
              for (final AlertKind kind in AlertKind.values)
                DropdownMenuItem<AlertKind>(
                  value: kind,
                  child: Text(alertKindLabel(l10n, kind)),
                ),
            ],
            onChanged: _submitting
                ? null
                : (AlertKind? value) {
                    if (value != null) {
                      setState(() => _kind = value);
                    }
                  },
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          DropdownButtonFormField<AlertSeverity>(
            initialValue: _severity,
            decoration: InputDecoration(
              labelText: l10n.alertCreateSeverityLabel,
              border: const OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<AlertSeverity>>[
              for (final AlertSeverity severity in AlertSeverity.values)
                DropdownMenuItem<AlertSeverity>(
                  value: severity,
                  child: Text(alertSeverityLabel(l10n, severity)),
                ),
            ],
            onChanged: _submitting
                ? null
                : (AlertSeverity? value) {
                    if (value != null) {
                      setState(() => _severity = value);
                    }
                  },
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          TextFormField(
            controller: _description,
            enabled: !_submitting,
            maxLines: 4,
            maxLength: _descriptionMaxLength,
            decoration: InputDecoration(
              labelText: l10n.alertCreateDescriptionLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (String? value) {
              if ((value ?? '').length > _descriptionMaxLength) {
                return l10n.alertCreateDescriptionTooLong;
              }
              return null;
            },
          ),
          if (_submitError != null) ...<Widget>[
            Text(
              alertErrorMessage(l10n, _submitError!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
          ],
        ],
      ),
    );
  }

  String? _validateTitle(AppLocalizations l10n, String? value) {
    final String text = (value ?? '').trim();
    if (text.length < 2) {
      return l10n.alertCreateTitleTooShort;
    }
    if (text.length > _titleMaxLength) {
      return l10n.alertCreateTitleTooLong;
    }
    return null;
  }
}
