import 'package:flutter/material.dart';

import '../../app/legalhub_theme.dart';

/// A tappable dashboard entry tile: an icon bubble, a title/subtitle pair,
/// and a trailing chevron inside an outlined card.
///
/// E1 extraction: nine feature entry cards (booking, discovery, matters,
/// documents, messaging, billing, compliance, tasks, approvals) previously
/// duplicated this exact structure; they now delegate to this shared card,
/// passing their feature's icon + localized copy through constructor
/// parameters. Theme-aware (`ColorScheme`), RTL-safe (directional padding),
/// and ripple-provided by the [InkWell] — the whole card is the tap target.
class AppEntryCard extends StatelessWidget {
  const AppEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  /// The feature's leading icon inside the primary-container bubble.
  final IconData icon;

  /// The card title (localized by the caller — the card owns no l10n).
  final String title;

  /// The card subtitle (localized by the caller).
  final String subtitle;

  /// Navigation callback; null renders a non-interactive card.
  final VoidCallback? onTap;

  /// Optional accessibility label overriding the concatenated semantics of
  /// the title/subtitle text. When null (the default) the card keeps the
  /// default text semantics exactly as the pre-extraction cards did.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget card = Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 22,
                  color: scheme.onPrimaryContainer,
                  fill: 1,
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
    // A custom label replaces the concatenated text semantics; when null the
    // card keeps the default (pre-extraction) semantics untouched.
    if (semanticLabel == null) {
      return card;
    }
    return Semantics(label: semanticLabel, child: card);
  }
}
