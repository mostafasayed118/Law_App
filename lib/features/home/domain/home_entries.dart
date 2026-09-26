import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/roles/user_role.dart';
import '../../../l10n/app_localizations.dart';

/// A data descriptor for one home-dashboard entry.
///
/// The dashboard used to import twelve feature `*_entry_card.dart`
/// presentation widgets directly, so any entry-card API change broke Home
/// (audit: cross-feature `presentation → presentation` coupling). Entries
/// are now data: [icon] + localized copy + [route] + a capability gate.
/// The builder renders the shared `AppEntryCard` from these descriptors, so
/// `home_screen.dart` depends on no feature presentation library — only on
/// this domain file, the router, and shared widgets.
///
/// The twelve thin `*EntryCard` widget classes stay in their features as
/// compatibility wrappers (existing tests construct them by type); they
/// render the identical `AppEntryCard` with the identical parameters below,
/// so both paths are visually byte-identical.
class HomeEntry {
  const HomeEntry({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.isVisible,
  });

  /// Stable id for tests and analytics (e.g. `'matters'`).
  final String id;

  /// Leading bubble icon (mirrors the feature wrapper's icon exactly).
  final IconData icon;

  /// Localized title/subtitle getters (mirror the wrapper's l10n keys).
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) subtitle;

  /// Forward-navigation route (the builder always `push`es — E2E BUG-1).
  final String route;

  /// Capability gate (navigation hint only, never authorization).
  final bool Function(RoleCapability capabilities) isVisible;
}

/// The dashboard entries in render order, with their capability gates.
///
/// Order, icons, copy keys, routes, and gates mirror the pre-extraction
/// `_homeEntryCards` exactly: booking (+ video riding the booking gate per
/// D-15/A-2), discovery, matters, documents, messages, invoices (riding the
/// documents gate per D-BI5), notifications, alerts, tasks, approvals,
/// research (D-R1 legal-facing roles only).
List<HomeEntry> homeEntriesFor(RoleCapability capabilities) {
  const List<HomeEntry> all = <HomeEntry>[
    HomeEntry(
      id: 'booking',
      icon: Icons.event_available_outlined,
      title: _bookingTitle,
      subtitle: _bookingSubtitle,
      route: AppRoutes.book,
      isVisible: _canBook,
    ),
    HomeEntry(
      id: 'video',
      icon: Icons.video_call_outlined,
      title: _videoTitle,
      subtitle: _videoSubtitle,
      route: AppRoutes.video,
      isVisible: _canBook,
    ),
    HomeEntry(
      id: 'discovery',
      icon: Icons.person_search_outlined,
      title: _discoveryTitle,
      subtitle: _discoverySubtitle,
      route: AppRoutes.discovery,
      isVisible: _canDiscover,
    ),
    HomeEntry(
      id: 'matters',
      icon: Icons.folder_copy_outlined,
      title: _mattersTitle,
      subtitle: _mattersSubtitle,
      route: AppRoutes.matters,
      isVisible: _canViewMatters,
    ),
    HomeEntry(
      id: 'documents',
      icon: Icons.description_outlined,
      title: _vaultTitle,
      subtitle: _vaultSubtitle,
      route: AppRoutes.vault,
      isVisible: _canViewDocuments,
    ),
    HomeEntry(
      id: 'messages',
      icon: Icons.forum_outlined,
      title: _messagesTitle,
      subtitle: _messagesSubtitle,
      route: AppRoutes.messages,
      isVisible: _canViewMessages,
    ),
    HomeEntry(
      id: 'invoices',
      icon: Icons.request_quote_outlined,
      title: _invoicesTitle,
      subtitle: _invoicesSubtitle,
      route: AppRoutes.invoices,
      isVisible: _canViewDocuments,
    ),
    HomeEntry(
      id: 'notifications',
      icon: Icons.notifications_none_outlined,
      title: _notificationsTitle,
      subtitle: _notificationsSubtitle,
      route: AppRoutes.notificationsFeed,
      isVisible: _canViewNotifications,
    ),
    HomeEntry(
      id: 'alerts',
      icon: Icons.shield_outlined,
      title: _alertsTitle,
      subtitle: _alertsSubtitle,
      route: AppRoutes.alerts,
      isVisible: _canViewAlerts,
    ),
    HomeEntry(
      id: 'tasks',
      icon: Icons.checklist_outlined,
      title: _tasksTitle,
      subtitle: _tasksSubtitle,
      route: AppRoutes.tasks,
      isVisible: _canViewTasks,
    ),
    HomeEntry(
      id: 'approvals',
      icon: Icons.approval_outlined,
      title: _approvalsTitle,
      subtitle: _approvalsSubtitle,
      route: AppRoutes.approvals,
      isVisible: _canViewApprovals,
    ),
    HomeEntry(
      id: 'research',
      icon: Icons.auto_awesome_outlined,
      title: _researchTitle,
      subtitle: _researchSubtitle,
      route: AppRoutes.research,
      isVisible: _canUseAiResearch,
    ),
  ];
  return all.where((HomeEntry e) => e.isVisible(capabilities)).toList();
}

