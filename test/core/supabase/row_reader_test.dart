import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/supabase/row_reader.dart';

void main() {
  group('requiredString', () {
    test('returns the raw string, untrimmed', () {
      expect(requiredString(<String, dynamic>{'id': ' a1 '}, 'id'), ' a1 ');
    });

    test('throws a key-naming FormatException when absent', () {
      expect(
        () => requiredString(<String, dynamic>{}, 'id'),
        throwsA(
          isA<FormatException>().having(
            (FormatException error) => error.message,
            'message',
            contains('id'),
          ),
        ),
      );
    });

    test('throws when the value is not a string', () {
      expect(
        () => requiredString(<String, dynamic>{'id': 1}, 'id'),
        throwsFormatException,
      );
    });

    test('rejects blank strings by default', () {
      expect(
        () => requiredString(<String, dynamic>{'id': '   '}, 'id'),
        throwsFormatException,
      );
    });

    test('allowWhitespaceOnly preserves the lenient legacy check', () {
      expect(
        requiredString(
          <String, dynamic>{'id': '   '},
          'id',
          allowWhitespaceOnly: true,
        ),
        '   ',
      );
      expect(
        () => requiredString(
          <String, dynamic>{'id': ''},
          'id',
          allowWhitespaceOnly: true,
        ),
        throwsFormatException,
      );
    });
  });

  group('optionalString', () {
    test('returns null for absent, non-string, or blank values', () {
      expect(optionalString(null), isNull);
      expect(optionalString(1), isNull);
      expect(optionalString(''), isNull);
      expect(optionalString('   '), isNull);
    });

    test('returns the trimmed value', () {
      expect(optionalString(' a1 '), 'a1');
    });
  });

  group('requiredDate', () {
    test('parses without converting the time zone', () {
      final DateTime parsed = requiredDate(<String, dynamic>{
        'at': '2024-01-02T03:04:05Z',
      }, 'at');
      expect(parsed, DateTime.utc(2024, 1, 2, 3, 4, 5));
      expect(parsed.isUtc, isTrue);
    });

    test('names the key when absent or not a string', () {
      expect(
        () => requiredDate(<String, dynamic>{}, 'at'),
        throwsA(
          isA<FormatException>().having(
            (FormatException error) => error.message,
            'message',
            contains('at'),
          ),
        ),
      );
      expect(
        () => requiredDate(<String, dynamic>{'at': 1}, 'at'),
        throwsFormatException,
      );
    });

    test('names the key when unparseable', () {
      expect(
        () => requiredDate(<String, dynamic>{'at': 'not-a-date'}, 'at'),
        throwsA(
          isA<FormatException>().having(
            (FormatException error) => error.message,
            'message',
            allOf(contains('at'), contains('invalid')),
          ),
        ),
      );
    });
  });

  group('optionalDate', () {
    test('returns null for absent or blank values', () {
      expect(optionalDate(null), isNull);
      expect(optionalDate(1), isNull);
      expect(optionalDate(''), isNull);
    });

    test('parses without converting the time zone', () {
      final DateTime? parsed = optionalDate('2024-01-02T03:04:05Z');
      expect(parsed, DateTime.utc(2024, 1, 2, 3, 4, 5));
      expect(parsed!.isUtc, isTrue);
    });

    test('throws on an unparseable value', () {
      expect(() => optionalDate('not-a-date'), throwsFormatException);
    });
  });

  group('rowsFrom', () {
    test('returns an empty list for null or a non-list payload', () {
      expect(rowsFrom(null), isEmpty);
      expect(rowsFrom('rows'), isEmpty);
      expect(rowsFrom(<String, dynamic>{'id': 'a1'}), isEmpty);
    });

    test('keeps the plain map rows and skips non-map entries', () {
      final Map<String, dynamic> row = <String, dynamic>{'id': 'a1'};
      final List<Map<String, dynamic>> rows = rowsFrom(<Object?>[
        row,
        1,
        null,
        'x',
      ]);
      expect(rows, hasLength(1));
      expect(rows.single, same(row));
    });

    test('returns a fixed-length list', () {
      final List<Map<String, dynamic>> rows = rowsFrom(<Object?>[
        <String, dynamic>{'id': 'a1'},
      ]);
      expect(() => rows.add(<String, dynamic>{}), throwsUnsupportedError);
    });
  });
}
