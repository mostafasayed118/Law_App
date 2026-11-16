import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/library/domain/highlight_offsets.dart';

/// Offset conversion is the boundary between Flutter (UTF-16) and Postgres
/// (characters). Arabic is BMP so the two agree — until an article heading holds
/// an emoji or another astral character, at which point every highlight after it
/// shifts. These tests pin the conversion, not just the happy path.
void main() {
  group('runeOffsetOf', () {
    test('is the identity for pure-ASCII text', () {
      expect(runeOffsetOf('hello', 0), 0);
      expect(runeOffsetOf('hello', 3), 3);
      expect(runeOffsetOf('hello', 5), 5);
    });

    test('is the identity for Arabic text (all BMP)', () {
      const String arabic = 'ينظم هذا النص عقد الإيجار';
      expect(runeOffsetOf(arabic, 0), 0);
      expect(runeOffsetOf(arabic, 5), 5);
      expect(runeOffsetOf(arabic, arabic.length), arabic.runes.length);
    });

    test('counts an astral character as one rune, not two', () {
      // '😀' is a surrogate pair in UTF-16: length 2, one rune.
      const String text = '😀abc';
      expect(text.length, 5);
      expect(text.runes.length, 4);
      expect(runeOffsetOf(text, 0), 0);
      expect(runeOffsetOf(text, 2), 1);
      expect(runeOffsetOf(text, 3), 2);
      expect(runeOffsetOf(text, 5), 4);
    });

    test('clamps an offset that splits a surrogate pair to the rune start', () {
      const String text = '😀abc';
      // Offset 1 is inside the emoji; a highlight may not start there.
      expect(runeOffsetOf(text, 1), 0);
    });

    test('clamps out-of-range offsets', () {
      expect(runeOffsetOf('abc', -5), 0);
      expect(runeOffsetOf('abc', 99), 3);
    });
  });

  group('utf16OffsetOf', () {
    test('round-trips with runeOffsetOf', () {
      const String text = 'عقد 😀 الإيجار';
      for (int rune = 0; rune <= text.runes.length; rune++) {
        final int utf16 = utf16OffsetOf(text, rune);
        expect(runeOffsetOf(text, utf16), rune, reason: 'rune $rune');
      }
    });

    test('skips two UTF-16 units for an astral character', () {
      const String text = '😀a';
      expect(utf16OffsetOf(text, 0), 0);
      expect(utf16OffsetOf(text, 1), 2);
      expect(utf16OffsetOf(text, 2), 3);
    });
  });

  group('substringByRunes', () {
    test('matches what the server verifies for Arabic text', () {
      const String body =
          'المادة الأولى: ينظم هذا النص عقد الإيجار بين الأطراف.';
      // Select the first five characters the way the server counts them.
      expect(substringByRunes(body, 0, 5), body.substring(0, 5));
      expect(substringByRunes(body, 0, 5).length, 5);
    });

    test('does not split a surrogate pair', () {
      const String text = '😀abc';
      expect(substringByRunes(text, 0, 1), '😀');
      expect(substringByRunes(text, 1, 4), 'abc');
    });

    test('clamps out-of-range spans', () {
      expect(substringByRunes('abc', -1, 99), 'abc');
      expect(substringByRunes('abc', 2, 1), '');
    });
  });
}
