import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/app/theme/theme_cubit.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/data/local/in_memory_theme_mode_store.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/main.dart';
import 'package:material_ui/material_ui.dart';

/// Flutter's built-in accessibility guidelines on a representative slice of
/// the app. The two tap-target guidelines and the label guideline are the
/// cheap, structural signals; text-contrast is pinned by the token-level test
/// in `theme_contrast_test.dart` because widget-level contrast cannot see
/// theme-derived colors through every custom widget.
void main() {
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late ThemeCubit themeCubit;
  late GoRouter router;

  setUp(() async {
    await resetServiceLocator();
    configureDependencies();
    authCubit = AuthCubit(
      FakeAuthGateway(),
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
    localeCubit = LocaleCubit(InMemoryLocaleStore());
    await localeCubit.load();
    themeCubit = ThemeCubit(InMemoryThemeModeStore());
    await themeCubit.load();
  });

  tearDown(() async {
    router.dispose();
    await authCubit.close();
    await localeCubit.close();
    await themeCubit.close();
    await resetServiceLocator();
  });

  Future<void> open(
    WidgetTester tester,
    String route, {
    bool signedIn = true,
  }) async {
    if (signedIn) {
      await authCubit.startDemoSession();
    }
    // Build the router AFTER the session decision: the shell routes redirect
    // to sign-in while signed out, which would silently test the wrong screen.
    router = createAppRouter(authCubit);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LegalHubApp(
        router: router,
        authCubit: authCubit,
        localeCubit: localeCubit,
        themeCubit: themeCubit,
      ),
    );
    await tester.pumpAndSettle();
    router.go(route);
    await tester.pumpAndSettle();
  }

  const Map<String, String> screens = <String, String>{
    'sign-in': AppRoutes.signIn,
    'sign-up': AppRoutes.signUp,
    'home': AppRoutes.home,
    'matters': AppRoutes.matters,
    'messages': AppRoutes.messages,
    'library': AppRoutes.library,
    'saved': AppRoutes.librarySaved,
    'settings': AppRoutes.settings,
    'account': AppRoutes.settingsAccount,
    'profile': AppRoutes.profile,
    'privacy': AppRoutes.privacy,
    'terms': AppRoutes.terms,
  };

  for (final MapEntry<String, String> screen in screens.entries) {
    final bool signedIn = screen.key != 'sign-in' && screen.key != 'sign-up';
    testWidgets('${screen.key}: labeled tap targets', (tester) async {
      await open(tester, screen.value, signedIn: signedIn);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('${screen.key}: Android 48dp tap targets', (tester) async {
      await open(tester, screen.value, signedIn: signedIn);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  }
}
