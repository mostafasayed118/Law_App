import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/features/messaging/presentation/message_thread_detail_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Localized copy for a message-send failure.
///
/// The gateway's [AppError.userMessage] is English by design (the data layer
/// has no l10n); the composer renders this presentation-level mapping instead.
/// The typed [AppError.kind] carries denial/outage, while the client-side
/// length guard uses the `message_too_long` code.
String messageSendErrorMessage(AppLocalizations l10n, AppError error) {
  if (error.code == 'message_too_long') {
    return l10n.messageErrorTooLong(MessageThreadDetailCubit.maxMessageLength);
  }
  if (error.kind == AppErrorKind.denied) {
    return l10n.messageErrorDenied;
  }
  if (error.kind == AppErrorKind.unavailable) {
    return l10n.messageErrorUnavailable;
  }
  return l10n.messageErrorFailed;
}
