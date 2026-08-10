import 'package:flutter/material.dart';

import '../../app/legalhub_theme.dart';

/// A section header plus its content — the C2 consolidation: the search
/// `_GroupSection` (titleMedium w700 primary + children) and the
/// matter-details `_WorkspaceBlock` (titleSmall w700 + section) previously
/// duplicated this `Column(start)` → `Text(w700)` + `spaceSm` + content
/// shape, differing only in the title style and where the inter-section
/// spacing lives (both parents own that spacing now).
///
/// Purely presentational — no cubit reads, no l10n lookups inside; call
/// sites pass the title, the content widgets, and (optionally) the title
/// style (defaults to the `titleMedium` w700 primary emphasis shape).
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.children = const <Widget>[],
    this.titleStyle,
    super.key,
  });

  /// The section title (e.g. `l10n.matterWorkspaceDocumentsTitle`).
  final String title;

  /// The content widgets (rows, sections, …). No gap is injected between
  /// them — call sites keep their exact spacing.
  final List<Widget> children;

  /// Overrides the default `titleMedium` w700 primary emphasis style (the
  /// matter-details workspace headers use `titleSmall` w700).
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style:
              titleStyle ??
              text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        ...children,
      ],
    );
  }
}
