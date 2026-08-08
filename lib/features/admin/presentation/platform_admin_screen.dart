import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/admin/platform_admin_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../orgs/presentation/org_error_messages.dart';
import 'platform_admin_cubit.dart';

/// Platform-owner admin surface (P3.5, permission matrix §5).
///
/// Two metadata-only sections — organizations and members — loaded in
/// parallel. The owner-only RPCs gate server-side: a non-owner sees the
/// distinct denied state (`permission denied`), never an empty-success list
/// (AC-7). Actions (platform suspend/reactivate, delete demo account) go
/// through the [PlatformAdminCubit]; every outcome renders as returned, and
/// failures surface as localized, non-sensitive messages.
class PlatformAdminScreen extends StatefulWidget {
  const PlatformAdminScreen({this.gateway, super.key});

  /// Test seam: production leaves this null and the screen resolves the
  /// locator's registered [PlatformAdminGateway]; tests inject a gateway to
  /// pin owner/non-owner/action behavior without the DI graph.
  final PlatformAdminGateway? gateway;

  @override
  State<PlatformAdminScreen> createState() => _PlatformAdminScreenState();
}

class _PlatformAdminScreenState extends State<PlatformAdminScreen> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // The feature-scoped cubit is provided here (the roster pattern: the org
    // hub provides OrgCubit above the roster; this screen is its own hub).
    // [gateway] is the test seam; production resolves the locator's seam.
    return BlocProvider<PlatformAdminCubit>(
      create: (_) => PlatformAdminCubit(
        widget.gateway ?? serviceLocator<PlatformAdminGateway>(),
      ),
      child: _LoadOnMount(
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.platformAdminTitle)),
          body: BlocBuilder<PlatformAdminCubit, PlatformAdminState>(
            builder: (BuildContext context, PlatformAdminState state) {
              switch (state) {
                case PlatformAdminLoaded(
                  organizations: final List<OrganizationSummary> organizations,
                  members: final List<OrgMember> members,
                  pendingUserId: final String? pendingUserId,
                  platformAudit: final List<AuditEntry> platformAudit,
                  orgAudit: final List<AuditEntry> orgAudit,
                  selectedAuditOrgId: final String? selectedAuditOrgId,
                  auditLoading: final bool auditLoading,
                  auditError: final OrgFailureKind? auditError,
                ):
                  return _AdminLists(
                    organizations: organizations,
                    members: members,
                    pendingUserId: pendingUserId,
                    platformAudit: platformAudit,
                    orgAudit: orgAudit,
                    selectedAuditOrgId: selectedAuditOrgId,
                    auditLoading: auditLoading,
                    auditError: auditError,
                  );
                case PlatformAdminDenied():
                  return _DeniedState();
                case PlatformAdminFailed(
                  error: _,
                  kind: final OrgFailureKind kind,
                ):
                  return _FailedState(kind: kind);
                case PlatformAdminInitial() || PlatformAdminLoading():
                  return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Loads the admin lists once after the first frame.
///
/// Lives BELOW the screen's BlocProvider so its context resolves the cubit
/// (the member roster's arrival pattern: load whenever the lists are not
/// already visible or in flight).
class _LoadOnMount extends StatefulWidget {
  const _LoadOnMount({required this.child});

  final Widget child;

  @override
  State<_LoadOnMount> createState() => _LoadOnMountState();
}

class _LoadOnMountState extends State<_LoadOnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final PlatformAdminState state = context.read<PlatformAdminCubit>().state;
      if (state is! PlatformAdminLoaded && state is! PlatformAdminLoading) {
        context.read<PlatformAdminCubit>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The three metadata sections: organizations, members, then the audit
/// trail (contract §8 — redacted metadata only).
class _AdminLists extends StatelessWidget {
  const _AdminLists({
    required this.organizations,
    required this.members,
    required this.pendingUserId,
    required this.platformAudit,
    required this.orgAudit,
    required this.selectedAuditOrgId,
    required this.auditLoading,
    required this.auditError,
  });

  final List<OrganizationSummary> organizations;
  final List<OrgMember> members;
  final String? pendingUserId;
  final List<AuditEntry> platformAudit;
  final List<AuditEntry> orgAudit;
  final String? selectedAuditOrgId;
  final bool auditLoading;
  final OrgFailureKind? auditError;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceMd,
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceXl * 2,
      ),
      children: <Widget>[
        Text(
          l10n.platformAdminOrganizations,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        if (organizations.isEmpty)
          Text(l10n.stateEmpty)
        else
          ...organizations.map(
            (OrganizationSummary org) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.domain_outlined),
              title: Text(org.name),
              subtitle: Text(
                MaterialLocalizations.of(
                  context,
                ).formatShortDate(org.createdAt),
              ),
            ),
          ),
        const SizedBox(height: LegalHubTheme.spaceXl),
        Text(
          l10n.platformAdminMembers,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        if (members.isEmpty)
          Text(l10n.stateEmpty)
        else
          ...members.map(
            (OrgMember member) => _MemberRow(
              member: member,
              organizationName: _orgNameFor(
                organizations,
                member.organizationId,
              ),
              pending: member.userId == pendingUserId,
            ),
          ),
        const SizedBox(height: LegalHubTheme.spaceXl),
        Text(
          l10n.platformAdminAudit,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        _AuditSection(
          organizations: organizations,
          platformAudit: platformAudit,
          orgAudit: orgAudit,
          selectedAuditOrgId: selectedAuditOrgId,
          auditLoading: auditLoading,
          auditError: auditError,
        ),
      ],
    );
  }

  static String? _orgNameFor(
    List<OrganizationSummary> organizations,
    String? organizationId,
  ) {
    if (organizationId == null) {
      return null;
    }
    for (final OrganizationSummary org in organizations) {
      if (org.id == organizationId) {
        return org.name;
      }
    }
    return null;
  }
}

/// One member metadata row: identity + role/status + the platform actions
/// (suspend/reactivate toggle on active/suspended, delete demo account).
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.organizationName,
    required this.pending,
  });

  final OrgMember member;
  final String? organizationName;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(_initial(member.displayName)),
      ),
      title: Text(member.displayName),
      subtitle: Text(
        organizationName == null
            ? _statusLabel(l10n, member)
            : '$organizationName · ${_statusLabel(l10n, member)}',
      ),
      trailing: pending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (member.status == MembershipStatus.active)
                  IconButton(
                    icon: const Icon(Icons.pause_circle_outline),
                    tooltip: l10n.actionSuspend,
                    onPressed: () => _runToggle(context, suspend: true),
                  ),
                if (member.status == MembershipStatus.suspended)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: l10n.actionReactivate,
                    onPressed: () => _runToggle(context, suspend: false),
                  ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: l10n.platformAdminDeleteDemo,
                  onPressed: () => _confirmAndDelete(context),
                ),
              ],
            ),
    );
  }

  Future<void> _runToggle(BuildContext context, {required bool suspend}) async {
    final PlatformAdminCubit cubit = context.read<PlatformAdminCubit>();
    final OrgFailureKind? kind = suspend
        ? await cubit.suspendMembership(
            organizationId: member.organizationId,
            userId: member.userId,
          )
        : await cubit.reactivateMembership(
            organizationId: member.organizationId,
            userId: member.userId,
          );
    if (!context.mounted) {
      return;
    }
    if (kind != null) {
      _showActionError(context, kind);
    }
  }

  /// Prompts before the destructive delete; the server refuses the caller's
  /// own account (never self). Typed denials surface as localized messages.
  Future<void> _confirmAndDelete(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ColorScheme scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.platformAdminDeleteConfirmTitle),
          content: Text(
            l10n.platformAdminDeleteConfirmBody(member.displayName),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            // Error-tinted confirm so the destructive action reads as
            // dangerous (M3 pattern, mirroring the member-removal dialog).
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.platformAdminDeleteConfirmAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final OrgFailureKind? kind = await context
        .read<PlatformAdminCubit>()
        .deleteDemoAccount(userId: member.userId);
    if (!context.mounted) {
      return;
    }
    if (kind != null) {
      _showActionError(context, kind);
    }
  }

  void _showActionError(BuildContext context, OrgFailureKind kind) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(orgErrorMessage(AppLocalizations.of(context), kind)),
      ),
    );
  }

  String _initial(String displayName) =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  String _statusLabel(AppLocalizations l10n, OrgMember member) {
    return switch (member.status) {
      MembershipStatus.invited => l10n.memberStatusInvited,
      MembershipStatus.active => l10n.memberStatusActive,
      MembershipStatus.suspended => l10n.memberStatusSuspended,
      MembershipStatus.removed => l10n.memberStatusRemoved,
    };
  }
}

