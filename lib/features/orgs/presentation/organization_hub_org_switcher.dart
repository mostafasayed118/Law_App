part of 'organization_hub_screen.dart';

/// Compact active-org selector over [Session.memberships].
///
/// Local UI context only: the selection changes which membership the hub
/// renders and is never transmitted; the server re-derives membership per
/// D-08 (matrix §3 "switch active organization" is a UX hint, not an
/// authority).
class _OrgSwitcher extends StatelessWidget {
  const _OrgSwitcher({
    required this.memberships,
    required this.selectedOrganizationId,
    required this.onChanged,
  });

  final List<OrganizationMembership> memberships;
  final String selectedOrganizationId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: LegalHubTheme.marginMobile,
          vertical: LegalHubTheme.spaceXs,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.apartment_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: LegalHubTheme.spaceSm),
            Text(l10n.orgSwitcherLabel),
            const SizedBox(width: LegalHubTheme.spaceSm),
            Expanded(
              child: DropdownButton<String>(
                value: selectedOrganizationId,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: <DropdownMenuItem<String>>[
                  for (final OrganizationMembership membership in memberships)
                    DropdownMenuItem<String>(
                      value: membership.organizationId,
                      child: Text(
                        // P3.2 name-resolution note: a suspended/removed
                        // membership's org name is not resolvable — fall
                        // back to the org id so the switcher still labels
                        // the row honestly.
                        membership.organizationName ??
                            membership.organizationId,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (String? id) {
                  if (id != null) {
                    onChanged(id);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
