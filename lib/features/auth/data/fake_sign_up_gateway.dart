import '../../../core/errors/result.dart';
import '../domain/sign_up_gateway.dart';
import '../domain/sign_up_request.dart';

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
