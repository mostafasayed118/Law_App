part of 'organization_hub_screen.dart';

/// Partner-only "Audit trail" entry into `/organizations/audit` (partner
/// org-audit slice 2026-08-09). Navigation hint only — the `read_org_audit`
/// RPC enforces the actual authorization.
class _AuditEntryTile extends StatelessWidget {
  const _AuditEntryTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceSm,
        LegalHubTheme.marginMobile,
        0,
      ),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.all(Radius.circular(LegalHubTheme.radiusLg)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.all(
            Radius.circular(LegalHubTheme.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: LegalHubTheme.spaceSm),
                Expanded(child: Text(l10n.orgAuditHubEntry)),
                Icon(Icons.chevron_right, size: 20, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
