import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parity net for the bundled legal content, mirroring the ARB parity check.
///
/// A section that exists in English but not Arabic or Turkish would render as
/// a silently truncated policy in that locale. This fails the build before a
/// user ever reads a half-policy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, dynamic>> load(String code) async {
    final String raw = await rootBundle.loadString(
      'assets/legal/legal_$code.json',
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> sections(
    Map<String, dynamic> data,
    String document,
  ) => (data[document] as List<dynamic>)
      .map((dynamic raw) => raw as Map<String, dynamic>)
      .toList();

  List<String> idsOf(Map<String, dynamic> data, String document) => sections(
    data,
    document,
  ).map((Map<String, dynamic> row) => row['id'] as String).toList();

  test('all three locales declare identical section ids', () async {
    final Map<String, dynamic> en = await load('en');
    final Map<String, dynamic> ar = await load('ar');
    final Map<String, dynamic> tr = await load('tr');

    for (final String document in <String>['privacy', 'terms']) {
      final List<String> enIds = idsOf(en, document);
      expect(enIds, isNotEmpty, reason: '$document has no sections');

      for (final MapEntry<String, Map<String, dynamic>> locale
          in <String, Map<String, dynamic>>{'ar': ar, 'tr': tr}.entries) {
        expect(
          idsOf(locale.value, document),
          enIds,
          reason: '${locale.key} $document section ids differ from English',
        );
      }
    }
  });

  test('no section has an empty heading or empty paragraphs', () async {
    for (final String code in <String>['en', 'ar', 'tr']) {
      final Map<String, dynamic> data = await load(code);
      for (final String document in <String>['privacy', 'terms']) {
        for (final Map<String, dynamic> row in sections(data, document)) {
          final String id = row['id'] as String;
          expect(
            (row['heading'] as String).trim(),
            isNotEmpty,
            reason: '$code $document/$id has an empty heading',
          );
          final List<String> paragraphs = (row['paragraphs'] as List<dynamic>)
              .map((dynamic p) => p as String)
              .toList();
          expect(
            paragraphs,
            isNotEmpty,
            reason: '$code $document/$id has no paragraphs',
          );
          for (final String paragraph in paragraphs) {
            expect(
              paragraph.trim(),
              isNotEmpty,
              reason: '$code $document/$id has an empty paragraph',
            );
          }
        }
      }
    }
  });

  test('section ids are unique within a document', () async {
    final Map<String, dynamic> en = await load('en');
    for (final String document in <String>['privacy', 'terms']) {
      final List<String> ids = idsOf(en, document);
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'duplicate id in $document',
      );
    }
  });
}
