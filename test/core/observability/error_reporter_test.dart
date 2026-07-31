import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/observability/error_reporter.dart';

void main() {
  group('InMemoryErrorReporter', () {
    test('stores the redacted log map on report', () async {
      final InMemoryErrorReporter reporter = InMemoryErrorReporter();

      const AppError error = AppError(
        code: 'auth_failed',
        userMessage: 'Sign-in failed',
        context: <String, Object?>{'password': 'super-secret-123'},
      );
      await reporter.report(error);

      expect(reporter.reports, hasLength(1));
      final Map<String, Object?> stored = reporter.reports.single;
      expect(stored['code'], 'auth_failed');
      expect(stored['message'], 'Sign-in failed');
      expect(
        (stored['context']! as Map<String, Object?>)['password'],
        '[REDACTED]',
      );
    });

    test('appends every report in order', () async {
      final InMemoryErrorReporter reporter = InMemoryErrorReporter();

      await reporter.report(
        const AppError(code: 'first', userMessage: 'First'),
      );
      await reporter.report(
        const AppError(code: 'second', userMessage: 'Second'),
      );

      expect(reporter.reports, hasLength(2));
      expect(reporter.reports[0]['code'], 'first');
      expect(reporter.reports[1]['code'], 'second');
    });

    test('redacts credential-shaped context before storing', () async {
      final InMemoryErrorReporter reporter = InMemoryErrorReporter();

      await reporter.report(
        const AppError(
          code: 'x',
          userMessage: 'm',
          context: <String, Object?>{
            'token': 'abc123',
            'email': 'person@example.com',
            'nested': <String, Object?>{'otp': '123456'},
          },
        ),
      );

      final Map<String, Object?> context =
          reporter.reports.single['context']! as Map<String, Object?>;
      expect(context['token'], '[REDACTED]');
      expect(context['email'], '[REDACTED]');
      expect((context['nested']! as Map<String, Object?>)['otp'], '[REDACTED]');
    });
  });

  group('ConsoleErrorReporter', () {
    // print() forwards to Zone.current.print, so running report() inside a
    // zone whose print handler captures lines lets us assert the exact output
    // without depending on the test framework's print interception.
    test('prints the sanitized line without leaking credentials', () async {
      const AppError error = AppError(
        code: 'auth_failed',
        userMessage: 'Sign-in failed',
        context: <String, Object?>{'password': 'super-secret-123'},
      );

      final List<String> printed = <String>[];
      await runZoned(
        () => ConsoleErrorReporter().report(error),
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            printed.add(line);
          },
        ),
      );

      expect(printed, hasLength(1));
      expect(printed.single, contains('LegalHub error:'));
      expect(printed.single, contains('[REDACTED]'));
      expect(printed.single, isNot(contains('super-secret-123')));
    });
  });
}
