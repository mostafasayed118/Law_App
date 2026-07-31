import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/features/auth/domain/password_recovery_request.dart';

void main() {
  group('PasswordRecoveryRequest', () {
    test('exposes the recovery flow fields', () {
      const PasswordRecoveryRequest request = PasswordRecoveryRequest(
        email: 'amira@example.com',
        otp: '123456',
        newPassword: 'super-secret-123',
      );

      expect(request.email, 'amira@example.com');
      expect(request.otp, '123456');
      expect(request.newPassword, 'super-secret-123');
    });

    test('is equatable on field values', () {
      const PasswordRecoveryRequest a = PasswordRecoveryRequest(
        email: 'amira@example.com',
        otp: '123456',
        newPassword: 'super-secret-123',
      );
      const PasswordRecoveryRequest b = PasswordRecoveryRequest(
        email: 'amira@example.com',
        otp: '123456',
        newPassword: 'super-secret-123',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toRedactedMap never emits the new password in clear text', () {
      const PasswordRecoveryRequest request = PasswordRecoveryRequest(
        email: 'amira@example.com',
        otp: '123456',
        newPassword: 'super-secret-123',
      );

      final Map<String, Object?> redacted = request.toRedactedMap();

      expect(redacted['newPassword'], '[REDACTED]');
      expect(redacted.values.join(), isNot(contains('super-secret-123')));
    });

    test('toRedactedMap redacts the OTP (credential-adjacent)', () {
      const PasswordRecoveryRequest request = PasswordRecoveryRequest(
        email: 'amira@example.com',
        otp: '123456',
        newPassword: 'super-secret-123',
      );

      final Map<String, Object?> redacted = request.toRedactedMap();

      // The OTP is a short-lived credential and must never reach a diagnostic
      // surface in clear text.
      expect(redacted['otp'], '[REDACTED]');
      expect(redacted.values.join(), isNot(contains('123456')));
    });

    test('toRedactedMap redacts email PII', () {
      const PasswordRecoveryRequest request = PasswordRecoveryRequest(
        email: 'amira@example.com',
        otp: '123456',
        newPassword: 'super-secret-123',
      );

      final Map<String, Object?> redacted = request.toRedactedMap();

      expect(redacted['email'], '[REDACTED]');
      expect(redacted.values.join(), isNot(contains('amira@example.com')));
    });

    test(
      'toRedactedMap is safe to feed into AppError.context (idempotent)',
      () {
        const PasswordRecoveryRequest request = PasswordRecoveryRequest(
          email: 'amira@example.com',
          otp: '123456',
          newPassword: 'super-secret-123',
        );

        // The redaction contract: the diagnostic map produced by
        // PasswordRecoveryRequest is already sanitized, and re-running it
        // through Redactor.map must be idempotent (no clear-text leaks even if
        // the consumer re-redacts).
        final Map<String, Object?> once = request.toRedactedMap();
        final Map<String, Object?> twice = Redactor.map(once);

        expect(twice, once);
        expect(twice.values.join(), isNot(contains('super-secret-123')));
        expect(twice.values.join(), isNot(contains('123456')));
        expect(twice.values.join(), isNot(contains('amira@example.com')));
      },
    );

    test('produces a PasswordRecoveryRequest from validated raw input', () {
      final PasswordRecoveryRequest request = PasswordRecoveryRequest.fromRaw(
        email: '  AMIRA@EXAMPLE.COM  ',
        otp: '  123456  ',
        newPassword: 'super-secret-123',
      );

      // Email is trimmed and lower-cased to the canonical stored form; the
      // OTP and new password are trimmed of surrounding whitespace only
      // (internal characters are preserved).
      expect(request.email, 'amira@example.com');
      expect(request.otp, '123456');
      expect(request.newPassword, 'super-secret-123');
    });

    test('is a value object: implements Equatable', () {
      const PasswordRecoveryRequest request = PasswordRecoveryRequest(
        email: 'amira@example.com',
        otp: '123456',
        newPassword: 'super-secret-123',
      );

      expect(request, isA<Equatable>());
    });
  });
}
