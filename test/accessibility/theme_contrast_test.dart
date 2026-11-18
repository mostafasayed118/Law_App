import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:material_ui/material_ui.dart';

/// WCAG 2.2 contrast floor for body text (4.5:1), computed on the real theme
/// tokens rather than eyeballed. Both brightnesses are pinned; a future token
/// edit that drops a foreground below the floor fails here instead of shipping
/// unreadable text.
void main() {
  double relativeLuminance(Color color) {
    double linear(num channel) {
      final double c = channel / 255.0;
      if (c <= 0.04045) {
        return c / 12.92;
      }
      return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    // Use the explicit ARGB integer rather than the deprecated .value getter
    // or channel accessors whose numeric type shifted across Flutter releases.
    final int argb = color.toARGB32();
    return 0.2126 * linear((argb >> 16) & 0xFF) +
        0.7152 * linear((argb >> 8) & 0xFF) +
        0.0722 * linear(argb & 0xFF);
  }

  double contrast(Color foreground, Color background) {
    final double a = relativeLuminance(foreground);
    final double b = relativeLuminance(background);
    final double lighter = a > b ? a : b;
    final double darker = a > b ? b : a;
    return (lighter + 0.05) / (darker + 0.05);
  }

  const double bodyFloor = 4.5;

  group('light theme body-text pairs', () {
    const Map<String, (Color, Color)> pairs = <String, (Color, Color)>{
      'onSurface/surface': (LegalHubTheme.onSurface, LegalHubTheme.surface),
      'onSurfaceVariant/surface': (
        LegalHubTheme.onSurfaceVariant,
        LegalHubTheme.surface,
      ),
      'onPrimary/primary': (LegalHubTheme.onPrimary, LegalHubTheme.primary),
      'onSecondary/secondary': (
        LegalHubTheme.onSecondary,
        LegalHubTheme.secondary,
      ),
      'onSecondaryContainer/secondaryContainer': (
        LegalHubTheme.onSecondaryContainer,
        LegalHubTheme.secondaryContainer,
      ),
      'onError/error': (LegalHubTheme.onError, LegalHubTheme.error),
      'onErrorContainer/errorContainer': (
        LegalHubTheme.onErrorContainer,
        LegalHubTheme.errorContainer,
      ),
    };

    for (final MapEntry<String, (Color, Color)> pair in pairs.entries) {
      test('${pair.key} >= $bodyFloor:1', () {
        final double ratio = contrast(pair.value.$1, pair.value.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(bodyFloor),
          reason: '${pair.key} is $ratio:1',
        );
      });
    }
  });

  group('dark theme body-text pairs', () {
    const Map<String, (Color, Color)> pairs = <String, (Color, Color)>{
      'darkOnSurface/darkSurface': (
        LegalHubTheme.darkOnSurface,
        LegalHubTheme.darkSurface,
      ),
      'darkOnSurfaceVariant/darkSurface': (
        LegalHubTheme.darkOnSurfaceVariant,
        LegalHubTheme.darkSurface,
      ),
      'darkOnPrimary/darkPrimary': (
        LegalHubTheme.darkOnPrimary,
        LegalHubTheme.darkPrimary,
      ),
      'darkOnSecondary/darkSecondary': (
        LegalHubTheme.darkOnSecondary,
        LegalHubTheme.darkSecondary,
      ),
      'darkOnSecondaryContainer/darkSecondaryContainer': (
        LegalHubTheme.darkOnSecondaryContainer,
        LegalHubTheme.darkSecondaryContainer,
      ),
      'darkOnError/darkError': (
        LegalHubTheme.darkOnError,
        LegalHubTheme.darkError,
      ),
      'darkOnErrorContainer/darkErrorContainer': (
        LegalHubTheme.darkOnErrorContainer,
        LegalHubTheme.darkErrorContainer,
      ),
    };

    for (final MapEntry<String, (Color, Color)> pair in pairs.entries) {
      test('${pair.key} >= $bodyFloor:1', () {
        final double ratio = contrast(pair.value.$1, pair.value.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(bodyFloor),
          reason: '${pair.key} is $ratio:1',
        );
      });
    }
  });
}
