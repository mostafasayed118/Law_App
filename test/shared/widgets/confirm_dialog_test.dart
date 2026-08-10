import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/confirm_dialog.dart';

// showConfirmDialog is the E4 extraction: the member-removal (roster),
// delete-account (profile), and demo-account-delete (admin) dialogs
// previously duplicated this exact AlertDialog. These tests pin the shared
// contract — title/content render, cancel resolves false, the error-tinted
// confirm resolves true — so the re-pointed call sites keep their behavior.
void main() {
  testWidgets('renders title, content, and both actions', (tester) async {
    await tester.pumpWidget(const OpenConfirmDialogHarness());
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Confirm title'), findsOneWidget);
    expect(find.text('Confirm content'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete forever'), findsOneWidget);
  });

  testWidgets('cancel resolves to false and closes the dialog', (tester) async {
    await tester.pumpWidget(const OpenConfirmDialogHarness());
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('result:false'), findsOneWidget);
    expect(find.text('Confirm title'), findsNothing);
  });

  testWidgets('confirm resolves to true and closes the dialog', (tester) async {
    await tester.pumpWidget(const OpenConfirmDialogHarness());
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();

    expect(find.text('result:true'), findsOneWidget);
    expect(find.text('Confirm title'), findsNothing);
  });

  testWidgets('confirm button is error-tinted (M3 destructive pattern)', (
    tester,
  ) async {
    await tester.pumpWidget(const OpenConfirmDialogHarness());
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete forever'),
    );
    final Color? backgroundColor = button.style?.backgroundColor?.resolve(
      <WidgetState>{},
    );

    expect(backgroundColor, LegalHubTheme.light.colorScheme.error);
  });
}

class OpenConfirmDialogHarness extends StatefulWidget {
  const OpenConfirmDialogHarness({super.key});

  @override
  State<OpenConfirmDialogHarness> createState() =>
      OpenConfirmDialogHarnessState();
}

class OpenConfirmDialogHarnessState extends State<OpenConfirmDialogHarness> {
  String result = 'no result';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: LegalHubTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        // The harness State's own context sits above the MaterialApp; the
        // button uses a Builder context below it so AppLocalizations and the
        // theme resolve (mirroring a real screen's call site).
        body: Builder(
          builder: (BuildContext buttonContext) => Column(
            children: <Widget>[
              FilledButton(
                onPressed: () async {
                  final bool? confirmed = await showConfirmDialog(
                    context: buttonContext,
                    title: 'Confirm title',
                    content: const Text('Confirm content'),
                    confirmLabel: 'Delete forever',
                  );
                  if (!mounted) {
                    return;
                  }
                  setState(() => result = 'result:$confirmed');
                },
                child: const Text('Open'),
              ),
              Text(result),
            ],
          ),
        ),
      ),
    );
  }
}
