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
import 'package:legalhub/main.dart';
import 'package:legalhub/shared/widgets/layout/two_pane.dart';

/// Two-pane master/detail on expanded windows (≥840dp) and the unchanged
/// push navigation below it.
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
      FakeOrganizationGateway(),
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
    await resetServiceLocator();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    configureDependencies();
    await tester.pumpWidget(
      LegalHubApp(
        router: router,
        authCubit: authCubit,
        localeCubit: localeCubit,
        themeCubit: themeCubit,
      ),
    );
    await tester.pumpAndSettle();
    await authCubit.startDemoSession();
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String route) async {
    router.go(route);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('phone keeps push navigation for matters and messages', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(411, 867));

    await go(tester, AppRoutes.matters);
    expect(find.byType(TwoPane), findsNothing);
    await tester.tap(find.text('Demo acquisition review'));
    await tester.pumpAndSettle();
    expect(find.text('Matter details'), findsOneWidget);

    await go(tester, AppRoutes.messages);
    expect(find.byType(TwoPane), findsNothing);
    await tester.tap(find.text('Demo matter updates'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('matters: wide window auto-selects and swaps the detail pane', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(1024, 768));
    await go(tester, AppRoutes.matters);

    expect(find.byType(TwoPane), findsOneWidget);
    // The first matter is auto-selected: list row + detail headline.
    expect(find.text('Demo acquisition review'), findsNWidgets(2));

    await tester.tap(find.text('Family status consultation'));
    await tester.pumpAndSettle();
    expect(find.text('Family status consultation'), findsNWidgets(2));
    expect(find.text('Demo acquisition review'), findsOneWidget);
    expect(find.byType(TwoPane), findsOneWidget);
  });

  testWidgets('matters: deep link opens the two-pane with that matter', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(1024, 768));
    await go(tester, '/matters/matter-2');

    expect(find.byType(TwoPane), findsOneWidget);
    expect(find.text('Commercial lease consultation'), findsNWidgets(2));
  });

  testWidgets('messages: wide window shows the transcript beside the list', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(1024, 768));
    await go(tester, AppRoutes.messages);

    expect(find.byType(TwoPane), findsOneWidget);
    // List row + embedded detail header.
    expect(find.text('Demo matter updates'), findsNWidgets(2));
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Consultation follow-up — demo'));
    await tester.pumpAndSettle();
    expect(find.text('Consultation follow-up — demo'), findsNWidgets(2));
    expect(find.text('Demo matter updates'), findsOneWidget);
  });

  testWidgets('messages: deep link opens the two-pane with that thread', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(1024, 768));
    router.go(
      AppRoutes.messageThreadDetailFor('thread-2'),
      extra: 'Consultation follow-up — demo',
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TwoPane), findsOneWidget);
    expect(find.text('Consultation follow-up — demo'), findsNWidgets(2));
  });

  testWidgets('two-pane survives text scale 2.0 on a tablet', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(1024, 768), textScale: 2.0);
    await go(tester, AppRoutes.matters);
    expect(find.byType(TwoPane), findsOneWidget);
    await go(tester, AppRoutes.messages);
    expect(find.byType(TwoPane), findsOneWidget);
  });

  testWidgets('booking shows the draft summary only on expanded windows', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(1024, 768));
    await go(tester, AppRoutes.book);
    expect(find.text('Review your booking'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);

    await pumpApp(tester, size: const Size(411, 867));
    await go(tester, AppRoutes.book);
    expect(find.text('Review your booking'), findsNothing);
  });

  testWidgets('phone pushes the document and invoice metadata details', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(411, 867));

    await go(tester, AppRoutes.vault);
    expect(find.byType(TwoPane), findsNothing);
    await tester.tap(find.text('Demo engagement letter'));
    await tester.pumpAndSettle();
    expect(find.text('Document details'), findsOneWidget);

    await go(tester, AppRoutes.invoices);
    await tester.tap(find.text('INV-2026-0001'));
    await tester.pumpAndSettle();
    expect(find.text('Invoice details'), findsOneWidget);
  });

  testWidgets('documents: wide window auto-selects and swaps the metadata', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(1024, 768));
    await go(tester, AppRoutes.vault);

    expect(find.byType(TwoPane), findsOneWidget);
    expect(find.text('Demo engagement letter'), findsNWidgets(2));
    expect(find.text('Type'), findsOneWidget);

    await tester.ensureVisible(find.text('Correspondence log — demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Correspondence log — demo'));
    await tester.pumpAndSettle();
    expect(find.text('Correspondence log — demo'), findsNWidgets(2));
    expect(find.byType(TwoPane), findsOneWidget);
  });

  testWidgets('invoices: wide window auto-selects and swaps the metadata', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(1024, 768));
    await go(tester, AppRoutes.invoices);

    expect(find.byType(TwoPane), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('EGP 1250.00'), findsOneWidget);

    await tester.tap(find.text('INV-2026-0003'));
    await tester.pumpAndSettle();
    expect(find.text('INV-2026-0003'), findsNWidgets(2));
    expect(find.text('EGP 620.00'), findsOneWidget);
  });

  testWidgets('document and invoice deep links open the two-pane', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(1024, 768));
    await go(tester, '/vault/doc-4');
    expect(find.byType(TwoPane), findsOneWidget);
    expect(find.text('Correspondence log — demo'), findsNWidgets(2));

    await go(tester, '/invoices/invoice-2');
    expect(find.byType(TwoPane), findsOneWidget);
    expect(find.text('INV-2026-0002'), findsNWidgets(2));
  });
}
