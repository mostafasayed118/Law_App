import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/deep_link/app_link_parser.dart';
import 'package:legalhub/app/deep_link/deep_link_config.dart';
import 'package:legalhub/app/flavor.dart';

void main() {
  test('dev scheme classifies an accept-invite link', () {
    const config = DeepLinkConfig(scheme: 'com.legalhub.app.dev');
    final parser = AppLinkParser(config: config);
    final intent = parser.parse(config.acceptInviteUri('token-1'));
    expect(intent, isA<AcceptInviteIntent>());
    expect((intent as AcceptInviteIntent).token, 'token-1');
  });

  test('production scheme is unchanged', () {
    const parser = AppLinkParser();
    final intent = parser.parse(
      const DeepLinkConfig.production().acceptInviteUri('t-2'),
    );
    expect(intent, isA<AcceptInviteIntent>());
  });

  test('dev auth callback URI uses the dev scheme', () {
    expect(
      const DeepLinkConfig(
        scheme: 'com.legalhub.app.dev',
      ).authCallbackUri().toString(),
      'com.legalhub.app.dev://auth/v1/callback',
    );
  });

  test('production auth callback URI is unchanged', () {
    expect(
      const DeepLinkConfig.production().authCallbackUri().toString(),
      'com.legalhub.app://auth/v1/callback',
    );
  });

  test('forConfig follows the flavor application ID', () {
    expect(
      DeepLinkConfig.forConfig(const AppConfig.development()).scheme,
      'com.legalhub.app.dev',
    );
    expect(
      DeepLinkConfig.forConfig(const AppConfig.production()).scheme,
      'com.legalhub.app',
    );
  });

  test('acceptInviteUri trims the token and rejects a blank one', () {
    expect(
      const DeepLinkConfig.production().acceptInviteUri('  token-1  '),
      Uri.parse('com.legalhub.app://accept-invite?token=token-1'),
    );
    expect(
      () => const DeepLinkConfig.production().acceptInviteUri('   '),
      throwsArgumentError,
    );
  });
}
