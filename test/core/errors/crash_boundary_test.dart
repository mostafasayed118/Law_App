import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/observability/crash_boundary.dart';
import 'package:legalhub/core/observability/error_reporter.dart';

void main() {
  late InMemoryErrorReporter reporter;
  late CrashBoundary boundary;
  late List<FlutterErrorDetails> presented;
  late FlutterExceptionHandler? previousFlutterHandler;
  late bool Function(Object error, StackTrace stackTrace)?
  previousPlatformHandler;

  setUp(() {
    reporter = InMemoryErrorReporter();
    presented = <FlutterErrorDetails>[];
    previousFlutterHandler = FlutterError.onError;
    previousPlatformHandler = PlatformDispatcher.instance.onError;
    boundary = installGlobalErrorHandlers(
      reporter,
      // Keep test output clean; the default presenter is FlutterError's.
      presenter: presented.add,
    );
  });

  tearDown(() {
    boundary.dispose();
    // Dispose restores what was captured at install time; pin the originals
    // explicitly so a failing install can never leak handlers across tests.
    FlutterError.onError = previousFlutterHandler;
    PlatformDispatcher.instance.onError = previousPlatformHandler;
  });

  test('a FlutterError is presented and reported exactly once', () async {
    final FlutterError exception = FlutterError('boom');

    FlutterError.onError!(FlutterErrorDetails(exception: exception));
    FlutterError.onError!(FlutterErrorDetails(exception: exception));
    await pumpEventQueue();

    expect(boundary.isInstalled, isTrue);
    expect(presented, hasLength(2));
    expect(reporter.reports, hasLength(1));
    expect(reporter.reports.single['code'], 'uncaught_flutter_error');
    expect(reporter.reports.single['technical_message'], contains('boom'));
    final Map<String, Object?> context =
        reporter.reports.single['context']! as Map<String, Object?>;
    expect(context['source'], 'uncaught_flutter_error');
  });

  test('the same error object is not reported twice across handlers', () async {
    final StateError error = StateError('seen twice');

    FlutterError.onError!(FlutterErrorDetails(exception: error));
    final bool handled = PlatformDispatcher.instance.onError!(
      error,
      StackTrace.current,
    );
    await pumpEventQueue();

    expect(handled, isTrue);
    expect(reporter.reports, hasLength(1));
  });

  test('an uncaught platform error is reported and marked handled', () async {
    final bool handled = PlatformDispatcher.instance.onError!(
      StateError('platform boom'),
      StackTrace.current,
    );
    await pumpEventQueue();

    expect(handled, isTrue);
    expect(reporter.reports, hasLength(1));
    expect(reporter.reports.single['code'], 'uncaught_platform_error');
    expect(
      reporter.reports.single['technical_message'],
      contains('platform boom'),
    );
  });

  test('a zone error is reported through the boundary hook', () async {
    await runZonedGuarded<Future<void>>(() async {
      unawaited(Future<void>.microtask(() => throw StateError('zone boom')));
      await Future<void>.delayed(Duration.zero);
    }, boundary.reportUncaught);
    await pumpEventQueue();

    expect(reporter.reports, hasLength(1));
    expect(reporter.reports.single['code'], 'uncaught_zone_error');
  });

  test('a reporter that throws synchronously never escapes a handler', () {
    final CrashBoundary throwing = installGlobalErrorHandlers(
      _ThrowingReporter(),
      presenter: presented.add,
    );
    addTearDown(throwing.dispose);

    expect(
      () => FlutterError.onError!(
        FlutterErrorDetails(exception: FlutterError('flutter boom')),
      ),
      returnsNormally,
    );
    expect(
      () => PlatformDispatcher.instance.onError!(
        StateError('platform boom'),
        StackTrace.current,
      ),
      returnsNormally,
    );
    expect(
      () => throwing.reportUncaught(
        ArgumentError('zone boom'),
        StackTrace.current,
      ),
      returnsNormally,
    );
  });

  test('an error whose toString throws is still contained', () async {
    final bool handled = PlatformDispatcher.instance.onError!(
      _BrokenToStringError(),
      StackTrace.current,
    );
    await pumpEventQueue();

    expect(handled, isTrue);
    expect(reporter.reports, hasLength(1));
    expect(
      reporter.reports.single['technical_message'],
      contains('_BrokenToStringError'),
    );
  });

  test(
    'a reporter that fails asynchronously does not surface unhandled',
    () async {
      final CrashBoundary failing = installGlobalErrorHandlers(
        _FailingReporter(),
        presenter: presented.add,
      );
      addTearDown(failing.dispose);

      expect(
        () => FlutterError.onError!(
          FlutterErrorDetails(exception: FlutterError('flutter boom')),
        ),
        returnsNormally,
      );
      expect(
        () => PlatformDispatcher.instance.onError!(
          StateError('platform boom'),
          StackTrace.current,
        ),
        returnsNormally,
      );
      // An unhandled rejected future would fail this test asynchronously.
      await pumpEventQueue();
    },
  );
}

class _ThrowingReporter implements ErrorReporter {
  @override
  Future<void> report(AppError error) {
    throw StateError('sink is down');
  }
}

class _FailingReporter implements ErrorReporter {
  @override
  Future<void> report(AppError error) =>
      Future<void>.error(StateError('sink is down'));
}

class _BrokenToStringError {
  @override
  String toString() => throw StateError('toString is broken');
}
