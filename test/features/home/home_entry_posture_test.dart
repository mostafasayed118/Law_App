import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/backend_posture.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/auth/data/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/home/domain/home_entries.dart';
import 'package:legalhub/features/home/presentation/home_screen.dart';
import 'package:legalhub/features/orgs/data/fake_membership_repository.dart';
import 'package:legalhub/features/orgs/data/fake_organization_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// W3 / device finding F1: in a configured (real-backend) build the
/// dashboard must not advertise server-backed features as demo data. Every
/// current entry — discovery and AI research included — has a Supabase
/// gateway, so all twelve carry configured-build wording. A future fake-only
/// entry would keep its demo wording in every build.
void main() {
  late AuthCubit authCubit;

  setUp(() {
    authCubit = AuthCubit(
      FakeAuthGateway(),
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
  });

  tearDown(() async {
    await authCubit.close();
    await resetServiceLocator();
  });

  /// Registers the configured (real-backend) posture — the seam the app
  /// registers when the Supabase env is configured.
  void useConfiguredBackend() {
    serviceLocator.registerSingleton<BackendPosture>(
      const BackendPosture(isLocalOnly: false),
    );
  }

  Widget pumpHome(
    Locale locale, {
    Map<UserRole, RoleCapability> capabilitiesForRole = roleCapabilities,
  }) {
    return BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(capabilitiesForRole: capabilitiesForRole),
      ),
    );
  }

  /// Every entry the dashboard can show, with the capability set that keeps
  /// all twelve visible (the AI-research gate is the only role-varying one).
  List<HomeEntry> allEntries() =>
      homeEntriesFor(const RoleCapability(canUseAiResearch: true));

  group('home entry gateway truth', () {
    test('classifies every entry by whether its gateway is server-backed', () {
      final Map<String, bool> expected = <String, bool>{
        'booking': true,
        'video': true,
        'discovery': true,
        'matters': true,
        'documents': true,
        'messages': true,
        'invoices': true,
        'notifications': true,
        'alerts': true,
        'tasks': true,
        'approvals': true,
        'research': true,
      };
      final List<HomeEntry> entries = allEntries();

      // The twelve ids and their order are pinned: a new entry must be
      // classified here too, never silently defaulted.
      expect(
        entries.map((HomeEntry e) => e.id).toList(),
        expected.keys.toList(),
      );
      for (final HomeEntry entry in entries) {
        expect(
          entry.isServerBacked,
          expected[entry.id],
          reason: 'entry ${entry.id} gateway truth',
        );
      }
    });

    test('only the server-backed entries carry configured-build wording', () {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));

      for (final HomeEntry entry in allEntries()) {
        final String? configured = entry.configuredSubtitle?.call(l10n);
        if (entry.isServerBacked) {
          expect(configured, isNotNull);
          // The configured-build wording must never claim demo data.
          expect(configured, isNot(contains('demo')));
          // ... and it must differ from the demo wording it replaces.
          expect(configured, isNot(entry.subtitle(l10n)));
        } else {
          // A (future) fake-only entry has no configured-build wording at
          // all: its demo wording is truthful in every build and stays.
          expect(configured, isNull);
          expect(entry.subtitle(l10n), contains('demo'));
        }

        // The resolution rule: the demo posture always shows the demo
        // wording; the configured posture shows the real wording only for a
        // server-backed entry.
        expect(entry.subtitleFor(l10n, localOnly: true), entry.subtitle(l10n));
        expect(
          entry.subtitleFor(l10n, localOnly: false),
          entry.isServerBacked ? configured : entry.subtitle(l10n),
          reason: 'entry ${entry.id} configured-posture subtitle',
        );
      }
    });
  });

  group('home entry copy follows the backend posture', () {
    testWidgets(
      'demo posture keeps the demo wording on a server-backed entry',
      (tester) async {
        await tester.pumpWidget(pumpHome(const Locale('en')));
        await tester.pumpAndSettle();

        // No BackendPosture registered => the historical demo posture.
        expect(
          find.text('Schedule a consultation — development demo.'),
          findsOneWidget,
        );
        expect(
          find.text('Schedule a consultation with an available attorney.'),
          findsNothing,
        );
      },
    );

    testWidgets('configured posture reads as the real feature', (tester) async {
      useConfiguredBackend();
      await tester.pumpWidget(pumpHome(const Locale('en')));
      await tester.pumpAndSettle();

      expect(
        find.text('Schedule a consultation with an available attorney.'),
        findsOneWidget,
      );
      expect(
        find.text('Schedule a consultation — development demo.'),
        findsNothing,
      );
    });

    testWidgets(
      'configured posture drops the demo wording on discovery and research',
      (tester) async {
        useConfiguredBackend();
        await tester.pumpWidget(
          pumpHome(
            const Locale('en'),
            capabilitiesForRole: <UserRole, RoleCapability>{
              // No session is restored in this test: Home projects the client
              // role, so the test override must key the client row.
              UserRole.client: const RoleCapability(
                canViewAttorneyDiscovery: true,
                canUseAiResearch: true,
              ),
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Find an attorney'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text('Browse attorney profiles and practice areas.'),
          findsOneWidget,
        );
        expect(
          find.text('Browse demo attorney profiles — development demo.'),
          findsNothing,
        );

        await tester.scrollUntilVisible(
          find.text('AI research'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(
            'Ask the research assistant across your matters and documents — '
            'advisory only.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Ask the demo research assistant — advisory only.'),
          findsNothing,
        );
      },
    );

    testWidgets('demo posture keeps the discovery demo wording', (
      tester,
    ) async {
      await tester.pumpWidget(pumpHome(const Locale('en')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Find an attorney'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Browse demo attorney profiles — development demo.'),
        findsOneWidget,
      );
      expect(
        find.text('Browse attorney profiles and practice areas.'),
        findsNothing,
      );
    });

    testWidgets('configured posture reads the real wording in Arabic', (
      tester,
    ) async {
      useConfiguredBackend();
      await tester.pumpWidget(pumpHome(const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('احجز استشارة مع محامٍ متاح.'), findsOneWidget);
      expect(find.text('جدولة استشارة — عرض تجريبي للتطوير.'), findsNothing);
    });
  });
}
