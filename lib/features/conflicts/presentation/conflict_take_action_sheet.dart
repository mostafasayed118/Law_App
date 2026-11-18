import 'package:flutter/material.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/features/approvals/domain/approvals_gateway.dart';
import 'package:legalhub/features/approvals/presentation/approval_create_sheet.dart';
import 'package:legalhub/features/approvals/presentation/approvals_cubit.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_gateway.dart';
import 'package:legalhub/features/tasks/presentation/task_board_cubit.dart';
import 'package:legalhub/features/tasks/presentation/task_create_sheet.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/app_modal_sheet.dart';

/// "Take action" sheet launched from a compliance-alert detail sheet. Not a
/// route. Two procedures open the existing create sheets; two are disabled
/// because their features are deferred in this build.
Future<void> showComplianceTakeActionSheet(
  BuildContext context, {
  required ComplianceAlert alert,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (BuildContext context) => ComplianceTakeActionSheet(alert: alert),
  );
}

class ComplianceTakeActionSheet extends StatelessWidget {
  const ComplianceTakeActionSheet({required this.alert, super.key});

  final ComplianceAlert alert;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.conflictsActionRequired,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              l10n.conflictsResolution,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              l10n.conflictsActionBody(alert.matterId ?? '—'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            _ProcedureCard(
              label: l10n.conflictsInitiateWall,
              estimate: l10n.conflictsEstTime('24-48h'),
              note: l10n.conflictsWallDisabled,
              enabled: false,
              onTap: null,
            ),
            _ProcedureCard(
              label: l10n.conflictsRequestWaiver,
              estimate: l10n.conflictsEstTime('3-5 days'),
              note: null,
              enabled: true,
              onTap: () => _openWaiver(context),
            ),
            _ProcedureCard(
              label: l10n.conflictsEscalatePartner,
              estimate: l10n.conflictsEstTime('12-24h'),
              note: null,
              enabled: true,
              onTap: () => _openTask(context),
            ),
            _ProcedureCard(
              label: l10n.conflictsFileDisclosure,
              estimate: l10n.conflictsEstTime('7-14 days'),
              note: l10n.conflictsFilingDisabled,
              enabled: false,
              onTap: null,
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.conflictsCancel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWaiver(BuildContext context) async {
    final ApprovalsCubit cubit = ApprovalsCubit(
      serviceLocator<ApprovalsGateway>(),
      serviceLocator<MatterGateway>(),
    );
    try {
      await showApprovalCreateSheet(
        context,
        cubit: cubit,
        initialMatterId: alert.matterId,
      );
    } finally {
      await cubit.close();
    }
  }

  Future<void> _openTask(BuildContext context) async {
    final TaskBoardCubit cubit = TaskBoardCubit(
      serviceLocator<TaskBoardGateway>(),
      serviceLocator<MatterGateway>(),
      serviceLocator<OrganizationGateway>(),
    );
    try {
      await showTaskCreateSheet(
        context,
        cubit: cubit,
        initialMatterId: alert.matterId,
        initialTitle: 'Review conflict: ${alert.title}',
      );
    } finally {
      await cubit.close();
    }
  }
}

class _ProcedureCard extends StatelessWidget {
  const _ProcedureCard({
    required this.label,
    required this.estimate,
    required this.enabled,
    required this.note,
    required this.onTap,
  });

  final String label;
  final String estimate;
  final bool enabled;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Card(
        child: ListTile(
          enabled: enabled,
          onTap: onTap,
          title: Text(label),
          subtitle: Text(note == null ? estimate : '$estimate\n$note'),
          trailing: enabled
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(l10n.conflictsSelectProcedure),
                    const Icon(Icons.arrow_forward),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}
