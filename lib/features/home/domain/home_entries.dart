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
/// This file is Flutter-free and routing-free by contract: [icon] is a
/// [HomeEntryIcon] token and [route] a [HomeEntryRoute] token (audit:
/// domain-layer Flutter import). The presentation boundary
/// (`home_entry_cards.dart`) resolves both tokens to [IconData] and route
/// strings through exhaustive switches, so adding an entry is a domain
/// token plus one arm per resolver — a missed arm is a compile error, never
/// a silent desync.
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
    this.configuredSubtitle,
  });

  /// Stable id for tests and analytics (e.g. `'matters'`).
  final String id;

  /// Leading bubble icon token (resolved to [IconData] at the presentation
  /// boundary; mirrors the feature wrapper's icon exactly).
  final HomeEntryIcon icon;

  /// Localized title/subtitle getters (mirror the wrapper's l10n keys).
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) subtitle;

  /// The subtitle to render in a configured (real-backend) build.
  ///
  /// `null` for the fake-only entries: their gateway has no Supabase
  /// implementation, so their data is synthetic in EVERY build and the demo
  /// wording of [subtitle] is truthful there — changing it would hide the
  /// truth instead of stating it.
  final String Function(AppLocalizations l10n)? configuredSubtitle;

  /// Whether this entry's data comes from a real (server-backed) gateway in a
  /// configured build — true exactly when [configuredSubtitle] is set.
  ///
  /// The flag is per entry, not a single global posture: the dashboard mixes
  /// server-backed entries with fake-only ones, so only the former can drop
  /// their demo wording in a configured build.
  bool get isServerBacked => configuredSubtitle != null;

  /// The subtitle to render for the given backend posture.
  ///
  /// [localOnly] is the app-wide posture seam (`backendIsLocalOnly`): true in
  /// the demo-posture build, false in a configured (real-backend) build. A
  /// server-backed entry reads as the real feature there; a fake-only entry
  /// keeps its demo wording, which is the truthful one in every build.
  String subtitleFor(AppLocalizations l10n, {required bool localOnly}) {
    if (!localOnly && isServerBacked) {
      // Provably non-null: [isServerBacked] is derived from it.
      return configuredSubtitle!(l10n);
    }
    return subtitle(l10n);
  }

  /// Forward-navigation route token (resolved to the `AppRoutes.*` string
  /// at the presentation boundary; the builder always `push`es — E2E BUG-1).
  final HomeEntryRoute route;

  /// Capability gate (navigation hint only, never authorization).
  final bool Function(RoleCapability capabilities) isVisible;
}

/// Presentation-boundary icon token for a [HomeEntry].
///
/// One value per dashboard entry; the resolver in `home_entry_cards.dart`
/// maps each to the `Icons.*` constant the feature wrapper uses.
enum HomeEntryIcon {
  booking,
  video,
  discovery,
  matters,
  documents,
  messages,
  invoices,
  notifications,
  alerts,
  tasks,
  approvals,
  research,
}

