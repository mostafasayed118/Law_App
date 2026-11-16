import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/auth/supabase_password_api.dart';
import 'package:legalhub/data/profile/supabase_account_api.dart';
import 'package:legalhub/features/profile/data/supabase_account_gateway.dart';
import 'package:legalhub/features/profile/data/supabase_password_gateway.dart';
import 'package:legalhub/features/profile/domain/account_errors.dart';
import 'package:legalhub/features/profile/domain/password_gateway.dart';

/// Row-free mapping tests: the RPCs return void, so what matters here is that
/// each stable SQL condition maps to the right AppError and that a provider
/// exception cannot leak across the seam.
void main() {
  group('SupabaseAccountGateway', () {
    test('the last-partner refusal maps to its own error', () async {
      final SupabaseAccountGateway gateway = SupabaseAccountGateway(
        _StubAccountApi(
          deleteError: const AccountApiException(
            '23514',
            message: 'account_deletion_last_partner',
          ),
        ),
      );
      final result = await gateway.deleteAccount();
      expect(
        (result as Failure<void>).error.code,
        AccountErrors.lastPartnerCode,
      );
    });

    test('the platform-owner refusal maps to its own error', () async {
      final SupabaseAccountGateway gateway = SupabaseAccountGateway(
        _StubAccountApi(
          deleteError: const AccountApiException(
            '23514',
            message: 'account_deletion_platform_owner',
          ),
        ),
      );
      final Result<void> result = await gateway.deleteAccount();
      expect(
        (result as Failure<void>).error.code,
        AccountErrors.platformOwnerCode,
      );
    });

    test('an invalid display name is not reported as an outage', () async {
      final SupabaseAccountGateway gateway = SupabaseAccountGateway(
        _StubAccountApi(
          updateError: const AccountApiException(
            '22023',
            message: 'legal_profile_invalid_display_name',
          ),
        ),
      );
      final Result<void> result = await gateway.updateDisplayName('x');
      expect(
        (result as Failure<void>).error.code,
        AccountErrors.invalidNameCode,
      );
    });

    test('a successful update forwards the trimmed value', () async {
      final _StubAccountApi api = _StubAccountApi();
      final SupabaseAccountGateway gateway = SupabaseAccountGateway(api);
      await gateway.updateDisplayName('اسم');
      expect(api.lastName, 'اسم');
    });
  });

  group('SupabasePasswordGateway', () {
    test('reauth-required is a denial, not a retryable outage', () async {
      final SupabasePasswordGateway gateway = SupabasePasswordGateway(
        _StubPasswordApi(
          const PasswordChangeException(
            PasswordChangeFailureKind.reauthRequired,
          ),
        ),
      );
      final Result<void> result = await gateway.changePassword('pw');
      expect((result as Failure<void>).error.code, PasswordErrors.reauthCode);
    });

    test('an unavailable provider is retryable', () async {
      final SupabasePasswordGateway gateway = SupabasePasswordGateway(
        _StubPasswordApi(
          const PasswordChangeException(PasswordChangeFailureKind.unavailable),
        ),
      );
      final Result<void> result = await gateway.changePassword('pw');
      expect(
        (result as Failure<void>).error.code,
        PasswordErrors.unavailableCode,
      );
    });
  });
}

class _StubAccountApi implements AccountApi {
  _StubAccountApi({this.deleteError, this.updateError});

  final Object? deleteError;
  final Object? updateError;
  String? lastName;

  @override
  Future<void> updateDisplayName(String displayName) async {
    if (updateError != null) {
      throw updateError!;
    }
    lastName = displayName;
  }

  @override
  Future<void> deleteAccount() async {
    if (deleteError != null) {
      throw deleteError!;
    }
  }
}

class _StubPasswordApi implements PasswordApi {
  _StubPasswordApi(this.error);

  final Object? error;

  @override
  Future<void> changePassword(String newPassword) async {
    if (error != null) {
      throw error!;
    }
  }
}