/// The audit trail section (contract §8 — redacted metadata only; D-P0C4
/// holds: no raw `SELECT` on `audit_events` ever, the RPCs are the only
/// read path).
///
/// Section-local per D-AUD2: the platform-wide trail is fetched on mount
/// ([PlatformAdminCubit.loadAudit]) and a per-org trail on selector change
/// ([PlatformAdminCubit.selectAuditOrg]) — the matter-sections per-section
/// pattern, hosted on the existing cubit (no new cubit). A `denied` audit
/// read flips the whole surface to the distinct denied state (AC-7, never
/// an empty-success trail); a non-denial failure renders inline with retry
/// so the loaded orgs/members lists survive.
class _AuditSection extends StatefulWidget {
  const _AuditSection({
    required this.organizations,
    required this.platformAudit,
    required this.orgAudit,
    required this.selectedAuditOrgId,
    required this.auditLoading,
    required this.auditError,
  });

  final List<OrganizationSummary> organizations;
  final List<AuditEntry> platformAudit;
  final List<AuditEntry> orgAudit;
  final String? selectedAuditOrgId;
  final bool auditLoading;
  final OrgFailureKind? auditError;

  @override
  State<_AuditSection> createState() => _AuditSectionState();
}

class _AuditSectionState extends State<_AuditSection> {
  @override
  void initState() {
    super.initState();
    // Section-local fetch on mount (the matter-sections pattern).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final PlatformAdminState state = context.read<PlatformAdminCubit>().state;
      if (state is PlatformAdminLoaded &&
          !state.auditLoading &&
          state.platformAudit.isEmpty) {
        context.read<PlatformAdminCubit>().loadAudit();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<AuditEntry> rows = widget.selectedAuditOrgId == null
        ? widget.platformAudit
        : widget.orgAudit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Org scope selector: null = the platform-wide trail, an org id =
        // that org's trail (owner-only first surface; partner UI follow-up).
        DropdownButton<String?>(
          value: widget.selectedAuditOrgId,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.platformAdminAuditPlatform),
            ),
            for (final OrganizationSummary org in widget.organizations)
              DropdownMenuItem<String?>(
                value: org.id,
                child: Text(org.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (String? id) =>
              context.read<PlatformAdminCubit>().selectAuditOrg(id),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        if (widget.auditLoading)
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(
              vertical: LegalHubTheme.spaceMd,
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (widget.auditError != null)
          _auditError(context, l10n)
        else if (rows.isEmpty)
          Text(l10n.stateEmpty)
        else
          ...rows.map(
            (AuditEntry entry) => _AuditRow(
              entry: entry,
              organizationName: _orgNameFor(
                widget.organizations,
                entry.organizationId,
              ),
            ),
          ),
      ],
    );
  }

  Widget _auditError(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          orgErrorMessage(l10n, widget.auditError!),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        TextButton(
          onPressed: () {
            if (widget.selectedAuditOrgId == null) {
              context.read<PlatformAdminCubit>().loadAudit();
            } else {
              context.read<PlatformAdminCubit>().selectAuditOrg(
                widget.selectedAuditOrgId,
              );
            }
          },
          child: Text(l10n.retry),
        ),
      ],
    );
  }

  static String? _orgNameFor(
    List<OrganizationSummary> organizations,
    String? organizationId,
  ) => _AdminLists._orgNameFor(organizations, organizationId);
}

