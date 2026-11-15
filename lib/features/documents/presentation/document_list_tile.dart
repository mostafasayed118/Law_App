part of 'document_list_screen.dart';

/// A metadata row. The whole row opens the metadata detail (`/vault/:id`);
/// the resolved row's compact "View matter" chip remains a second, nested
/// tap target (D-C2). **No content, preview, download, or share affordance
/// exists anywhere in the row** — the detail it opens is metadata-only too
/// (D-V1).
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.localOnly,
    required this.onViewMatter,
    required this.onOpen,
  });

  final Document document;
  final bool localOnly;

  /// The reverse cross-link tap, or null when the row renders no chip
  /// (no embedded matter title or the nav hint not granted, D-C2/D-C4).
  final VoidCallback? onViewMatter;

  /// Whole-row open → the metadata detail.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Same localized date shape as the matter details surface (yMMMd,
    // locale-aware via l10n.localeName).
    final String date = formatMediumDate(l10n, document.createdAt);
    return AppTile(
      icon: Icons.folder_outlined,
      title: DemoLabels(
        l10n,
        localOnly: localOnly,
      ).documentTitle(document.title),
      subtitles: <String>['${documentTypeLabel(l10n, document.type)} · $date'],
      onTap: onOpen,
      // The chips wrap beneath the metadata line (the roster pattern); the
      // link chip stays a nested secondary tap target in the row (D-C2).
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
