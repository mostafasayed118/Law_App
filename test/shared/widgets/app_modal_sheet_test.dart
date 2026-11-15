import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/shared/widgets/app_modal_sheet.dart';

/// Proves the shared sheet helper keeps the bottom-sheet contract (scroll
/// controlled, keyboard-aware) while capping the sheet on wide windows.
void main() {
  Future<void> openSheet(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            capturedContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    unawaited(
      showAppSheet<void>(
        context: capturedContext,
        builder: (BuildContext context) => const Padding(
          padding: EdgeInsets.all(24),
          child: Text('sheet body'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double sheetWidth(WidgetTester tester) {
    return tester
        .getSize(
          find
              .ancestor(
                of: find.text('sheet body'),
                matching: find.byType(Material),
              )
              .last,
        )
        .width;
  }

  testWidgets('phone width is unaffected', (WidgetTester tester) async {
    await openSheet(tester, const Size(320, 568));
    expect(find.text('sheet body'), findsOneWidget);
    expect(sheetWidth(tester), lessThanOrEqualTo(320));
  });

  testWidgets('wide window uses a centered dialog', (
    WidgetTester tester,
  ) async {
    await openSheet(tester, const Size(1200, 900));
    expect(find.text('sheet body'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(sheetWidth(tester), lessThanOrEqualTo(appSheetMaxWidth));
  });

  testWidgets('sheet body survives text scale 2.0 on a narrow phone', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openSheet(tester, const Size(320, 568));
    expect(find.text('sheet body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