/// One redacted audit row: action + redacted summary + scope + date.
/// Metadata-only (contract §8) — no credentials, no content, no PII field
/// names; rows are read-only (no tap affordance).
class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry, required this.organizationName});

  final AuditEntry entry;
  final String? organizationName;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String date = MaterialLocalizations.of(
      context,
    ).formatShortDate(entry.serverTimestamp);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        child: Text(entry.action.isEmpty ? '?' : entry.action[0].toUpperCase()),
      ),
      title: Text(entry.redactedSummary),
      subtitle: Text(
        [?organizationName, entry.action, entry.outcome, date].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// Distinct non-owner state: the owner-only RPCs denied server-side. Never
/// rendered as an empty-success list (AC-7); no retry — the gate is
/// identity, not a transient failure.
class _DeniedState extends StatelessWidget {
  const _DeniedState();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LegalHubTheme.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              l10n.stateUnauthorized,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              orgErrorMessage(l10n, OrgFailureKind.denied),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A non-denial failure with a retry (transient, unlike the denied gate).
class _FailedState extends StatelessWidget {
  const _FailedState({required this.kind});

  final OrgFailureKind kind;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: 32,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(orgErrorMessage(l10n, kind), textAlign: TextAlign.center),
          const SizedBox(height: LegalHubTheme.spaceSm),
          TextButton(
            onPressed: () => context.read<PlatformAdminCubit>().load(),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
