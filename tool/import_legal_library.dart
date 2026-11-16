// tool/import_legal_library.dart
//
// Offline importer for official legal text (ADR-0009).
//
// Reads a documented JSON file (docs/legal_library_import_schema.md), validates
// it, and prints a SQL script that inserts the rows. It never opens a network
// connection and never applies anything: the owner reviews the SQL and runs it
// against the dev project, then the production project, through the normal
// migration discipline.
//
// Usage:
//   dart run tool/import_legal_library.dart --input <file.json> > import.sql
//
// Exit codes: 0 = valid (SQL on stdout), 1 = validation failed (errors on
// stderr, no SQL emitted), 2 = bad invocation.
//
// Why a tool instead of hand-written INSERTs: the failure that matters here is
// a silent one — a document imported with six of its forty articles, or two
// articles sharing a number because of a copy-paste. The validator refuses the
// whole file on any such defect, so a partial import cannot happen by accident.

import 'dart:convert';
import 'dart:io';

/// Allowed values, mirroring the schema enums in
/// supabase/migrations/32_legal_library.sql. Kept as literals here because the
/// tool must not depend on Flutter or on generated code.
const Set<String> _sourceKinds = <String>{
  'statute',
  'regulation',
  'court_ruling',
};
const Set<String> _categories = <String>{
  'civil',
  'criminal',
  'labor',
  'commercial',
  'family',
  'administrative',
  'constitutional',
  'other',
};
const Set<String> _statuses = <String>{
  'in_force',
  'amended',
  'repealed',
  'unknown',
};

const int _maxTitleLength = 400;
const int _maxArticleNumberLength = 40;
const int _maxBodyLength = 20000;

Future<void> main(List<String> args) async {
  final String? inputPath = _argValue(args, '--input');
  if (inputPath == null) {
    stderr.writeln(
      'usage: dart run tool/import_legal_library.dart --input <file.json>',
    );
    exitCode = 2;
    return;
  }

  final File file = File(inputPath);
  if (!file.existsSync()) {
    stderr.writeln('input file not found: $inputPath');
    exitCode = 2;
    return;
  }

  final String raw = file.readAsStringSync();
  final List<String> errors = validateImportJson(raw);
  if (errors.isNotEmpty) {
    stderr.writeln('import rejected — ${errors.length} problem(s):');
    for (final String error in errors) {
      stderr.writeln('  - $error');
    }
    exitCode = 1;
    return;
  }

  final String sql = renderImportSql(raw);
  stdout.writeln(sql);

  final ImportedLibrary? library = parseImportJson(raw, <String>[]);
  if (library != null) {
    stderr.writeln(
      'validated: ${library.documents.length} document(s), '
      '${library.articles} article(s).',
    );
  }
}

/// Parses and validates [jsonText]. Returns every problem found; an empty list
/// means the file is importable.
///
/// Public so the validator can be tested directly: a tool whose only interface
/// is stdout is a tool whose failure modes are untested.
List<String> validateImportJson(String jsonText) {
  final List<String> errors = <String>[];
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException catch (e) {
    return <String>['invalid JSON: ${e.message}'];
  }
  _parse(decoded, errors);
  return errors;
}

/// Renders the SQL for a validated [jsonText].
///
/// Returns an empty string when the input is invalid — call
/// [validateImportJson] first if the reason matters. Emitting partial SQL for a
/// rejected file is the failure this tool exists to prevent, so there is no
/// "best effort" mode.
String renderImportSql(String jsonText) {
  final List<String> errors = <String>[];
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException {
    return '';
  }
  final ImportedLibrary? library = _parse(decoded, errors);
  if (library == null || errors.isNotEmpty) {
    return '';
  }
  return _sqlFor(library);
}

/// Returns the parsed library, or null when the input is invalid.
ImportedLibrary? parseImportJson(String jsonText, List<String> errors) {
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException catch (e) {
    errors.add('invalid JSON: ${e.message}');
    return null;
  }
  return _parse(decoded, errors);
}

