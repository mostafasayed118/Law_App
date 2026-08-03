import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/auth_outcome.dart';

void main() {
  group('AuthOutcome.success', () {
    test('is success and exposes the value', () {
      const AuthOutcome<String> outcome = AuthOutcome<String>.success('ok');

      expect(outcome.isSuccess, isTrue);
      expect(outcome.valueOrNull, 'ok');
      expect(outcome.failureOrNull, isNull);
    });

    test('is the AuthSuccess subtype', () {
      const AuthOutcome<int> outcome = AuthOutcome<int>.success(42);

      expect(outcome, isA<AuthSuccess<int>>());
    });
  });

  group('AuthOutcome.failure', () {
    test('is not success and exposes the typed failure', () {
      const AuthFailure failure = AuthFailure(
        kind: AuthFailureKind.userDisabled,
      );
      const AuthOutcome<String> outcome = AuthOutcome<String>.failure(failure);

      expect(outcome.isSuccess, isFalse);
      expect(outcome.valueOrNull, isNull);
      expect(outcome.failureOrNull, failure);
    });

    test('is the AuthFailed subtype', () {
      const AuthOutcome<int> outcome = AuthOutcome<int>.failure(
        AuthFailure(kind: AuthFailureKind.unknown),
      );

      expect(outcome, isA<AuthFailed<int>>());
    });
  });

  group('AuthSuccess and AuthFailed carry their payloads', () {
    test('AuthSuccess holds the value', () {
      const AuthSuccess<String> success = AuthSuccess<String>('payload');
      expect(success.value, 'payload');
    });

    test('AuthFailed holds the failure', () {
      const AuthFailure failure = AuthFailure(
        kind: AuthFailureKind.sessionExpired,
        message: 'Session expired',
      );
      const AuthFailed<String> failed = AuthFailed<String>(failure);
      expect(failed.failure, failure);
    });
  });

  group('AuthFailure equality (Equatable)', () {
    test('is equal for identical kind and message', () {
      const AuthFailure a = AuthFailure(
        kind: AuthFailureKind.invalidCredentials,
        message: 'bad',
      );
      const AuthFailure b = AuthFailure(
        kind: AuthFailureKind.invalidCredentials,
        message: 'bad',
      );

      expect(a, b);
    });

    test('differs on kind', () {
      const AuthFailure a = AuthFailure(kind: AuthFailureKind.signedOut);
      const AuthFailure b = AuthFailure(kind: AuthFailureKind.sessionExpired);

      expect(a, isNot(b));
    });

    test('differs on message and ignores null vs value', () {
      const AuthFailure withMessage = AuthFailure(
        kind: AuthFailureKind.unknown,
        message: 'boom',
      );
      const AuthFailure withoutMessage = AuthFailure(
        kind: AuthFailureKind.unknown,
      );

      expect(withMessage, isNot(withoutMessage));
    });
  });

  group('AuthFailureKind exposes the contract failure kinds', () {
    test('covers every typed reason an auth operation can fail', () {
      expect(AuthFailureKind.values, <AuthFailureKind>[
        AuthFailureKind.signedOut,
        AuthFailureKind.sessionExpired,
        AuthFailureKind.invalidCredentials,
        AuthFailureKind.userDisabled,
        AuthFailureKind.membershipDenied,
        AuthFailureKind.providerUnavailable,
        AuthFailureKind.unknown,
      ]);
    });
  });

  group('Privacy boundary', () {
    test('AuthFailure props are exactly [kind, message]', () {
      // Contract §8 / gate3 §3.2: the typed failure crossing the seam must
      // never carry passwords, tokens, reset codes, or PII.
      const AuthFailure failure = AuthFailure(
        kind: AuthFailureKind.providerUnavailable,
        message: 'Provider unavailable',
      );

      expect(failure.props, <Object?>[
        AuthFailureKind.providerUnavailable,
        'Provider unavailable',
      ]);
    });

    test('valueOrNull and failureOrNull are never both set', () {
      const AuthOutcome<String> success = AuthOutcome<String>.success('v');
      const AuthOutcome<String> failed = AuthOutcome<String>.failure(
        AuthFailure(kind: AuthFailureKind.signedOut),
      );

      expect(success.valueOrNull, isNotNull);
      expect(success.failureOrNull, isNull);
      expect(failed.failureOrNull, isNotNull);
      expect(failed.valueOrNull, isNull);
    });
  });
}
