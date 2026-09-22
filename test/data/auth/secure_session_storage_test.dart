import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/auth/secure_session_storage.dart';

/// In-memory fakes: the real seam is a platform plugin (Keychain/Keystore)
/// that a unit test cannot satisfy.
class _FakeSecureStore implements SecureSessionStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _FakeLegacyStore implements LegacyPlaintextSession {
  final Map<String, String> _values = <String, String>{};

  void seed(String key, String value) => _values[key] = value;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

void main() {
  const String key = 'sb-demo-auth-token';

  group('SecureSupabaseLocalStorage (P1.2 iOS half, OI-D3)', () {
    test("defaultKeyFor derives supabase_flutter's key scheme", () {
      expect(
        SecureSupabaseLocalStorage.defaultKeyFor(
          'https://exampleproject.supabase.co',
        ),
        'sb-exampleproject-auth-token',
      );
    });

    test('persists and reads the session through the secure seam', () async {
      final _FakeSecureStore secure = _FakeSecureStore();
      final SecureSupabaseLocalStorage storage = SecureSupabaseLocalStorage(
        persistSessionKey: key,
        secureStore: secure,
        legacyStore: _FakeLegacyStore(),
      );

      await storage.initialize();
      expect(await storage.hasAccessToken(), isFalse);

      await storage.persistSession('{"access_token":"a"}');
      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), '{"access_token":"a"}');
      expect(secure._values[key], '{"access_token":"a"}');
    });

    test('removePersistedSession clears the payload', () async {
      final SecureSupabaseLocalStorage storage = SecureSupabaseLocalStorage(
        persistSessionKey: key,
        secureStore: _FakeSecureStore(),
        legacyStore: _FakeLegacyStore(),
      );
      await storage.initialize();
      await storage.persistSession('{"access_token":"a"}');

      await storage.removePersistedSession();

      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    });

    test('serves the PKCE verifier through the same secure seam', () async {
      // gotrue's GotrueAsyncStorage surface. The code verifier is a
      // bearer-grade secret for the duration of the flow, so it moves to the
      // secure seam together with the session — the default kept it plaintext.
      final _FakeSecureStore secure = _FakeSecureStore();
      final SecureSupabaseLocalStorage storage = SecureSupabaseLocalStorage(
        persistSessionKey: key,
        secureStore: secure,
        legacyStore: _FakeLegacyStore(),
      );

      await storage.setItem(key: 'pkce-verifier', value: 'v3r1f13r');

      expect(await storage.getItem(key: 'pkce-verifier'), 'v3r1f13r');
      expect(secure._values['pkce-verifier'], 'v3r1f13r');

      await storage.removeItem(key: 'pkce-verifier');
      expect(await storage.getItem(key: 'pkce-verifier'), isNull);
    });

    test(
      'migrates a legacy plaintext session and deletes the plaintext',
      () async {
        final _FakeSecureStore secure = _FakeSecureStore();
        final _FakeLegacyStore legacy = _FakeLegacyStore()
          ..seed(key, '{"legacy":true}');
        final SecureSupabaseLocalStorage storage = SecureSupabaseLocalStorage(
          persistSessionKey: key,
          secureStore: secure,
          legacyStore: legacy,
        );

        await storage.initialize();

        // The session survived the upgrade, and the plaintext copy is gone.
        expect(await storage.accessToken(), '{"legacy":true}');
        expect(legacy._values, isEmpty);
      },
    );

    test(
      'never overwrites a live secure session with the legacy one',
      () async {
        final _FakeSecureStore secure = _FakeSecureStore();
        final _FakeLegacyStore legacy = _FakeLegacyStore()
          ..seed(key, '{"legacy":true}');
        final SecureSupabaseLocalStorage storage = SecureSupabaseLocalStorage(
          persistSessionKey: key,
          secureStore: secure,
          legacyStore: legacy,
        );
        await secure.write(key, '{"current":true}');

        await storage.initialize();

        expect(await storage.accessToken(), '{"current":true}');
      },
    );
  });
}
