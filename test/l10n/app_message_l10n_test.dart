import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/l10n/app_message_l10n.dart';

void main() {
  group('AppMessageKey inventory', () {
    test('has 129 unique values matching allAppMessageKeys', () {
      expect(AppMessageKey.values, hasLength(129));
      expect(allAppMessageKeys, hasLength(129));
      expect(allAppMessageKeys.toSet(), hasLength(129));
      expect(allAppMessageKeys.toSet(), AppMessageKey.values.toSet());
    });
  });

  group('appMessage', () {
    test('every inventory key resolves non-empty copy in EN, AR, and TR', () {
      const Map<AppMessageKey, Map<String, Object?>>
      argsByKey = <AppMessageKey, Map<String, Object?>>{
        AppMessageKey
                .errEnterAQuestionBetweenResearchRequestMinQuestionLengthAndResearchRequest:
            <String, Object?>{'minQuestionLength': 2, 'maxQuestionLength': 500},
        AppMessageKey.errMessageIsTooLongMaxMaxMessageLengthCharacters:
            <String, Object?>{'maxMessageLength': 2000},
      };
      for (final String code in <String>['en', 'ar', 'tr']) {
        final AppLocalizations l10n = lookupAppLocalizations(Locale(code));

        for (final AppMessageKey key in allAppMessageKeys) {
          final String copy = appMessage(
            l10n,
            key,
            args: argsByKey[key] ?? const <String, Object?>{},
          );

          expect(
            copy.trim(),
            isNotEmpty,
            reason: 'empty copy for $key in $code',
          );
          expect(
            copy,
            isNot(l10n.stateError),
            reason: '$key resolves the stateError fallback in $code',
          );
        }
      }
    });

    test('missing interpolation args fall back to stateError', () {
      for (final String code in <String>['en', 'ar', 'tr']) {
        final AppLocalizations l10n = lookupAppLocalizations(Locale(code));

        expect(
          appMessage(
            l10n,
            AppMessageKey.errMessageIsTooLongMaxMaxMessageLengthCharacters,
          ),
          l10n.stateError,
        );
        expect(
          appMessage(
            l10n,
            AppMessageKey
                .errEnterAQuestionBetweenResearchRequestMinQuestionLengthAndResearchRequest,
          ),
          l10n.stateError,
        );
      }
    });
  });
}
