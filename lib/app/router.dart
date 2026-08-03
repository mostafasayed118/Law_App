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
import '../features/booking/presentation/booking_screen.dart';
import '../features/discovery/presentation/attorney_profile_screen.dart';
import '../features/discovery/presentation/attorney_search_screen.dart';
import '../features/documents/presentation/document_list_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/settings_screen.dart';
import '../features/matters/presentation/matter_details_screen.dart';
import '../features/matters/presentation/matter_list_screen.dart';
import '../features/notifications/presentation/notification_settings_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/presentation/onboarding_success_screen.dart';
import '../features/orgs/presentation/accept_invitation_screen.dart';
import '../features/orgs/presentation/organization_hub_screen.dart';
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
  static const String organizations = '/organizations';
  static const String acceptInvitation = '/accept-invitation';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String book = '/book';
  static const String discovery = '/discovery';
  static const String discoveryProfile = '/discovery/:attorneyId';
  static const String matters = '/matters';
  static const String matterDetails = '/matters/:matterId';
  static const String vault = '/vault';

  /// The profile route for one attorney (path-param substitution).
  static String attorneyProfile(String attorneyId) => '/discovery/$attorneyId';

  /// The details route for one matter (path-param substitution).
  static String matterDetail(String matterId) => '/matters/$matterId';
}

/// Routes are navigation UX only. They do not authorize access to any future
/// organization, matter, document, or other server-side resource.
///
/// [capabilitiesForRole] is a test seam mirroring `configureDependencies`:
/// production always uses [roleCapabilities], tests may inject a map with a
/// restricted role (e.g. a role without `canViewSettings`) to pin the shell
/// behavior for every capability combination.
GoRouter createAppRouter(
  AuthCubit authCubit, {
  Map<UserRole, RoleCapability> capabilitiesForRole = roleCapabilities,
}) => GoRouter(
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
          _AppShell(
            authCubit: authCubit,
            capabilitiesForRole: capabilitiesForRole,
            child: child,
          ),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          builder: (BuildContext context, GoRouterState state) =>
              HomeScreen(capabilitiesForRole: capabilitiesForRole),
        ),
        GoRoute(
          path: AppRoutes.book,
          builder: (BuildContext context, GoRouterState state) =>
              const BookingScreen(),
        ),
        GoRoute(
          path: AppRoutes.discovery,
          builder: (BuildContext context, GoRouterState state) =>
              const AttorneySearchScreen(),
        ),
        GoRoute(
          path: AppRoutes.discoveryProfile,
          builder: (BuildContext context, GoRouterState state) =>
              AttorneyProfileScreen(
                attorneyId: state.pathParameters['attorneyId'] ?? '',
              ),
        ),
        GoRoute(
          path: AppRoutes.matters,
          builder: (BuildContext context, GoRouterState state) =>
              const MatterListScreen(),
        ),
        GoRoute(
          path: AppRoutes.matterDetails,
          builder: (BuildContext context, GoRouterState state) =>
              MatterDetailsScreen(
                matterId: state.pathParameters['matterId'] ?? '',
              ),
        ),
        GoRoute(
          path: AppRoutes.vault,
          builder: (BuildContext context, GoRouterState state) =>
              const DocumentListScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.organizations,
          builder: (BuildContext context, GoRouterState state) =>
              const OrganizationHubScreen(),
        ),
        GoRoute(
          path: AppRoutes.acceptInvitation,
          builder: (BuildContext context, GoRouterState state) =>
              const AcceptInvitationScreen(),
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
    // Phase 4.1 deep-link recovery: a recovery session (PKCE exchange of a
    // recovery link, or a pending recovery restored from storage) must land
    // on the reset step — never home, and it must not be bounced away from
    // the reset step while the recovery is pending. The flag clears on
    // sign-out, which the reset flow performs after updating the password.
    if (authenticated && authCubit.recoveryPending) {
      if (path != AppRoutes.forgotPasswordReset) {
        return AppRoutes.forgotPasswordReset;
      }
      return null;
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
        location == AppRoutes.acceptInvitation;
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
      body: child,
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
