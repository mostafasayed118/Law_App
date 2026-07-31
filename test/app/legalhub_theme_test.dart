import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';

// B5 acceptance (bootstrap spec §7): the theme package passes when the light
// ColorScheme.primary is Midnight Blue #0b1d2e. ADR-0005 reconciled the
// undocumented #041627 to the canonical value. These tests pin the token so
// future drift fails loudly instead of silently propagating to app-bar text,
// elevated buttons, and links.
void main() {
  group('LegalHubTheme light tokens (ADR-0005)', () {
    test(
      'light ColorScheme.primary is the canonical Midnight Blue #0b1d2e',
      () {
        final ThemeData light = LegalHubTheme.light;

        expect(light.colorScheme.primary, const Color(0xFF0B1D2E));
      },
    );

    test(
      'light primaryContainer is #1A2B3C — a tracked deviation from spec #0b1d2e',
      () {
        // ADR-0005 Open condition: primary-container (#1A2B3C in code vs
        // #0b1d2e in spec) is a separate tracked deviation to be reconciled in
        // a follow-up batch with a light/dark + EN/AR/RTL visual review.
        // Pinning the current value here means that follow-up batch has a
        // failing test to update, so the change can't slip in silently.
        final ThemeData light = LegalHubTheme.light;

        expect(light.colorScheme.primaryContainer, const Color(0xFF1A2B3C));
      },
    );

    test('light secondary is Old Gold #775A19', () {
      final ThemeData light = LegalHubTheme.light;

      expect(light.colorScheme.secondary, const Color(0xFF775A19));
    });

    test('light surface is the tiered cool-white #F8F9FF', () {
      final ThemeData light = LegalHubTheme.light;

      expect(light.colorScheme.surface, const Color(0xFFF8F9FF));
    });

    test('light error is #BA1A1A (not color-alone for status)', () {
      final ThemeData light = LegalHubTheme.light;

      expect(light.colorScheme.error, const Color(0xFFBA1A1A));
    });
  });

  group('LegalHubTheme dark tokens (ADR-0002)', () {
    test('dark ColorScheme.primary is the light-on-dark #B7C8DE', () {
      final ThemeData dark = LegalHubTheme.dark;

      expect(dark.colorScheme.primary, const Color(0xFFB7C8DE));
    });

    test('dark surface is #0D1C2E', () {
      final ThemeData dark = LegalHubTheme.dark;

      expect(dark.colorScheme.surface, const Color(0xFF0D1C2E));
    });
  });

  group('LegalHubTheme spacing and radius constants', () {
    test('exposes the documented spacing scale', () {
      // Pinning the scale guards against a token rename that silently
      // changes every layout using these constants.
      expect(LegalHubTheme.spaceXs, 4);
      expect(LegalHubTheme.spaceSm, 8);
      expect(LegalHubTheme.spaceMd, 16);
      expect(LegalHubTheme.spaceLg, 24);
      expect(LegalHubTheme.spaceXl, 32);
      expect(LegalHubTheme.marginMobile, 20);
      expect(LegalHubTheme.marginDesktop, 40);
    });

    test('exposes the documented radius scale', () {
      expect(LegalHubTheme.radiusSm, 2);
      expect(LegalHubTheme.radiusDefault, 4);
      expect(LegalHubTheme.radiusMd, 6);
      expect(LegalHubTheme.radiusLg, 8);
      expect(LegalHubTheme.radiusXl, 12);
      expect(LegalHubTheme.radiusFull, 9999);
    });
  });

  group('LegalHubTheme font selection by locale', () {
    test('uses NotoSans for Latin locales', () {
      // ThemeData no longer exposes a top-level fontFamily; the family is set
      // on the text theme styles. bodyLarge is a representative body style.
      final ThemeData theme = LegalHubTheme.forLocale(const Locale('en'));

      expect(theme.textTheme.bodyLarge?.fontFamily, 'NotoSans');
    });

    test('uses NotoNaskhArabic for Arabic (RTL) locales', () {
      final ThemeData theme = LegalHubTheme.forLocale(const Locale('ar'));

      expect(theme.textTheme.bodyLarge?.fontFamily, 'NotoNaskhArabic');
    });

    test('uses PlayfairDisplay for Latin display headings', () {
      final ThemeData theme = LegalHubTheme.forLocale(const Locale('en'));

      expect(theme.textTheme.displaySmall?.fontFamily, 'PlayfairDisplay');
    });

    test('falls back to NotoNaskhArabic for Arabic display headings', () {
      final ThemeData theme = LegalHubTheme.forLocale(const Locale('ar'));

      expect(theme.textTheme.displaySmall?.fontFamily, 'NotoNaskhArabic');
    });
  });
}
