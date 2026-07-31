import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';

void main() {
  group('AppError', () {
    test('is an Equatable value object across its fields', () {
      const AppError a = AppError(
        code: 'auth_failed',
        userMessage: 'Sign-in failed',
        technicalMessage: 'OTP expired',
        context: <String, Object?>{'flow': 'sign-in'},
      );
      const AppError b = AppError(
        code: 'auth_failed',
        userMessage: 'Sign-in failed',
        technicalMessage: 'OTP expired',
        context: <String, Object?>{'flow': 'sign-in'},
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('distinguishes errors that differ by code', () {
      const AppError a = AppError(code: 'a', userMessage: 'm');
      const AppError b = AppError(code: 'b', userMessage: 'm');

      expect(a, isNot(equals(b)));
    });

    test('defaults technicalMessage to null and context to an empty map', () {
      const AppError error = AppError(code: 'x', userMessage: 'm');

      expect(error.technicalMessage, isNull);
      expect(error.context, isEmpty);
    });

    test(
      'toLogMap flattens code, userMessage, technicalMessage, and context',
      () {
        const AppError error = AppError(
          code: 'recovery_failed',
          userMessage: 'Recovery failed',
          technicalMessage: 'edge timeout',
          context: <String, Object?>{'attempt': 2},
        );

        final Map<String, Object?> map = error.toLogMap();

        expect(map['code'], 'recovery_failed');
        expect(map['message'], 'Recovery failed');
        expect(map['technical_message'], 'edge timeout');
        expect(map['context'], <String, Object?>{'attempt': 2});
      },
    );

    test(
      'toLogMap omits technicalMessage when null and context when empty',
      () {
        const AppError error = AppError(code: 'x', userMessage: 'm');

        final Map<String, Object?> map = error.toLogMap();

        expect(map.containsKey('technical_message'), isFalse);
        expect(map.containsKey('context'), isFalse);
        expect(map.keys, <String>['code', 'message']);
      },
    );

    // The class doc states protected content, credentials, and session
    // material must never be passed as diagnostic context. AppError does not
    // enforce this itself — it trusts callers. This test pins that contract
    // by documenting that arbitrary context passes through unchanged, so the
    // responsibility stays with the caller. The redaction layer
    // (Redactor.map) is the actual guard and is tested in
    // bootstrap_boundaries_test.dart.
    test(
      'passes context through verbatim (caller owns the no-credential rule)',
      () {
        const AppError error = AppError(
          code: 'x',
          userMessage: 'm',
          context: <String, Object?>{'caller_field': 'caller_value'},
        );

        expect(error.context['caller_field'], 'caller_value');
        expect(error.toLogMap()['context'], error.context);
      },
    );
  });
}
