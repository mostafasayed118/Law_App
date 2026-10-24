/// Trims [value] and collapses a blank result to null.
///
/// Write payloads treat "no note/description" as null rather than an empty
/// string, so the server receives one canonical absent value.
String? trimOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
