import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'org_audit_cubit.dart';
part 'org_audit_list.dart';
part 'org_audit_row.dart';
part 'org_audit_outcome_chip.dart';
part 'org_audit_centered_state.dart';

/// Partner org-audit read surface (partner org-audit slice 2026-08-09,
/// scope `docs/partner_org_audit_scope_2026-08-09.md`).
///
/// Read-only by D-AUD1: renders the active organization's **server-redacted**
/// audit rows as returned by the partner-capable `read_org_audit` RPC —
/// never content, credentials, or a raw `audit_events` SELECT (D-P0C4).
/// No export affordance. A non-partner (or cross-org) caller sees the
/// distinct denied state (AC-7 — never empty success); an org with no
/// events shows an honest empty state. With no active org at all (signed
/// out / memberships not hydrated) the screen shows the no-organization
/// state instead of a blank surface.
class OrgAuditScreen extends StatefulWidget {
  const OrgAuditScreen({super.key, this.organizationId});

  /// Optional explicit org context (tests). When null, the screen resolves
  /// the active-org context from the [ActiveOrgStore] (D-08 — a local UI
  /// context; the server re-derives membership).
  final String? organizationId;

  @override
  State<OrgAuditScreen> createState() => _OrgAuditScreenState();
}

class _OrgAuditScreenState extends State<OrgAuditScreen> {
  final ActiveOrgStore _activeOrgStore = serviceLocator<ActiveOrgStore>();
  late final OrgAuditCubit _cubit;

  /// The resolved org context for this visit (null when no org is active —
  /// the no-context arm below, never a blank screen).
  String? _organizationId;

  @override
  void initState() {
    super.initState();
    final OrganizationGateway gateway = serviceLocator<OrganizationGateway>();
    _cubit = OrgAuditCubit(gateway);
    _organizationId =
        widget.organizationId ?? _activeOrgStore.activeOrganizationId;
    final String? organizationId = _organizationId;
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
    // No active org (signed out, or membership not yet hydrated): an honest
    // no-context state instead of the old blank screen — the cubit never
    // loads, so the Initial arm below would render nothing.
    if (_organizationId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.orgAuditTitle)),
        body: _CenteredState(
          icon: Icons.business_outlined,
          iconColor: Theme.of(context).colorScheme.outline,
          message: l10n.orgAuditNoOrganization,
        ),
      );
    }
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
                    ? _CenteredState(
                        icon: Icons.check_circle_outline,
                        iconColor: Theme.of(context).colorScheme.outline,
                        message: l10n.orgAuditEmpty,
                      )
                    : _AuditList(entries: entries),
              // AC-7: the server said `permission denied` — never empty
              // success, and no retry (the gate is not transient).
              OrgAuditDenied() => _CenteredState(
                icon: Icons.lock_outline,
                iconColor: Theme.of(context).colorScheme.error,
                message: l10n.orgAuditDenied,
              ),
              // Transient failure with a retry that re-issues the load.
              OrgAuditFailed() => _CenteredState(
                icon: Icons.cloud_off_outlined,
                iconColor: Theme.of(context).colorScheme.error,
                message: l10n.orgAuditError,
                action: FilledButton(
                  onPressed: _cubit.retry,
                  child: Text(l10n.orgAuditRetry),
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}
