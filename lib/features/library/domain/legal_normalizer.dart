/// Arabic orthographic normalisation — the Dart port of
/// `public.legal_normalize_ar(text)` in
/// `supabase/migrations/32_legal_library.sql` (ADR-0009).
///
/// The two implementations must stay semantically identical: the server builds
/// `search_text` with the SQL function and the demo gateway searches with this
/// one, so a divergence would make the same query behave differently in a
/// configured build and in the credential-free one. The unit tests pin the
/// cases both share.
///
/// What it does: strips tashkeel (harakat), Quranic annotation marks and the
/// superscript alef; removes tatweel; folds the alef variants and the
/// alef-maqsura; folds ta-marbuta to ha; lowercases Latin; collapses runs of
/// whitespace.
///
/// What it deliberately does NOT do: stemming, root extraction, or removal of
/// the Arabic definite article from the indexed text. It is an orthographic
/// fold, not a morphological analyser — a stemming decision is a linguistic
/// commitment this module does not make.
library;

const Set<int> _tashkeel = <int>{
  0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650, 0x0651, 0x0652, //
  0x0653, 0x0654, 0x0655, 0x0656, 0x0657, 0x0658, 0x0659, 0x065A,
  0x065B, 0x065C, 0x065D, 0x065E, 0x065F, 0x0670, 0x06D6, 0x06D7,
  0x06D8, 0x06D9, 0x06DA, 0x06DB, 0x06DC, 0x06DD, 0x06DE, 0x06DF,
  0x06E0, 0x06E1, 0x06E2, 0x06E3, 0x06E4, 0x06E5, 0x06E6, 0x06E7,
  0x06E8, 0x06E9, 0x06EA, 0x06EB, 0x06EC, 0x06ED,
};

const int _tatweel = 0x0640;
const int _alef = 0x0627;
const int _alefMaqsura = 0x0649;
const int _ya = 0x064A;
const int _taMarbuta = 0x0629;
const int _ha = 0x0647;

/// Folds [input] to its searchable form. Never returns a value containing
/// leading, trailing or repeated spaces.
String normalizeArabic(String input) {
  final StringBuffer buffer = StringBuffer();
  final String lowered = input.toLowerCase();

  for (final int rune in lowered.runes) {
    if (_tashkeel.contains(rune) || rune == _tatweel) {
      continue;
    }
    switch (rune) {
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0622: // آ
      case 0x0671: // ٱ
        buffer.writeCharCode(_alef);
      case _alefMaqsura:
        buffer.writeCharCode(_ya);
      case _taMarbuta:
        buffer.writeCharCode(_ha);
      default:
        buffer.writeCharCode(rune);
    }
  }

  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Removes a leading Arabic definite article from every word.
///
/// This is the Dart port of the SQL `regexp_replace(..., '\mال', '', 'g')`
/// used to build the article-stripped half of `search_text`. It is a
/// convenience for search, never applied to displayed text: "الايجار" renders
/// as written and only matches as "ايجار".
String stripArabicArticle(String input) {
  return input.replaceAllMapped(
    RegExp('(^|\\s)\u0627\u0644'),
    (Match match) => match.group(1) ?? '',
  );
}

/// The exact string the server stores in `search_text` for [input]: the
/// normalised text followed by the normalised article-stripped text.
///
/// Indexing both halves is what lets a bare "ايجار" reach "الايجار" without a
/// stemmer.
String legalSearchText(String input) =>
    '${normalizeArabic(input)} ${normalizeArabic(stripArabicArticle(input))}';

/// Splits [query] into normalised, punctuation-free tokens.
///
/// Mirrors the server's tokenisation step: normalise, split on whitespace, drop
/// anything that is not a letter or a digit. The character class is spelled out
/// rather than expressed as `\u0600-\u06FF` because that block also contains
/// Arabic punctuation (U+060C "،", U+061B "؛", U+061F "؟"), which the server's
/// `[[:alnum:]]` excludes and which must not survive as a token here. A query
/// of only punctuation yields an empty list, which the search surfaces treat as
/// "no query".
List<String> searchTokens(String query) {
  final String normalized = normalizeArabic(query);
  return normalized
      .split(' ')
      .map(
        (String token) => token.replaceAll(
          RegExp(
            '[^0-9A-Za-z'
            '\u0621-\u063A\u0641-\u064A' // Arabic letters (no punctuation)
            '\u0660-\u0669\u06F0-\u06F9' // Arabic-Indic and extended digits
            '\u0671-\u06D3' // alef wasla .. heh goal (stops before U+06D4)
            ']',
          ),
          '',
        ),
      )
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
}
