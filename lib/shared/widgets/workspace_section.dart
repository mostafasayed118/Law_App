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
class WorkspaceSection<T> extends StatelessWidget {
  const WorkspaceSection({
    required this.state,
    required this.onRetry,
    required this.errorCopy,
    required this.emptyCopy,
    required this.itemBuilder,
    super.key,
  });

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

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return ViewStateSwitch<List<T>>(
      state: state,
      onRetry: onRetry,
      builder: (BuildContext context, List<T> items) => _rows(context, items),
      empty: _empty(text, scheme),
      errorCopy: errorCopy,
      loadingPadding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
      errorPadding: EdgeInsets.zero,
      errorTextStyle: text.bodySmall?.copyWith(color: scheme.error),
    );
  }

  Widget _rows(BuildContext context, List<T> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final T item in items) ...<Widget>[
          itemBuilder(context, item),
          const SizedBox(height: LegalHubTheme.spaceSm),
        ],
      ],
    );
  }

  Widget _empty(TextTheme text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceXs),
      child: Text(
        emptyCopy,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