String? _argValue(List<String> args, String name) {
  for (int i = 0; i < args.length; i++) {
    if (args[i] == name && i + 1 < args.length) {
      return args[i + 1];
    }
    if (args[i].startsWith('$name=')) {
      return args[i].substring(name.length + 1);
    }
  }
  return null;
}

// --- model -----------------------------------------------------------------

class ImportedLibrary {
  ImportedLibrary({required this.source, required this.documents});

  final ImportedSource source;
  final List<ImportedDocument> documents;

  int get articles => documents.fold(
    0,
    (int sum, ImportedDocument d) => sum + d.articles.length,
  );
}

class ImportedSource {
  ImportedSource({
    required this.nameAr,
    required this.kind,
    required this.jurisdiction,
    required this.isSample,
    this.nameEn,
  });

  final String nameAr;
  final String? nameEn;
  final String kind;
  final String jurisdiction;
  final bool isSample;
}

class ImportedDocument {
  ImportedDocument({
    required this.titleAr,
    required this.category,
    required this.status,
    required this.isSample,
    required this.articles,
    this.titleEn,
    this.officialNumber,
    this.year,
    this.summaryAr,
    this.publishedAt,
  });

  final String titleAr;
  final String? titleEn;
  final String? officialNumber;
  final int? year;
  final String category;
  final String status;
  final String? summaryAr;
  final String? publishedAt;
  final bool isSample;
  final List<ImportedArticle> articles;
}

class ImportedArticle {
  ImportedArticle({
    required this.articleNumber,
    required this.ordinal,
    required this.bodyAr,
    required this.isSample,
    this.headingAr,
  });

  final String articleNumber;
  final int ordinal;
  final String? headingAr;
  final String bodyAr;
  final bool isSample;
}

// --- validation ------------------------------------------------------------

ImportedLibrary? _parse(Object? decoded, List<String> errors) {
  if (decoded is! Map<String, dynamic>) {
    errors.add('root must be a JSON object');
    return null;
  }

  final Object? rawSource = decoded['source'];
  if (rawSource is! Map<String, dynamic>) {
    errors.add('missing "source" object');
    return null;
  }

  final ImportedSource? source = _parseSource(rawSource, errors);

  final Object? rawDocuments = decoded['documents'];
  if (rawDocuments is! List<dynamic>) {
    errors.add('missing "documents" array');
    return null;
  }
  if (rawDocuments.isEmpty) {
    errors.add('"documents" is empty — nothing to import');
    return null;
  }

  final List<ImportedDocument> documents = <ImportedDocument>[];
  for (int i = 0; i < rawDocuments.length; i++) {
    final Object? raw = rawDocuments[i];
    if (raw is! Map<String, dynamic>) {
      errors.add('documents[$i] must be an object');
      continue;
    }
    final ImportedDocument? document = _parseDocument(raw, i, errors);
    if (document != null) {
      documents.add(document);
    }
  }

  if (source == null || errors.isNotEmpty) {
    return null;
  }

  // Cross-document guard: the same title twice in one file is almost always a
  // copy-paste, and it would produce two indistinguishable rows.
  final Set<String> titles = <String>{};
  for (final ImportedDocument document in documents) {
    final String key = document.titleAr.trim();
    if (!titles.add(key)) {
      errors.add('document title appears twice: "$key"');
    }
  }

  return ImportedLibrary(source: source, documents: documents);
}

ImportedSource? _parseSource(Map<String, dynamic> raw, List<String> errors) {
  final String? nameAr = _requiredString(raw, 'name_ar', 'source', errors);
  final String? kind = _requiredString(raw, 'kind', 'source', errors);
  if (kind != null && !_sourceKinds.contains(kind)) {
    errors.add('source.kind "$kind" is not one of ${_sourceKinds.join(', ')}');
  }
  final String jurisdiction =
      (raw['jurisdiction'] as String?)?.trim().toUpperCase() ?? 'EG';
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(jurisdiction)) {
    errors.add(
      'source.jurisdiction must be a 2-letter code, got "$jurisdiction"',
    );
  }
  if (nameAr == null || kind == null) {
    return null;
  }
  return ImportedSource(
    nameAr: nameAr,
    nameEn: _optionalString(raw['name_en']),
    kind: kind,
    jurisdiction: jurisdiction,
    isSample: raw['is_sample'] == true,
  );
}

