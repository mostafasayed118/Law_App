/// Offset conversion between Flutter (UTF-16 code units) and Postgres
/// (characters / Unicode code points) — ADR-0010.
///
/// `TextSelection` reports UTF-16 offsets. Postgres `substring(text from start
/// for len)` counts **characters**. For Arabic (BMP) the two agree, but an
/// article body may legitimately contain a surrogate pair — an emoji in a
/// heading, a rare symbol — and on that row a naive hand-off would shift every
/// highlight in the article by one per astral character.
///
/// The library therefore stores **rune offsets** and converts at both
/// boundaries. These helpers are the only place the conversion lives.
library;

/// Converts a UTF-16 offset into a rune (code point) offset.
///
/// An offset that splits a surrogate pair is clamped to the start of that
/// character: a highlight may not begin or end inside one.
int runeOffsetOf(String text, int utf16Offset) {
  if (utf16Offset <= 0) {
    return 0;
  }
  if (utf16Offset >= text.length) {
    return text.runes.length;
  }
  int utf16 = 0;
  int runes = 0;
  for (final int codePoint in text.runes) {
    final int width = codePoint > 0xFFFF ? 2 : 1;
    if (utf16 + width > utf16Offset) {
      return runes;
    }
    utf16 += width;
    runes++;
  }
  return runes;
}

/// Converts a rune offset back into a UTF-16 offset, for rendering.
int utf16OffsetOf(String text, int runeOffset) {
  if (runeOffset <= 0) {
    return 0;
  }
  int runes = 0;
  int utf16 = 0;
  for (final int codePoint in text.runes) {
    if (runes >= runeOffset) {
      return utf16;
    }
    utf16 += codePoint > 0xFFFF ? 2 : 1;
    runes++;
  }
  return utf16;
}

/// Substrings [text] by rune offsets, end-exclusive.
///
/// Mirrors Postgres `substring(text from start + 1 for end - start)`, which is
/// what `create_legal_highlight` verifies against.
String substringByRunes(String text, int startRune, int endRune) {
  final List<int> runes = text.runes.toList(growable: false);
  final int start = startRune.clamp(0, runes.length);
  final int end = endRune.clamp(start, runes.length);
  return String.fromCharCodes(runes.sublist(start, end));
}
