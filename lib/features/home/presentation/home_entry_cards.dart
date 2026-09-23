part of 'home_screen.dart';

/// The capability-gated dashboard entry cards, returned as one flat list
/// so the sliver delegate keeps receiving the same eagerly-built literal
/// it did before the readability split.
List<Widget> _homeEntryCards(
  BuildContext context,
  RoleCapability capabilities,
) {
  return <Widget>[
    if (capabilities.canBookConsultation) ...[
      const SizedBox(height: LegalHubTheme.spaceLg),
      BookingEntryCard(onTap: () => context.go(AppRoutes.book)),
      // Spec D-15 demo-posture: the video entry rides the booking gate
      // (A-2: "book" → "join call" — the same audience, no new role flag).
      // Visibility hint only; the demo surface has no backend to authorize.
      const SizedBox(height: LegalHubTheme.spaceMd),
      VideoEntryCard(onTap: () => context.go(AppRoutes.video)),
    ],
    if (capabilities.canViewAttorneyDiscovery) ...[
      const SizedBox(height: LegalHubTheme.spaceMd),
      DiscoveryEntryCard(onTap: () => context.go(AppRoutes.discovery)),
    ],
    if (capabilities.canViewMatters) ...[
      const SizedBox(height: LegalHubTheme.spaceMd),
      MatterEntryCard(onTap: () => context.go(AppRoutes.matters)),
    ],
    if (capabilities.canViewDocuments) ...[
      const SizedBox(height: LegalHubTheme.spaceMd),
      DocumentEntryCard(onTap: () => context.go(AppRoutes.vault)),
    ],
    if (capabilities.canViewMessages) ...[
      const SizedBox(height: LegalHubTheme.spaceMd),
      MessageEntryCard(onTap: () => context.go(AppRoutes.messages)),
    ],
    // Billing slice (D-BI5): the standalone invoices list rides
    // the same canViewDocuments gate as the per-matter invoices
    // section — no new role flag (matrix §4: invoices are
    // matter-scoped content with client/attorney SHIP, same as
    // documents). Visibility hint only; the RLS gate is
    // server-side.
    if (capabilities.canViewDocuments) ...[
      const SizedBox(height: LegalHubTheme.spaceMd),
      BillingInvoicesEntryCard(onTap: () => context.go(AppRoutes.invoices)),
    ],
    // Notification-feed slice (D-N1): the org-scoped feed
    // rides its own nav-hint flag, true for every role (matrix
    // §4 member SHIP — the organizations gate admits any
    // active member; no role hierarchy in the feed).
    // Visibility hint only; the RLS gate is server-side and
    // `platform_owner_admin` is denied always (D-P0C1(a)).
    if (capabilities.canViewNotifications) ...[
      const SizedBox(height: LegalHubTheme.spaceMd),
      NotificationFeedEntryCard(
        onTap: () => context.go(AppRoutes.notificationsFeed),
      ),
    ],
    // v1 queue (2026-08-09 scope drafts): the three read-only
    // demo surfaces ride their own nav-hint flags; visibility
    // hints only, never authorization (pages render demo
    // data; the server/authority does not exist yet).
    if (capabilities.canViewAlerts) ...[
      const SizedBox(height: LegalHubTheme.spaceMd),
      ComplianceAlertsEntryCard(onTap: () => context.go(AppRoutes.alerts)),
    ],
    if (capabilities.canViewTasks) ...[
      const SizedBox(height: LegalHubTheme.spaceMd),
      TaskBoardEntryCard(onTap: () => context.go(AppRoutes.tasks)),
    ],
    if (capabilities.canViewApprovals) ...[
      const SizedBox(height: LegalHubTheme.spaceMd),
      ApprovalsEntryCard(onTap: () => context.go(AppRoutes.approvals)),
    ],
    // AI research slice (plan 2026-09-02, D-R1): the
    // research-assistant entry rides its own nav-hint flag,
    // granted to the legal-facing roles only (attorney /
    // researchAnalyst / partner). Visibility hint only — the
    // surface itself is client-side synthetic (D-1).
    if (capabilities.canUseAiResearch) ...[
      const SizedBox(height: LegalHubTheme.spaceMd),
      AiResearchEntryCard(onTap: () => context.go(AppRoutes.research)),
    ],
  ];
}
