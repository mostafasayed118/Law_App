import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/backend_posture.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/home/domain/home_entries.dart';
import 'package:legalhub/features/home/presentation/home_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// W3 / device finding F1: in a configured (real-backend) build the
/// dashboard must not advertise the server-backed features as demo data.
/// The fake-only entries (video, discovery, compliance alerts, pending
/// approvals, AI research) keep their demo wording in EVERY build — their
/// gateways have no Supabase implementation, so the demo wording is the
/// truthful one.
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

  Widget pumpHome(Locale locale) {
    return BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
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
        'video': false,
        'discovery': false,
        'matters': true,
        'documents': true,
        'messages': true,
        'invoices': true,
        'notifications': true,
        'alerts': false,
        'tasks': true,
        'approvals': false,
        'research': false,
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
          // Fake-only entries have no configured-build wording at all: their
          // demo wording is truthful in every build and stays.
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

    testWidgets('configured posture keeps the fake-only entries truthful', (
      tester,
    ) async {
      useConfiguredBackend();
      await tester.pumpWidget(pumpHome(const Locale('en')));
      await tester.pumpAndSettle();

      // The discovery gateway is fake-only: its data is synthetic in every
      // build, so the demo wording stays — gating it would hide the truth.
      await tester.scrollUntilVisible(
        find.text('Find an attorney'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Browse demo attorney profiles — development demo.'),
        findsOneWidget,
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
