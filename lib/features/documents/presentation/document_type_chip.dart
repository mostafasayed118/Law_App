import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';

/// Small colored chip rendering a document's type on the vault tile.
///
/// Mirrors the matter status chip pattern (feature-local to documents; the
/// vault has no second surface yet, but the shared shape keeps the chip
/// reusable if a details projection ever lands). Display-only — the chip
/// has no tap affordance, consistent with the D-V1 metadata-only line (the
/// vault rows are not interactive).
class DocumentTypeChip extends StatelessWidget {
  const DocumentTypeChip({required this.label, super.key});

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
