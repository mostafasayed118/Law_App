import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/deep_link/app_link_parser.dart';

void main() {
  group('AppLinkParser', () {
    const AppLinkParser parser = AppLinkParser();

    test('classifies an accept-invite share link with its token', () {
      final AppLinkIntent intent = parser.parse(
        Uri.parse('com.legalhub.app://accept-invite?token=one-time-token'),
      );

      expect(intent, isA<AcceptInviteIntent>());
      expect((intent as AcceptInviteIntent).token, 'one-time-token');
    });

    test('trims the token (share links may carry accidental whitespace)', () {
      final AppLinkIntent intent = parser.parse(
        Uri.parse('com.legalhub.app://accept-invite?token=%20token-1%20'),
      );

      expect((intent as AcceptInviteIntent).token, 'token-1');
    });

    test('an accept link without a token is not actionable', () {
      final AppLinkIntent intent = parser.parse(
        Uri.parse('com.legalhub.app://accept-invite'),
      );

      expect(intent, isA<NoAppLinkIntent>());
    });

    test('an accept link with a blank token is not actionable', () {
      final AppLinkIntent intent = parser.parse(
        Uri.parse('com.legalhub.app://accept-invite?token=%20'),
      );

      expect(intent, isA<NoAppLinkIntent>());
    });

    test('a recovery callback URI is classified but left to the observer', () {
      final AppLinkIntent intent = parser.parse(
        Uri.parse('com.legalhub.app://auth/v1/callback?code=abc'),
      );

      expect(intent, isA<RecoveryIntent>());
    });

    test('a foreign scheme is ignored', () {
      final AppLinkIntent intent = parser.parse(
        Uri.parse('https://example.com/accept-invite?token=x'),
      );

      expect(intent, isA<NoAppLinkIntent>());
    });

    test('a foreign host on the app scheme is ignored', () {
      final AppLinkIntent intent = parser.parse(
        Uri.parse('com.legalhub.app://other-host?token=x'),
      );

      expect(intent, isA<NoAppLinkIntent>());
    });

    test('an auth host with a foreign path is ignored', () {
      final AppLinkIntent intent = parser.parse(
        Uri.parse('com.legalhub.app://auth/other'),
      );

      expect(intent, isA<NoAppLinkIntent>());
    });
  });

  group('AppLinkParser.acceptInviteUri (produce side)', () {
    test('builds the canonical accept-invite share link', () {
      expect(
        AppLinkParser.acceptInviteUri('token-1'),
        Uri.parse('com.legalhub.app://accept-invite?token=token-1'),
      );
    });

    test('round-trips: parse(acceptInviteUri(t)) is AcceptInviteIntent(t)', () {
      final AppLinkIntent intent = const AppLinkParser().parse(
        AppLinkParser.acceptInviteUri('t-42'),
      );

      expect(intent, isA<AcceptInviteIntent>());
      expect((intent as AcceptInviteIntent).token, 't-42');
    });

    test('encodes token characters via the query, then round-trips', () {
      const String token = 'a&b c=12';
      final AppLinkIntent intent = const AppLinkParser().parse(
        AppLinkParser.acceptInviteUri(token),
      );

      expect(intent, isA<AcceptInviteIntent>());
      expect((intent as AcceptInviteIntent).token, token);
    });

    test('trims accidental whitespace before building the link', () {
      expect(
        AppLinkParser.acceptInviteUri('  token-1  '),
        Uri.parse('com.legalhub.app://accept-invite?token=token-1'),
      );
    });

    test('rejects a blank token (an accept link needs its token)', () {
      expect(() => AppLinkParser.acceptInviteUri('   '), throwsArgumentError);
    });
  });
}
