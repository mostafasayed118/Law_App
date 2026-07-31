import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/auth/presentation/forgot_password/otp_field_row.dart';

// OtpFieldRow is a pure presentation widget: it owns 6 controllers/focus nodes,
// auto-advances focus, exposes `code`/`clear()` via a GlobalKey, and publishes
// the all-cells-filled state to an optional ValueNotifier. These tests pin that
// contract directly.
//
// OtpFieldRow's TextFields need a Material ancestor (MaterialApp.home alone does
// not provide one), so each pump wraps the row in a Scaffold.
void main() {
  Widget pumpRow({
    int length = 6,
    GlobalKey<OtpFieldRowState>? key,
    ValueNotifier<bool>? notifier,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: OtpFieldRow(
          key: key,
          length: length,
          completionNotifier: notifier,
        ),
      ),
    );
  }

  testWidgets('renders exactly length cells (default 6)', (tester) async {
    await tester.pumpWidget(pumpRow());
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('renders a custom length when provided', (tester) async {
    await tester.pumpWidget(pumpRow(length: 4));
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('code is empty before any input', (tester) async {
    final GlobalKey<OtpFieldRowState> key = GlobalKey<OtpFieldRowState>();
    await tester.pumpWidget(pumpRow(key: key));
    await tester.pump();

    expect(key.currentState?.code, '');
  });

  testWidgets('code concatenates the entered digits in order', (tester) async {
    final GlobalKey<OtpFieldRowState> key = GlobalKey<OtpFieldRowState>();
    await tester.pumpWidget(pumpRow(key: key));
    await tester.pump();

    for (int i = 0; i < 6; i++) {
      await tester.enterText(find.byType(TextField).at(i), '${(i + 1) % 10}');
    }
    await tester.pump();

    expect(key.currentState?.code, '123456');
  });

  testWidgets('clear() empties every cell and resets code', (tester) async {
    final GlobalKey<OtpFieldRowState> key = GlobalKey<OtpFieldRowState>();
    await tester.pumpWidget(pumpRow(key: key));
    await tester.pump();

    for (int i = 0; i < 6; i++) {
      await tester.enterText(find.byType(TextField).at(i), '9');
    }
    await tester.pump();
    expect(key.currentState?.code, '999999');

    key.currentState?.clear();
    await tester.pump();

    expect(key.currentState?.code, '');
    for (final TextField t in tester.widgetList<TextField>(
      find.byType(TextField),
    )) {
      expect(t.controller?.text, '');
    }
  });

  testWidgets(
    'publishes false to completionNotifier until all cells are filled, then true',
    (tester) async {
      final ValueNotifier<bool> complete = ValueNotifier<bool>(false);
      addTearDown(complete.dispose);
      await tester.pumpWidget(pumpRow(notifier: complete));
      await tester.pump();

      // Initially incomplete.
      expect(complete.value, isFalse);

      // Fill 5 of 6: still incomplete.
      for (int i = 0; i < 5; i++) {
        await tester.enterText(find.byType(TextField).at(i), '1');
        await tester.pump();
      }
      expect(complete.value, isFalse);

      // Fill the 6th: complete.
      await tester.enterText(find.byType(TextField).at(5), '1');
      await tester.pump();
      expect(complete.value, isTrue);
    },
  );
}
