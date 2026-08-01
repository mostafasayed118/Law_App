import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/auth/supabase_env.dart';

/// Builds a JWT-shaped string whose payload carries the given role claim.
/// Matches the base64url convention used by the supabase adapter tests.
String _jwtWithRole(String role) {
  final String header = base64Url
      .encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
      .replaceAll('=', '');
  final String payload = base64Url
      .encode(utf8.encode('{"iss":"supabase","role":"$role","iat":1784988109}'))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

void main() {
  group('SupabaseEnv.roleClaim', () {
    test('decodes the anon role from a well-formed key', () {
      expect(SupabaseEnv.roleClaim(_jwtWithRole('anon')), 'anon');
    });

    test('decodes a service_role claim (so the guard can refuse it)', () {
      expect(
        SupabaseEnv.roleClaim(_jwtWithRole('service_role')),
        'service_role',
      );
    });

    test('returns null for a non-JWT value', () {
      expect(SupabaseEnv.roleClaim('not-a-jwt'), isNull);
    });

    test('returns null for a two-part token', () {
      expect(SupabaseEnv.roleClaim('header.payload'), isNull);
    });

    test('returns null when the payload is not a JSON object', () {
      final String payload = base64Url
          .encode(utf8.encode('"just a string"'))
          .replaceAll('=', '');
      expect(SupabaseEnv.roleClaim('h.$payload.s'), isNull);
    });

    test('returns null when the role claim is not a string', () {
      final String payload = base64Url
          .encode(utf8.encode('{"role":42}'))
          .replaceAll('=', '');
      expect(SupabaseEnv.roleClaim('h.$payload.s'), isNull);
    });
  });

  group('SupabaseEnv.ensureAnonKey', () {
    test('accepts an anon public key', () {
      expect(
        () => SupabaseEnv.ensureAnonKey(_jwtWithRole('anon')),
        returnsNormally,
      );
    });

    test('refuses a service_role key', () {
      expect(
        () => SupabaseEnv.ensureAnonKey(_jwtWithRole('service_role')),
        throwsStateError,
      );
    });

    test('refuses an undecodable value', () {
      expect(() => SupabaseEnv.ensureAnonKey('not-a-jwt'), throwsStateError);
    });
  });

  group('SupabaseEnv configuration', () {
    test('isConfigured requires both url and anon key', () {
      expect(const SupabaseEnv(url: '', anonKey: '').isConfigured, isFalse);
      expect(
        const SupabaseEnv(
          url: 'https://x.supabase.co',
          anonKey: '',
        ).isConfigured,
        isFalse,
      );
      expect(const SupabaseEnv(url: '', anonKey: 'key').isConfigured, isFalse);
      expect(
        const SupabaseEnv(
          url: 'https://x.supabase.co',
          anonKey: 'key',
        ).isConfigured,
        isTrue,
      );
    });
  });
}
