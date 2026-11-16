part of 'router.dart';

/// UX-only role projection for the selected organization (the org switcher's
/// client-side context), falling back to the session's first active
/// membership for tests and pre-selection states, then to the least-privilege
/// client role. Never an authorization grant — the server re-derives the
/// role per request.
UserRole _projectedRole(AuthCubit authCubit) {
  final Session? session = authCubit.state.session;
  return session
          ?.membershipForOrganization(
            serviceLocator<ActiveOrgStore>().activeOrganizationId,
          )
          ?.role ??
      session?.primaryRole ??
      UserRole.client;
}

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
          AttorneySearchScreen(
            // The home dashboard's practice-area cards deep-link in with the
            // area preselected (`?area=…`); an absent/unknown value opens
            // the plain "All" surface (never an error).
            initialPracticeArea: AppRoutes.practiceAreaFromQuery(
              state.uri.queryParameters['area'],
            ),
          ),
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
        final UserRole role = _projectedRole(authCubit);
        return MatterListScreen(
          canCreateMatter: role == UserRole.partner,
          capabilities: capabilityForRole(capabilitiesForRole, role),
        );
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
        // UX-only projection of the selected organization's active
        // membership role (mirrors the shell); the workspace sections are
        // navigation hints, never authorization grants (D-W5).
        final UserRole role = _projectedRole(authCubit);
        final RoleCapability capabilities = capabilityForRole(
          capabilitiesForRole,
          role,
        );
        final String matterId = state.pathParameters['matterId'] ?? '';
        // Expanded windows render the list + this matter side by side; a
        // deep link keeps the URL and gains the master list.
        if (MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded) {
          return MatterListScreen(
            canCreateMatter: role == UserRole.partner,
            capabilities: capabilities,
            initialSelectedMatterId: matterId,
          );
        }
        return MatterDetailsScreen(
          matterId: matterId,
          capabilities: capabilities,
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
        return DocumentListScreen(
          capabilities: capabilityForRole(capabilitiesForRole, role),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.documentDetails,
      builder: (BuildContext context, GoRouterState state) {
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        final RoleCapability capabilities = capabilityForRole(
          capabilitiesForRole,
          role,
        );
        final String documentId = state.pathParameters['documentId'] ?? '';
        // Expanded windows render the vault list + this document side by
        // side; a deep link keeps the URL and gains the master list.
        if (MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded) {
          return DocumentListScreen(
            capabilities: capabilities,
            initialSelectedDocumentId: documentId,
          );
        }
        return DocumentDetailsScreen(
          documentId: documentId,
          capabilities: capabilities,
        );
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
        return MessageListScreen(
          capabilities: capabilityForRole(capabilitiesForRole, role),
        );
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
        final String threadId = state.pathParameters['threadId'] ?? '';
        // Expanded windows render the thread list + this transcript side by
        // side; a deep link keeps the URL and gains the master list.
        if (MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded) {
          final UserRole role =
              authCubit.state.session?.primaryRole ?? UserRole.client;
          return MessageListScreen(
            capabilities: capabilityForRole(capabilitiesForRole, role),
            initialSelectedThreadId: threadId,
            initialSelectedThreadTitle: extra is String ? extra : null,
          );
        }
        return MessageThreadDetailScreen(
          threadId: threadId,
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
          capabilities: capabilityForRole(capabilitiesForRole, role),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.invoices,
      builder: (BuildContext context, GoRouterState state) =>
          const BillingInvoicesScreen(),
    ),
    GoRoute(
      path: AppRoutes.invoiceDetails,
      builder: (BuildContext context, GoRouterState state) {
        final String invoiceId = state.pathParameters['invoiceId'] ?? '';
        // Expanded windows render the invoices list + this invoice side by
        // side; a deep link keeps the URL and gains the master list.
        if (MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded) {
          return BillingInvoicesScreen(initialSelectedInvoiceId: invoiceId);
        }
        return InvoiceDetailsScreen(invoiceId: invoiceId);
      },
    ),
    GoRoute(
      path: AppRoutes.alerts,
      builder: (BuildContext context, GoRouterState state) {
        // UX-only projection from the active membership: create/resolve
        // authority is the partner or compliance-officer role;
        // acknowledgement is offered to every member. The RPCs re-assert
        // every gate server-side.
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        return ComplianceAlertsScreen(
          canManage:
              role == UserRole.partner || role == UserRole.complianceOfficer,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.tasks,
      builder: (BuildContext context, GoRouterState state) =>
          const TaskBoardScreen(),
    ),
    GoRoute(
      path: AppRoutes.video,
      builder: (BuildContext context, GoRouterState state) {
        // UX-only projections from the active membership: scheduling is
        // offered to partners and attorneys, ending to the session's creator
        // or a partner. The create/end RPCs re-assert every gate server-side,
        // so these flags are navigation hints, never authorization grants.
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        return VideoConsultationScreen(
          canCreate: role == UserRole.partner || role == UserRole.attorney,
          canEndAny: role == UserRole.partner,
          currentUserId: authCubit.state.session?.userId,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.approvals,
      builder: (BuildContext context, GoRouterState state) {
        // UX-only projections from the active membership: decision authority
        // is the partner role, and cancel is offered to the requester. The
        // decide/cancel RPCs re-assert both gates server-side.
        final UserRole role =
            authCubit.state.session?.primaryRole ?? UserRole.client;
        return ApprovalsScreen(
          canDecide: role == UserRole.partner,
          currentUserId: authCubit.state.session?.userId,
        );
      },
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
        return AiResearchScreen(
          capabilities: capabilityForRole(capabilitiesForRole, role),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.library,
      builder: (BuildContext context, GoRouterState state) =>
          const LibraryHomeScreen(),
    ),
    // Declared before /library/:documentId so the literal segment wins the
    // match: go_router resolves in declaration order.
    GoRoute(
      path: AppRoutes.librarySaved,
      builder: (BuildContext context, GoRouterState state) =>
          const LibrarySavedScreen(),
    ),
    GoRoute(
      path: AppRoutes.librarySearch,
      builder: (BuildContext context, GoRouterState state) =>
          LibrarySearchScreen(
            initialQuery: state.uri.queryParameters['q'] ?? '',
          ),
    ),
    GoRoute(
      path: AppRoutes.libraryDocument,
      builder: (BuildContext context, GoRouterState state) {
        final String documentId = state.pathParameters['documentId'] ?? '';
        // Expanded windows render the list + this document side by side; a deep
        // link keeps the URL and gains the master list.
        if (MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded) {
          return LibraryHomeScreen(initialSelectedDocumentId: documentId);
        }
        return LibraryDocumentScreen(documentId: documentId);
      },
    ),
    GoRoute(
      path: AppRoutes.libraryArticle,
      builder: (BuildContext context, GoRouterState state) =>
          LibraryArticleScreen(
            articleId: state.pathParameters['articleId'] ?? '',
          ),
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
        return OrganizationHubScreen(
          capabilities: capabilityForRole(capabilitiesForRole, role),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.orgAudit,
      builder: (BuildContext context, GoRouterState state) {
        // UX-only projection of the active membership's role (mirrors
        // the shell); the audit surface renders the server's typed
        // denial for non-partners — never empty success (AC-7).
        return const OrgAuditScreen();
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
    GoRoute(
      // The directory admin rides the authenticated shell and the same
      // platform-admin surface: the owner-only RPCs gate server-side, so a
      // non-owner sees the typed unauthorized arm (never empty success).
      path: AppRoutes.attorneysAdmin,
      builder: (BuildContext context, GoRouterState state) =>
          const AttorneyAdminScreen(),
    ),
  ];
}
