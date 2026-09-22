part of 'router.dart';

class _AppShell extends StatelessWidget {
  const _AppShell({
    required this.authCubit,
    required this.capabilitiesForRole,
    required this.child,
  });

  final AuthCubit authCubit;
  final Map<UserRole, RoleCapability> capabilitiesForRole;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    final AppLocalizations l10n = AppLocalizations.of(context);
    // UX-only projection from the active membership's org-scoped role. The
    // session itself carries no client-owned role (contract §5); this is a
    // navigation hint, never an authorization grant.
    final UserRole role =
        authCubit.state.session?.primaryRole ?? UserRole.client;
    final RoleCapability capabilities = capabilitiesForRole[role]!;

    // Destinations are rendered from capabilities in a fixed order (home,
    // then settings). The selected index and the tap target are derived from
    // this same list, so they stay in range and consistent for every
    // capability combination — including roles that hide a destination.
    final List<(String, NavigationDestination)> destinations =
        <(String, NavigationDestination)>[
          if (capabilities.canViewHome)
            (
              AppRoutes.home,
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: l10n.homeNavigation,
              ),
            ),
          if (capabilities.canViewSettings)
            (
              AppRoutes.settings,
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: l10n.settingsNavigation,
              ),
            ),
        ];

    // The settings destination stays highlighted on the settings surface and
    // the screens reached from it (profile, notifications); every other
    // shell route (home) is its own destination. The selected index is
    // derived from the rendered destination list itself, so it survives
    // future destination reordering or additions.
    final bool onSettingsSurface =
        location == AppRoutes.settings ||
        location == AppRoutes.profile ||
        location == AppRoutes.notifications ||
        location == AppRoutes.organizations ||
        location == AppRoutes.orgAudit ||
        location == AppRoutes.acceptInvitation ||
        location == AppRoutes.platformAdmin;
    final String targetRoute = onSettingsSurface
        ? AppRoutes.settings
        : AppRoutes.home;
    final int index = destinations.indexWhere(
      ((String, NavigationDestination) destination) =>
          destination.$1 == targetRoute,
    );
    // A route whose destination is not rendered (only possible when a
    // destination is hidden by capability) falls back to the first rendered
    // destination; with fewer than two destinations the bar is hidden below.
    final int safeIndex = index == -1 ? 0 : index;

    // Material 3's NavigationBar requires at least two destinations; a role
    // with fewer visible destinations gets no bottom bar at all rather than
    // a framework assertion. All current roles render both, so this is a
    // graceful-degradation guard for capability combinations that do not
    // exist yet.
    return Scaffold(
      // Responsive content shell: every screen nested under the ShellRoute
      // (home, matters, documents, messaging, orgs, admin, settings, …) has
      // its body centered and capped at 840px on medium/expanded widths
      // instead of stretching full-bleed. On compact widths the constraint
      // is a no-op, so phone layouts are unchanged. The bottom nav stays
      // full-width.
      body: ResponsiveContent(child: child),
      bottomNavigationBar: destinations.length < 2
          ? null
          : NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (int value) =>
                  context.go(destinations[value].$1),
              destinations: <Widget>[
                for (final (String, NavigationDestination) destination
                    in destinations)
                  destination.$2,
              ],
            ),
    );
  }
}
