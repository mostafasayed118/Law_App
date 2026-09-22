part of 'router.dart';

/// The authenticated shell's nested routes. Split out of
/// [createAppRouter] so the router file stays under the readability
/// line; the closure inputs travel as explicit parameters — identical
/// semantics to the previous inline literal.
List<RouteBase> _shellRoutes(
  AuthCubit authCubit,
  Map<UserRole, RoleCapability> capabilitiesForRole,
) {
  return <RouteBase>[
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
      builder: (BuildContext context, GoRouterState state) {
        // F-01 step 2 client swap: the create entry is a UX-only partner
        // gate (the shell's capability pattern); the `create_matter` RPC
        // re-asserts F2-D1 server-side, so a non-partner caller reaching
        // the create screen gets the typed denial, never empty success.
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        return MatterListScreen(canCreateMatter: role == UserRole.partner);
      },
    ),
    GoRoute(
      path: AppRoutes.matterCreate,
      builder: (BuildContext context, GoRouterState state) =>
          const MatterCreateScreen(),
    ),
    GoRoute(
      path: AppRoutes.matterDetails,
      builder: (BuildContext context, GoRouterState state) {
        // UX-only projection of the active membership's role (mirrors
        // the shell); the workspace sections are navigation hints, never
        // authorization grants (D-W5).
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        return MatterDetailsScreen(
          matterId: state.pathParameters['matterId'] ?? '',
          capabilities: capabilitiesForRole[role]!,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.vault,
      builder: (BuildContext context, GoRouterState state) {
        // UX-only projection of the active membership's role (mirrors
        // the shell); the reverse cross-link chip is a navigation hint,
        // never an authorization grant (D-C4).
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        return DocumentListScreen(capabilities: capabilitiesForRole[role]!);
      },
    ),
    GoRoute(
      path: AppRoutes.messages,
      builder: (BuildContext context, GoRouterState state) {
        // UX-only projection of the active membership's role (mirrors
        // the shell); the reverse cross-link chip is a navigation hint,
        // never an authorization grant (D-C4).
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        return MessageListScreen(capabilities: capabilitiesForRole[role]!);
      },
    ),
    GoRoute(
      path: AppRoutes.messageThreadDetail,
      builder: (BuildContext context, GoRouterState state) {
        // The read-only thread-detail surface (D-RT5). The tapped row's
        // title travels as the route `extra` (Q3 — the title is already
        // client-side); a deep link without it falls back to the
        // localized generic title.
        final Object? extra = state.extra;
        return MessageThreadDetailScreen(
          threadId: state.pathParameters['threadId'] ?? '',
          threadTitle: extra is String ? extra : null,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.search,
      builder: (BuildContext context, GoRouterState state) {
        // UX-only projection of the active membership's role (mirrors
        // the shell); group visibility is a navigation hint, never an
        // authorization grant (D-S2/D-W5).
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        return SearchScreen(
          initialQuery: state.uri.queryParameters['q'] ?? '',
          capabilities: capabilitiesForRole[role]!,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.invoices,
      builder: (BuildContext context, GoRouterState state) =>
          const BillingInvoicesScreen(),
    ),
    GoRoute(
      path: AppRoutes.alerts,
      builder: (BuildContext context, GoRouterState state) =>
          const ComplianceAlertsScreen(),
    ),
    GoRoute(
      path: AppRoutes.tasks,
      builder: (BuildContext context, GoRouterState state) =>
          const TaskBoardScreen(),
    ),
    GoRoute(
      path: AppRoutes.approvals,
      builder: (BuildContext context, GoRouterState state) =>
          const ApprovalsScreen(),
    ),
    GoRoute(
      path: AppRoutes.research,
      builder: (BuildContext context, GoRouterState state) {
        // AI research slice (D-R1): UX-only projection of the active
        // membership's role (mirrors the shell); the entry is a
        // navigation hint for the legal-facing roles, never an
        // authorization grant — the surface itself is client-side
        // synthetic (D-1).
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        return AiResearchScreen(capabilities: capabilitiesForRole[role]!);
      },
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (BuildContext context, GoRouterState state) =>
          const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.organizations,
      builder: (BuildContext context, GoRouterState state) {
        // UX-only projection of the active membership's role (mirrors
        // the shell); the hub's partner "Audit trail" entry is a
        // navigation hint, never an authorization grant (the
        // read_org_audit RPC gates server-side).
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        return OrganizationHubScreen(capabilities: capabilitiesForRole[role]!);
      },
    ),
    GoRoute(
      path: AppRoutes.orgAudit,
      builder: (BuildContext context, GoRouterState state) {
        // UX-only projection of the active membership's role (mirrors
        // the shell); the audit surface renders the server's typed
        // denial for non-partners — never empty success (AC-7).
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        return OrgAuditScreen(capabilities: capabilitiesForRole[role]!);
      },
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
    GoRoute(
      path: AppRoutes.notificationsFeed,
      builder: (BuildContext context, GoRouterState state) =>
          const NotificationFeedScreen(),
    ),
    GoRoute(
      path: AppRoutes.platformAdmin,
      builder: (BuildContext context, GoRouterState state) =>
          const PlatformAdminScreen(),
    ),
  ];
}
