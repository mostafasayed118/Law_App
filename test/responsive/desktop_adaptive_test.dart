import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:legalhub/features/home/presentation/widgets/practice_area_card.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/main.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

/// Desktop/foldable adaptive behavior: hinge-aware two-pane geometry, the
/// click cursor on every tappable card, and keyboard traversal order.
void main() {
  group('two-pane foldable geometry', () {
    Future<void> pumpPane(
      WidgetTester tester, {
      required List<DisplayFeature> features,
    }) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(displayFeatures: features),
                child: const Scaffold(
                  body: TwoPane(list: Text('MASTER'), detail: Text('DETAIL')),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a vertical hinge replaces the divider with its width', (
      WidgetTester tester,
    ) async {
      await pumpPane(
        tester,
        features: const <DisplayFeature>[
          DisplayFeature(
            bounds: Rect.fromLTWH(500, 0, 24, 800),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      expect(find.text('MASTER'), findsOneWidget);
      expect(find.text('DETAIL'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('two-pane-hinge-gap'))).width,
        24,
      );
      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('a fold (crease) keeps the 1px divider', (
      WidgetTester tester,
    ) async {
      await pumpPane(
        tester,
        features: const <DisplayFeature>[
          DisplayFeature(
            bounds: Rect.fromLTWH(500, 0, 8, 800),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      );

      expect(find.byKey(const Key('two-pane-hinge-gap')), findsNothing);
      expect(find.byType(VerticalDivider), findsOneWidget);
    });
  });

  Future<void> expectClickCursor(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: KeyedSubtree(key: const Key('hover-target'), child: widget),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('hover-target'))),
    );
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
      reason: '${widget.runtimeType} must show a click cursor',
    );
    await gesture.removePointer();
  }

  testWidgets('AppTile shows the click cursor', (WidgetTester tester) async {
    await expectClickCursor(
      tester,
      AppTile(icon: Icons.folder_outlined, title: 'Row', onTap: () {}),
    );
  });

  testWidgets('AppEntryCard shows the click cursor', (
    WidgetTester tester,
  ) async {
    await expectClickCursor(
      tester,
      AppEntryCard(
        icon: Icons.folder_outlined,
        title: 'Entry',
        subtitle: 'Subtitle',
        onTap: () {},
      ),
    );
  });

  testWidgets('PracticeAreaCard shows the click cursor', (
    WidgetTester tester,
  ) async {
    await expectClickCursor(
      tester,
      PracticeAreaCard(icon: Icons.gavel, label: 'Area', onTap: () {}),
    );
  });

  testWidgets('MatterLinkChip shows the click cursor', (
    WidgetTester tester,
  ) async {
    await expectClickCursor(tester, MatterLinkChip(onTap: () {}));
  });

  testWidgets('Tab traversal visits the rail and reaches the content', (
    WidgetTester tester,
  ) async {
    final AuthCubit authCubit = AuthCubit(
      FakeAuthGateway(),
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
    final LocaleCubit localeCubit = LocaleCubit(InMemoryLocaleStore());
    final ThemeCubit themeCubit = ThemeCubit(InMemoryThemeModeStore());
    final GoRouter router = createAppRouter(authCubit);
    addTearDown(() async {
      router.dispose();
      await authCubit.close();
      await localeCubit.close();
      await themeCubit.close();
      await resetServiceLocator();
    });

    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    bool sawFocus = false;
    bool sawRail = false;
    bool sawOutsideRail = false;
    for (int i = 0; i < 16; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final FocusNode? focus = FocusManager.instance.primaryFocus;
      final BuildContext? context = focus?.context;
      if (focus == null || context == null) {
        continue;
      }
      sawFocus = true;
      bool insideRail = false;
      context.visitAncestorElements((Element element) {
        if (element.widget is NavigationRail) {
          insideRail = true;
          return false;
        }
        return true;
      });
      if (insideRail) {
        sawRail = true;
      } else {
        sawOutsideRail = true;
      }
    }

    expect(sawFocus, isTrue);
    expect(sawRail, isTrue, reason: 'Tab must reach the navigation rail');
    expect(
      sawOutsideRail,
      isTrue,
      reason: 'Tab must leave the rail and reach the content',
    );
  });
}
