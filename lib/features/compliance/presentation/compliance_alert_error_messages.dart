import '../../../core/errors/app_error.dart';
import '../../../l10n/app_localizations.dart';

/// Localized copy for a compliance-alert action failure.
///
/// The gateway's [AppError.userMessage] is English by design (the data layer
/// has no l10n); the sheets render this presentation-level mapping instead.
/// The typed [AppError.kind] carries denial/outage, and the `_invalid` code
/// suffix (or the not-found code) marks a server refusal.
String alertErrorMessage(AppLocalizations l10n, AppError error) {
  if (error.kind == AppErrorKind.denied) {
    return l10n.alertErrorDenied;
  }
  if (error.kind == AppErrorKind.unavailable) {
    return l10n.alertErrorUnavailable;
  }
  if (error.code.endsWith('_invalid') || error.code == 'compliance_not_found') {
    return l10n.alertErrorInvalid;
  }
  return l10n.alertErrorFailed;
}
