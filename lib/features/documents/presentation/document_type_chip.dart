import 'package:flutter/material.dart';

import '../../../shared/widgets/label_chip.dart';

/// Small colored chip rendering a document's type on the vault tile.
///
/// Mirrors the matter status chip pattern (feature-local to documents; the
/// vault has no second surface yet, but the shared shape keeps the chip
/// reusable if a details projection ever lands). Display-only — the chip
/// has no tap affordance, consistent with the D-V1 metadata-only line (the
/// vault rows are not interactive).
///
/// E5 wrapper: the visual shell is the shared [LabelChip]; this class keeps
/// the feature's tertiary-container colors and the public name the vault
/// tiles construct by type.
class DocumentTypeChip extends StatelessWidget {
  const DocumentTypeChip({required this.label, super.key});

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
