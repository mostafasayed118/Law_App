import '../../../../core/errors/app_error.dart';
import '../../../../core/state/view_state.dart';
import '../../../../l10n/app_localizations.dart';

/// Re-wraps a recovery [ViewError] with the localized generic denial so the
/// shared [ViewStateView] renders localized copy (plan §4 l10n: EN/AR/TR +
/// RTL). Every recovery failure resolves to the same one generic
/// non-enumerating message (plan §7), so the code is preserved for
/// diagnostics while the user-facing message is always the localized notice.
ViewState<void> localizeRecoveryError(
  ViewState<void> state,
  AppLocalizations l10n,
) {
  if (state is ViewError<void>) {
    return ViewError<void>(
      AppError(
        code: state.error.code,
        userMessage: l10n.recoveryErrorNotice,
        // Preserve the redacted diagnostic context (ADR-0003) and any
        // technical message so diagnostics stay intact.
        technicalMessage: state.error.technicalMessage,
        context: state.error.context,
      ),
    );
  }
  return state;
}
