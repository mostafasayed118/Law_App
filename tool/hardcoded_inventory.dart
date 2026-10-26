import 'dart:io';

class Rule {
  const Rule(this.name, this.pattern, {this.exempt = const <String>{}});
  final String name;
  final RegExp pattern;
  final Set<String> exempt;
}

final List<Rule> rules = <Rule>[
  Rule(
    'raw-color',
    RegExp(r'Color\(0x[0-9A-Fa-f]{6,8}\)'),
    exempt: <String>{'lib/app/legalhub_theme.dart'},
  ),
  Rule('material-color', RegExp(r'\bColors\.[a-zA-Z]+')),
  Rule(
    'motion-200-300ms',
    RegExp(r'Duration\(milliseconds:\s*(200|300)\)'),
    exempt: <String>{'lib/app/legalhub_motion.dart'},
  ),
  Rule(
    'timeout-15s',
    RegExp(r'Duration\(seconds:\s*15\)'),
    exempt: <String>{'lib/core/contracts/network.dart'},
  ),
  Rule('table-from', RegExp(r'from\(\x27([a-z_]+)\x27\)')),
  Rule('rpc-call', RegExp(r'rpc(?:<[^>]+>)?\(\x27([a-z_]+)\x27')),
  Rule('edge-invoke', RegExp(r'invoke\(\x27([a-z0-9-]+)\x27')),
  Rule('max-length', RegExp(r'maxLength:\s*(\d+)')),
  Rule('duration-seconds', RegExp(r'Duration\(seconds:\s*(\d+)\)')),
  Rule('raw-font-size', RegExp(r'fontSize:\s*(\d+)')),
  Rule(
    'failure-copy',
    RegExp(
      r'(userMessage|deniedMessage|validationMessage|unavailableMessage|failedMessage)'
      r'\s*:\s*\x27',
    ),
  ),
];

void main() {
  final List<File> files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .where((File f) => !f.path.contains('app_localizations'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  stdout.writeln('| rule | file:line | literal |');
  stdout.writeln('|---|---|---|');
  for (final File file in files) {
    final String relative = file.path.replaceAll('\\', '/');
    final List<String> lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      for (final Rule rule in rules) {
        if (rule.exempt.contains(relative)) {
          continue;
        }
        final RegExpMatch? match = rule.pattern.firstMatch(lines[i]);
        if (match != null) {
          final String literal = match.group(0)!.replaceAll('|', r'\|');
          stdout.writeln('| ${rule.name} | $relative:${i + 1} | `$literal` |');
        }
      }
    }
  }
}
