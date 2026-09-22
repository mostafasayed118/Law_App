import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/active_org_store.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../core/roles/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
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
