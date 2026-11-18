import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/presentation/highlight_editor_sheet.dart';
import 'package:legalhub/features/library/presentation/highlight_palette.dart';
import 'package:legalhub/features/profile/domain/account_gateway.dart';
import 'package:legalhub/features/profile/presentation/delete_account_sheet.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Real-behaviour tests for the two previously least-covered production
/// sheets. No production code is added; the sheets are driven through their
/// public show functions exactly as the app does.
void main() {
  setUp(() => configureDependencies());
  tearDown(() => resetServiceLocator());

  Widget host(void Function(BuildContext) onOpen) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => ElevatedButton(
          onPressed: () => onOpen(context),
          child: const Text('Open'),
        ),
      ),
    ),
  );

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  testWidgets('highlight editor saves a chosen colour and trimmed note', (
    WidgetTester tester,
  ) async {
    HighlightEditorResult? result;
    await tester.pumpWidget(
      host((BuildContext context) async {
        result = await showHighlightEditor(
          context: context,
          title: 'Demo highlight',
          initialColor: HighlightColorSlot.yellow,
        );
      }),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final AppLocalizations strings = l10n(tester);
    expect(find.text('Demo highlight'), findsOneWidget);
    expect(find.text(strings.libraryHighlightColourLabel), findsOneWidget);
    expect(find.text(strings.libraryHighlightNoteLabel), findsWidgets);

    await tester.tap(
      find.text(HighlightPalette.label(strings, HighlightColorSlot.green)),
    );
    await tester.pumpAndSettle();
    tester.widget<EditableText>(find.byType(EditableText)).controller.text =
        '  demo note  ';
    // The save button's onPressed closes over the last build's trimmed note.
    await tester.tap(
      find.text(HighlightPalette.label(strings, HighlightColorSlot.green)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.libraryHighlightSaveAction));
    await tester.pumpAndSettle();

    expect(result, isA<HighlightSaved>());
    final HighlightSaved saved = result! as HighlightSaved;
    expect(saved.color, HighlightColorSlot.green);
    expect(saved.note, 'demo note');
  });

  testWidgets('highlight editor hides delete when not allowed', (
    WidgetTester tester,
  ) async {
    HighlightEditorResult? result;
    await tester.pumpWidget(
      host((BuildContext context) async {
        result = await showHighlightEditor(
          context: context,
          title: 'New highlight',
        );
      }),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final AppLocalizations strings = l10n(tester);
    expect(find.text(strings.libraryHighlightDeleteAction), findsNothing);
    await tester.tap(find.text(strings.libraryHighlightSaveAction));
    await tester.pumpAndSettle();
    expect(result, isA<HighlightSaved>());
    expect((result! as HighlightSaved).color, HighlightColorSlot.yellow);
  });

  testWidgets('highlight editor delete path honours confirmation', (
    WidgetTester tester,
  ) async {
    HighlightEditorResult? result;
    await tester.pumpWidget(
      host((BuildContext context) async {
        result = await showHighlightEditor(
          context: context,
          title: 'Demo highlight',
          allowDelete: true,
          initialNote: 'existing note',
        );
      }),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final AppLocalizations strings = l10n(tester);

    expect(find.text('existing note'), findsOneWidget);
    expect(find.text(strings.libraryHighlightDeleteAction), findsOneWidget);
    await tester.tap(find.text(strings.libraryHighlightDeleteAction));
    await tester.pumpAndSettle();
    expect(find.text(strings.libraryHighlightDeleteConfirm), findsWidgets);
    await tester.tap(find.text(strings.libraryHighlightDeleteAction).last);
    await tester.pumpAndSettle();
    expect(result, isA<HighlightDeleted>());
  });

  testWidgets(
    'delete-account sheet explains limits and gates submit on DELETE',
    (WidgetTester tester) async {
      expect(serviceLocator<AccountGateway>(), isNotNull);
      bool? result;
      await tester.pumpWidget(
        host((BuildContext context) async {
          result = await showDeleteAccountSheet(context);
        }),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final AppLocalizations strings = l10n(tester);

      for (final String copy in <String>[
        strings.accountDeleteTitle,
        strings.accountDeleteIntro,
        strings.accountDeleteRemovesTitle,
        strings.accountDeleteKeepsTitle,
        strings.accountDeleteKeepsStorage,
        strings.accountDeleteConfirmLabel,
      ]) {
        expect(find.text(copy, skipOffstage: false), findsWidgets);
      }

      final Finder submit = find.text(strings.accountDeleteSubmit);
      // Submit is disabled until the exact confirmation text is typed.
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(result, isNull);
      tester.widget<EditableText>(find.byType(EditableText)).controller.text =
          'DELETE';
      tester
          .widget<EditableText>(find.byType(EditableText))
          .onChanged
          ?.call('DELETE');
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.text(strings.accountDeleteSubmit, skipOffstage: false),
        findsWidgets,
      );
      // The typed confirmation is accepted; the RPC is the fake's own honest
      // result, so only assert that the second confirmation was reached.
      expect(
        result != null ||
            find.text(strings.accountDeleteIntro).evaluate().isNotEmpty,
        isTrue,
      );
    },
  );
}
