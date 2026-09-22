import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/compliance_alert.dart';
import '../domain/compliance_gateway.dart';
import 'compliance_alerts_cubit.dart';
import 'compliance_alerts_state.dart';

/// Compliance-alerts list surface (v1 queue; spec §6 row
/// `compliance_alerts`, deferred→v1 read-only).
///
/// Renders the deterministic synthetic alert rows (title/severity/date) with
/// **text + severity label** — never color alone (INSTRUCTIONS §4.5). No
/// actions, no escalation, no export — a read-only demo surface.
class ComplianceAlertsScreen extends StatelessWidget {
  const ComplianceAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertsTitle)),
      // The shared cubit-scoped list shell (audit 2026-09-21, M-10).
      body:
          CubitListSurface<
            ComplianceAlertsCubit,
            ComplianceAlertsState,
            ComplianceAlert
          >(
            createCubit: () => ComplianceAlertsCubit(
              serviceLocator<ComplianceAlertsGateway>(),
            ),
            project: (ComplianceAlertsState state) => state.alerts,
            load: (ComplianceAlertsCubit cubit) => cubit.load(),
            tileBuilder: (BuildContext context, ComplianceAlert alert) =>
                _AlertTile(alert: alert),
            empty: (BuildContext context, ComplianceAlertsState state) =>
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: LegalHubTheme.spaceMd,
                  ),
                  child: Text(
                    l10n.alertsEmpty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            errorCopy: l10n.alertsError,
            localOnlyNote: l10n.alertsLocalOnlyNote,
          ),
    );
  }
}

/// A read-only alert row: text + severity label, never color alone
/// (INSTRUCTIONS §4.5); no tap affordance.
class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final ComplianceAlert alert;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final IconData icon = switch (alert.severity) {
      AlertSeverity.info => Icons.info_outline,
      AlertSeverity.attention => Icons.warning_amber_outlined,
      AlertSeverity.critical => Icons.error_outline,
    };
    final String label = switch (alert.severity) {
      AlertSeverity.info => l10n.alertSeverityInfo,
      AlertSeverity.attention => l10n.alertSeverityAttention,
      AlertSeverity.critical => l10n.alertSeverityCritical,
    };
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: LegalHubTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    alert.title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
