import 'dart:convert';
import 'dart:io';

final RegExp namedArg = RegExp(
  r'(userMessage|deniedMessage|validationMessage|unavailableMessage|failedMessage)'
  r"\s*:\s*'((?:[^'\\]|\\.)*)'",
);

final RegExp namedArgTernary = RegExp(
  r'(userMessage|deniedMessage|validationMessage|unavailableMessage|failedMessage)'
  r"\s*:\s*[A-Za-z_][A-Za-z0-9_]*\s*\?\s*'((?:[^'\\]|\\.)*)'\s*:\s*'((?:[^'\\]|\\.)*)'",
);

final RegExp namedArgStart = RegExp(
  r'(userMessage|deniedMessage|validationMessage|unavailableMessage|failedMessage)'
  r'\s*:\s*',
);

final RegExp messageForSwitch = RegExp(
  r'_messageFor\([^)]*\)\s*=>\s*switch \([^)]*\)\s*\{',
);

final RegExp stringLiteral = RegExp(r"'((?:[^'\\]|\\.)*)'");

const Set<String> ternaryInventoryFiles = <String>{
  'lib/data/discovery/supabase_attorney_gateway.dart',
};

String keyFor(String literal) {
  final List<String> words = literal
      .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .take(8)
      .toList();
  final String pascal = words
      .map((String w) => w[0].toUpperCase() + w.substring(1))
      .join();
  return 'err${pascal.isEmpty ? 'Message' : pascal}';
}

String decodeDartEscapes(String raw) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < raw.length; i++) {
    if (raw[i] != '\\' || i + 1 >= raw.length) {
      out.write(raw[i]);
      continue;
    }
    final String next = raw[i + 1];
    if (next == 'n') {
      out.write('\n');
    } else if (next == 'r') {
      out.write('\r');
    } else if (next == 't') {
      out.write('\t');
    } else if (next == 'b') {
      out.write('\b');
    } else if (next == 'f') {
      out.write('\f');
    } else if (next == 'v') {
      out.write('\v');
    } else if (next == '\\') {
      out.write('\\');
    } else if (next == "'") {
      out.write("'");
    } else if (next == '"') {
      out.write('"');
    } else if (next == r'$') {
      out.write(r'$');
    } else {
      out.write(raw[i]);
      out.write(next);
    }
    i++;
  }
  return out.toString();
}

String? unparsedReason(String rest) {
  if (rest.startsWith("r'") || rest.startsWith('r"')) {
    return 'raw string';
  }
  if (rest.startsWith("'''") || rest.startsWith('"""')) {
    return 'triple-quoted string';
  }
  if (rest.startsWith('"')) {
    return 'double-quoted string';
  }
  return null;
}

int lineOf(String content, int offset) =>
    '\n'.allMatches(content.substring(0, offset)).length + 1;

void record(Map<String, List<String>> target, String literal, String location) {
  target.putIfAbsent(literal, () => <String>[]).add(location);
}

void main() {
  stdout.encoding = utf8;
  final Map<String, List<String>> hits = <String, List<String>>{};
  final Map<String, List<String>> extras = <String, List<String>>{};
  final List<String> unparsed = <String>[];
  final List<File> files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  for (final File file in files) {
    final String path = file.path.replaceAll('\\', '/');
    if (path.contains('app_localizations') ||
        path.contains('app_message_key')) {
      continue;
    }
    final String content = file.readAsStringSync();
    final Set<int> consumed = <int>{};
    for (final RegExpMatch match in namedArg.allMatches(content)) {
      consumed.add(match.start);
      record(
        hits,
        decodeDartEscapes(match.group(2)!),
        '$path:${lineOf(content, match.start)}',
      );
    }
    if (ternaryInventoryFiles.contains(path)) {
      for (final RegExpMatch match in namedArgTernary.allMatches(content)) {
        consumed.add(match.start);
        final String location = '$path:${lineOf(content, match.start)}';
        record(hits, decodeDartEscapes(match.group(2)!), location);
        record(hits, decodeDartEscapes(match.group(3)!), location);
      }
    }
    final RegExpMatch? messageFor = messageForSwitch.firstMatch(content);
    if (messageFor != null) {
      final int end = content.indexOf('};', messageFor.end);
      final String body = content.substring(
        messageFor.end,
        end < 0 ? content.length : end,
      );
      for (final RegExpMatch match in stringLiteral.allMatches(body)) {
        record(
          extras,
          decodeDartEscapes(match.group(1)!),
          '$path:${lineOf(content, messageFor.end + match.start)}',
        );
      }
    }
    for (final RegExpMatch match in namedArgStart.allMatches(content)) {
      if (consumed.contains(match.start)) {
        continue;
      }
      final String rest = content.substring(match.end);
      final String? reason = unparsedReason(rest);
      if (reason == null) {
        continue;
      }
      final String preview = rest.split('\n').first.trim();
      unparsed.add(
        '$path:${lineOf(content, match.start)}\t${match.group(1)}\t$reason\t$preview',
      );
    }
  }
  final Map<String, int> used = <String, int>{};
  final List<String> literals = hits.keys.toList()..sort();
  stdout.writeln('literal\tkey\tcount\tfiles');
  for (final String literal in literals) {
    final String base = keyFor(literal);
    final int n = (used[base] ?? 0) + 1;
    used[base] = n;
    final String key = n == 1 ? base : '$base$n';
    final String escaped = literal.replaceAll('\t', ' ').replaceAll('\n', ' ');
    stdout.writeln(
      '$escaped\t$key\t${hits[literal]!.length}\t${hits[literal]!.join(',')}',
    );
  }
  stdout.writeln('# EXTRA — leave (presentation-mapped)');
  stdout.writeln('literal\tkey\tcount\tfiles');
  final List<String> extraLiterals = extras.keys.toList()..sort();
  for (final String literal in extraLiterals) {
    final String escaped = literal.replaceAll('\t', ' ').replaceAll('\n', ' ');
    stdout.writeln(
      '$escaped\t-\t${extras[literal]!.length}\t${extras[literal]!.join(',')}',
    );
  }
  stdout.writeln('# UNPARSED');
  if (unparsed.isEmpty) {
    stdout.writeln('# none');
  } else {
    for (final String entry in unparsed) {
      stdout.writeln(entry);
    }
  }
}