bool _canBook(RoleCapability c) => c.canBookConsultation;
bool _canDiscover(RoleCapability c) => c.canViewAttorneyDiscovery;
bool _canViewMatters(RoleCapability c) => c.canViewMatters;
bool _canViewDocuments(RoleCapability c) => c.canViewDocuments;
bool _canViewMessages(RoleCapability c) => c.canViewMessages;
bool _canViewNotifications(RoleCapability c) => c.canViewNotifications;
bool _canViewAlerts(RoleCapability c) => c.canViewAlerts;
bool _canViewTasks(RoleCapability c) => c.canViewTasks;
bool _canViewApprovals(RoleCapability c) => c.canViewApprovals;
bool _canUseAiResearch(RoleCapability c) => c.canUseAiResearch;

String _bookingTitle(AppLocalizations l10n) => l10n.bookingEntryTitle;
String _bookingSubtitle(AppLocalizations l10n) => l10n.bookingEntrySubtitle;
String _videoTitle(AppLocalizations l10n) => l10n.videoEntryTitle;
String _videoSubtitle(AppLocalizations l10n) => l10n.videoEntrySubtitle;
String _discoveryTitle(AppLocalizations l10n) => l10n.discoveryEntryTitle;
String _discoverySubtitle(AppLocalizations l10n) => l10n.discoveryEntrySubtitle;
String _mattersTitle(AppLocalizations l10n) => l10n.matterEntryTitle;
String _mattersSubtitle(AppLocalizations l10n) => l10n.matterEntrySubtitle;
String _vaultTitle(AppLocalizations l10n) => l10n.vaultEntryTitle;
String _vaultSubtitle(AppLocalizations l10n) => l10n.vaultEntrySubtitle;
String _messagesTitle(AppLocalizations l10n) => l10n.messagesEntryTitle;
String _messagesSubtitle(AppLocalizations l10n) => l10n.messagesEntrySubtitle;
String _invoicesTitle(AppLocalizations l10n) => l10n.invoicesEntryTitle;
String _invoicesSubtitle(AppLocalizations l10n) => l10n.invoicesEntrySubtitle;
String _notificationsTitle(AppLocalizations l10n) =>
    l10n.notificationsFeedEntryTitle;
String _notificationsSubtitle(AppLocalizations l10n) =>
    l10n.notificationsFeedEntrySubtitle;
String _alertsTitle(AppLocalizations l10n) => l10n.alertsEntryTitle;
String _alertsSubtitle(AppLocalizations l10n) => l10n.alertsEntrySubtitle;
String _tasksTitle(AppLocalizations l10n) => l10n.tasksEntryTitle;
String _tasksSubtitle(AppLocalizations l10n) => l10n.tasksEntrySubtitle;
String _approvalsTitle(AppLocalizations l10n) => l10n.approvalsEntryTitle;
String _approvalsSubtitle(AppLocalizations l10n) => l10n.approvalsEntrySubtitle;
String _researchTitle(AppLocalizations l10n) => l10n.aiResearchEntryTitle;
String _researchSubtitle(AppLocalizations l10n) => l10n.aiResearchEntrySubtitle;
