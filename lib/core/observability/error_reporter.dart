import '../errors/app_error.dart';

abstract interface class ErrorReporter {
  Future<void> report(AppError error);
}

/// Removes common credential/PII-shaped values before diagnostics are stored.
class Redactor {
  Redactor._();

  static const Set<String> _sensitiveKeys = <String>{
    'password',
    'token',
    'access_token',
    'refresh_token',
    'authorization',
    'secret',
    'anon_key',
    'email',
    'phone',
  };

  static Map<String, Object?> map(Map<String, Object?> input) =>
      <String, Object?>{
        for (final MapEntry<String, Object?> entry in input.entries)
          entry.key: _value(entry.key, entry.value),
      };

  static Object? _value(String key, Object? value) {
    if (_sensitiveKeys.contains(key.toLowerCase())) {
      return '[REDACTED]';
    }
    if (value is String) {
      return value
          .replaceAll(
            RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'),
            '[REDACTED_EMAIL]',
          )
          .replaceAll(
            RegExp(r'Bearer\s+\S+', caseSensitive: false),
            'Bearer [REDACTED]',
          );
    }
    if (value is Map<String, Object?>) {
      return map(value);
    }
    if (value is List<Object?>) {
      return value
          .map(
            (Object? item) => item is Map<String, Object?> ? map(item) : item,
          )
          .toList();
    }
    return value;
  }
}

class ConsoleErrorReporter implements ErrorReporter {
  @override
  Future<void> report(AppError error) async {
    // Keep diagnostics limited to the sanitized map. Sentry/Supabase are
    // future integrations and must not be wired into the Flutter client here.
    // ignore: avoid_print
    print('LegalHub error: ${Redactor.map(error.toLogMap())}');
  }
}

class InMemoryErrorReporter implements ErrorReporter {
  final List<Map<String, Object?>> reports = <Map<String, Object?>>[];

  @override
  Future<void> report(AppError error) async {
    reports.add(Redactor.map(error.toLogMap()));
  }
}
