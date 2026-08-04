import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';

/// Small chip rendering a thread's synthetic message count on the list tile.
///
/// Mirrors the document type chip pattern (feature-local to messaging). A
/// count only — never message content (D-MSG1 body-less line: a number, not
/// text). Display-only — the chip has no tap affordance, consistent with the
/// read-only thread list (rows are deliberately not interactive, D-MSG3).
class MessageCountChip extends StatelessWidget {
  const MessageCountChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LegalHubTheme.spaceSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusSm),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onTertiaryContainer),
      ),
    );
  }
}
