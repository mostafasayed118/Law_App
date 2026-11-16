import 'package:flutter/material.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Maps a highlight slot to its theme colour and its localized name.
///
/// The tokens live in `legalhub_theme.dart` (the single colour source) and this
/// file only chooses between them, so a palette change never means editing a
/// widget and a new slot is a compile error here rather than a colourless
/// highlight on a device.
abstract final class HighlightPalette {
  /// The background tint for [slot] at the current brightness.
  ///
  /// Highlights are drawn as a background behind body text, so the text colour
  /// is left alone: contrast is always text-on-tint, which the theme tokens keep
  /// above 4.5:1 in both brightnesses.
  static Color background(BuildContext context, HighlightColorSlot slot) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return switch (slot) {
      HighlightColorSlot.yellow =>
        dark
            ? LegalHubTheme.darkHighlightYellow
            : LegalHubTheme.highlightYellow,
      HighlightColorSlot.green =>
        dark ? LegalHubTheme.darkHighlightGreen : LegalHubTheme.highlightGreen,
      HighlightColorSlot.blue =>
        dark ? LegalHubTheme.darkHighlightBlue : LegalHubTheme.highlightBlue,
      HighlightColorSlot.pink =>
        dark ? LegalHubTheme.darkHighlightPink : LegalHubTheme.highlightPink,
    };
  }

  /// The localized slot name, for the picker and for screen readers.
  static String label(AppLocalizations l10n, HighlightColorSlot slot) {
    return switch (slot) {
      HighlightColorSlot.yellow => l10n.libraryColourYellow,
      HighlightColorSlot.green => l10n.libraryColourGreen,
      HighlightColorSlot.blue => l10n.libraryColourBlue,
      HighlightColorSlot.pink => l10n.libraryColourPink,
    };
  }
}
