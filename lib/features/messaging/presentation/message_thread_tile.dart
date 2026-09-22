part of 'message_list_screen.dart';

/// A read-only metadata row with **exactly two tap targets**: the whole-row
/// thread-open affordance (the first thread-open in the app, D-RT5 — tap a
/// thread row → the read-only detail surface) and, on resolved rows under
/// the `canViewMatters` hint, the compact `MatterLinkChip` reverse
/// cross-link (D-C2/D-C4). No chevron and no other trailing action — the
/// row stays metadata-only otherwise (D-MSG1).
class _MessageThreadTile extends StatelessWidget {
  const _MessageThreadTile({
    required this.thread,
    required this.onOpenThread,
    required this.onViewMatter,
  });

  final MessageThread thread;

  /// The whole-row thread-open tap → the read-only thread-detail surface
  /// (D-RT5). Always non-null for a listed row.
  final VoidCallback onOpenThread;

  /// The reverse cross-link tap, or null when the row renders no chip
  /// (unresolved `matterRef` or the nav hint not granted, D-C2/D-C4).
  ///
  /// Null-checked with a `case` pattern below: public final fields do not
  /// promote in Dart 3.2, so a plain `!= null` check would not narrow the
  /// type here.
  final VoidCallback? onViewMatter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Same localized date shape as the vault/details surfaces (yMMMd,
    // locale-aware via l10n.localeName).
    final String date = formatMediumDate(l10n, thread.lastActivityAt);
    return AppTile(
      icon: Icons.forum_outlined,
      title: thread.title,
      subtitles: <String>['${thread.participants.join(', ')} · $date'],
      // The chips wrap beneath the metadata line (the roster pattern); the
      // link chip stays a secondary tap target in the row (D-C2). The row
      // stays chevron-free (D-MSG1).
      trailing: Wrap(
        spacing: LegalHubTheme.spaceSm,
        runSpacing: LegalHubTheme.spaceSm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          MessageCountChip(
            label: l10n.messagesMessageCount(thread.messageCount),
          ),
          if (onViewMatter case final VoidCallback tap)
            MatterLinkChip(onTap: tap),
        ],
      ),
      onTap: onOpenThread,
      showChevron: false,
    );
  }
}
