import 'package:flutter/material.dart';

import '../../core/state/view_state.dart';
import '../../l10n/app_localizations.dart';

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

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.label,
    this.child,
    this.action,
  });

  final IconData icon;
  final String label;
  final Widget? child;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
          if (child != null) ...<Widget>[const SizedBox(height: 12), child!],
          if (action != null) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: action,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ],
      ),
    );
  }
}
