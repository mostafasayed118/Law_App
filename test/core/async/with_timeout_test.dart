import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/async/with_timeout.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('a never-completing future times out', () async {
    final future = Completer<void>().future;
    await expectLater(
      withRequestTimeout(future, timeout: const Duration(milliseconds: 10)),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('a completing future returns its value', () async {
    expect(await withRequestTimeout(Future<int>.value(7)), 7);
  });

  test('SupabaseSeam.invokeWithTimeout applies the shared 15 s deadline', () {
    fakeAsync((FakeAsync async) {
      final Completer<FunctionResponse> never = Completer<FunctionResponse>();
      Object? error;
      SupabaseSeam.invokeWithTimeout(() => never.future).then<void>(
        (_) {},
        onError: (Object caught) {
          error = caught;
        },
      );

      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 14));
      expect(error, isNull);

      async.elapse(const Duration(seconds: 1));
      expect(error, isA<TimeoutException>());
    });
  });
}
