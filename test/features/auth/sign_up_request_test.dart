import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/features/auth/domain/sign_up_request.dart';

void main() {
  group('SignUpRequest', () {
    test('exposes the four bootstrap auth fields', () {
      const SignUpRequest request = SignUpRequest(
        name: 'Amira Hassan',
        email: 'amira@example.com',
        phone: '+201234567890',
        password: 'super-secret-123',
      );

      expect(request.name, 'Amira Hassan');
      expect(request.email, 'amira@example.com');
      expect(request.phone, '+201234567890');
      expect(request.password, 'super-secret-123');
    });

    test('is equatable on field values', () {
      const SignUpRequest a = SignUpRequest(
        name: 'Amira Hassan',
        email: 'amira@example.com',
        phone: '+201234567890',
        password: 'super-secret-123',
      );
      const SignUpRequest b = SignUpRequest(
        name: 'Amira Hassan',
        email: 'amira@example.com',
        phone: '+201234567890',
        password: 'super-secret-123',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toRedactedMap never emits the password in clear text', () {
      const SignUpRequest request = SignUpRequest(
        name: 'Amira Hassan',
        email: 'amira@example.com',
        phone: '+201234567890',
        password: 'super-secret-123',
      );

      final Map<String, Object?> redacted = request.toRedactedMap();

      expect(redacted['password'], '[REDACTED]');
      expect(redacted.values.join(), isNot(contains('super-secret-123')));
    });

    test('toRedactedMap redacts email and phone PII', () {
      const SignUpRequest request = SignUpRequest(
        name: 'Amira Hassan',
        email: 'amira@example.com',
        phone: '+201234567890',
        password: 'super-secret-123',
      );

      final Map<String, Object?> redacted = request.toRedactedMap();

      // PII keys are masked by the Redactor policy.
      expect(redacted['email'], '[REDACTED]');
      expect(redacted['phone'], '[REDACTED]');
      // The clear-text PII must not survive anywhere in the map.
      expect(redacted.values.join(), isNot(contains('amira@example.com')));
      expect(redacted.values.join(), isNot(contains('+201234567890')));
    });

    test('toRedactedMap is safe to feed into AppError.context', () {
      const SignUpRequest request = SignUpRequest(
        name: 'Amira Hassan',
        email: 'amira@example.com',
        phone: '+201234567890',
        password: 'super-secret-123',
      );

      // The redaction contract: the diagnostic map produced by SignUpRequest
      // is already sanitized, and re-running it through Redactor.map must be
      // idempotent (no clear-text PII leaks even if the consumer re-redacts).
      final Map<String, Object?> once = request.toRedactedMap();
      final Map<String, Object?> twice = Redactor.map(once);

      expect(twice, once);
      expect(twice.values.join(), isNot(contains('super-secret-123')));
      expect(twice.values.join(), isNot(contains('amira@example.com')));
    });

    test('name is retained for diagnostics (not classified as PII)', () {
      const SignUpRequest request = SignUpRequest(
        name: 'Amira Hassan',
        email: 'amira@example.com',
        phone: '+201234567890',
        password: 'super-secret-123',
      );

      expect(request.toRedactedMap()['name'], 'Amira Hassan');
    });

    test('produces a SignUpRequest from validated raw input', () {
      final SignUpRequest request = SignUpRequest.fromRaw(
        name: '  Amira Hassan  ',
        email: 'AMIRA@EXAMPLE.COM',
        phone: '+201234567890',
        password: 'super-secret-123',
      );

      expect(request.name, 'Amira Hassan');
      expect(request.email, 'amira@example.com');
      expect(request.phone, '+201234567890');
      expect(request.password, 'super-secret-123');
    });

    test('is a value object: implements Equatable', () {
      const SignUpRequest request = SignUpRequest(
        name: 'Amira Hassan',
        email: 'amira@example.com',
        phone: '+201234567890',
        password: 'super-secret-123',
      );

      expect(request, isA<Equatable>());
    });
  });
}
