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
    final RoleCapability capabilities = capabilityForRole(
      capabilitiesForRole,
      role,
    );

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
    // the screens reached from it (profile, notifications, platform admin and
    // its nested routes); every other shell route (home) is its own
    // destination. The selected index is derived from the rendered
    // destination list itself, so it survives future destination reordering
    // or additions.
    final bool onPlatformAdminSurface =
        location == AppRoutes.platformAdmin ||
        location.startsWith('${AppRoutes.platformAdmin}/');
    final bool onSettingsSurface =
        location == AppRoutes.settings ||
        location == AppRoutes.settingsAccount ||
        location == AppRoutes.profile ||
        location == AppRoutes.notifications ||
        location == AppRoutes.organizations ||
        location == AppRoutes.orgAudit ||
        location == AppRoutes.acceptInvitation ||
        onPlatformAdminSurface;
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
    // with fewer visible destinations gets no navigation chrome at all rather
    // than a framework assertion. All current roles render both, so this is a
    // graceful-degradation guard for capability combinations that do not
    // exist yet.
    //
    // Adaptive breakpoint (Material 3 expanded, 840dp): phone and medium
    // windows keep the bottom bar; expanded desktop/landscape layouts get a
    // leading NavigationRail so the shell stops being a stretched phone. The
    // content column stays centered and capped by ResponsiveContent beside
    // the rail. Keeping medium on the bar is deliberate: the pinned shell
    // route tests exercise the bottom-bar tap targets at 800×600, and the
    // bar is a valid medium layout.
    final bool useRail =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final bool showNavigation = destinations.length >= 2;
    // Rail labels scale with the user's text size; a fixed 72px rail clips
    // "Settings" at the 2.0 accessibility ceiling (the label row overflowed
    // by 26px). Measuring at the label size (not at 1.0) also respects
    // Android's non-linear text scaler. Bounded so an extreme system scale
    // cannot eat the whole window.
    final double railTextScale =
        (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 3.0);

    void selectDestination(int value) {
      // Tab switches are stack resets (E2E BUG-1 follow-up, 2026-09-24): pop
      // pushed pages first so re-tapping the current tab returns to the tab
      // root. A bare `go` is a no-op when the base URI already matches, which
      // left the pushed page stuck on top with a dead tab beneath it. `go`
      // then replaces any remainder.
      final GoRouter router = GoRouter.of(context);
      while (router.canPop()) {
        router.pop();
      }
      context.go(destinations[value].$1);
    }

    final Widget content = ResponsiveContent(child: child);

    return Scaffold(
      // Responsive content shell: every screen nested under the ShellRoute
      // (home, matters, documents, messaging, orgs, admin, settings, …) has
      // its body centered and capped at 840px on medium/expanded widths
      // instead of stretching full-bleed. On compact widths the constraint
      // is a no-op, so phone layouts are unchanged.
      body: FocusTraversalGroup(
        // Deterministic desktop keyboard order: the rail (leading pane),
        // then the content column. Material's default is reading order too,
        // but pinning it here keeps the order stable as panes are added.
        policy: ReadingOrderTraversalPolicy(),
        child: useRail && showNavigation
            ? Row(
                children: <Widget>[
                  SafeArea(
                    child: NavigationRail(
                      selectedIndex: safeIndex,
                      onDestinationSelected: selectDestination,
                      labelType: NavigationRailLabelType.all,
                      minWidth: 72 * railTextScale,
                      destinations: <NavigationRailDestination>[
                        for (final (String, NavigationDestination) destination
                            in destinations)
                          NavigationRailDestination(
                            icon: destination.$2.icon,
                            selectedIcon: destination.$2.selectedIcon,
                            label: Text(destination.$2.label),
                          ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
      bottomNavigationBar: !showNavigation || useRail
          ? null
          : NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: selectDestination,
              destinations: <Widget>[
                for (final (String, NavigationDestination) destination
                    in destinations)
                  destination.$2,
              ],
            ),
    );
  }
}
