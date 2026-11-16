import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/profile/domain/password_gateway.dart';

/// Demo password seam. It never holds a real credential: it accepts any
/// password meeting the client-side strength rule and reports success, so the
/// flow is reviewable without touching a real account. A configured build binds
/// the Supabase adapter instead (ADR-0011).
class FakePasswordGateway implements PasswordGateway {
  FakePasswordGateway({this.reject = false});

  /// Set by tests to exercise the failure arm.
  final bool reject;

  int calls = 0;
  String? lastPassword;

  @override
  Future<Result<void>> changePassword(String newPassword) async {
    calls++;
    lastPassword = newPassword;
    if (reject) {
      return const Result<void>.failure(PasswordErrors.unavailable);
    }
    return const Result<void>.success(null);
  }
}
