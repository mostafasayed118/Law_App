import 'package:flutter/material.dart';

import '../../app/legalhub_theme.dart';

/// A small colored status chip: a `spaceSm`-padded, `radiusSm` rounded
/// container with a single-line label.
///
/// E5 extraction: the matter status, document type, message count, and
/// roster role/status chips previously duplicated this exact container. Each
/// feature supplies its own colors (secondary/tertiary/error container
/// tones) and text style (the small `labelSmall` default or the roster's
/// `labelLarge`); the shell is rendered identically everywhere.
///
/// Display-only — the chip carries no tap affordance. [maxLines] defaults to
/// 1 with ellipsis; pass null for no line clamp (the roster chips).
class LabelChip extends StatelessWidget {
  const LabelChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.style,
    this.maxLines = 1,
    super.key,
  });

  /// The chip text (localized by the caller — the chip owns no l10n).
  final String label;

  /// The chip's container color.
  final Color background;

  /// The label's text color.
  final Color foreground;

  /// The base text style; the foreground color is always applied on top.
  final TextStyle? style;

  /// Line clamp; null renders the label unclamped (roster posture).
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LegalHubTheme.spaceSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusSm),
        ),
      ),
      child: Text(
        label,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: (style ?? Theme.of(context).textTheme.labelSmall)?.copyWith(
          color: foreground,
        ),
      ),
    );
  }
}
