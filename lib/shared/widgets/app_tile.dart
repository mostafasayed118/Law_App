import 'package:flutter/material.dart';

import '../../app/legalhub_theme.dart';

/// A standardized list row card: an optional leading (avatar or icon), a
/// title/subtitle pair, an optional trailing widget (e.g., a status-chip
/// wrap), and — when tappable — a ripple and a trailing chevron.
///
/// E2 extraction: the search result tiles and the list-screen rows (matters,
/// documents, messaging, approvals, tasks) previously duplicated this exact
/// card shape — `radiusLg` outlined card, `spaceMd` padding, primary-container
/// avatar, `bodyMedium` w600 title over a `bodySmall` metadata line.
///
/// **D-C2 tappable contract:** when [onTap] is null the card renders no
/// `InkWell` and no chevron (and keeps the default `Clip.none`); a read-only
/// metadata row must not read as tappable. When [onTap] is provided the card
/// installs the ripple (with `Clip.antiAlias`) and — unless [showChevron] is
/// false — the trailing chevron. The chevron opt-out exists for the
/// metadata-first thread row (D-MSG1), which is whole-row tappable yet stays
/// chevron-free.
class AppTile extends StatelessWidget {
  const AppTile({
    required this.title,
    this.subtitles = const <String>[],
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    super.key,
  });

  /// The row's title (`bodyMedium` w600).
  final String title;

  /// The metadata lines under the title (`bodySmall`, `onSurfaceVariant`),
  /// each separated by the standard 2px gap; empty renders no subtitle.
  final List<String> subtitles;

  /// Convenience leading: a primary-container avatar wrapping [icon]. Ignored
  /// when [leading] is provided.
  final IconData? icon;

  /// Full custom leading (an initial-letter avatar, a bare status icon, …);
  /// takes precedence over [icon]. The surrounding card, gap, and layout are
  /// still applied.
  final Widget? leading;

  /// A widget rendered directly under the subtitle (chips wrap, …). No gap is
  /// injected — call sites keep their exact spacing.
  final Widget? trailing;

  /// The whole-row tap; null renders a non-interactive, chevron-free row
  /// (D-C2).
  final VoidCallback? onTap;

  /// Renders the trailing chevron when [onTap] is provided; false keeps a
  /// tappable row chevron-free (the metadata-first thread row, D-MSG1).
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget? leadingWidget =
        leading ??
        (icon == null
            ? null
            : CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
              ));
    final Widget content = Padding(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
      child: Row(
        children: <Widget>[
          if (leadingWidget != null) ...<Widget>[
            leadingWidget,
            const SizedBox(width: LegalHubTheme.spaceMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                for (final String line in subtitles) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                ?trailing,
              ],
            ),
          ),
          if (onTap != null && showChevron) ...<Widget>[
            const SizedBox(width: LegalHubTheme.spaceSm),
            Icon(Icons.chevron_right, color: scheme.outline),
          ],
        ],
      ),
    );
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
