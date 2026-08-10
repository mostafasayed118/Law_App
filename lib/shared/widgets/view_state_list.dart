import 'package:flutter/material.dart';

import '../../app/legalhub_theme.dart';
import '../../core/state/view_state.dart';
import '../../l10n/app_localizations.dart';

/// A scrollable variant of [ViewStateSwitch] for list screens whose arms are
/// `ListView`s with a local-only-note footer.
///
/// Follow-up extraction (designed 2026-08-11): the approvals, compliance,
/// and task-board screens duplicated this exact switch — a `spaceXl`-padded
/// loading spinner, a note-wrapped empty arm, a ListView error arm, and a
/// success ListView of tiles followed by the same footer note. Each call
/// site supplies its feature's empty widget, error copy, retry callback,
/// local-only note, and tile builder; the arms render identically
/// everywhere.
///
/// Behavior note: the offline/unauthorized arms render the same
/// note-wrapped empty ListView as the empty arm — normalized per the owner
/// decision recorded in the design doc's §4 (previously they rendered the
/// plain empty copy, an inconsistency of the pre-extraction screens).
class ViewStateList<T> extends StatelessWidget {
  const ViewStateList({
    required this.state,
    required this.onRetry,
    required this.itemBuilder,
    required this.empty,
    required this.errorCopy,
    required this.localOnlyNote,
    this.listPadding = const EdgeInsetsDirectional.all(
      LegalHubTheme.marginMobile,
    ),
    super.key,
  });

  /// The state driving the switch.
  final ViewState<T> state;

  /// Retry callback wired to the error arm's `TextButton`.
  final VoidCallback onRetry;

  /// The success arm's tile widgets, including their inter-tile gaps.
  final List<Widget> Function(BuildContext context, T data) itemBuilder;

  /// The feature's plain empty copy, rendered inside the note-wrapped
  /// ListView for empty, offline, and unauthorized alike.
  final Widget empty;

  /// The feature's error copy, rendered above the retry button.
  final String errorCopy;

  /// The footer note under the empty copy and the success tiles.
  final String localOnlyNote;

  /// The ListView padding on the empty, error, and success arms.
  final EdgeInsetsGeometry listPadding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget note = Text(
      localOnlyNote,
      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );
    return switch (state) {
      ViewLoading<T>() => const Padding(
        padding: EdgeInsetsDirectional.all(LegalHubTheme.spaceXl),
        child: Center(child: CircularProgressIndicator()),
      ),
      ViewEmpty<T>() || ViewOffline<T>() || ViewUnauthorized<T>() => ListView(
        padding: listPadding,
        children: <Widget>[
          empty,
          const SizedBox(height: LegalHubTheme.spaceLg),
          note,
        ],
      ),
      ViewError<T>() => ListView(
        padding: listPadding,
        children: <Widget>[
          Text(
            errorCopy,
            style: text.bodyMedium?.copyWith(color: scheme.error),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
      ViewSuccess<T>(data: final T data) => ListView(
        padding: listPadding,
        children: <Widget>[
          ...itemBuilder(context, data),
          const SizedBox(height: LegalHubTheme.spaceLg),
          note,
        ],
      ),
    };
  }
}
