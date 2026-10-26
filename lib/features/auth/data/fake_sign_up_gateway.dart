import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/auth/domain/sign_up_gateway.dart';
import 'package:legalhub/features/auth/domain/sign_up_request.dart';

/// Dev-only sign-up seam; ignores the request and returns success.
///
/// No real credential, password, or identity data is persisted or logged. Real
/// sign-up is a later, approved data-layer slice (P1, gated behind the P0
/// decisions in `docs/auth_tenant_authorization_contract.md` §10).
class FakeSignUpGateway implements SignUpGateway {
  @override
  Future<Result<void>> submit(SignUpRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return Result<void>.success(null);
  }
}