ImportedDocument? _parseDocument(
  Map<String, dynamic> raw,
  int index,
  List<String> errors,
) {
  final String where = 'documents[$index]';
  final String? titleAr = _requiredString(raw, 'title_ar', where, errors);
  if (titleAr != null && titleAr.length > _maxTitleLength) {
    errors.add('$where.title_ar exceeds $_maxTitleLength characters');
  }
  final String? category = _requiredString(raw, 'category', where, errors);
  if (category != null && !_categories.contains(category)) {
    errors.add(
      '$where.category "$category" is not one of ${_categories.join(', ')}',
    );
  }
  final String status = (raw['status'] as String?)?.trim() ?? 'unknown';
  if (!_statuses.contains(status)) {
    errors.add('$where.status "$status" is not one of ${_statuses.join(', ')}');
  }
  final Object? rawYear = raw['year'];
  int? year;
  if (rawYear != null) {
    if (rawYear is! int || rawYear < 1800 || rawYear > 2200) {
      errors.add('$where.year must be an integer between 1800 and 2200');
    } else {
      year = rawYear;
    }
  }

  final Object? rawArticles = raw['articles'];
  if (rawArticles is! List<dynamic> || rawArticles.isEmpty) {
    errors.add('$where.articles must be a non-empty array');
    return null;
  }

  final List<ImportedArticle> articles = <ImportedArticle>[];
  final Set<String> numbers = <String>{};
  final Set<int> ordinals = <int>{};
  final bool documentSample = raw['is_sample'] == true;

  for (int j = 0; j < rawArticles.length; j++) {
    final Object? rawArticle = rawArticles[j];
    final String articleWhere = '$where.articles[$j]';
    if (rawArticle is! Map<String, dynamic>) {
      errors.add('$articleWhere must be an object');
      continue;
    }
    final String? number = _requiredString(
      rawArticle,
      'article_number',
      articleWhere,
      errors,
    );
    final String? body = _requiredString(
      rawArticle,
      'body_ar',
      articleWhere,
      errors,
    );
    if (number != null && number.length > _maxArticleNumberLength) {
      errors.add(
        '$articleWhere.article_number exceeds $_maxArticleNumberLength characters',
      );
    }
    if (body != null && body.length > _maxBodyLength) {
      errors.add('$articleWhere.body_ar exceeds $_maxBodyLength characters');
    }
    final Object? rawOrdinal = rawArticle['ordinal'] ?? (j + 1);
    if (rawOrdinal is! int || rawOrdinal < 1) {
      errors.add('$articleWhere.ordinal must be a positive integer');
      continue;
    }
    if (number != null) {
      if (!numbers.add(number.trim())) {
        errors.add('$where has a duplicate article_number "$number"');
      }
    }
    if (!ordinals.add(rawOrdinal)) {
      errors.add('$where has a duplicate ordinal $rawOrdinal');
    }
    if (number == null || body == null || body.trim().isEmpty) {
      continue;
    }
    articles.add(
      ImportedArticle(
        articleNumber: number.trim(),
        ordinal: rawOrdinal,
        headingAr: _optionalString(rawArticle['heading_ar']),
        bodyAr: body,
        // An article may not claim to be official while its document is
        // sample, or vice versa: the flag is inherited unless explicitly set.
        isSample: rawArticle['is_sample'] as bool? ?? documentSample,
      ),
    );
  }

  if (titleAr == null || category == null) {
    return null;
  }
  return ImportedDocument(
    titleAr: titleAr,
    titleEn: _optionalString(raw['title_en']),
    officialNumber: _optionalString(raw['official_number']),
    year: year,
    category: category,
    status: status,
    summaryAr: _optionalString(raw['summary_ar']),
    publishedAt: _optionalString(raw['published_at']),
    isSample: documentSample,
    articles: articles,
  );
}

