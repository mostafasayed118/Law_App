import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/state/view_state.dart';

/// Boundary tests for the cross-cutting core primitives shared across features:
/// `Result`, `ViewState`, and the `Redactor` privacy-by-design contract.
///
/// Cubit emission-stream tests live in dedicated files mirroring `lib/`:
/// - `test/features/auth/auth_cubit_test.dart`
/// - `test/features/auth/password_recovery_cubit_test.dart`
/// - `test/app/localization/locale_cubit_test.dart`
void main() {
  group('Result and shared view state boundaries', () {
    test('models success and failure explicitly', () {
      const Result<String> success = Result<String>.success('ready');
      const Result<String> failure = Result<String>.failure(
        AppError(code: 'offline', userMessage: 'Unavailable'),
      );

      expect(success.isSuccess, isTrue);
      expect(success.valueOrNull, 'ready');
      expect(failure.isSuccess, isFalse);
      expect(failure.errorOrNull?.code, 'offline');
    });

    test('view states remain equatable and typed', () {
      expect(const ViewLoading<String>(), const ViewLoading<String>());
      expect(const ViewEmpty<String>(), const ViewEmpty<String>());
      expect(
        const ViewUnauthorized<String>(),
        const ViewUnauthorized<String>(),
      );
      expect(
        const ViewSuccess<String>('value'),
        const ViewSuccess<String>('value'),
      );
    });
  });

  test(
    'redacts credential-shaped keys, email addresses, and bearer tokens',
    () {
      final Map<String, Object?> sanitized = Redactor.map(<String, Object?>{
        'password': 'secret',
        'message': 'Contact person@example.com',
        'authorization': 'Bearer abc123',
        'nested': <String, Object?>{'token': 'value'},
      });

      expect(sanitized['password'], '[REDACTED]');
      expect(sanitized['message'], 'Contact [REDACTED_EMAIL]');
      expect(sanitized['authorization'], '[REDACTED]');
      expect(
        (sanitized['nested']! as Map<String, Object?>)['token'],
        '[REDACTED]',
      );
    },
  );

  test(
    'redacts password-recovery credential keys (otp, new_password, newPassword)',
    () {
      // Regression guard: the password-recovery flow adds `otp` (a
      // short-lived credential) and `newPassword`/`new_password` to the
      // sensitive-key policy. These must be masked wherever they appear.
      final Map<String, Object?> sanitized = Redactor.map(<String, Object?>{
        'otp': '123456',
        'newPassword': 'super-secret-123',
        'new_password': 'also-secret-456',
      });

      expect(sanitized['otp'], '[REDACTED]');
      expect(sanitized['newPassword'], '[REDACTED]');
      expect(sanitized['new_password'], '[REDACTED]');
    },
  );
}