/// Presentation-boundary route token for a [HomeEntry].
///
/// One value per dashboard entry; the resolver in `home_entry_cards.dart`
/// maps each to its `AppRoutes.*` string. The token keeps the domain free
/// of the app router: renaming a route touches the resolver only.
enum HomeEntryRoute {
  book,
  video,
  discovery,
  matters,
  vault,
  messages,
  invoices,
  notificationsFeed,
  alerts,
  tasks,
  approvals,
  research,
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
      icon: HomeEntryIcon.booking,
      title: _bookingTitle,
      subtitle: _bookingSubtitle,
      configuredSubtitle: _bookingConfiguredSubtitle,
      route: HomeEntryRoute.book,
      isVisible: _canBook,
    ),
    HomeEntry(
      id: 'video',
      icon: HomeEntryIcon.video,
      title: _videoTitle,
      subtitle: _videoSubtitle,
      route: HomeEntryRoute.video,
      isVisible: _canBook,
    ),
    HomeEntry(
      id: 'discovery',
      icon: HomeEntryIcon.discovery,
      title: _discoveryTitle,
      subtitle: _discoverySubtitle,
      route: HomeEntryRoute.discovery,
      isVisible: _canDiscover,
    ),
    HomeEntry(
      id: 'matters',
      icon: HomeEntryIcon.matters,
      title: _mattersTitle,
      subtitle: _mattersSubtitle,
      configuredSubtitle: _mattersConfiguredSubtitle,
      route: HomeEntryRoute.matters,
      isVisible: _canViewMatters,
    ),
    HomeEntry(
      id: 'documents',
      icon: HomeEntryIcon.documents,
      title: _vaultTitle,
      subtitle: _vaultSubtitle,
      configuredSubtitle: _vaultConfiguredSubtitle,
      route: HomeEntryRoute.vault,
      isVisible: _canViewDocuments,
    ),
    HomeEntry(
      id: 'messages',
      icon: HomeEntryIcon.messages,
      title: _messagesTitle,
      subtitle: _messagesSubtitle,
      configuredSubtitle: _messagesConfiguredSubtitle,
      route: HomeEntryRoute.messages,
      isVisible: _canViewMessages,
    ),
    HomeEntry(
      id: 'invoices',
      icon: HomeEntryIcon.invoices,
      title: _invoicesTitle,
      subtitle: _invoicesSubtitle,
      configuredSubtitle: _invoicesConfiguredSubtitle,
      route: HomeEntryRoute.invoices,
      isVisible: _canViewDocuments,
    ),
    HomeEntry(
      id: 'notifications',
      icon: HomeEntryIcon.notifications,
      title: _notificationsTitle,
      subtitle: _notificationsSubtitle,
      configuredSubtitle: _notificationsConfiguredSubtitle,
      route: HomeEntryRoute.notificationsFeed,
      isVisible: _canViewNotifications,
    ),
    HomeEntry(
      id: 'alerts',
      icon: HomeEntryIcon.alerts,
      title: _alertsTitle,
      subtitle: _alertsSubtitle,
      configuredSubtitle: _alertsConfiguredSubtitle,
      route: HomeEntryRoute.alerts,
      isVisible: _canViewAlerts,
    ),
    HomeEntry(
      id: 'tasks',
      icon: HomeEntryIcon.tasks,
      title: _tasksTitle,
      subtitle: _tasksSubtitle,
      configuredSubtitle: _tasksConfiguredSubtitle,
      route: HomeEntryRoute.tasks,
      isVisible: _canViewTasks,
    ),
    HomeEntry(
      id: 'approvals',
      icon: HomeEntryIcon.approvals,
      title: _approvalsTitle,
      subtitle: _approvalsSubtitle,
      configuredSubtitle: _approvalsConfiguredSubtitle,
      route: HomeEntryRoute.approvals,
      isVisible: _canViewApprovals,
    ),
    HomeEntry(
      id: 'research',
      icon: HomeEntryIcon.research,
      title: _researchTitle,
      subtitle: _researchSubtitle,
      route: HomeEntryRoute.research,
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
String _bookingConfiguredSubtitle(AppLocalizations l10n) =>
    l10n.bookingEntrySubtitleConfigured;
String _videoTitle(AppLocalizations l10n) => l10n.videoEntryTitle;
String _videoSubtitle(AppLocalizations l10n) => l10n.videoEntrySubtitle;
String _discoveryTitle(AppLocalizations l10n) => l10n.discoveryEntryTitle;
String _discoverySubtitle(AppLocalizations l10n) => l10n.discoveryEntrySubtitle;
String _mattersTitle(AppLocalizations l10n) => l10n.matterEntryTitle;
String _mattersSubtitle(AppLocalizations l10n) => l10n.matterEntrySubtitle;
String _mattersConfiguredSubtitle(AppLocalizations l10n) =>
    l10n.matterEntrySubtitleConfigured;
String _vaultTitle(AppLocalizations l10n) => l10n.vaultEntryTitle;
String _vaultSubtitle(AppLocalizations l10n) => l10n.vaultEntrySubtitle;
String _vaultConfiguredSubtitle(AppLocalizations l10n) =>
    l10n.vaultEntrySubtitleConfigured;
String _messagesTitle(AppLocalizations l10n) => l10n.messagesEntryTitle;
String _messagesSubtitle(AppLocalizations l10n) => l10n.messagesEntrySubtitle;
String _messagesConfiguredSubtitle(AppLocalizations l10n) =>
    l10n.messagesEntrySubtitleConfigured;
String _invoicesTitle(AppLocalizations l10n) => l10n.invoicesEntryTitle;
String _invoicesSubtitle(AppLocalizations l10n) => l10n.invoicesEntrySubtitle;
String _invoicesConfiguredSubtitle(AppLocalizations l10n) =>
    l10n.invoicesEntrySubtitleConfigured;
String _notificationsTitle(AppLocalizations l10n) =>
    l10n.notificationsFeedEntryTitle;
String _notificationsSubtitle(AppLocalizations l10n) =>
    l10n.notificationsFeedEntrySubtitle;
String _notificationsConfiguredSubtitle(AppLocalizations l10n) =>
    l10n.notificationsFeedEntrySubtitleConfigured;
String _alertsTitle(AppLocalizations l10n) => l10n.alertsEntryTitle;
String _alertsSubtitle(AppLocalizations l10n) => l10n.alertsEntrySubtitle;
String _alertsConfiguredSubtitle(AppLocalizations l10n) =>
    l10n.alertsEntrySubtitleConfigured;
String _tasksTitle(AppLocalizations l10n) => l10n.tasksEntryTitle;
String _tasksSubtitle(AppLocalizations l10n) => l10n.tasksEntrySubtitle;
String _tasksConfiguredSubtitle(AppLocalizations l10n) =>
    l10n.tasksEntrySubtitleConfigured;
String _approvalsTitle(AppLocalizations l10n) => l10n.approvalsEntryTitle;
String _approvalsSubtitle(AppLocalizations l10n) => l10n.approvalsEntrySubtitle;
String _approvalsConfiguredSubtitle(AppLocalizations l10n) =>
    l10n.approvalsEntrySubtitleConfigured;
String _researchTitle(AppLocalizations l10n) => l10n.aiResearchEntryTitle;
String _researchSubtitle(AppLocalizations l10n) => l10n.aiResearchEntrySubtitle;
