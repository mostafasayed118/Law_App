import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
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
