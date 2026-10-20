import 'package:flutter/foundation.dart';

import '../errors/app_error.dart';

abstract interface class ErrorReporter {
  Future<void> report(AppError error);
}

/// Removes common credential/PII-shaped values before diagnostics are stored.
class Redactor {
  Redactor._();

  static const Set<String> _sensitiveKeys = <String>{
    'password',
    'new_password',
    'newpassword',
    'otp',
    'token',
    'access_token',
    'refresh_token',
    'authorization',
    'secret',
    'anon_key',
    'api_key',
    'supabase_url',
    'supabase_anon_key',
    'service_role',
    'pass',
    'pwd',
    'email',
    'phone',
  };

  static final RegExp _emailPattern = RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}');
  static final RegExp _bearerPattern = RegExp(
    r'Bearer\s+\S+',
    caseSensitive: false,
  );

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
          .replaceAll(_emailPattern, '[REDACTED_EMAIL]')
          .replaceAll(_bearerPattern, 'Bearer [REDACTED]');
    }
    if (value is Map) {
      return <String, Object?>{
        for (final MapEntry<dynamic, dynamic> entry in value.entries)
          '${entry.key}': _value('${entry.key}', entry.value),
      };
    }
    if (value is List) {
      return value
          .map((dynamic item) => item is Map ? _value('', item) : item)
          .toList();
    }
    return value;
  }
}

class ConsoleErrorReporter implements ErrorReporter {
  ConsoleErrorReporter({void Function(String? message, {int? wrapWidth})? sink})
    : sink = sink ?? debugPrint;

  final void Function(String? message, {int? wrapWidth}) sink;

  @override
  Future<void> report(AppError error) async {
    // Keep diagnostics limited to the sanitized map. Sentry/Supabase are
    // future integrations and must not be wired into the Flutter client here.
    sink('LegalHub error: ${Redactor.map(error.toLogMap())}');
  }
}

/// Fans one report out to several delegates (R7, 2026-09-24).
///
/// The remote-sink seam for launch: production injects
/// `CompositeErrorReporter([ConsoleErrorReporter(), SentryReporter()])`
/// (or OTel) without touching call sites. Every delegate MUST keep
/// [Redactor] on its own write path (as [ConsoleErrorReporter] and
/// [InMemoryErrorReporter] do) — a delegate that logs `error.toLogMap()`
/// raw violates the redaction contract. Best-effort fan-out: one
/// delegate's failure never blocks the others.
class CompositeErrorReporter implements ErrorReporter {
  CompositeErrorReporter(this._delegates);

  final List<ErrorReporter> _delegates;

  /// Sinks that threw during fan-out. Best-effort must stay observable.
  int droppedReports = 0;

  @override
  Future<void> report(AppError error) async {
    for (final ErrorReporter delegate in _delegates) {
      try {
        await delegate.report(error);
      } on Object {
        // Best-effort: a failing sink must not break error reporting.
        droppedReports++;
      }
    }
  }
}

class InMemoryErrorReporter implements ErrorReporter {
  final List<Map<String, Object?>> reports = <Map<String, Object?>>[];

  @override
  Future<void> report(AppError error) async {
    reports.add(Redactor.map(error.toLogMap()));
  }
}
