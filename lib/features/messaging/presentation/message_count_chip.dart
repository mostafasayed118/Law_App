import 'package:flutter/material.dart';

import '../../../shared/widgets/label_chip.dart';

/// Small chip rendering a thread's synthetic message count on the list tile.
///
/// Mirrors the document type chip pattern (feature-local to messaging). A
/// count only — never message content (D-MSG1 body-less line: a number, not
/// text). Display-only — the chip has no tap affordance, consistent with the
/// read-only thread list (rows are deliberately not interactive, D-MSG3).
///
/// E5 wrapper: the visual shell is the shared [LabelChip]; this class keeps
/// the feature's tertiary-container colors and the public name the list
/// tiles and l10n tests construct by type.
class MessageCountChip extends StatelessWidget {
  const MessageCountChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LabelChip(
      label: label,
      background: scheme.tertiaryContainer,
      foreground: scheme.onTertiaryContainer,
    );
  }
}
