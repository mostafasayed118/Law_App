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

    test(
      'redacts payment provider and card-shaped context before storing',
      () async {
        final InMemoryErrorReporter reporter = InMemoryErrorReporter();
        const Set<String> keys = <String>{
          'payment_token',
          'checkout_url',
          'provider_order_id',
          'provider_transaction_id',
          'hmac',
          'pan',
          'cvv',
          'card_number',
        };

        await reporter.report(
          AppError(
            code: 'payment_failed',
            userMessage: 'Payment failed',
            context: <String, Object?>{
              for (final String key in keys) key: 'sensitive-value',
            },
          ),
        );

        final Map<String, Object?> context =
            reporter.reports.single['context']! as Map<String, Object?>;
        for (final String key in keys) {
          expect(context[key], '[REDACTED]', reason: key);
        }
      },
    );
  });

  group('CompositeErrorReporter (R7 remote-sink seam)', () {
    test('fans out to every delegate', () async {
      final InMemoryErrorReporter first = InMemoryErrorReporter();
      final InMemoryErrorReporter second = InMemoryErrorReporter();

      await CompositeErrorReporter(<ErrorReporter>[
        first,
        second,
      ]).report(const AppError(code: 'x', userMessage: 'm'));

      expect(first.reports, hasLength(1));
      expect(second.reports, hasLength(1));
    });

    test('a throwing delegate never blocks the others', () async {
      final InMemoryErrorReporter survivor = InMemoryErrorReporter();

      await CompositeErrorReporter(<ErrorReporter>[
        _ThrowingReporter(),
        survivor,
      ]).report(const AppError(code: 'x', userMessage: 'm'));

      expect(survivor.reports, hasLength(1));
    });

    test('delegates keep Redactor on their own write path', () async {
      final InMemoryErrorReporter inner = InMemoryErrorReporter();

      await CompositeErrorReporter(<ErrorReporter>[inner]).report(
        const AppError(
          code: 'x',
          userMessage: 'm',
          context: <String, Object?>{'password': 'super-secret-123'},
        ),
      );

      final Map<String, Object?> context =
          inner.reports.single['context']! as Map<String, Object?>;
      expect(context['password'], '[REDACTED]');
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

class _ThrowingReporter implements ErrorReporter {
  @override
  Future<void> report(AppError error) async {
    throw StateError('sink down');
  }
}
