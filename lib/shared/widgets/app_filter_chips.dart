import 'package:flutter/material.dart';

import '../../app/legalhub_theme.dart';

/// A horizontally scrollable row of [FilterChip]s for single-select filters:
/// an "All" chip (clears the selection) followed by one chip per enum value.
///
/// This is the E7 extraction: the matter status filter
/// (`matter_list_screen.dart` `_StatusFilterChips`) and the practice-area
/// filter (`attorney_search_screen.dart` `_AreaFilterChips`) previously
/// duplicated this exact row. The widget is purely presentational — it does
/// not read a cubit or build l10n strings; call sites pass the label
/// function and the selection callback as closures.
class AppFilterChips<T> extends StatelessWidget {
  const AppFilterChips({
    required this.values,
    required this.selected,
    required this.allLabel,
    required this.labelOf,
    required this.onSelected,
    super.key,
  });

  /// The enum values to render one chip each (e.g. `MatterStatus.values`).
  final List<T> values;

  /// The current selection; null renders the "All" chip selected.
  final T? selected;

  /// The "All" filter label (e.g. `l10n.matterFilterAll`).
  final String allLabel;

  /// The label for a single value (e.g. `matterStatusLabel(l10n, status)`).
  final String Function(T value) labelOf;

  /// Called with null when "All" is tapped and with the value when a value
  /// chip is tapped (or null again when a selected value chip is tapped off).
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          FilterChip(
            label: Text(allLabel),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final T value in values) ...<Widget>[
            const SizedBox(width: LegalHubTheme.spaceSm),
            FilterChip(
              label: Text(labelOf(value)),
              selected: selected == value,
              onSelected: (bool isSelected) =>
                  onSelected(isSelected ? value : null),
            ),
          ],
        ],
      ),
    );
  }
}