String? _requiredString(
  Map<String, dynamic> row,
  String key,
  String where,
  List<String> errors,
) {
  final Object? value = row[key];
  if (value is! String || value.trim().isEmpty) {
    errors.add('$where.$key is required and must be a non-empty string');
    return null;
  }
  return value.trim();
}

String? _optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

// --- SQL emission ----------------------------------------------------------

String _sqlFor(ImportedLibrary library) {
  final StringBuffer out = StringBuffer();
  final ImportedSource source = library.source;

  out.writeln(
    '-- Generated by tool/import_legal_library.dart — review before running.',
  );
  out.writeln('-- Source: ${source.nameAr}');
  out.writeln(
    '-- Documents: ${library.documents.length} · Articles: ${library.articles}',
  );
  out.writeln(
    '-- Sample data: ${source.isSample ? 'YES — invented content' : 'no'}',
  );
  out.writeln('begin;');
  out.writeln();
  out.writeln('do \$\$');
  out.writeln('declare');
  out.writeln('  v_source uuid;');
  out.writeln('  v_document uuid;');
  out.writeln('begin');
  out.writeln('  select id into v_source');
  out.writeln('    from public.legal_sources');
  out.writeln(
    '   where name_ar = ${_quote(source.nameAr)}'
    ' and jurisdiction = ${_quote(source.jurisdiction)};',
  );
  out.writeln('  if v_source is null then');
  out.writeln('    insert into public.legal_sources');
  out.writeln('      (name_ar, name_en, kind, jurisdiction, is_sample)');
  out.writeln(
    '    values (${_quote(source.nameAr)}, ${_nullable(source.nameEn)}, '
    '${_quote(source.kind)}, ${_quote(source.jurisdiction)}, ${source.isSample});',
  );
  out.writeln('    select id into v_source');
  out.writeln('      from public.legal_sources');
  out.writeln(
    '     where name_ar = ${_quote(source.nameAr)}'
    ' and jurisdiction = ${_quote(source.jurisdiction)};',
  );
  out.writeln('  end if;');
  out.writeln();

  for (final ImportedDocument document in library.documents) {
    out.writeln('  -- ${document.titleAr}');
    out.writeln('  select id into v_document');
    out.writeln('    from public.legal_documents');
    out.writeln('   where source_id = v_source');
    out.writeln('     and title_ar = ${_quote(document.titleAr)};');
    out.writeln('  if v_document is null then');
    out.writeln('    insert into public.legal_documents');
    out.writeln(
      '      (source_id, title_ar, title_en, official_number, year, category, '
      'status, summary_ar, published_at, is_sample)',
    );
    out.writeln(
      '    values (v_source, ${_quote(document.titleAr)}, '
      '${_nullable(document.titleEn)}, ${_nullable(document.officialNumber)}, '
      '${document.year ?? 'null'}, ${_quote(document.category)}, '
      '${_quote(document.status)}, ${_nullable(document.summaryAr)}, '
      '${_nullableDate(document.publishedAt)}, ${document.isSample})',
    );
    out.writeln('    returning id into v_document;');
    for (final ImportedArticle article in document.articles) {
      out.writeln('    insert into public.legal_articles');
      out.writeln(
        '      (document_id, article_number, ordinal, heading_ar, body_ar, is_sample)',
      );
      out.writeln(
        '    values (v_document, ${_quote(article.articleNumber)}, '
        '${article.ordinal}, ${_nullable(article.headingAr)}, '
        '${_quote(article.bodyAr)}, ${article.isSample});',
      );
    }
    out.writeln('  else');
    out.writeln(
      "    raise notice 'skipped existing document: %', ${_quote(document.titleAr)};",
    );
    out.writeln('  end if;');
    out.writeln();
  }

  out.writeln('end \$\$;');
  out.writeln();
  out.writeln('commit;');
  return out.toString();
}

String _quote(String value) => "'${value.replaceAll("'", "''")}'";

String _nullable(String? value) => value == null ? 'null' : _quote(value);

String _nullableDate(String? value) =>
    value == null ? 'null' : '${_quote(value)}::date';
