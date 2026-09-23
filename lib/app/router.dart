import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/practice_area.dart';
import '../core/roles/user_role.dart';
import '../features/admin/presentation/platform_admin_screen.dart';
import '../features/approvals/presentation/approvals_screen.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/forgot_password/forgot_password_email_screen.dart';
import '../features/auth/presentation/forgot_password/forgot_password_otp_screen.dart';
import '../features/auth/presentation/forgot_password/forgot_password_reset_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/billing/presentation/billing_invoices_screen.dart';
import '../features/booking/presentation/booking_screen.dart';
import '../features/compliance/presentation/compliance_alerts_screen.dart';
import '../features/discovery/presentation/attorney_profile_screen.dart';
import '../features/discovery/presentation/attorney_search_screen.dart';
import '../features/documents/presentation/document_list_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/settings_screen.dart';
import '../features/matters/presentation/matter_create_screen.dart';
import '../features/matters/presentation/matter_details_screen.dart';
import '../features/matters/presentation/matter_list_screen.dart';
import '../features/messaging/presentation/message_list_screen.dart';
import '../features/messaging/presentation/message_thread_detail_screen.dart';
import '../features/notifications/presentation/notification_feed_screen.dart';
import '../features/notifications/presentation/notification_settings_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/presentation/onboarding_success_screen.dart';
import '../features/orgs/presentation/accept_invitation_screen.dart';
import '../features/orgs/presentation/org_audit_screen.dart';
import '../features/orgs/presentation/organization_hub_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/research/presentation/ai_research_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/tasks/presentation/task_board_screen.dart';
import '../features/video/presentation/video_consultation_screen.dart';
import '../l10n/app_localizations.dart';
import '../shared/responsive/responsive.dart';
part 'router_shell_routes.dart';
part 'router_app_shell.dart';
part 'router_refresh_stream.dart';

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
  static const String orgAudit = '/organizations/audit';
  static const String acceptInvitation = '/accept-invitation';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String notificationsFeed = '/notifications/feed';
  static const String platformAdmin = '/platform-admin';
  static const String book = '/book';
  static const String discovery = '/discovery';
  static const String discoveryProfile = '/discovery/:attorneyId';
  static const String matters = '/matters';
  static const String matterCreate = '/matters/new';
  static const String matterDetails = '/matters/:matterId';
  static const String vault = '/vault';
  static const String messages = '/messages';
  static const String messageThreadDetail = '/messages/:threadId';
  static const String invoices = '/invoices';
  static const String alerts = '/alerts';
  static const String tasks = '/tasks';
  static const String approvals = '/approvals';
  static const String research = '/research';
  static const String search = '/search';
  static const String video = '/video';

  /// The profile route for one attorney (path-param substitution).
  static String attorneyProfile(String attorneyId) => '/discovery/$attorneyId';

  /// The details route for one matter (path-param substitution).
  static String matterDetail(String matterId) => '/matters/$matterId';

  /// The read-only thread-detail route for one thread (path-param
  /// substitution; the tapped row's title travels as the route `extra` —
  /// D-RT5/Q3, the title is already client-side so no embed is needed).
  static String messageThreadDetailFor(String threadId) =>
      '/messages/$threadId';

  /// The search route with its `q` query param (URL-encoded; `?q=` never
  /// carries real data — local-only demo queries, D-S5).
  static String searchQuery(String query) =>
      '$search?q=${Uri.encodeQueryComponent(query)}';

  /// The discovery route pre-narrowed to one practice area (the home
  /// dashboard's practice-area cards, the D-S4 wiring). The enum name
  /// travels as the query value (English token, URL-encoded); an unknown
  /// value degrades to the plain "All" surface — never a crash.
  static String discoveryArea(PracticeArea area) =>
      '$discovery?area=${Uri.encodeQueryComponent(area.name)}';

  /// Parses the `?area=` query value back to a [PracticeArea], or null for
  /// an absent/unknown value (the plain surface, never an error).
  static PracticeArea? practiceAreaFromQuery(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final PracticeArea area in PracticeArea.values) {
      if (area.name == raw) {
        return area;
      }
    }
    return null;
  }
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
      routes: _shellRoutes(authCubit, capabilitiesForRole),
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
