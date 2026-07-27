import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/roles/user_role.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/settings_screen.dart';
import '../features/onboarding/presentation/access_screen.dart';
import '../l10n/app_localizations.dart';

class AppRoutes {
  AppRoutes._();

  static const String access = '/access';
  static const String home = '/home';
  static const String settings = '/settings';
}

/// Routes are navigation UX only. They do not authorize access to any future
/// organization, matter, document, or other server-side resource.
GoRouter createAppRouter(AuthCubit authCubit) => GoRouter(
  initialLocation: AppRoutes.access,
  refreshListenable: GoRouterRefreshStream(authCubit.stream),
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.access,
      builder: (BuildContext context, GoRouterState state) =>
          const AccessScreen(),
    ),
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) =>
          _AppShell(authCubit: authCubit, child: child),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsScreen(),
        ),
      ],
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final bool authenticated = authCubit.state.isAuthenticated;
    final bool onAccess = state.uri.path == AppRoutes.access;
    if (!authenticated && !onAccess) {
      return AppRoutes.access;
    }
    if (authenticated && onAccess) {
      return AppRoutes.home;
    }
    return null;
  },
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<Object?> stream) {
    _subscription = stream.listen((Object? _) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.authCubit, required this.child});

  final AuthCubit authCubit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    final int index = location == AppRoutes.settings ? 1 : 0;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final UserRole role = authCubit.state.session?.role ?? UserRole.client;
    final RoleCapability capabilities = roleCapabilities[role]!;
    final List<NavigationDestination> destinations = <NavigationDestination>[
      if (capabilities.canViewHome)
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: l10n.homeNavigation,
        ),
      if (capabilities.canViewSettings)
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: l10n.settingsNavigation,
        ),
    ];
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (int value) =>
            context.go(value == 0 ? AppRoutes.home : AppRoutes.settings),
        destinations: destinations,
      ),
    );
  }
}
