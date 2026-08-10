import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../core/roles/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import 'active_org_store.dart';
import 'org_audit_cubit.dart';

/// Partner org-audit read surface (partner org-audit slice 2026-08-09,
/// scope `docs/partner_org_audit_scope_2026-08-09.md`).
///
/// Read-only by D-AUD1: renders the active organization's **server-redacted**
/// audit rows as returned by the partner-capable `read_org_audit` RPC —
/// never content, credentials, or a raw `audit_events` SELECT (D-P0C4).
/// No export affordance. A non-partner (or cross-org) caller sees the
/// distinct denied state (AC-7 — never empty success); an org with no
/// events shows an honest empty state.
class OrgAuditScreen extends StatefulWidget {
  const OrgAuditScreen({
    super.key,
    this.organizationId,
    required this.capabilities,
  });

  /// Optional explicit org context (tests). When null, the screen resolves
  /// the active-org context from the [ActiveOrgStore] (D-08 — a local UI
  /// context; the server re-derives membership).
  final String? organizationId;

  /// UX-only navigation hint, never an authorization grant.
  final RoleCapability capabilities;

  @override
  State<OrgAuditScreen> createState() => _OrgAuditScreenState();
}

class _OrgAuditScreenState extends State<OrgAuditScreen> {
  final ActiveOrgStore _activeOrgStore = serviceLocator<ActiveOrgStore>();
  late final OrgAuditCubit _cubit;

  @override
  void initState() {
    super.initState();
    final OrganizationGateway gateway = serviceLocator<OrganizationGateway>();
    _cubit = OrgAuditCubit(gateway);
    final String? organizationId =
        widget.organizationId ?? _activeOrgStore.activeOrganizationId;
    if (organizationId != null) {
      _cubit.load(organizationId: organizationId);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orgAuditTitle)),
      body: BlocProvider<OrgAuditCubit>.value(
        value: _cubit,
        child: BlocBuilder<OrgAuditCubit, OrgAuditState>(
          builder: (BuildContext context, OrgAuditState state) {
            return switch (state) {
              OrgAuditInitial() => const SizedBox.shrink(),
              OrgAuditLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              OrgAuditLoaded(entries: final List<AuditEntry> entries) =>
                entries.isEmpty
                    ? _EmptyState(message: l10n.orgAuditEmpty)
                    : _AuditList(entries: entries),
              OrgAuditDenied() => _DeniedState(l10n: l10n),
              OrgAuditFailed() => OrgAuditFailedBlock(
                retry: _cubit.retry,
                l10n: l10n,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _AuditList extends StatelessWidget {
  const _AuditList({required this.entries});

  final List<AuditEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceSm,
        LegalHubTheme.marginMobile,
        LegalHubTheme.marginMobile,
      ),
      itemCount: entries.length,
      separatorBuilder: (BuildContext context, int index) =>
          SizedBox(height: LegalHubTheme.spaceSm),
      itemBuilder: (BuildContext context, int index) =>
          _AuditRow(entry: entries[index]),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String issued = formatMediumDate(
      l10n,
      entry.serverTimestamp.toLocal(),
    );
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(LegalHubTheme.radiusLg)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: LegalHubTheme.spaceSm),
                Expanded(child: Text(entry.action, style: text.titleSmall)),
                // Server vocabulary rendered verbatim; color is never the
                // sole carrier (the chip also names the outcome).
                _OutcomeChip(outcome: entry.outcome, l10n: l10n),
              ],
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              entry.redactedSummary,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            // Redacted metadata only: timestamp + correlation id (when the
            // server supplies one) — never content or credentials.
            Text(
              entry.correlationId == null
                  ? issued
                  : '$issued · ${entry.correlationId}',
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// Names the server-side outcome (`allowed`/`denied`) with a localized
/// label; an unexpected value is rendered verbatim (loud, never a silent
/// guess).
class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({required this.outcome, required this.l10n});

  final String outcome;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String label = switch (outcome) {
      'allowed' => l10n.orgAuditOutcomeAllowed,
      'denied' => l10n.orgAuditOutcomeDenied,
      _ => outcome,
    };
    final Color background = outcome == 'denied'
        ? scheme.errorContainer
        : scheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LegalHubTheme.spaceSm,
        vertical: LegalHubTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.all(Radius.circular(LegalHubTheme.radiusLg)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// Honest empty trail — distinct from the denied state.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle_outline, size: 40, color: scheme.outline),
            const SizedBox(height: LegalHubTheme.spaceMd),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Distinct denied state (AC-7) — the server said `permission denied`; this
/// is never "an empty trail".
class _DeniedState extends StatelessWidget {
  const _DeniedState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.lock_outline, size: 40, color: scheme.error),
            const SizedBox(height: LegalHubTheme.spaceMd),
            Text(l10n.orgAuditDenied, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Failed state with a retry that re-issues the same org load.
class OrgAuditFailedBlock extends StatelessWidget {
  const OrgAuditFailedBlock({
    super.key,
    required this.retry,
    required this.l10n,
  });

  final Future<void> Function() retry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            Text(l10n.orgAuditError, textAlign: TextAlign.center),
            const SizedBox(height: LegalHubTheme.spaceMd),
            FilledButton(onPressed: retry, child: Text(l10n.orgAuditRetry)),
          ],
        ),
      ),
    );
  }
}
