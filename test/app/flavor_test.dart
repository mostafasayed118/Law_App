import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/flavor.dart';

void main() {
  group('AppFlavor.parse', () {
    test('empty resolves to production (legacy flavor-less behavior)', () {
      expect(AppFlavor.parse(''), AppFlavor.production);
    });

    test('accepts development and dev spellings', () {
      expect(AppFlavor.parse('development'), AppFlavor.development);
      expect(AppFlavor.parse('dev'), AppFlavor.development);
    });

    test('accepts production and prod spellings', () {
      expect(AppFlavor.parse('production'), AppFlavor.production);
      expect(AppFlavor.parse('prod'), AppFlavor.production);
    });

    test('rejects unknown values fast', () {
      expect(() => AppFlavor.parse('staging'), throwsStateError);
    });
  });

  group('AppConfig defaults', () {
    test('development owns the dev display name and .dev application ID', () {
      const AppConfig config = AppConfig.development();
      expect(config.flavor, AppFlavor.development);
      expect(config.appName, 'LegalHub Dev');
      expect(config.applicationId, 'com.legalhub.app.dev');
      expect(config.deepLinkScheme, 'com.legalhub.app.dev');
    });

    test('production keeps the store application ID byte-for-byte', () {
      const AppConfig config = AppConfig.production();
      expect(config.flavor, AppFlavor.production);
      expect(config.appName, 'LegalHub');
      expect(config.applicationId, 'com.legalhub.app');
      expect(config.deepLinkScheme, 'com.legalhub.app');
    });

    test('flavors own distinct deep-link schemes', () {
      expect(
        const AppConfig.development().deepLinkScheme,
        isNot(const AppConfig.production().deepLinkScheme),
      );
    });

    test('empty Supabase pair is not configured (DI stays on fakes)', () {
      expect(const AppConfig.development().isConfigured, isFalse);
      expect(
        const AppConfig.development(
          supabaseUrl: 'https://example.supabase.co',
        ).isConfigured,
        isFalse,
      );
      expect(
        const AppConfig.development(
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon-key',
        ).isConfigured,
        isTrue,
      );
    });

    test('toSupabaseEnv carries the pair to the Supabase seam', () {
      const AppConfig config = AppConfig.development(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      );
      final env = config.toSupabaseEnv();
      expect(env.url, 'https://example.supabase.co');
      expect(env.anonKey, 'anon-key');
      expect(env.isConfigured, isTrue);
    });
  });

  group('AppConfig.fromEnvironment', () {
    test('no dart-defines resolves to unconfigured production', () {
      final AppConfig config = AppConfig.fromEnvironment();
      expect(config.flavor, AppFlavor.production);
      expect(config.applicationId, 'com.legalhub.app');
      expect(config.isConfigured, isFalse);
    });

    test('pinned factories keep their flavor without dart-defines', () {
      expect(
        AppConfig.developmentFromEnvironment().flavor,
        AppFlavor.development,
      );
      expect(
        AppConfig.productionFromEnvironment().flavor,
        AppFlavor.production,
      );
      expect(
        AppConfig.developmentFromEnvironment().applicationId,
        'com.legalhub.app.dev',
      );
    });
  });
}
