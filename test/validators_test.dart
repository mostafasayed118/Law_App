import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/l10n/app_localizations_en.dart';
import 'package:legalhub/shared/forms/validators.dart';

void main() {
  late final AppLocalizationsEn l10n;

  setUpAll(() {
    l10n = AppLocalizationsEn();
  });

  group('LegalHubValidators.required', () {
    test('rejects null and whitespace-only values', () {
      expect(LegalHubValidators.required(l10n, null), l10n.validatorRequired);
      expect(LegalHubValidators.required(l10n, ''), l10n.validatorRequired);
      expect(LegalHubValidators.required(l10n, '   '), l10n.validatorRequired);
    });

    test('accepts non-empty trimmed values', () {
      expect(LegalHubValidators.required(l10n, 'a'), isNull);
      expect(LegalHubValidators.required(l10n, '  ab  '), isNull);
    });
  });

  group('LegalHubValidators.email', () {
    test('rejects empty and malformed addresses', () {
      expect(LegalHubValidators.email(l10n, null), l10n.validatorEmailInvalid);
      expect(LegalHubValidators.email(l10n, ''), l10n.validatorEmailInvalid);
      expect(
        LegalHubValidators.email(l10n, 'plainstring'),
        l10n.validatorEmailInvalid,
      );
      expect(
        LegalHubValidators.email(l10n, 'no-tld@domain'),
        l10n.validatorEmailInvalid,
      );
      expect(
        LegalHubValidators.email(l10n, 'space in@domain.com'),
        l10n.validatorEmailInvalid,
      );
    });

    test('accepts well-formed addresses after trimming', () {
      expect(LegalHubValidators.email(l10n, 'a@b.co'), isNull);
      expect(LegalHubValidators.email(l10n, '  user@example.org  '), isNull);
    });
  });

  group('LegalHubValidators.minLength', () {
    test('throws on negative thresholds', () {
      expect(() => LegalHubValidators.minLength(l10n, -1), throwsArgumentError);
    });

    test('rejects values shorter than the threshold', () {
      final v = LegalHubValidators.minLength(l10n, 8);
      expect(v(null), l10n.validatorMinLength(8));
      expect(v(''), l10n.validatorMinLength(8));
      expect(v('1234567'), l10n.validatorMinLength(8));
    });

    test('accepts values at or beyond the threshold', () {
      final v = LegalHubValidators.minLength(l10n, 8);
      expect(v('12345678'), isNull);
      expect(v('123456789'), isNull);
    });
  });

  group('LegalHubValidators.matches', () {
    test('rejects empty, null, or differing values', () {
      final v = LegalHubValidators.matches(l10n, 'secret');
      expect(v(null), l10n.validatorMismatch);
      expect(v(''), l10n.validatorMismatch);
      expect(v('different'), l10n.validatorMismatch);
    });

    test('accepts an exact match', () {
      expect(LegalHubValidators.matches(l10n, 'secret')('secret'), isNull);
    });
  });

  group('LegalHubValidators.strongPassword', () {
    test('rejects empty and too-short values with the length message', () {
      final v = LegalHubValidators.strongPassword(l10n);
      expect(v(null), l10n.validatorPasswordLength(12));
      expect(v(''), l10n.validatorPasswordLength(12));
      // 9 chars — below the 12-char floor even with 3+ classes.
      expect(v('Abc12!Xy'), l10n.validatorPasswordLength(12));
      // 11 chars — still under the floor.
      expect(v('1234567890a'), l10n.validatorPasswordLength(12));
    });

    test('rejects values with fewer than 3 of 4 classes', () {
      final v = LegalHubValidators.strongPassword(l10n);
      // 12+ chars, lowercase + digits only = 2 classes.
      expect(v('abcdefghijk1'), l10n.validatorPasswordClasses);
      // 12+ chars, lowercase + uppercase only = 2 classes.
      expect(v('abcdefghijkL'), l10n.validatorPasswordClasses);
    });

    test('rejects passwords containing the account email', () {
      final v = LegalHubValidators.strongPassword(
        l10n,
        email: 'amira@example.com',
      );
      // Meets length + classes, but the local part appears verbatim.
      expect(v('AmiraStr0ng-Pass'), l10n.validatorPasswordEmail);
      // The full address is embedded.
      expect(v('Str0ng-Pass-amira@example.com'), l10n.validatorPasswordEmail);
    });

    test('accepts a password meeting every rule', () {
      final v = LegalHubValidators.strongPassword(
        l10n,
        email: 'amira@example.com',
      );
      expect(v('Str0ng-Pass-1'), isNull);
    });

    test('skips the email rule when no email is available', () {
      final v = LegalHubValidators.strongPassword(l10n);
      // Would trip the email rule with the email supplied; without it, the
      // same value is accepted (deep-link/refresh reset fallback).
      expect(v('AmiraStr0ng-Pass'), isNull);
    });
  });

  group('LegalHubValidators.classCount', () {
    test('counts how many of the 4 classes appear', () {
      expect(LegalHubValidators.classCount('lowercase'), 1);
      expect(LegalHubValidators.classCount('lowerUPPER'), 2);
      expect(LegalHubValidators.classCount('lowerUpper12'), 3);
      expect(LegalHubValidators.classCount('Lower-Upper-12!'), 4);
    });
  });

  group('LegalHubValidators.containsEmail', () {
    test('matches the local part and full address case-insensitively', () {
      expect(
        LegalHubValidators.containsEmail('AmiraStr0ng', 'amira@example.com'),
        isTrue,
      );
      expect(
        LegalHubValidators.containsEmail(
          'Str0ng-Pass-amira@example.com',
          'amira@example.com',
        ),
        isTrue,
      );
      expect(
        LegalHubValidators.containsEmail('Str0ng-Pass', 'amira@example.com'),
        isFalse,
      );
    });
  });

  group('LegalHubValidators.passwordStrength', () {
    test('tiers map to weak / fair / strong', () {
      expect(LegalHubValidators.passwordStrength(''), PasswordStrength.weak);
      expect(LegalHubValidators.passwordStrength('abc'), PasswordStrength.weak);
      // 4 classes + 12+ chars (score 5) → fair.
      expect(
        LegalHubValidators.passwordStrength('Str0ng-Pass-1'),
        PasswordStrength.fair,
      );
      // 4 classes + 16+ chars (score 6) → strong.
      expect(
        LegalHubValidators.passwordStrength('Str0ng-Pass-1234'),
        PasswordStrength.strong,
      );
    });
  });
}
