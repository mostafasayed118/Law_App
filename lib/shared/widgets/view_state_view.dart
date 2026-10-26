import 'package:flutter/material.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/l10n/app_error_label.dart';
import 'package:legalhub/l10n/app_localizations.dart';

part 'view_state_message.dart';

class ViewStateView<T> extends StatelessWidget {
  const ViewStateView({
    required this.state,
    this.onRetry,
    this.errorFallback,
    super.key,
  });

  final ViewState<T> state;
  final VoidCallback? onRetry;

  /// Localized copy for an unkeyed [ViewError]. Callers that already localize
  /// the error message pass it here; the default is the generic
  /// [AppLocalizations.stateError], never the raw producer text.
  final String? errorFallback;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return switch (state) {
      ViewLoading<T>() => _StateMessage(
        icon: Icons.hourglass_empty,
        label: l10n.stateLoading,
        child: const CircularProgressIndicator(),
      ),
      ViewSuccess<T>() => _StateMessage(
        icon: Icons.check_circle_outline,
        label: l10n.stateSuccess,
      ),
      ViewEmpty<T>() => _StateMessage(
        icon: Icons.inbox_outlined,
        label: l10n.stateEmpty,
      ),
      ViewError<T>(error: final error) => _StateMessage(
        icon: Icons.error_outline,
        label: appErrorLabel(
          l10n,
          error,
          fallback: errorFallback ?? l10n.stateError,
        ),
        action: onRetry,
      ),
      ViewOffline<T>() => _StateMessage(
        icon: Icons.cloud_off_outlined,
        label: l10n.stateOffline,
      ),
      ViewUnauthorized<T>() => _StateMessage(
        icon: Icons.lock_outline,
        label: l10n.stateUnauthorized,
      ),
    };
  }
}
