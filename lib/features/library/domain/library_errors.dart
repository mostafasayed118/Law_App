import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';

/// The failure vocabulary of the Legal Library (ADR-0009).
///
/// Codes are stable strings the presentation layer may branch on; the user
/// facing copy always comes from a localized [AppMessageKey] rather than these
/// literals.
abstract final class LibraryErrors {
  static const String documentNotFoundCode = 'legal_document_not_found';
  static const String articleNotFoundCode = 'legal_article_not_found';
  static const String unavailableCode = 'legal_library_unavailable';
  static const String queryTooLongCode = 'legal_search_query_too_long';

  static const AppError documentNotFound = AppError(
    code: documentNotFoundCode,
    userMessage: 'The document was not found.',
    messageKey: AppMessageKey.errTheLegalDocumentWasNotFound,
  );

  static const AppError articleNotFound = AppError(
    code: articleNotFoundCode,
    userMessage: 'The article was not found.',
    messageKey: AppMessageKey.errTheLegalArticleWasNotFound,
  );

  static const AppError unavailable = AppError(
    code: unavailableCode,
    userMessage: 'Unable to load the library. Please try again.',
    messageKey: AppMessageKey.errUnableToLoadTheLibraryPleaseTryAgain,
    kind: AppErrorKind.unavailable,
  );

  static const AppError queryTooLong = AppError(
    code: queryTooLongCode,
    userMessage: 'The search query is too long.',
    messageKey: AppMessageKey.errTheSearchQueryIsTooLong,
  );
}
