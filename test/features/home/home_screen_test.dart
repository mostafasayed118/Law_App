import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/home/presentation/home_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late AuthCubit authCubit;

  setUp(() {
    authCubit = AuthCubit(FakeAuthGateway(), InMemoryErrorReporter());
  });

  tearDown(() async {
    await authCubit.close();
  });

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

  testWidgets('renders the localized activity-card copy in English', (
    tester,
  ) async {
    await tester.pumpWidget(pumpHome(const Locale('en')));
    await tester.pumpAndSettle();

    // The Phase 5 booking entry renders above the activity cards, so the
    // activity content sits below the fold on a default test surface; scroll
    // it into view before asserting (slivers only build visible children).
    await tester.scrollUntilVisible(
      find.text('Estate of H. Vance vs. City'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // The hardcoded English strings must no longer be the source of these
    // labels — they now flow through AppLocalizations. Asserting the EN value
    // proves the keys resolve (regression guard for the localization fix).
    expect(find.text('Estate of H. Vance vs. City'), findsOneWidget);
    expect(find.text('Today, 10:00 AM'), findsOneWidget);
    expect(find.text('Atty. R. Sterling'), findsOneWidget);
    expect(find.textContaining('preliminary injunction'), findsOneWidget);
  });

  testWidgets('renders the localized activity-card copy in Arabic (RTL)', (
    tester,
  ) async {
    await tester.pumpWidget(pumpHome(const Locale('ar')));
    await tester.pumpAndSettle();

    // Same below-the-fold situation as the EN test: scroll the activity cards
    // into view before asserting the Arabic copy.
    await tester.scrollUntilVisible(
      find.text('تركة هـ. فانس ضد المدينة'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // The Arabic translations must render — the original hardcoded English
    // strings were a localization-contract violation. Asserting the Arabic
    // value proves the .arb keys resolve in all three locales, not just EN.
    expect(find.text('تركة هـ. فانس ضد المدينة'), findsOneWidget);
    expect(find.text('اليوم، ١٠:٠٠ صباحًا'), findsOneWidget);
    expect(find.text('المحامي ر. ستيرلينغ'), findsOneWidget);

    // Directionality is RTL for Arabic.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Directionality &&
            widget.textDirection == TextDirection.rtl,
      ),
      findsWidgets,
    );
  });

  group('booking entry (Phase 5 slice 5.2)', () {
    testWidgets('renders the entry card with the default capability map', (
      tester,
    ) async {
      await tester.pumpWidget(pumpHome(const Locale('en')));
      await tester.pumpAndSettle();

      // The default roleCapabilities grants canBookConsultation to every
      // bootstrap role, so the demo client sees the booking entry on the
      // dashboard (nav hint only, never an authorization grant).
      expect(find.text('Book a consultation'), findsOneWidget);
      expect(find.textContaining('Schedule a consultation'), findsOneWidget);
    });

    testWidgets('hides the entry when the capability is not granted', (
      tester,
    ) async {
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeScreen(
              capabilitiesForRole: <UserRole, RoleCapability>{
                UserRole.client: const RoleCapability(
                  canViewHome: true,
                  canViewSettings: true,
                  canBookConsultation: false,
                  canViewAttorneyDiscovery: true,
                  canViewMatters: true,
                  canViewDocuments: true,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Book a consultation'), findsNothing);
    });
  });

  group('discovery entry (Phase 6 slice 6.1)', () {
    testWidgets('renders the entry card with the default capability map', (
      tester,
    ) async {
      await tester.pumpWidget(pumpHome(const Locale('en')));
      await tester.pumpAndSettle();

      // The default roleCapabilities grants canViewAttorneyDiscovery to
      // every bootstrap role (D-A6), so the demo client sees the discovery
      // entry on the dashboard (nav hint only, never an authorization
      // grant).
      expect(find.text('Find an attorney'), findsOneWidget);
      expect(
        find.textContaining('Browse demo attorney profiles'),
        findsOneWidget,
      );
    });

    testWidgets('hides the entry when the capability is not granted', (
      tester,
    ) async {
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeScreen(
              capabilitiesForRole: <UserRole, RoleCapability>{
                UserRole.client: const RoleCapability(
                  canViewHome: true,
                  canViewSettings: true,
                  canBookConsultation: true,
                  canViewAttorneyDiscovery: false,
                  canViewMatters: false,
                  canViewDocuments: false,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find an attorney'), findsNothing);
    });
  });

  group('matter entry (Phase 7 slice 7.1)', () {
    testWidgets('renders the entry card with the default capability map', (
      tester,
    ) async {
      await tester.pumpWidget(pumpHome(const Locale('en')));
      await tester.pumpAndSettle();

      // The default roleCapabilities grants canViewMatters to every
      // bootstrap role (D-M6), so the demo client sees the matter entry
      // on the dashboard (nav hint only, never an authorization grant).
      expect(find.text('My matters'), findsOneWidget);
      expect(find.textContaining('Browse demo matter files'), findsOneWidget);
    });

    testWidgets('hides the entry when the capability is not granted', (
      tester,
    ) async {
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeScreen(
              capabilitiesForRole: <UserRole, RoleCapability>{
                UserRole.client: const RoleCapability(
                  canViewHome: true,
                  canViewSettings: true,
                  canBookConsultation: true,
                  canViewAttorneyDiscovery: true,
                  canViewMatters: false,
                  canViewDocuments: true,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My matters'), findsNothing);
    });
  });

  group('document vault entry (Phase 8 slice 8.1)', () {
    testWidgets('renders the entry card with the default capability map', (
      tester,
    ) async {
      await tester.pumpWidget(pumpHome(const Locale('en')));
      await tester.pumpAndSettle();

      // The default roleCapabilities grants canViewDocuments to every
      // bootstrap role (D-V5), so the demo client sees the vault entry on
      // the dashboard (nav hint only, never an authorization grant).
      expect(find.text('Document vault'), findsOneWidget);
      expect(
        find.textContaining('Browse demo document metadata'),
        findsOneWidget,
      );
    });

    testWidgets('hides the entry when the capability is not granted', (
      tester,
    ) async {
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeScreen(
              capabilitiesForRole: <UserRole, RoleCapability>{
                UserRole.client: const RoleCapability(
                  canViewHome: true,
                  canViewSettings: true,
                  canBookConsultation: true,
                  canViewAttorneyDiscovery: true,
                  canViewMatters: true,
                  canViewDocuments: false,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Document vault'), findsNothing);
    });
  });

  group('greeting fallback (D-T3 pin)', () {
    testWidgets(
      'falls back to the localized neutral name when no session is present',
      (tester) async {
        await tester.pumpWidget(pumpHome(const Locale('en')));
        await tester.pumpAndSettle();

        // No session has been started, so `session?.displayName ??
        // l10n.homeFallbackName` resolves to the localized neutral name.
        // This pin guards the D-T3 resolution (5.2): the fallback is no
        // longer a hardcoded English fixture — it flows through
        // AppLocalizations in every locale. The branch is reachable when
        // HomeScreen renders without a session (direct pump — the router
        // guard makes it unreachable via /home).
        expect(find.text('Hello, Guest'), findsOneWidget);
      },
    );

    testWidgets('fallback greeting is localized in Arabic and Turkish', (
      tester,
    ) async {
      // The neutral fallback must render in all three supported locales,
      // proving the D-T3 fixture string was removed, not just renamed.
      await tester.pumpWidget(pumpHome(const Locale('ar')));
      await tester.pumpAndSettle();
      expect(find.text('مرحبًا، ضيف'), findsOneWidget);

      await tester.pumpWidget(pumpHome(const Locale('tr')));
      await tester.pumpAndSettle();
      expect(find.text('Merhaba, Misafir'), findsOneWidget);
    });

    testWidgets('uses the session display name once a demo session is active', (
      tester,
    ) async {
      await authCubit.startDemoSession();
      await tester.pumpWidget(pumpHome(const Locale('en')));
      await tester.pumpAndSettle();

      // The session displayName replaces the fallback entirely.
      expect(find.text('Hello, Demo user'), findsOneWidget);
      expect(find.text('Hello, Guest'), findsNothing);
    });
  });
}
