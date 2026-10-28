import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';

import 'compliance_alert_error_messages.dart';
import 'compliance_alert_labels.dart';
import 'compliance_alerts_cubit.dart';

/// The action that closed the detail sheet, or null when it was dismissed.
enum ComplianceAlertDetailOutcome { acknowledged, resolved }

/// Opens the alert detail sheet with the caller's permitted actions.
///
/// [cubit] is the list's own [ComplianceAlertsCubit] — re-provided around the
/// sheet because a modal's context sits under the Navigator, not under the
/// caller's provider scope. Acknowledgement is offered to any active member;
/// [canManage] (partner or compliance officer, a router projection) gates the
/// resolve action. The RPCs are the authority for both gates.
Future<ComplianceAlertDetailOutcome?> showComplianceAlertDetailSheet(
  BuildContext context, {
  required ComplianceAlert alert,
  required ComplianceAlertsCubit cubit,
  required bool canManage,
}) {
  return showModalBottomSheet<ComplianceAlertDetailOutcome>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) =>
        BlocProvider<ComplianceAlertsCubit>.value(
          value: cubit,
          child: ComplianceAlertDetailSheet(alert: alert, canManage: canManage),
        ),
  );
}

/// Detail sheet for one compliance alert (design §4 Task 6).
///
/// Shows title, status, severity, kind, description, due date, and the
/// acknowledgement/resolution timestamps. Acknowledge renders for any member
/// while the alert is open; resolve renders for a manager while the alert is
/// not terminal. Every action goes through the cubit and a refusal renders
/// the typed, localized failure copy — never a success. No automated legal
/// verification is claimed.
class ComplianceAlertDetailSheet extends StatefulWidget {
  const ComplianceAlertDetailSheet({
    required this.alert,
    required this.canManage,
    super.key,
  });

  final ComplianceAlert alert;
  final bool canManage;

  @override
  State<ComplianceAlertDetailSheet> createState() =>
      _ComplianceAlertDetailSheetState();
}

class _ComplianceAlertDetailSheetState
    extends State<ComplianceAlertDetailSheet> {
  final TextEditingController _note = TextEditingController();

  bool _submitting = false;
  AppError? _actionError;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canAcknowledge => widget.alert.isAcknowledgeable;

  bool get _canResolve => widget.canManage && widget.alert.isResolvable;

  Future<void> _acknowledge() async {
    setState(() {
      _submitting = true;
      _actionError = null;
    });
    final AppError? error = await context
        .read<ComplianceAlertsCubit>()
        .acknowledge(widget.alert.id);
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(ComplianceAlertDetailOutcome.acknowledged);
      return;
    }
    setState(() {
      _submitting = false;
      _actionError = error;
    });
  }

  Future<void> _resolve() async {
    setState(() {
      _submitting = true;
      _actionError = null;
    });
    final AppError? error = await context.read<ComplianceAlertsCubit>().resolve(
      widget.alert.id,
      note: _note.text,
    );
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(ComplianceAlertDetailOutcome.resolved);
      return;
    }
    setState(() {
      _submitting = false;
      _actionError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ComplianceAlert alert = widget.alert;
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
                demoAlertTitle(l10n, alert.title),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
              _stateLine(
                icon: alertSeverityIcon(alert.severity),
                label:
                    '${l10n.alertDetailSeverity}: '
                    '${alertSeverityLabel(l10n, alert.severity)}',
              ),
              const SizedBox(height: LegalHubTheme.spaceXs),
              _stateLine(
                icon: alertStatusIcon(alert.status),
                label: alertStatusLabel(l10n, alert.status),
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              Text(
                '${l10n.alertDetailKind}: '
                '${alertKindLabel(l10n, alert.kind)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
              Text(
                '${l10n.alertDetailCreated}: '
                '${formatMediumDate(l10n, alert.createdAt.toLocal())}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (alert.dueAt != null)
                Text(
                  '${l10n.alertDetailDue}: '
                  '${formatMediumDate(l10n, alert.dueAt!.toLocal())}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (alert.description != null) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceMd),
                Text(
                  l10n.alertDetailDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: LegalHubTheme.spaceXs),
                Text(alert.description!),
              ],
              if (alert.acknowledgedAt != null)
                _timestampLine(
                  l10n.alertDetailAcknowledged,
                  alert.acknowledgedAt!,
                ),
              if (alert.resolvedAt != null)
                _timestampLine(l10n.alertDetailResolved, alert.resolvedAt!),
              if (_canResolve) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceLg),
                TextField(
                  controller: _note,
                  enabled: !_submitting,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: l10n.alertResolveNoteLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              if (_canAcknowledge) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceLg),
                OutlinedButton(
                  onPressed: _submitting ? null : _acknowledge,
                  child: Text(l10n.alertAcknowledgeAction),
                ),
              ],
              if (_canResolve) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceSm),
                FilledButton(
                  onPressed: _submitting ? null : _resolve,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.alertResolveAction),
                ),
              ],
              if (_actionError != null) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceMd),
                Text(
                  alertErrorMessage(l10n, _actionError!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stateLine({required IconData icon, required String label}) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: LegalHubTheme.spaceXs),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _timestampLine(String label, DateTime at) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceSm),
      child: Text(
        '$label: ${formatMediumDateTime(AppLocalizations.of(context), at.toLocal())}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
