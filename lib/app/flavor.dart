import '../data/auth/supabase_env.dart';

/// Build flavors for the LegalHub client.
///
/// `development` is the day-to-day loop (dev app name, `.dev` application
/// ID suffix, dev Supabase project). `production` is the store-facing
/// configuration (un-suffixed IDs, prod Supabase project). The native shells
/// mirror the same split: Android `productFlavors` (`development` /
/// `production`) and the matching iOS schemes/configurations.
enum AppFlavor {
  /// Day-to-day development build (`LegalHub Dev`, `com.legalhub.app.dev`).
  development,

  /// Store-facing build (`LegalHub`, `com.legalhub.app`).
  production;

  /// Parses the `APP_FLAVOR` dart-define. Empty (flag absent) resolves to
  /// [production] so legacy flavor-less invocations
  /// (`flutter run --dart-define-from-file=.env`) keep today's behavior.
  /// Any other unknown value is a hard configuration error.
  static AppFlavor parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case '':
      case 'production':
      case 'prod':
        return AppFlavor.production;
      case 'development':
      case 'dev':
        return AppFlavor.development;
      default:
        throw StateError(
          'APP_FLAVOR must be "development" or "production" '
          '(found "$raw").',
        );
    }
  }
}

/// Flavor-scoped build configuration.
///
/// Values flow from `--dart-define` / `--dart-define-from-file` at build
/// time (never from committed source): `APP_FLAVOR` selects the flavor and
/// the remaining keys override that flavor's defaults. The per-flavor
/// template files (`.env.development.example` / `.env.production.example`)
/// document every key by name; real values live in the git-ignored
/// `.env.development` / `.env.production` files.
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.applicationId,
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  /// Development defaults: dev display name + `.dev` application ID.
  /// Supabase credentials still come from the build's dart-defines.
  const AppConfig.development({
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.apiBaseUrl = '',
  }) : flavor = AppFlavor.development,
       appName = 'LegalHub Dev',
       applicationId = 'com.legalhub.app.dev';

  /// Production defaults: store display name + un-suffixed application ID.
  const AppConfig.production({
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.apiBaseUrl = '',
  }) : flavor = AppFlavor.production,
       appName = 'LegalHub',
       applicationId = 'com.legalhub.app';

  /// Reads the configuration from build-time dart-defines.
  ///
  /// `APP_FLAVOR` picks the default set; `APP_NAME`, `APPLICATION_ID`,
  /// `API_BASE_URL`, `SUPABASE_URL`, and `SUPABASE_ANON_KEY` each override
  /// their default when non-empty. An empty Supabase pair means "not
  /// configured": the DI flip stays on the credential-free fakes, so
  /// env-less runs and tests keep working.
  factory AppConfig.fromEnvironment() {
    const String rawFlavor = String.fromEnvironment('APP_FLAVOR');
    final AppFlavor flavor = AppFlavor.parse(rawFlavor);
    final AppConfig defaults = flavor == AppFlavor.development
        ? const AppConfig.development()
        : const AppConfig.production();
    return _fromEnvironment(defaults);
  }

  /// Development entrypoint config: same keys as [fromEnvironment] but the
  /// flavor identity (name + application ID defaults) is pinned to
  /// development, so `-t lib/main_development.dart` always yields a dev
  /// configuration regardless of the `APP_FLAVOR` define.
  factory AppConfig.developmentFromEnvironment() =>
      _fromEnvironment(const AppConfig.development());

  /// Production entrypoint config: mirrors
  /// [developmentFromEnvironment] for `-t lib/main_production.dart`.
  factory AppConfig.productionFromEnvironment() =>
      _fromEnvironment(const AppConfig.production());

  static AppConfig _fromEnvironment(AppConfig defaults) {
    const String appName = String.fromEnvironment('APP_NAME');
    const String applicationId = String.fromEnvironment('APPLICATION_ID');
    const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return AppConfig(
      flavor: defaults.flavor,
      appName: appName.isEmpty ? defaults.appName : appName,
      applicationId: applicationId.isEmpty
          ? defaults.applicationId
          : applicationId,
      apiBaseUrl: apiBaseUrl.isEmpty ? defaults.apiBaseUrl : apiBaseUrl,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  }

  /// Which flavor this configuration describes.
  final AppFlavor flavor;

  /// OS-visible display name (`LegalHub Dev` vs `LegalHub`).
  final String appName;

  /// Android `applicationId` / iOS bundle identifier.
  final String applicationId;

  /// Base URL of the LegalHub REST backend, when one is configured.
  /// Empty means "no separate backend": Supabase is the backend.
  final String apiBaseUrl;

  /// Supabase project URL for this flavor.
  final String supabaseUrl;

  /// Supabase anon public key for this flavor (never a service-role key;
  /// the anon-key guard in [SupabaseEnv.ensureAnonKey] still applies).
  final String supabaseAnonKey;

  /// The custom-scheme deep link host. By convention it matches the
  /// [applicationId] (audit doc §12.19), so each flavor owns its scheme and
  /// a dev install cannot intercept production recovery links.
  String get deepLinkScheme => applicationId;

  /// True only when both Supabase values are present. A partially configured
  /// env is not treated as configured: the DI flip stays on the fakes rather
  /// than wiring a half-initialized provider.
  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Adapts this config to the Supabase seam consumed by bootstrap.
  SupabaseEnv toSupabaseEnv() =>
      SupabaseEnv(url: supabaseUrl, anonKey: supabaseAnonKey);
}
