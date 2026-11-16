import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/profile/supabase_account_api.dart';
import 'package:legalhub/features/profile/domain/account_errors.dart';
import 'package:legalhub/features/profile/domain/account_gateway.dart';

/// Account mutations backed by migration 34's RPCs (ADR-0011).
class SupabaseAccountGateway implements AccountGateway {
  SupabaseAccountGateway(this._api);

  final AccountApi _api;

  @override
  Future<Result<void>> updateDisplayName(String displayName) async {
    try {
      await _api.updateDisplayName(displayName);
      return const Result<void>.success(null);
    } on AccountApiException catch (e) {
      final bool invalid =
          e.code == '22023' ||
          e.message?.contains('legal_profile_invalid_display_name') == true;
      return Result<void>.failure(
        invalid ? AccountErrors.invalidName : AccountErrors.unavailable,
      );
    }
  }

  @override
  Future<Result<void>> deleteAccount() async {
    try {
      await _api.deleteAccount();
      return const Result<void>.success(null);
    } on AccountApiException catch (e) {
      final String text = '${e.code} ${e.message ?? ''}';
      if (text.contains('account_deletion_last_partner')) {
        return const Result<void>.failure(AccountErrors.lastPartner);
      }
      if (text.contains('account_deletion_platform_owner')) {
        return const Result<void>.failure(AccountErrors.platformOwner);
      }
      return Result<void>.failure(
        AppError(
          code: AccountErrors.unavailableCode,
          userMessage: 'Unable to delete your account. Please try again.',
          messageKey: AccountErrors.unavailable.messageKey,
          technicalMessage: e.message,
          kind: AppErrorKind.unavailable,
        ),
      );
    }
  }
}
