import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import on purpose: the importer is a command-line tool, not a
// package library, and the test's job is to pin the validation contract that
// protects a real import from a silent partial.
import '../../tool/import_legal_library.dart';

/// Builds a minimal valid file, with overrides so each test can break exactly
/// one thing.
String fileWith({
  Map<String, dynamic>? source,
  List<Map<String, dynamic>>? documents,
}) {
  return jsonEncode(<String, dynamic>{
    'source':
        source ??
        <String, dynamic>{
          'name_ar': 'مصدر',
          'kind': 'statute',
          'jurisdiction': 'EG',
          'is_sample': true,
        },
    'documents':
        documents ??
        <Map<String, dynamic>>[
          <String, dynamic>{
            'title_ar': 'وثيقة',
            'category': 'civil',
            'status': 'in_force',
            'is_sample': true,
            'articles': <Map<String, dynamic>>[
              <String, dynamic>{
                'article_number': '1',
                'ordinal': 1,
                'body_ar': 'نص المادة الأولى',
              },
            ],
          },
        ],
  });
}

Map<String, dynamic> documentWith({
  String titleAr = 'وثيقة',
  List<Map<String, dynamic>>? articles,
}) {
  return <String, dynamic>{
    'title_ar': titleAr,
    'category': 'civil',
    'status': 'in_force',
    'is_sample': true,
    'articles':
        articles ??
        <Map<String, dynamic>>[
          <String, dynamic>{
            'article_number': '1',
            'ordinal': 1,
            'body_ar': 'نص',
          },
        ],
  };
}

void main() {
  group('validateImportJson', () {
    test('accepts the bundled example file', () {
      final String raw = File(
        'tool/fixtures/legal_library_example.json',
      ).readAsStringSync();
      expect(validateImportJson(raw), isEmpty);
    });

    test('rejects malformed JSON', () {
      expect(validateImportJson('{ nope'), isNotEmpty);
    });

    test('rejects a file with no documents', () {
      expect(
        validateImportJson(fileWith(documents: <Map<String, dynamic>>[])),
        contains(contains('empty')),
      );
    });

    test('rejects a missing title', () {
      final Map<String, dynamic> doc = documentWith();
      doc.remove('title_ar');
      expect(
        validateImportJson(fileWith(documents: <Map<String, dynamic>>[doc])),
        contains(contains('title_ar')),
      );
    });

    test('rejects an unknown category', () {
      final Map<String, dynamic> doc = documentWith()
        ..['category'] = 'space_law';
      expect(
        validateImportJson(fileWith(documents: <Map<String, dynamic>>[doc])),
        contains(contains('category')),
      );
    });

    test('rejects an unknown source kind', () {
      expect(
        validateImportJson(
          fileWith(source: <String, dynamic>{'name_ar': 'م', 'kind': 'decree'}),
        ),
        contains(contains('kind')),
      );
    });

    test('rejects a bad jurisdiction code', () {
      expect(
        validateImportJson(
          fileWith(
            source: <String, dynamic>{
              'name_ar': 'م',
              'kind': 'statute',
              'jurisdiction': 'Egypt',
            },
          ),
        ),
        contains(contains('jurisdiction')),
      );
    });

    test('rejects duplicate article numbers within one document', () {
      final Map<String, dynamic> doc = documentWith(
        articles: <Map<String, dynamic>>[
          <String, dynamic>{
            'article_number': '5',
            'ordinal': 1,
            'body_ar': 'أ',
          },
          <String, dynamic>{
            'article_number': '5',
            'ordinal': 2,
            'body_ar': 'ب',
          },
        ],
      );
      expect(
        validateImportJson(fileWith(documents: <Map<String, dynamic>>[doc])),
        contains(contains('duplicate article_number')),
      );
    });

    test('rejects duplicate ordinals within one document', () {
      final Map<String, dynamic> doc = documentWith(
        articles: <Map<String, dynamic>>[
          <String, dynamic>{
            'article_number': '1',
            'ordinal': 3,
            'body_ar': 'أ',
          },
          <String, dynamic>{
            'article_number': '2',
            'ordinal': 3,
            'body_ar': 'ب',
          },
        ],
      );
      expect(
        validateImportJson(fileWith(documents: <Map<String, dynamic>>[doc])),
        contains(contains('duplicate ordinal')),
      );
    });

    test('rejects an empty body', () {
      final Map<String, dynamic> doc = documentWith(
        articles: <Map<String, dynamic>>[
          <String, dynamic>{
            'article_number': '1',
            'ordinal': 1,
            'body_ar': '   ',
          },
        ],
      );
      expect(
        validateImportJson(fileWith(documents: <Map<String, dynamic>>[doc])),
        contains(contains('body_ar')),
      );
    });

    test('rejects the same document title twice', () {
      expect(
        validateImportJson(
          fileWith(
            documents: <Map<String, dynamic>>[documentWith(), documentWith()],
          ),
        ),
        contains(contains('appears twice')),
      );
    });

    test('accepts a "5 مكرر" article number', () {
      final Map<String, dynamic> doc = documentWith(
        articles: <Map<String, dynamic>>[
          <String, dynamic>{
            'article_number': '5 مكرر',
            'ordinal': 6,
            'body_ar': 'نص',
          },
        ],
      );
      expect(
        validateImportJson(fileWith(documents: <Map<String, dynamic>>[doc])),
        isEmpty,
      );
    });
  });

  group('renderImportSql', () {
    test(
      'emits a transaction that resolves the source before the documents',
      () {
        final String sql = renderImportSql(
          fileWith(documents: <Map<String, dynamic>>[documentWith()]),
        );
        expect(sql, startsWith('-- Generated by'));
        expect(sql, contains('begin;'));
        expect(sql, contains('commit;'));
        expect(sql, contains('legal_sources'));
        expect(sql, contains('legal_documents'));
        expect(sql, contains('legal_articles'));
        // Skip-don't-duplicate: a re-run reports the existing document.
        expect(sql, contains('skipped existing document'));
      },
    );

    test('doubles single quotes so an apostrophe cannot break out', () {
      final Map<String, dynamic> doc = documentWith(
        articles: <Map<String, dynamic>>[
          <String, dynamic>{
            'article_number': '1',
            'ordinal': 1,
            'body_ar': "نص فيه ' علامة اقتباس",
          },
        ],
      );
      final String sql = renderImportSql(
        fileWith(documents: <Map<String, dynamic>>[doc]),
      );
      expect(sql, contains("''"));
    });

    test('emits nothing for an invalid file', () {
      expect(renderImportSql('{}'), isEmpty);
      expect(
        renderImportSql(fileWith(documents: <Map<String, dynamic>>[])),
        isEmpty,
      );
    });
  });
}
