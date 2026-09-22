import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The secure key-value seam this adapter is built on, isolated so tests can
/// fake it: the real one is the platform plugin, which needs a platform
/// channel a unit test cannot satisfy.
abstract interface class SecureSessionStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// The real seam: flutter_secure_storage — Keychain on iOS, the Android
/// Keystore-backed cipher (v11 default: AES-GCM data encryption with RSA-OAEP
/// key wrapping, no biometric prompt) on Android.
///
/// The iOS accessibility is [KeychainAccessibility.first_unlock]: the item is
/// readable once the device has been unlocked after a restart, which is the
/// standard choice for a refresh token — it keeps background token refreshes
/// working across a reboot instead of failing until the user unlocks.
class FlutterSecureSessionStore implements SecureSessionStore {
  const FlutterSecureSessionStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// The legacy plaintext seam this migration replaces (P1.2's "before"): the
/// refresh token in SharedPreferences — plaintext `NSUserDefaults` on iOS and
/// an XML file on Android. Read once during migration, then deleted.
abstract interface class LegacyPlaintextSession {
  Future<String?> read(String key);

  Future<void> remove(String key);
}

class SharedPreferencesPlaintextSession implements LegacyPlaintextSession {
  const SharedPreferencesPlaintextSession();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _prefs()).getString(key);

  @override
  Future<void> remove(String key) async => (await _prefs()).remove(key);
}

/// The session-persistence seam backed by the platform Keychain/Keystore —
/// P1.2's iOS half (owner decision OI-D3, 2026-09-22).
///
/// supabase_flutter's default [LocalStorage] persists the refresh token in
/// SharedPreferences. This implementation keeps the exact same key scheme
/// ([defaultKeyFor]) and wire behaviour, but the payload goes through
/// [SecureSessionStore], and an existing plaintext session is migrated once
/// instead of forcing a sign-out on upgrade.
///
/// It also implements gotrue's [GotrueAsyncStorage], so the PKCE code verifier
/// is stored through the same secure seam — the default kept that plaintext
/// too, and a verifier is a bearer-grade secret for the duration of the flow.
/// Pass `this` to **both** `authOptions.localStorage` and
/// `authOptions.pkceAsyncStorage`.
class SecureSupabaseLocalStorage extends LocalStorage
    implements GotrueAsyncStorage {
  SecureSupabaseLocalStorage({
    required this.persistSessionKey,
    this.secureStore = const FlutterSecureSessionStore(),
    this.legacyStore = const SharedPreferencesPlaintextSession(),
  });

  /// The key supabase_flutter derives for its default storage:
  /// `sb-<first label of the host>-auth-token`.
  static String defaultKeyFor(String supabaseUrl) =>
      'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';

  final String persistSessionKey;
  final SecureSessionStore secureStore;
  final LegacyPlaintextSession legacyStore;

  String? _cache;

  bool _migrated = false;

  @override
  Future<void> initialize() async {
    await _migrateLegacyPlaintext();
    _cache = await secureStore.read(persistSessionKey);
  }

  /// One-time migration (P1.2): a session persisted by the previous plaintext
  /// storage moves into the secure store and is deleted from SharedPreferences.
  ///
  /// Best-effort by design — a migration failure must not crash startup. The
  /// worst case is a sign-out on next launch, never an error surfaced to the
  /// user.
  Future<void> _migrateLegacyPlaintext() async {
    if (_migrated) {
      return;
    }
    _migrated = true;
    try {
      final String? legacy = await legacyStore.read(persistSessionKey);
      if (legacy == null) {
        return;
      }
      final String? current = await secureStore.read(persistSessionKey);
      if (current == null) {
        await secureStore.write(persistSessionKey, legacy);
      }
      await legacyStore.remove(persistSessionKey);
    } on Exception {
      // Best-effort; see the comment above.
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    _cache ??= await secureStore.read(persistSessionKey);
    return _cache != null;
  }

  @override
  Future<String?> accessToken() async {
    _cache ??= await secureStore.read(persistSessionKey);
    return _cache;
  }

  @override
  Future<void> removePersistedSession() async {
    _cache = null;
    await secureStore.delete(persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    _cache = persistSessionString;
    await secureStore.write(persistSessionKey, persistSessionString);
  }

  @override
  Future<String?> getItem({required String key}) => secureStore.read(key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      secureStore.write(key, value);

  @override
  Future<void> removeItem({required String key}) => secureStore.delete(key);
}
