import 'package:flutter/material.dart';

/// A centered error message with a retry action — the E9 extraction: the
/// attorney-profile and matter-details error arms previously duplicated
/// this exact `Center` → `Column` → error text + retry button shape.
///
/// Purely presentational — no cubit reads, no l10n lookups inside; call
/// sites pass the message and the retry callback as closures. The error
/// text is rendered with the theme's error color (centered) and the retry
/// [TextButton] sits directly beneath it, matching the pre-extraction
/// structure byte-for-byte.
class AppCenteredRetry extends StatelessWidget {
  const AppCenteredRetry({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
    super.key,
  });

  /// The error copy (e.g. `l10n.matterError`).
  final String message;

  /// The retry action (e.g. `context.read<MatterCubit>().load()`).
  final VoidCallback onRetry;

  /// The localized retry label (e.g. `l10n.retry`).
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error),
          ),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
