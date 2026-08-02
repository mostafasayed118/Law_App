import '../../../l10n/app_localizations.dart';

/// Reusable, pure input validators shared across auth and onboarding forms.
///
/// Each validator returns `null` when the value is acceptable and a localized
/// error string otherwise. They are deterministic and free of side effects so
/// they can be unit-tested in isolation.
class LegalHubValidators {
  LegalHubValidators._();

  /// Matches the common `local@domain.tld` shape used across the auth flows.
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Non-empty trimmed value.
  static String? required(AppLocalizations l10n, String? value) {
    final String text = value?.trim() ?? '';
    return text.isEmpty ? l10n.validatorRequired : null;
  }

  /// Valid email shape.
  static String? email(AppLocalizations l10n, String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty || !_emailRegex.hasMatch(text)) {
      return l10n.validatorEmailInvalid;
    }
    return null;
  }

  /// Minimum length, after trimming. `minLength` must be >= 0.
  static String? Function(String?) minLength(
    AppLocalizations l10n,
    int minLength,
  ) {
    if (minLength < 0) {
      throw ArgumentError('minLength must be non-negative: $minLength');
    }
    return (String? value) {
      final String text = value ?? '';
      return text.length < minLength
          ? l10n.validatorMinLength(minLength)
          : null;
    };
  }

  /// Value must equal [other] and be non-empty. Used for password confirmation.
  static String? Function(String?) matches(
    AppLocalizations l10n,
    String other,
  ) {
    return (String? value) {
      final String text = value ?? '';
      return (text.isEmpty || text != other) ? l10n.validatorMismatch : null;
    };
  }
}
