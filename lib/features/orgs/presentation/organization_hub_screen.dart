import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/auth/session.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_cubit.dart';
import 'active_org_store.dart';
import 'create_organization_screen.dart';
import 'member_roster_screen.dart';
import 'org_cubit.dart';

/// Hub for the organization surface (P3 slice 1.5 + Phase 2 slice 2.3;
/// active-org context formalized in Phase 7 slice 7.0).
///
/// Resolves the active-org context from the [ActiveOrgStore] (seeded from
/// [Session.activeMembership] — or an organization created in this visit)
/// and renders the roster when an org exists, or the create-org form when it
/// does not. With multiple session memberships the hub offers a client-side
/// org switcher: the selection is a local UI context only — it is never sent
/// anywhere, and the server stays the membership authority (D-08). Provides
/// the shared [OrgCubit] so create → roster shares one gateway-backed state
/// machine; switching orgs swaps the cubit (keyed by org) so the roster
/// always loads the selected org fresh.
class OrganizationHubScreen extends StatefulWidget {
  const OrganizationHubScreen({super.key});

  @override
  State<OrganizationHubScreen> createState() => _OrganizationHubScreenState();
}

class _OrganizationHubScreenState extends State<OrganizationHubScreen> {
  final ActiveOrgStore _activeOrgStore = serviceLocator<ActiveOrgStore>();
  String? _createdOrganizationId;

  @override
  void initState() {
    super.initState();
    _activeOrgStore.addListener(_onActiveOrgChanged);
  }

  @override
  void dispose() {
    _activeOrgStore.removeListener(_onActiveOrgChanged);
    super.dispose();
  }

  void _onActiveOrgChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Session? session = context.watch<AuthCubit>().state.session;
    // The store re-seeds itself when the session identity changes (and is a
    // no-op for the same session, preserving a user selection); calling it
    // here keeps the hub in sync on sign-out / user switch.
    _activeOrgStore.syncFromSession(session);
    final List<OrganizationMembership> memberships =
        session?.memberships ?? const <OrganizationMembership>[];
    final String? organizationId =
        _createdOrganizationId ?? _activeOrgStore.activeOrganizationId;
    // The switcher is a multi-org affordance only; the create-org context of
    // this visit wins over any selection (the new org is not in the session
    // yet).
    final bool showSwitcher =
        _createdOrganizationId == null && memberships.length > 1;
    return BlocProvider<OrgCubit>(
      key: ValueKey<String>('org-cubit-$organizationId'),
      create: (BuildContext context) =>
          OrgCubit(serviceLocator<OrganizationGateway>()),
      child: organizationId == null
          ? CreateOrganizationScreen(
              onCreated: (OrganizationSummary organization) {
                setState(() => _createdOrganizationId = organization.id);
              },
            )
          : Column(
              children: <Widget>[
                if (showSwitcher)
                  _OrgSwitcher(
                    memberships: memberships,
                    selectedOrganizationId: organizationId,
                    onChanged: _activeOrgStore.select,
                  ),
                Expanded(
                  child: MemberRosterScreen(organizationId: organizationId),
                ),
              ],
            ),
    );
  }
}

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
