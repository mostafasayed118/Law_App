import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/deep_link/deep_link_config.dart';
import 'package:legalhub/data/auth/auth_callback.dart';

void main() {
  group('AuthCallbackUri.pkceCode', () {
    test('accepts the custom-scheme recovery callback', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('com.legalhub.app://auth/v1/callback?code=abc123'),
        ),
        'abc123',
      );
    });

    test('accepts the development-flavor recovery callback', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('com.legalhub.app.dev://auth/v1/callback?code=abc123'),
        ),
        'abc123',
      );
    });

    test('honors a custom accepted-scheme set', () {
      const DeepLinkConfig devOnly = DeepLinkConfig(
        scheme: 'com.legalhub.app.dev',
        acceptedSchemes: <String>{'com.legalhub.app.dev'},
      );

      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('com.legalhub.app://auth/v1/callback?code=abc123'),
          config: devOnly,
        ),
        isNull,
      );
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('com.legalhub.app.dev://auth/v1/callback?code=abc123'),
          config: devOnly,
        ),
        'abc123',
      );
    });

    test('accepts the verified https callback', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('https://legalhub.app/auth/v1/callback?code=abc123'),
        ),
        'abc123',
      );
    });

    test('trims the code and tolerates a trailing slash', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('com.legalhub.app://auth/v1/callback/?code=%20abc%20'),
        ),
        'abc',
      );
    });

    test('rejects a missing code', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('com.legalhub.app://auth/v1/callback'),
        ),
        isNull,
      );
    });

    test('rejects a blank code', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('com.legalhub.app://auth/v1/callback?code=%20'),
        ),
        isNull,
      );
    });

    test('rejects an implicit-flow access token fragment', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse(
            'com.legalhub.app://auth/v1/callback'
            '#access_token=a&refresh_token=b&expires_in=3600'
            '&token_type=bearer',
          ),
        ),
        isNull,
      );
    });

    test('rejects implicit-flow tokens in the query next to a code', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse(
            'com.legalhub.app://auth/v1/callback'
            '?code=abc123&access_token=a',
          ),
        ),
        isNull,
      );
    });

    test('rejects a fragment even when a code is present', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('com.legalhub.app://auth/v1/callback?code=abc123#state=x'),
        ),
        isNull,
      );
    });

    test('rejects a foreign scheme', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('myapp://auth/v1/callback?code=abc123'),
        ),
        isNull,
      );
    });

    test('rejects a foreign https host', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('https://evil.example/auth/v1/callback?code=abc123'),
        ),
        isNull,
      );
    });

    test('rejects a different path on the auth host', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('com.legalhub.app://auth/v1/other?code=abc123'),
        ),
        isNull,
      );
    });

    test('rejects the custom-scheme accept-invite host', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse('com.legalhub.app://accept-invite?code=abc123'),
        ),
        isNull,
      );
    });

    test('rejects a foreign scheme with the right path', () {
      expect(
        AuthCallbackUri.pkceCode(
          Uri.parse(
            'https://legalhub.app.evil.example/auth/v1/callback?code=x',
          ),
        ),
        isNull,
      );
    });
  });
}
