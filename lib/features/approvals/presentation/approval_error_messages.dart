import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Localized copy for an approval action failure.
///
/// The gateway's [AppError.userMessage] is English by design (the data layer
/// has no l10n); the sheets render this presentation-level mapping instead.
/// The typed [AppError.kind] carries denial/outage, and the `_invalid` code
/// suffix (or the not-found code) marks a server refusal.
String approvalErrorMessage(AppLocalizations l10n, AppError error) {
  if (error.kind == AppErrorKind.denied) {
    return l10n.approvalErrorDenied;
  }
  if (error.kind == AppErrorKind.unavailable) {
    return l10n.approvalErrorUnavailable;
  }
  if (error.code.endsWith('_invalid') ||
      error.code == 'approval_not_found' ||
      error.code == 'approval_decide_failed') {
    return l10n.approvalErrorInvalid;
  }
  return l10n.approvalErrorFailed;
}
