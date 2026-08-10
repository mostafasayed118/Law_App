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

  /// Strong-password policy for account creation and password reset,
  /// following the NIST 800-63B / OWASP posture the project committed to:
  ///
  ///  - at least [_passwordMinLength] characters (12),
  ///  - at least 3 of the 4 character classes (lower, upper, digit, symbol),
  ///  - never contain the user's email (local part or full address) —
  ///    context-specific words are the first thing attackers try.
  ///
  /// [email] is optional: pass it when the form knows the account email (sign
  /// up, threaded reset) so the inclusion rule can apply; deep-link/refresh
  /// fallbacks without an email skip that one rule only.
  static String? Function(String?) strongPassword(
    AppLocalizations l10n, {
    String? email,
  }) {
    return (String? value) {
      final String text = value ?? '';
      if (text.length < _passwordMinLength) {
        return l10n.validatorPasswordLength(_passwordMinLength);
      }
      if (classCount(text) < _passwordMinClasses) {
        return l10n.validatorPasswordClasses;
      }
      if (email != null && containsEmail(text, email)) {
        return l10n.validatorPasswordEmail;
      }
      return null;
    };
  }

  /// Scores a candidate password into a coarse strength level for the live
  /// strength indicator on the auth forms. Pure and deterministic so it is
  /// unit-testable in isolation. The label/icon — never color alone — is what
  /// carries the meaning in the UI.
  static PasswordStrength passwordStrength(String value) {
    final int classes = classCount(value);
    int score = classes;
    if (value.length >= _passwordMinLength) {
      score += 1;
    }
    if (value.length >= _passwordStrongLength) {
      score += 1;
    }
    if (score >= _strongThreshold) {
      return PasswordStrength.strong;
    }
    if (score >= _fairThreshold) {
      return PasswordStrength.fair;
    }
    return PasswordStrength.weak;
  }

  /// How many of the four character classes (lower, upper, digit, symbol)
  /// appear in [value]. Exposed for the strength scorer and tests.
  static int classCount(String value) {
    int count = 0;
    if (_lowercase.hasMatch(value)) {
      count += 1;
    }
    if (_uppercase.hasMatch(value)) {
      count += 1;
    }
    if (_digit.hasMatch(value)) {
      count += 1;
    }
    if (_symbol.hasMatch(value)) {
      count += 1;
    }
    return count;
  }

  /// True when [email]'s local part (or the full address) appears inside
  /// [password], case-insensitively. Guards against "context-specific words"
  /// per NIST 800-63B.
  static bool containsEmail(String password, String email) {
    final String normalized = password.toLowerCase();
    final String trimmed = email.trim().toLowerCase();
    final String local = trimmed.split('@').first.trim();
    return (local.isNotEmpty && normalized.contains(local)) ||
        (trimmed.isNotEmpty && normalized.contains(trimmed));
  }

  static const int _passwordMinLength = 12;
  static const int _passwordMinClasses = 3;
  static const int _passwordStrongLength = 16;
  static const int _fairThreshold = 4;
  static const int _strongThreshold = 6;

  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _symbol = RegExp(r'[^a-zA-Z0-9\s]');
}

/// Coarse strength tiers for the password-strength indicator. The label and
/// icon are the primary signal; color is only an enhancement (the auth forms
/// never rely on color alone — ADR-0002 dark-theme posture).
enum PasswordStrength { weak, fair, strong }
