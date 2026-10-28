/// The `research-analyze` wire error codes.
///
/// The function's `{ "error": "<code>" }` body is authoritative; the gateway
/// preserves the code on each failure so presentation renders the typed copy.
/// One source; do not duplicate these literals.
abstract final class ResearchWireCodes {
  static const String unauthorized = 'unauthorized';
  static const String forbidden = 'forbidden';
  static const String invalidRequest = 'invalid_request';
  static const String contextTooLarge = 'context_too_large';
  static const String providerNotConfigured = 'provider_not_configured';
  static const String providerUnavailable = 'provider_unavailable';
  static const String invalidResponse = 'invalid_response';

  /// Client-side code for an unclassified provider failure. The gateway keeps
  /// the localized message key; this code is the stable presentation fallback.
  static const String researchFailed = 'research_failed';
}

/// The page size requested when reading the organization's run history.
const int kResearchRunPageSize = 20;
