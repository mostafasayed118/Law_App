import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/theme/theme_cubit.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/data/local/in_memory_theme_mode_store.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/auth/presentation/sign_in_screen.dart';
import 'package:legalhub/main.dart';

// The app-level theme-mode wiring: LegalHubApp reads ThemeCubit.state for
// MaterialApp.themeMode (system by default), so the persisted choice flips
// the whole app live. These tests pin that the cubit → MaterialApp seam is
// real (a dark selection actually renders the dark ThemeData).
void main() {
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late ThemeCubit themeCubit;
  late GoRouter router;

  setUp(() {
    authCubit = AuthCubit(
      FakeAuthGateway(),
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
    );
    localeCubit = LocaleCubit(InMemoryLocaleStore());
    themeCubit = ThemeCubit(InMemoryThemeModeStore());
    router = createAppRouter(authCubit);
  });

  tearDown(() async {
    router.dispose();
    await authCubit.close();
    await localeCubit.close();
    await themeCubit.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      LegalHubApp(
        router: router,
        authCubit: authCubit,
        localeCubit: localeCubit,
        themeCubit: themeCubit,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The theme MaterialApp applies to its descendants — read from a context
  /// below MaterialApp (the sign-in screen), not MaterialApp's own context
  /// (which sits above the Theme it injects).
  ThemeData appTheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SignInScreen)));

  testWidgets('starts in system mode by default', (tester) async {
    await pumpApp(tester);

    expect(themeCubit.state, ThemeMode.system);
    // ThemeMode.system resolves through the platform brightness; in tests
    // the platform is light, so the light theme is in effect.
    expect(appTheme(tester).brightness, Brightness.light);
  });

  testWidgets('setting dark flips the running app to the dark theme', (
    tester,
  ) async {
    await pumpApp(tester);

    await themeCubit.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(appTheme(tester).brightness, Brightness.dark);
  });

  testWidgets('setting light flips the running app back to light', (
    tester,
  ) async {
    await themeCubit.setThemeMode(ThemeMode.dark);
    await pumpApp(tester);
    expect(appTheme(tester).brightness, Brightness.dark);

    await themeCubit.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();

    expect(appTheme(tester).brightness, Brightness.light);
  });

  testWidgets('a persisted dark choice is restored on boot (restart)', (
    tester,
  ) async {
    // Seed the store before the app starts — the restart equivalent.
    final InMemoryThemeModeStore store = InMemoryThemeModeStore();
    await store.write(ThemeMode.dark);
    themeCubit = ThemeCubit(store);
    await themeCubit.load();

    await pumpApp(tester);

    expect(themeCubit.state, ThemeMode.dark);
    expect(appTheme(tester).brightness, Brightness.dark);
  });
}
