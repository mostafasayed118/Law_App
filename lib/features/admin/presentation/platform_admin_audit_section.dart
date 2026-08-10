part of 'platform_admin_screen.dart';

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
