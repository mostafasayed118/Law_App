import 'dart:convert';

/// Build-time Supabase configuration consumed from `--dart-define-from-file`.
///
/// The values come from `String.fromEnvironment`, which the Flutter tool
/// injects from the git-ignored `.env` file at build time (bootstrap spec
/// §4.6, `docs/p0_decision_capture.md` §2). `.env.example` stays names-only
/// so no secret ever enters version control.
class SupabaseEnv {
  const SupabaseEnv({required this.url, required this.anonKey});

  /// Reads the URL + anon key from `String.fromEnvironment` (the values
  /// `--dart-define-from-file=.env` injects at build time). When the file is
  /// absent or empty, both are the empty string and [isConfigured] is false.
  factory SupabaseEnv.fromEnvironment() => const SupabaseEnv(
    url: String.fromEnvironment('SUPABASE_URL'),
    anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  final String url;
  final String anonKey;

  /// True only when both values are present. A partially configured env is
  /// not treated as configured: the DI flip stays on the fake rather than
  /// wiring a half-initialized provider.
  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Decodes the JWT `role` claim of [anonKey] (payload segment only).
  ///
  /// This is a **configuration guard, not a security boundary**: the anon
  /// public key is a publishable credential and the provider verifies the
  /// signature at runtime. The guard exists to stop a privileged key
  /// (e.g. `service_role`) from ever being consumed on the Flutter client
  /// (contract §2.6, ADR-0007, `p0_decision_capture.md` §2).
  ///
  /// Returns null when [anonKey] is not a decodable three-part JWT.
  static String? roleClaim(String anonKey) {
    final List<String> parts = anonKey.split('.');
    if (parts.length != 3) {
      return null;
    }
    try {
      final String payload = base64Url.normalize(parts[1]);
      final Object? decoded = jsonDecode(
        utf8.decode(base64Url.decode(payload)),
      );
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final Object? role = decoded['role'];
      return role is String ? role : null;
    } on FormatException {
      return null;
    }
  }

  /// Refuses a configured key that does not carry the `anon` role.
  ///
  /// Batch 3.3 guard: the client build may only consume the anon public key.
  /// A `service_role` key (or any undecodable value) is a hard configuration
  /// error — fail fast rather than silently wiring a privileged credential
  /// into the client.
  static void ensureAnonKey(String anonKey) {
    final String? role = roleClaim(anonKey);
    if (role != 'anon') {
      final String found = role == null
          ? 'an undecodable value'
          : 'role "$role"';
      throw StateError(
        'SUPABASE_ANON_KEY must carry the "anon" role (found $found). '
        'A service-role key must never be consumed on the Flutter client.',
      );
    }
  }

  /// Refuses a Supabase URL that does not use HTTPS.
  ///
  /// Audit guard (A02:2021): without this, a `SUPABASE_URL` misconfigured
  /// with `http://` would still connect, exposing the auth token and all
  /// data over cleartext — even though the Android shell blocks cleartext
  /// traffic, desktop/test builds have no such backstop. Like
  /// [ensureAnonKey] this is a configuration guard: fail fast at startup
  /// rather than transmitting credentials insecurely.
  static void ensureHttpsUrl(String url) {
    final Uri? parsed = Uri.tryParse(url);
    if (parsed == null || parsed.scheme != 'https' || parsed.host.isEmpty) {
      throw StateError(
        'SUPABASE_URL must be an https:// URL '
        '(found "${url.isEmpty ? '<empty>' : url}").',
      );
    }
  }
}
