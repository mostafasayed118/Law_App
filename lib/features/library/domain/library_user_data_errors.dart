import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';

/// The failure vocabulary of per-user library data (ADR-0010).
///
/// Codes mirror the SQLSTATE vocabulary migration 33 raises, so the Supabase
/// adapter and the fake return the same `AppError` for the same condition. Caps
/// are distinguished from validation on purpose: "you have saved too many" is
/// not a bug in the reader and must not read like one.
abstract final class LibraryUserDataErrors {
  static const String notFoundCode = 'legal_highlight_not_found';
  static const String savedLimitCode = 'legal_saved_limit_reached';
  static const String highlightRejectedCode = 'legal_highlight_rejected';
  static const String unavailableCode = 'legal_saved_unavailable';

  static const AppError highlightNotFound = AppError(
    code: notFoundCode,
    userMessage: 'The highlight was not found.',
    messageKey: AppMessageKey.errTheHighlightWasNotFound,
  );

  static const AppError savedLimitReached = AppError(
    code: savedLimitCode,
    userMessage: 'You have reached the saved-items limit.',
    messageKey: AppMessageKey.errTheSavedItemsLimitWasReached,
  );

  static const AppError highlightRejected = AppError(
    code: highlightRejectedCode,
    userMessage: 'That selection could not be highlighted.',
    messageKey: AppMessageKey.errTheHighlightCouldNotBeSaved,
    kind: AppErrorKind.unavailable,
  );

  static const AppError unavailable = AppError(
    code: unavailableCode,
    userMessage: 'Unable to load your saved items. Please try again.',
    messageKey: AppMessageKey.errUnableToLoadYourSavedItems,
    kind: AppErrorKind.unavailable,
  );

  static AppError bookmarkFailed(String technicalMessage) => AppError(
    code: unavailableCode,
    userMessage: 'The bookmark could not be updated.',
    messageKey: AppMessageKey.errTheBookmarkCouldNotBeUpdated,
    technicalMessage: technicalMessage,
    kind: AppErrorKind.unavailable,
  );
}
