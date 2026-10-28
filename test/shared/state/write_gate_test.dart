import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/shared/state/write_gate.dart';

void main() {
  group('WriteGate', () {
    test('runs the write, then onSuccess, and returns null', () async {
      final WriteGate gate = WriteGate();
      final List<String> calls = <String>[];

      final AppError? error = await gate.run<int>(
        isClosed: () => false,
        write: () async {
          calls.add('write');
          return const Result<int>.success(7);
        },
        onSuccess: () async => calls.add('reload'),
      );

      expect(error, isNull);
      expect(calls, <String>['write', 'reload']);
    });

    test('returns the failure error and skips the reload', () async {
      final WriteGate gate = WriteGate();
      int reloads = 0;

      final AppError? error = await gate.run<int>(
        isClosed: () => false,
        write: () async => const Result<int>.failure(_failure),
        onSuccess: () async => reloads++,
      );

      expect(error, _failure);
      expect(reloads, 0);
    });

    test(
      'a second run while the first is in flight returns busyError',
      () async {
        final WriteGate gate = WriteGate();
        final Completer<Result<int>> pending = Completer<Result<int>>();

        final Future<AppError?> first = gate.run<int>(
          isClosed: () => false,
          write: () => pending.future,
          onSuccess: () async {},
        );
        await Future<void>.delayed(Duration.zero);
        final AppError? second = await gate.run<int>(
          isClosed: () => false,
          write: () async => const Result<int>.success(2),
          onSuccess: () async {},
        );

        expect(second, WriteGate.busyError);

        pending.complete(const Result<int>.success(1));
        expect(await first, isNull);
      },
    );

    test('a closed cubit never writes', () async {
      final WriteGate gate = WriteGate();
      int writes = 0;

      final AppError? error = await gate.run<int>(
        isClosed: () => true,
        write: () async {
          writes++;
          return const Result<int>.success(1);
        },
        onSuccess: () async {},
      );

      expect(error, isNull);
      expect(writes, 0);
    });

    test(
      'a thrown write rethrows and frees the gate for the next run (N1)',
      () async {
        final WriteGate gate = WriteGate();
        int writes = 0;

        await expectLater(
          gate.run<int>(
            isClosed: () => false,
            write: () async {
              writes++;
              throw StateError('gateway blew up');
            },
            onSuccess: () async {},
          ),
          throwsA(isA<StateError>()),
        );

        // The next tap must actually reach the gateway instead of being
        // refused as busy forever.
        final AppError? error = await gate.run<int>(
          isClosed: () => false,
          write: () async {
            writes++;
            return const Result<int>.success(7);
          },
          onSuccess: () async {},
        );

        expect(error, isNull);
        expect(writes, 2);
      },
    );
  });
}

const AppError _failure = AppError(
  code: 'write_failed',
  userMessage: 'The write failed.',
);
