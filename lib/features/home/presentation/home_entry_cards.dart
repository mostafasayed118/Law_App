part of 'home_screen.dart';

/// The capability-gated dashboard entry cards, returned as one flat list
/// so the sliver delegate keeps receiving the same eagerly-built literal
/// it did before the readability split.
///
/// Data-driven over [homeEntriesFor]: the entries (order, gates, routes,
/// copy keys) live in `home/domain/home_entries.dart`, which imports no
/// feature presentation library. This builder renders the shared
/// [AppEntryCard] directly, so `home_screen.dart` no longer imports the
/// twelve feature `*_entry_card.dart` widgets (audit: cross-feature
/// `presentation → presentation` coupling). The thin feature wrappers stay
/// in their features as compatibility shells rendering the identical card
/// with identical parameters — visuals and copy are byte-identical either
/// way.
///
/// Navigation contract (E2E BUG-1, 2026-09-24): every entry here is a
/// FORWARD navigation away from Home, so it must `push` — never `go`.
/// `go` replaces the whole stack, which left Home with nothing beneath it
/// and made the system BACK button exit the app from every feature screen
/// (`context.push` was used zero times before this fix). Tab switches in
/// `router_app_shell.dart` keep `go` deliberately: tabs are siblings, not
/// a parent/child relationship.
List<Widget> _homeEntryCards(
  BuildContext context,
  RoleCapability capabilities,
) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool localOnly = backendIsLocalOnly;
  final List<HomeEntry> entries = homeEntriesFor(capabilities);
  final List<Widget> cards = <Widget>[];
  for (int i = 0; i < entries.length; i++) {
    final HomeEntry entry = entries[i];
    cards.add(
      SizedBox(height: i == 0 ? LegalHubTheme.spaceLg : LegalHubTheme.spaceMd),
    );
    cards.add(
      AppEntryCard(
        icon: _iconFor(entry.icon),
        title: entry.title(l10n),
        subtitle: entry.subtitleFor(l10n, localOnly: localOnly),
        onTap: () => context.push(_routeFor(entry.route)),
      ),
    );
  }
  return cards;
}

/// Resolves a domain [HomeEntryIcon] token to its `Icons.*` constant.
///
/// Audit (domain-layer Flutter import): the domain owns the token, the
/// presentation owns this table. Exhaustive by construction — a new token
/// without an arm is a compile error. Values mirror the feature wrappers'
/// icons exactly, so both card paths stay byte-identical.
IconData _iconFor(HomeEntryIcon icon) => switch (icon) {
  HomeEntryIcon.booking => Icons.event_available_outlined,
  HomeEntryIcon.video => Icons.video_call_outlined,
  HomeEntryIcon.discovery => Icons.person_search_outlined,
  HomeEntryIcon.matters => Icons.folder_copy_outlined,
  HomeEntryIcon.documents => Icons.description_outlined,
  HomeEntryIcon.messages => Icons.forum_outlined,
  HomeEntryIcon.invoices => Icons.request_quote_outlined,
  HomeEntryIcon.notifications => Icons.notifications_none_outlined,
  HomeEntryIcon.alerts => Icons.shield_outlined,
  HomeEntryIcon.tasks => Icons.checklist_outlined,
  HomeEntryIcon.approvals => Icons.approval_outlined,
  HomeEntryIcon.research => Icons.auto_awesome_outlined,
};

/// Resolves a domain [HomeEntryRoute] token to its `AppRoutes.*` string.
///
/// Same contract as [_iconFor]: the domain names the destination, the
/// presentation maps it to the router. A renamed route touches this table
/// only — the domain never imports the router.
String _routeFor(HomeEntryRoute route) => switch (route) {
  HomeEntryRoute.book => AppRoutes.book,
  HomeEntryRoute.video => AppRoutes.video,
  HomeEntryRoute.discovery => AppRoutes.discovery,
  HomeEntryRoute.matters => AppRoutes.matters,
  HomeEntryRoute.vault => AppRoutes.vault,
  HomeEntryRoute.messages => AppRoutes.messages,
  HomeEntryRoute.invoices => AppRoutes.invoices,
  HomeEntryRoute.notificationsFeed => AppRoutes.notificationsFeed,
  HomeEntryRoute.alerts => AppRoutes.alerts,
  HomeEntryRoute.tasks => AppRoutes.tasks,
  HomeEntryRoute.approvals => AppRoutes.approvals,
  HomeEntryRoute.research => AppRoutes.research,
};
