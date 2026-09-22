part of 'document_list_screen.dart';

/// A read-only metadata row. Carries **no onTap on the row body, no chevron,
/// and no trailing action other than the Phase 12 "View matter" chip** — the
/// vault's metadata-only line (D-V1) now allows exactly one tap target per
/// resolved row: the compact `MatterLinkChip`, which is the ONLY InkWell in
/// the list (D-C2). The AC-2 pin asserts these absences structurally.
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.onViewMatter});

  final Document document;

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
    // Same localized date shape as the matter details surface (yMMMd,
    // locale-aware via l10n.localeName).
    final String date = formatMediumDate(l10n, document.createdAt);
    return AppTile(
      icon: Icons.folder_outlined,
      title: document.title,
      subtitles: <String>['${documentTypeLabel(l10n, document.type)} · $date'],
      // The chips wrap beneath the metadata line (the roster pattern); the
      // link chip stays the only tap target in the row (D-C2), so the card
      // itself renders no InkWell and no chevron (AppTile null onTap).
      trailing: switch (onViewMatter) {
        final VoidCallback tap => Padding(
          padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceSm),
          child: Wrap(
            spacing: LegalHubTheme.spaceSm,
            runSpacing: LegalHubTheme.spaceSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              DocumentTypeChip(label: documentTypeLabel(l10n, document.type)),
              MatterLinkChip(onTap: tap),
            ],
          ),
        ),
        null => null,
      },
    );
  }
}
