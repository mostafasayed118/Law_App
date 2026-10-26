/// HTTP status codes used by the provider-facing failure mappers.
///
/// The integer form serves switches over an `int` status (Edge Functions);
/// the `...Text` form serves the providers that report the status as a
/// string (`AuthException.statusCode`, `StorageException.statusCode`).
abstract final class HttpStatusCodes {
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int conflict = 409;
  static const int payloadTooLarge = 413;
  static const int unsupportedMediaType = 415;
  static const int unprocessableEntity = 422;
  static const int tooManyRequests = 429;
  static const int internalServerError = 500;
  static const int badGateway = 502;
  static const int serviceUnavailable = 503;
  static const int gatewayTimeout = 504;

  static const String badRequestText = '400';
  static const String unauthorizedText = '401';
  static const String forbiddenText = '403';
  static const String notFoundText = '404';
  static const String conflictText = '409';
  static const String payloadTooLargeText = '413';
  static const String unsupportedMediaTypeText = '415';
  static const String tooManyRequestsText = '429';
}
