import 'package:flutter/material.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/presentation/library_labels.dart';
import 'package:legalhub/features/library/presentation/sample_badge.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/label_chip.dart';

/// One document row in the library index.
///
/// Shows the header a reader needs to decide whether to open it: title, the
/// official number and year, the lifecycle status, the article count, and — when
/// the row is invented content — the sample badge.
class LibraryDocumentTile extends StatelessWidget {
  const LibraryDocumentTile({
    required this.document,
    required this.onTap,
    super.key,
  });

  final LegalDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    final List<String> meta = <String>[
      if (document.officialNumber != null) document.officialNumber!,
      if (document.year != null) '${document.year}',
      libraryCategoryLabel(l10n, document.category),
    ];

    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: LegalHubTheme.spaceSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(document.titleAr, style: text.titleMedium),
                  ),
                  if (document.isSample) ...<Widget>[
                    const SizedBox(width: LegalHubTheme.spaceXs),
                    const SampleBadge(),
                  ],
                ],
              ),
              const SizedBox(height: LegalHubTheme.spaceXs),
              Text(
                meta.join(' · '),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
              Wrap(
                spacing: LegalHubTheme.spaceXs,
                runSpacing: LegalHubTheme.spaceXs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  LabelChip(
                    label: libraryStatusLabel(l10n, document.status),
                    background: scheme.surfaceContainerHighest,
                    foreground: scheme.onSurfaceVariant,
                  ),
                  Text(
                    l10n.libraryDocumentArticles,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${document.articleCount}',
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
