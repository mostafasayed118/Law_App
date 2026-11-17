import 'package:flutter/material.dart';
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
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/main.dart';

import '../support/render_fonts.dart';
import '../support/screenshot_research_fixture.dart';

/// F-T8-02 RED: the screenshot path must show a completed demo run, never the
/// "no research runs yet" empty state.
void main() {
  testWidgets('screenshot research fixture shows a completed demo run', (
    WidgetTester tester,
  ) async {
    await resetServiceLocator();
    configureDependencies();
    final AuthCubit auth = AuthCubit(
      FakeAuthGateway(),
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
    final LocaleCubit locale = LocaleCubit(InMemoryLocaleStore());
    await locale.load();
    final ThemeCubit theme = ThemeCubit(InMemoryThemeModeStore());
    await theme.load();
    final GoRouter router = createAppRouter(auth);
    addTearDown(() async {
      router.dispose();
      await auth.close();
      await locale.close();
      await theme.close();
      return resetServiceLocator();
    });

    await loadRenderFonts();
    await locale.setLocale(const Locale('en'));
    await theme.setThemeMode(ThemeMode.light);
    await tester.pumpWidget(
      LegalHubApp(
        router: router,
        authCubit: auth,
        localeCubit: locale,
        themeCubit: theme,
      ),
    );
    await tester.pumpAndSettle();
    await auth.startDemoSession();
    await tester.pumpAndSettle();

    await seedScreenshotResearchFixture();
    router.go(AppRoutes.research);
    await tester.pumpAndSettle();

    expect(find.text('Demo research: sample matter brief'), findsOneWidget);
    expect(
      find.text(
        AppLocalizations.of(
          tester.element(find.byType(Scaffold).first),
        ).aiResearchRunsEmpty,
      ),
      findsNothing,
    );
  });
}
