import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/auth/data/fake_sign_up_gateway.dart';
import 'package:legalhub/features/auth/domain/sign_up_request.dart';

// FakeSignUpGateway is the dev-only seam behind the sign-up lifecycle (see the
// gateway/request class docs): it never persists or logs anything and ignores
// the request contents entirely. These tests pin that contract so a future
// "real" gateway can't accidentally regress the dev flow.
void main() {
  const SignUpRequest request = SignUpRequest(
    name: 'Jane Doe',
    email: 'jane@example.com',
    phone: '+1 (555) 000-0000',
    password: 'super-secret-123',
  );

  group('FakeSignUpGateway', () {
    test('submit resolves to a success Result for a valid request', () async {
      final FakeSignUpGateway gateway = FakeSignUpGateway();

      final Result<void> result = await gateway.submit(request);

      expect(result, isA<Success<void>>());
    });

    test(
      'submit ignores the request contents — any request succeeds',
      () async {
        final FakeSignUpGateway gateway = FakeSignUpGateway();

        // The seam is intentionally non-coupling: even a minimal request must
        // resolve to success, proving no validation or backend hides here.
        final Result<void> result = await gateway.submit(
          const SignUpRequest(name: '', email: '', phone: '', password: ''),
        );

        expect(result, isA<Success<void>>());
      },
    );
  });
}
