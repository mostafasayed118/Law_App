import 'package:flutter/material.dart';

import '../../app/legalhub_theme.dart';
import '../../core/state/view_state.dart';
import '../../l10n/app_localizations.dart';

/// Renders the non-success arms of a `ViewState<T>` list switch and delegates
/// the success arm to [builder].
///
/// E3 extraction: the list screens previously duplicated this exact switch —
/// a `spaceXl`-padded loading spinner, the feature's `empty` copy for both the
/// empty and the offline/unauthorized variants (a synthetic list has neither
/// state, so all three render the same copy rather than a distinct offline
/// surface), and a start-aligned error column with a retry button. Each call
/// site supplies its feature's empty widget, error copy, retry callback, and
/// success content; the arms are rendered identically everywhere.
///
/// This complements (and is distinct from) [ViewStateView], which renders a
/// centered full-page status message; this widget renders the state *around*
/// a feature's list content.
class ViewStateSwitch<T> extends StatelessWidget {
  const ViewStateSwitch({
    required this.state,
    required this.onRetry,
    required this.builder,
    required this.empty,
    required this.errorCopy,
    this.loadingPadding = const EdgeInsetsDirectional.all(
      LegalHubTheme.spaceXl,
    ),
    this.errorPadding = const EdgeInsetsDirectional.only(
      top: LegalHubTheme.spaceMd,
    ),
    this.errorTextStyle,
    super.key,
  });

  /// The state driving the switch.
  final ViewState<T> state;

  /// Retry callback wired to the error arm's `TextButton`.
  final VoidCallback onRetry;

  /// Success content; receives the loaded data.
  final Widget Function(BuildContext context, T data) builder;

  /// The feature's empty copy, rendered for empty, offline, and unauthorized.
  final Widget empty;

  /// The feature's error copy, rendered above the retry button.
  final String errorCopy;

  /// Padding around the loading spinner (the matter workspace sections use a
  /// tighter `spaceMd`; the list screens use the `spaceXl` default).
  final EdgeInsetsGeometry loadingPadding;

  /// Padding around the error column (the workspace sections use zero).
  final EdgeInsetsGeometry errorPadding;

  /// Error text style override (the workspace sections use `bodySmall`).
  final TextStyle? errorTextStyle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return switch (state) {
      ViewLoading<T>() => Padding(
        padding: loadingPadding,
        child: const Center(child: CircularProgressIndicator()),
      ),
      ViewEmpty<T>() => empty,
      ViewError<T>() => Padding(
        padding: errorPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              errorCopy,
              style:
                  errorTextStyle ??
                  text.bodyMedium?.copyWith(color: scheme.error),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
      ViewOffline<T>() || ViewUnauthorized<T>() => empty,
      ViewSuccess<T>(data: final T data) => builder(context, data),
    };
  }
}
