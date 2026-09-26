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
  final List<HomeEntry> entries = homeEntriesFor(capabilities);
  final List<Widget> cards = <Widget>[];
  for (int i = 0; i < entries.length; i++) {
    final HomeEntry entry = entries[i];
    cards.add(
      SizedBox(height: i == 0 ? LegalHubTheme.spaceLg : LegalHubTheme.spaceMd),
    );
    cards.add(
      AppEntryCard(
        icon: entry.icon,
        title: entry.title(l10n),
        subtitle: entry.subtitle(l10n),
        onTap: () => context.push(entry.route),
      ),
    );
  }
  return cards;
}
