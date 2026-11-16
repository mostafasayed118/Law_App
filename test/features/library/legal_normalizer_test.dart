import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/library/domain/legal_normalizer.dart';

/// The Dart port of `public.legal_normalize_ar` must behave exactly like the
/// SQL function, because the demo gateway searches with this one and the
/// server builds its index with that one. Each case here has a counterpart in
/// `supabase/tests/27_legal_library_rls.sql`.
void main() {
  group('normalizeArabic', () {
    test('strips tashkeel (harakat)', () {
      expect(normalizeArabic('الإيجَار'), normalizeArabic('الإيجار'));
      expect(normalizeArabic('مُحَمَّد'), 'محمد');
    });

    test('strips tatweel (kashida)', () {
      expect(normalizeArabic('ايـــجار'), 'ايجار');
    });

    test('folds the alef variants to bare alef', () {
      expect(normalizeArabic('أ'), 'ا');
      expect(normalizeArabic('إ'), 'ا');
      expect(normalizeArabic('آ'), 'ا');
      expect(normalizeArabic('ٱ'), 'ا');
      expect(normalizeArabic('أحكام'), normalizeArabic('احكام'));
    });

    test('folds alef maqsura to ya', () {
      expect(normalizeArabic('مصطفى'), 'مصطفي');
      expect(normalizeArabic('على'), 'علي');
    });

    test('folds ta marbuta to ha', () {
      expect(normalizeArabic('لائحة'), 'لائحه');
      expect(normalizeArabic('مادة'), 'ماده');
    });

    test('lowercases Latin text', () {
      expect(normalizeArabic('Lease LAW'), 'lease law');
    });

    test('collapses whitespace and trims', () {
      expect(normalizeArabic('  عقد    الإيجار  '), 'عقد الايجار');
      expect(normalizeArabic('\n\tمادة\n'), 'ماده');
    });

    test('is idempotent', () {
      const String input = 'الإيجَار التجريبي';
      final String once = normalizeArabic(input);
      expect(normalizeArabic(once), once);
    });

    test('returns an empty string for empty input', () {
      expect(normalizeArabic(''), '');
      expect(normalizeArabic('   '), '');
    });

    test('does not stem: a different root stays a different token', () {
      // A stemmer would collapse these; an orthographic fold must not.
      expect(normalizeArabic('ايجار'), isNot(normalizeArabic('مؤجر')));
    });
  });

  group('stripArabicArticle', () {
    test('removes the leading article from each word', () {
      expect(stripArabicArticle('الايجار'), 'ايجار');
      expect(stripArabicArticle('عقد الايجار'), 'عقد ايجار');
    });

    test('leaves words without the article untouched', () {
      expect(stripArabicArticle('عقد مكتوب'), 'عقد مكتوب');
    });

    test('only strips the article at a word start, not mid-word', () {
      // "مال" contains "ال" but not at a word start.
      expect(stripArabicArticle('مال'), 'مال');
    });
  });

  group('legalSearchText', () {
    test('carries both the plain and the article-stripped form', () {
      final String text = legalSearchText('عقد الإيجار');
      expect(text, contains('عقد الايجار'));
      expect(text, contains('عقد ايجار'));
    });
  });

  group('searchTokens', () {
    test('normalises and splits on whitespace', () {
      expect(searchTokens('عقد  الإيجار'), <String>['عقد', 'الايجار']);
    });

    test('drops punctuation', () {
      expect(searchTokens('الإيجار، الجديد.'), <String>['الايجار', 'الجديد']);
    });

    test('returns an empty list for punctuation-only input', () {
      expect(searchTokens('!!!'), isEmpty);
      expect(searchTokens('،؛'), isEmpty);
      expect(searchTokens(''), isEmpty);
    });
  });
}
