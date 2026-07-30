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
      expect(LegalHubValidators.required(l10n, null), l10n.stateError);
      expect(LegalHubValidators.required(l10n, ''), l10n.stateError);
      expect(LegalHubValidators.required(l10n, '   '), l10n.stateError);
    });

    test('accepts non-empty trimmed values', () {
      expect(LegalHubValidators.required(l10n, 'a'), isNull);
      expect(LegalHubValidators.required(l10n, '  ab  '), isNull);
    });
  });

  group('LegalHubValidators.email', () {
    test('rejects empty and malformed addresses', () {
      expect(LegalHubValidators.email(l10n, null), l10n.stateError);
      expect(LegalHubValidators.email(l10n, ''), l10n.stateError);
      expect(LegalHubValidators.email(l10n, 'plainstring'), l10n.stateError);
      expect(LegalHubValidators.email(l10n, 'no-tld@domain'), l10n.stateError);
      expect(
        LegalHubValidators.email(l10n, 'space in@domain.com'),
        l10n.stateError,
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
      expect(v(null), l10n.stateError);
      expect(v(''), l10n.stateError);
      expect(v('1234567'), l10n.stateError);
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
      expect(v(null), l10n.stateError);
      expect(v(''), l10n.stateError);
      expect(v('different'), l10n.stateError);
    });

    test('accepts an exact match', () {
      expect(LegalHubValidators.matches(l10n, 'secret')('secret'), isNull);
    });
  });
}
