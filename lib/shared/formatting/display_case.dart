import 'dart:ui';

/// Locale-aware uppercase for display styling (labels, chips, badges).
///
/// Dart's `String.toUpperCase()` uses Unicode simple case mapping, which is
/// wrong for Turkish display text: "i" becomes "I" (dotless capital) where
/// the locale-correct form is "İ" (dotted capital I), and the lowercase
/// dotless "ı" must become "I". RTL scripts (Arabic) are unaffected.
///
/// Use this for styling-only uppercase where the text can render under the
/// Turkish locale; never for canonicalization or matching.
String displayUppercase(String text, Locale locale) {
  if (locale.languageCode != 'tr') {
    return text.toUpperCase();
  }
  final StringBuffer buffer = StringBuffer();
  for (final int code in text.runes) {
    switch (code) {
      case 0x69: // 'i' -> 'İ' (dotted capital I)
        buffer.writeCharCode(0x0130);
      case 0x131: // 'ı' (dotless i) -> 'I' (dotless capital I)
        buffer.writeCharCode(0x49);
      default:
        buffer.write(String.fromCharCode(code).toUpperCase());
    }
  }
  return buffer.toString();
}
