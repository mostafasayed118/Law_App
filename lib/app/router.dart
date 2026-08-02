import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/roles/user_role.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/forgot_password/forgot_password_email_screen.dart';
import '../features/auth/presentation/forgot_password/forgot_password_otp_screen.dart';
import '../features/auth/presentation/forgot_password/forgot_password_reset_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/settings_screen.dart';
import '../features/notifications/presentation/notification_settings_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/presentation/onboarding_success_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../l10n/app_localizations.dart';

class AppRoutes {
  AppRoutes._();

  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String forgotPasswordOtp = '/forgot-password/otp';
  static const String forgotPasswordReset = '/forgot-password/reset';
  static const String onboarding = '/onboarding';
  static const String onboardingSuccess = '/onboarding/success';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
}

/// Routes are navigation UX only. They do not authorize access to any future
/// organization, matter, document, or other server-side resource.
GoRouter createAppRouter(AuthCubit authCubit) => GoRouter(
  initialLocation: AppRoutes.signIn,
  refreshListenable: GoRouterRefreshStream(authCubit.stream),
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.signIn,
      builder: (BuildContext context, GoRouterState state) =>
          const SignInScreen(),
    ),
    GoRoute(
      path: AppRoutes.signUp,
      builder: (BuildContext context, GoRouterState state) =>
          const SignUpScreen(),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (BuildContext context, GoRouterState state) =>
          const ForgotPasswordEmailScreen(),
    ),
    GoRoute(
      path: AppRoutes.forgotPasswordOtp,
      builder: (BuildContext context, GoRouterState state) =>
          const ForgotPasswordOtpScreen(),
    ),
    GoRoute(
      path: AppRoutes.forgotPasswordReset,
      builder: (BuildContext context, GoRouterState state) =>
          const ForgotPasswordResetScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (BuildContext context, GoRouterState state) =>
          const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboardingSuccess,
      builder: (BuildContext context, GoRouterState state) =>
          const OnboardingSuccessScreen(),
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
        GoRoute(
          path: AppRoutes.profile,
          builder: (BuildContext context, GoRouterState state) =>
              const ProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.notifications,
          builder: (BuildContext context, GoRouterState state) =>
              const NotificationSettingsScreen(),
        ),
      ],
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final bool authenticated = authCubit.state.isAuthenticated;
    final String path = state.uri.path;
    final bool onAuthRoute =
        path == AppRoutes.signIn ||
        path == AppRoutes.signUp ||
        path == AppRoutes.forgotPassword ||
        path == AppRoutes.forgotPasswordOtp ||
        path == AppRoutes.forgotPasswordReset;
    final bool onOnboarding =
        path == AppRoutes.onboarding || path == AppRoutes.onboardingSuccess;
    if (!authenticated && !onAuthRoute && !onOnboarding) {
      return AppRoutes.signIn;
    }
    if (authenticated && onAuthRoute) {
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
    // The settings destination stays highlighted on the settings surface and
    // the screens reached from it (profile, notifications); every other
    // shell route (home) is destination 0.
    final bool onSettingsSurface =
        location == AppRoutes.settings ||
        location == AppRoutes.profile ||
        location == AppRoutes.notifications;
    final int index = onSettingsSurface ? 1 : 0;
    final AppLocalizations l10n = AppLocalizations.of(context);
    // UX-only projection from the active membership's org-scoped role. The
    // session itself carries no client-owned role (contract §5); this is a
    // navigation hint, never an authorization grant.
    final UserRole role =
        authCubit.state.session?.primaryRole ?? UserRole.client;
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
