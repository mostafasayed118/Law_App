import 'package:flutter/material.dart';

import '../../app/legalhub_theme.dart';

/// A centered, padded, secondary-colored message — the Candidate-A
/// extraction: the attorney-profile and matter-details `_message` helpers
/// previously duplicated this exact `Center` → `Padding(spaceLg)` →
/// centered `Text(bodyMedium onSurfaceVariant)` shape (e.g. the
/// "not found" copy rendered for empty/offline/unauthorized states).
///
/// Purely presentational — no cubit reads, no l10n lookups inside; call
/// sites pass the message string.
class AppCenteredMessage extends StatelessWidget {
  const AppCenteredMessage({required this.text, super.key});

  /// The centered message copy (e.g. `l10n.discoveryProfileNotFound`).
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceLg),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
