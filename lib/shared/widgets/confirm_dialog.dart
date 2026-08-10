import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Prompts for confirmation before a destructive action and resolves to true
/// only on explicit confirmation.
///
/// E4 extraction: the member-removal (roster), delete-account (profile), and
/// demo-account-delete (admin) dialogs previously duplicated this exact
/// `AlertDialog` — a title, a content widget, a neutral cancel button
/// resolving to false, and an **error-tinted** confirm `FilledButton`
/// resolving to true so the destructive action reads as dangerous, distinct
/// from any primary button (M3 pattern). Cancel, dismiss, and back all
/// resolve to false; the caller is left to interpret the result.
Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required Widget content,
  required String confirmLabel,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ColorScheme scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: content,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          // Error-tinted confirm so the destructive action reads as
          // dangerous, distinct from any primary button (M3 pattern).
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}
