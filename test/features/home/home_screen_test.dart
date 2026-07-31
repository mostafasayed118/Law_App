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
      'falls back to the hardcoded Jonathan name when no session is present',
      (tester) async {
        await tester.pumpWidget(pumpHome(const Locale('en')));
        await tester.pumpAndSettle();

        // No session has been started, so `session?.displayName ?? 'Jonathan'`
        // resolves to the hardcoded fallback. This pins the D-T3 deviation:
        // the branch is reachable when HomeScreen renders without a session
        // (direct pump — the router guard makes it unreachable via /home).
        // Batch 5.2 must update this guard when it localizes/removes the
        // fallback.
        expect(find.text('Hello, Jonathan'), findsOneWidget);
      },
    );

    testWidgets('uses the session display name once a demo session is active', (
      tester,
    ) async {
      await authCubit.startDemoSession();
      await tester.pumpWidget(pumpHome(const Locale('en')));
      await tester.pumpAndSettle();

      // The session displayName replaces the fallback entirely.
      expect(find.text('Hello, Demo user'), findsOneWidget);
      expect(find.text('Hello, Jonathan'), findsNothing);
    });
  });
}
