import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/auth/data/fake_password_recovery_gateway.dart';
import 'package:legalhub/features/auth/domain/password_recovery_request.dart';

// FakePasswordRecoveryGateway is the dev-only seam behind the reset lifecycle
// (see the gateway/request class docs): the OTP and new password it receives
// are never logged or persisted, and it resolves to success regardless of the
// request contents. These tests pin that contract.
void main() {
  const PasswordRecoveryRequest request = PasswordRecoveryRequest(
    email: 'amira@example.com',
    otp: '123456',
    newPassword: 'super-secret-123',
  );

  group('FakePasswordRecoveryGateway', () {
    test('reset resolves to a success Result for a real request', () async {
      final FakePasswordRecoveryGateway gateway = FakePasswordRecoveryGateway();

      final Result<void> result = await gateway.reset(request);

      expect(result, isA<Success<void>>());
    });

    test('reset ignores the request contents — any request succeeds', () async {
      final FakePasswordRecoveryGateway gateway = FakePasswordRecoveryGateway();

      // Same non-coupling contract as the sign-up seam: no validation or
      // backend behavior hides behind the fake.
      final Result<void> result = await gateway.reset(
        const PasswordRecoveryRequest(email: '', otp: '', newPassword: ''),
      );

      expect(result, isA<Success<void>>());
    });
  });
}
