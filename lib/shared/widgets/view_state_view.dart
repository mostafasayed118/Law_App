import 'package:flutter/material.dart';

import '../../core/state/view_state.dart';
import '../../l10n/app_localizations.dart';

part 'view_state_message.dart';

class ViewStateView<T> extends StatelessWidget {
  const ViewStateView({required this.state, this.onRetry, super.key});

  final ViewState<T> state;
  final VoidCallback? onRetry;

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
        label: error.userMessage,
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
