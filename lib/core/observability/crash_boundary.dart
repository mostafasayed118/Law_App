import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/observability/error_reporter.dart';

/// Process-wide boundary funneling every *uncaught* error into the existing
/// [ErrorReporter] seam (audit 2026-10-28, R2: release builds had no boundary).
///
/// It owns two engine hooks:
/// * [FlutterError.onError] — presents the error (so debug builds keep the red
///   screen / console dump) and reports it;
/// * [PlatformDispatcher.onError] — reports engine-level errors and returns
///   `true` so the error is handled.
///
/// The zone hook for `runZonedGuarded` is [reportUncaught], used by
/// `main`'s bootstrap zone.
///
/// Contract:
/// * reports go through [ErrorReporter.report] only, so [Redactor] stays on
///   the write path — no raw payloads are logged from here;
/// * the same error object is reported at most once per boundary
///   ([_markReported]);
/// * nothing thrown by a handler or a sink ever escapes.
///
/// [ConsoleErrorReporter] stays the sink until the owner signs off on a
/// remote one (Sentry/Firebase) — see [CompositeErrorReporter] for that seam.
class CrashBoundary {
  CrashBoundary(
    ErrorReporter reporter, {
    void Function(FlutterErrorDetails details)? presenter,
  }) : _reporter = reporter,
       _presenter = presenter ?? FlutterError.presentError;

  static const String _flutterSource = 'uncaught_flutter_error';
  static const String _platformSource = 'uncaught_platform_error';
  static const String _zoneSource = 'uncaught_zone_error';

  /// Upper bound on the identity set: a long-lived process must not keep every
  /// error object forever. Older entries simply fall out of the window.
  static const int _dedupeWindow = 32;

  static const int _maxTechnicalLength = 500;
  static const int _maxStackLength = 2000;

  final void Function(FlutterErrorDetails details) _presenter;

  ErrorReporter _reporter;

  /// Identity hashes of errors already sent to the reporter.
  final Set<int> _reported = <int>{};

  FlutterExceptionHandler? _previousFlutterHandler;
  bool Function(Object error, StackTrace stackTrace)? _previousPlatformHandler;
  bool _installed = false;

  /// Whether the engine hooks currently point at this boundary.
  bool get isInstalled => _installed;

  /// Swaps the sink (the pre-DI console fallback is replaced by the reporter
  /// registered in the service locator). The dedupe window is kept.
  void useReporter(ErrorReporter reporter) {
    _reporter = reporter;
  }

  /// Points [FlutterError.onError] and [PlatformDispatcher.onError] at this
  /// boundary. Idempotent: a second call keeps the first saved originals.
  void install() {
    if (_installed) {
      return;
    }
    _previousFlutterHandler = FlutterError.onError;
    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    FlutterError.onError = _handleFlutterError;
    PlatformDispatcher.instance.onError = _handlePlatformError;
    _installed = true;
  }

  /// Restores the handlers that were in place before [install].
  void dispose() {
    if (!_installed) {
      return;
    }
    FlutterError.onError = _previousFlutterHandler;
    PlatformDispatcher.instance.onError = _previousPlatformHandler;
    _previousFlutterHandler = null;
    _previousPlatformHandler = null;
    _reported.clear();
    _installed = false;
  }

  /// Zone hook for `runZonedGuarded`; reports an otherwise-uncaught error.
  void reportUncaught(Object error, StackTrace stackTrace) {
    _report(error, stackTrace, source: _zoneSource);
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    try {
      _presenter(details);
    } on Object {
      // Presentation is best-effort; reporting below must still run.
    }
    _report(
      details.exception,
      details.stack,
      source: _flutterSource,
      library: details.library,
    );
  }

  bool _handlePlatformError(Object error, StackTrace stackTrace) {
    _report(error, stackTrace, source: _platformSource);
    // Handled: the engine must not forward this to the default crash path.
    return true;
  }

  void _report(
    Object error,
    StackTrace? stackTrace, {
    required String source,
    String? library,
  }) {
    try {
      if (!_markReported(error)) {
        return;
      }
      final AppError appError = AppError(
        code: source,
        userMessage: 'Something went wrong. Please try again.',
        technicalMessage: _describe(error),
        context: <String, Object?>{
          'source': source,
          'library': ?library,
          if (stackTrace != null)
            'stack': _clip(stackTrace.toString(), _maxStackLength),
        },
      );
      // Sinks are async; a failure (sync throw or failed future) must never
      // escalate into a second uncaught error — that would loop forever.
      final Future<void> pending = _reporter.report(appError);
      unawaited(pending.catchError((Object _) {}));
    } on Object {
      // Last line of defense: a handler is never allowed to throw — not even
      // when a sink throws synchronously or a broken `toString` fails.
    }
  }

  /// Returns true the first time [error] is seen, false afterwards.
  bool _markReported(Object error) {
    final int identity = identityHashCode(error);
    if (_reported.contains(identity)) {
      return false;
    }
    _reported.add(identity);
    if (_reported.length > _dedupeWindow) {
      _reported.remove(_reported.first);
    }
    return true;
  }

  String _describe(Object error) {
    try {
      return _clip(error.toString(), _maxTechnicalLength);
    } on Object {
      // A broken `toString` must not take the boundary down with it.
      return error.runtimeType.toString();
    }
  }

  String _clip(String value, int limit) =>
      value.length <= limit ? value : '${value.substring(0, limit)}…';
}

/// Installs the global error handlers for [reporter] and returns the boundary
/// (tests dispose it to restore the previous handlers).
CrashBoundary installGlobalErrorHandlers(
  ErrorReporter reporter, {
  void Function(FlutterErrorDetails details)? presenter,
}) {
  final CrashBoundary boundary = CrashBoundary(reporter, presenter: presenter);
  boundary.install();
  return boundary;
}
