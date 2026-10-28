/// Shared row readers for raw provider maps.
///
/// Every accessor names the offending key in its [FormatException] so provider
/// drift surfaces as a typed failure instead of a raw cast error.
library;

/// Returns [row]'s string at [key].
///
/// Rejects blank values by default; [allowWhitespaceOnly] preserves readers
/// that reject only the empty string.
String requiredString(
  Map<String, dynamic> row,
  String key, {
  bool allowWhitespaceOnly = false,
}) {
  final Object? value = row[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Row has no $key');
  }
  if (!allowWhitespaceOnly && value.trim().isEmpty) {
    throw FormatException('Row has no $key');
  }
  return value;
}

/// Returns [value] trimmed, or null when it is not a non-blank string.
String? optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Returns [row]'s parsed date at [key].
DateTime requiredDate(Map<String, dynamic> row, String key) {
  final Object? value = row[key];
  if (value is! String) {
    throw FormatException('Row has no $key');
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Row has an invalid $key');
  }
  return parsed;
}

/// Returns [value] parsed as a date, or null when absent or blank.
DateTime? optionalDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const FormatException('Row has an invalid date');
  }
  return parsed;
}

/// Extracts the plain map rows from a list-shaped provider payload, skipping
/// non-list payloads and non-map entries.
List<Map<String, dynamic>> rowsFrom(Object? data) {
  if (data is! List<dynamic>) {
    return const <Map<String, dynamic>>[];
  }
  return data.whereType<Map<String, dynamic>>().toList(growable: false);
}
