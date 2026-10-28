import 'package:flutter/material.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'view_state_switch.dart';

/// The state-shell of a matter-workspace section: the `ViewStateSwitch` arms
/// plus the rows column and the inline empty hint.
///
/// E10 extraction: the four matter workspace sections (documents, files,
/// invoices, messages) previously duplicated this shell — the switch arm
/// config (`spaceMd` loading padding, zero error padding, `bodySmall` error
/// text), the `where(matterRef)` filter, the `spaceSm`-gapped rows column,
/// and the `spaceXs`-top inline empty copy. This widget owns that shell;
/// each section keeps its own `BlocProvider`/`BlocBuilder` wiring (which
/// differs only in cubit/gateway types) and supplies the state, retry,
/// copies, and the per-item tile via [itemBuilder]. The matter scoping is
/// server-side now, so the widget renders exactly the rows it is given.
///
/// The success arm is a **preview**: at most [previewCount] rows render until
/// the reader expands the section, so the details surface builds 4 × 5 tiles
/// instead of up to 4 × 200 (audit 2026-10-27, F11). The expand affordance
/// renders only when the parent supplies [viewAllCopy].
class WorkspaceSection<T> extends StatefulWidget {
  const WorkspaceSection({
    required this.state,
    required this.onRetry,
    required this.errorCopy,
    required this.emptyCopy,
    required this.itemBuilder,
    this.viewAllCopy,
    this.previewCount = defaultPreviewCount,
    super.key,
  }) : assert(previewCount > 0, 'previewCount must be positive');

  /// The rows a collapsed section renders before the reader expands it.
  static const int defaultPreviewCount = 5;

  /// The section's list state (feature-scoped cubit projection).
  final ViewState<List<T>> state;

  /// Retry callback wired to the error arm's `TextButton`.
  final VoidCallback onRetry;

  /// The feature's error copy (e.g. `l10n.vaultError`).
  final String errorCopy;

  /// The feature's per-matter empty copy (e.g. `l10n.matterWorkspaceXEmpty`),
  /// rendered for the empty list and the offline/unauthorized variants.
  final String emptyCopy;

  /// Renders one row (typically an `AppTile`). The `spaceSm` inter-row gap
  /// is owned by this widget.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// The localized "view all" label (e.g. `l10n.viewAll`). When null the
  /// section stays at [previewCount] rows and offers no expand affordance.
  final String? viewAllCopy;

  /// Maximum rows rendered while collapsed.
  final int previewCount;

  @override
  State<WorkspaceSection<T>> createState() => _WorkspaceSectionState<T>();
}

class _WorkspaceSectionState<T> extends State<WorkspaceSection<T>> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return ViewStateSwitch<List<T>>(
      state: widget.state,
      onRetry: widget.onRetry,
      builder: (BuildContext context, List<T> items) => _rows(context, items),
      empty: _empty(text, scheme),
      errorCopy: widget.errorCopy,
      loadingPadding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
      errorPadding: EdgeInsets.zero,
      errorTextStyle: text.bodySmall?.copyWith(color: scheme.error),
    );
  }

  Widget _rows(BuildContext context, List<T> items) {
    final String? viewAllCopy = widget.viewAllCopy;
    final bool hasMore = items.length > widget.previewCount;
    final List<T> visible = _expanded || !hasMore
        ? items
        : items.take(widget.previewCount).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final T item in visible) ...<Widget>[
          widget.itemBuilder(context, item),
          const SizedBox(height: LegalHubTheme.spaceSm),
        ],
        if (hasMore && !_expanded && viewAllCopy != null)
          TextButton(
            onPressed: () => setState(() => _expanded = true),
            child: Text(viewAllCopy),
          ),
      ],
    );
  }

  Widget _empty(TextTheme text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceXs),
      child: Text(
        widget.emptyCopy,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
