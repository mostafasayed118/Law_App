import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';

/// Failure vocabulary for the account surface (ADR-0011).
///
/// Codes mirror the stable exceptions migration 34 raises. The two governance
/// refusals are kept distinct from a generic failure because the reader can act
/// on them: add another partner, or transfer platform ownership.
abstract final class AccountErrors {
  static const String invalidNameCode = 'legal_profile_invalid_display_name';
  static const String profileNotFoundCode = 'legal_profile_not_found';
  static const String lastPartnerCode = 'account_deletion_last_partner';
  static const String platformOwnerCode = 'account_deletion_platform_owner';
  static const String unavailableCode = 'account_unavailable';

  static const AppError invalidName = AppError(
    code: invalidNameCode,
    userMessage: 'Enter a name between 2 and 120 characters.',
    messageKey: AppMessageKey.errTheNameIsInvalid,
  );

  static const AppError profileNotFound = AppError(
    code: profileNotFoundCode,
    userMessage: 'Your profile could not be found.',
    messageKey: AppMessageKey.errYourProfileCouldNotBeFound,
  );

  static const AppError lastPartner = AppError(
    code: lastPartnerCode,
    userMessage:
        'You are the last active partner. Add another partner before deleting your account.',
    messageKey: AppMessageKey.errYouAreTheLastActivePartner,
  );

  static const AppError platformOwner = AppError(
    code: platformOwnerCode,
    userMessage:
        'You are the platform owner. Transfer ownership before deleting your account.',
    messageKey: AppMessageKey.errYouAreThePlatformOwner,
  );

  static const AppError unavailable = AppError(
    code: unavailableCode,
    userMessage: 'Unable to update your account. Please try again.',
    messageKey: AppMessageKey.errUnableToUpdateYourAccount,
    kind: AppErrorKind.unavailable,
  );
}
