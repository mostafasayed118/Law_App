import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'compliance_alert_create_sheet.dart';
import 'compliance_alert_detail_sheet.dart';
import 'compliance_alert_labels.dart';
import 'compliance_alerts_cubit.dart';
import 'compliance_alerts_state.dart';

part 'compliance_alert_tile.dart';

/// Org-scoped compliance-alerts list (design §4).
///
/// [canManage] is a UX-only projection of the active membership's role
/// (partner or compliance officer) passed by the router; acknowledgement is
/// offered to every member. The create/acknowledge/resolve RPCs re-assert
/// every gate server-side, so a refusal renders the typed failure, never a
/// success. No automated legal verification is claimed.
class ComplianceAlertsScreen extends StatefulWidget {
  const ComplianceAlertsScreen({super.key, this.canManage = false});

  final bool canManage;

  @override
  State<ComplianceAlertsScreen> createState() => _ComplianceAlertsScreenState();
}

class _ComplianceAlertsScreenState extends State<ComplianceAlertsScreen> {
  // The list surface's BlocProvider owns this cubit's lifecycle (it closes it
  // on unmount); the Scaffold-level FAB shares the same instance.
  late final ComplianceAlertsCubit _cubit = ComplianceAlertsCubit(
    serviceLocator<ComplianceAlertsGateway>(),
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool localOnly = backendIsLocalOnly;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertsTitle)),
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_alert_outlined),
              label: Text(l10n.alertsCreateFab),
            )
          : null,
      body:
          CubitListSurface<
            ComplianceAlertsCubit,
            ComplianceAlertsState,
            ComplianceAlert
          >(
            createCubit: () => _cubit,
            project: (ComplianceAlertsState state) => state.alerts,
            load: (ComplianceAlertsCubit cubit) => cubit.load(),
            tileBuilder: (BuildContext context, ComplianceAlert alert) =>
                _AlertTile(
                  alert: alert,
                  localOnly: localOnly,
                  onTap: () => _openDetail(alert),
                ),
            header: <Widget>[
              BlocBuilder<ComplianceAlertsCubit, ComplianceAlertsState>(
                buildWhen:
                    (
                      ComplianceAlertsState previous,
                      ComplianceAlertsState next,
                    ) => previous.status != next.status,
                builder: (BuildContext context, ComplianceAlertsState state) {
                  return AppFilterChips<AlertStatus>(
                    values: AlertStatus.values,
                    selected: state.status,
                    allLabel: l10n.alertsFilterAll,
                    labelOf: (AlertStatus status) =>
                        alertStatusLabel(l10n, status),
                    onSelected: _cubit.setStatus,
                  );
                },
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
              BlocBuilder<ComplianceAlertsCubit, ComplianceAlertsState>(
                buildWhen:
                    (
                      ComplianceAlertsState previous,
                      ComplianceAlertsState next,
                    ) => previous.severity != next.severity,
                builder: (BuildContext context, ComplianceAlertsState state) {
                  return AppFilterChips<AlertSeverity>(
                    values: AlertSeverity.values,
                    selected: state.severity,
                    allLabel: l10n.alertsFilterAll,
                    labelOf: (AlertSeverity severity) =>
                        alertSeverityLabel(l10n, severity),
                    onSelected: _cubit.setSeverity,
                  );
                },
              ),
              const SizedBox(height: LegalHubTheme.spaceLg),
            ],
            empty: (BuildContext context, ComplianceAlertsState state) =>
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: LegalHubTheme.spaceMd,
                  ),
                  child: Text(
                    l10n.alertsEmptyFiltered,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            errorCopy: l10n.alertsError,
            localOnlyNote: localOnly
                ? l10n.alertsLocalOnlyNote
                : l10n.alertsStoredNote,
          ),
    );
  }

  Future<void> _openCreate() async {
    final bool? created = await showComplianceAlertCreateSheet(
      context,
      cubit: _cubit,
    );
    if (!mounted || created != true) {
      return;
    }
    _showSnack(AppLocalizations.of(context).alertCreateSuccess);
  }

  Future<void> _openDetail(ComplianceAlert alert) async {
    final ComplianceAlertDetailOutcome? outcome =
        await showComplianceAlertDetailSheet(
          context,
          alert: alert,
          cubit: _cubit,
          canManage: widget.canManage,
        );
    if (!mounted || outcome == null) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    _showSnack(switch (outcome) {
      ComplianceAlertDetailOutcome.acknowledged =>
        l10n.alertAcknowledgedSuccess,
      ComplianceAlertDetailOutcome.resolved => l10n.alertResolvedSuccess,
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
