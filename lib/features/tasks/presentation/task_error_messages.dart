import '../../../core/errors/app_error.dart';
import '../../../l10n/app_localizations.dart';

/// Localized copy for a task create/assign failure.
///
/// The gateway's [AppError.userMessage] is English by design (data layer has
/// no l10n); the sheets render this presentation-level mapping instead. The
/// typed [AppError.kind] carries denial/outage, and the `_invalid` code suffix
/// marks a server validation refusal (the task gateway's validation arm maps
/// to `unknown` kind, so the code is the only validation signal).
String taskErrorMessage(AppLocalizations l10n, AppError error) {
  if (error.kind == AppErrorKind.denied) {
    return l10n.taskErrorDenied;
  }
  if (error.kind == AppErrorKind.unavailable) {
    return l10n.taskErrorUnavailable;
  }
  if (error.code.endsWith('_invalid')) {
    return l10n.taskErrorInvalid;
  }
  return l10n.taskErrorFailed;
}
