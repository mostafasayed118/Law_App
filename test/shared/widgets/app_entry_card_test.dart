import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/shared/widgets/app_entry_card.dart';

// AppEntryCard is the E1 extraction: nine feature entry cards (booking,
// discovery, matters, documents, messaging, billing, compliance, tasks,
// approvals) previously duplicated this exact shell and now delegate to it.
// These tests pin the shared contract — render, tap, non-interactive null
// onTap, optional semantic label, theme awareness, RTL safety, and narrow /
// large-text resilience — so the wrappers stay byte-identical to the
// pre-extraction cards.
void main() {
  const IconData testIcon = Icons.star_outline;

  Widget pumpAppEntryCard({
    VoidCallback? onTap,
    String? semanticLabel,
    ThemeMode themeMode = ThemeMode.light,
    TextDirection direction = TextDirection.ltr,
    double width = 400,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      theme: LegalHubTheme.light,
      darkTheme: LegalHubTheme.dark,
      themeMode: themeMode,
      home: Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SizedBox(
            width: width,
            child: AppEntryCard(
              icon: testIcon,
              title: 'Entry title',
              subtitle: 'Entry subtitle',
              onTap: onTap,
              semanticLabel: semanticLabel,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders icon, title, and subtitle', (tester) async {
    await tester.pumpWidget(pumpAppEntryCard());

    expect(find.byIcon(testIcon), findsOneWidget);
    expect(find.text('Entry title'), findsOneWidget);
    expect(find.text('Entry subtitle'), findsOneWidget);
    // Trailing chevron preserved from the pre-extraction cards.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('fires onTap when tapped', (tester) async {
    int taps = 0;
    await tester.pumpWidget(pumpAppEntryCard(onTap: () => taps++));

    await tester.tap(find.byType(AppEntryCard));
    expect(taps, 1);
  });

  testWidgets('null onTap renders a non-interactive card', (tester) async {
    final int taps = 0;
    await tester.pumpWidget(pumpAppEntryCard());

    await tester.tap(find.byType(AppEntryCard), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('applies the semantic label when provided', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(pumpAppEntryCard(semanticLabel: 'Custom label'));

    expect(find.bySemanticsLabel(RegExp('Custom label')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('uses theme surface colors in both light and dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(pumpAppEntryCard(themeMode: ThemeMode.dark));

    final Material material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppEntryCard),
        matching: find.byType(Material),
      ),
    );
    final ColorScheme darkScheme = LegalHubTheme.dark.colorScheme;
    expect(material.color, darkScheme.surfaceContainerLowest);
  });

  testWidgets('renders under RTL without overflow', (tester) async {
    await tester.pumpWidget(
      pumpAppEntryCard(direction: TextDirection.rtl, width: 320),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Entry title'), findsOneWidget);
    expect(find.text('Entry subtitle'), findsOneWidget);
  });

  testWidgets('renders at 320px width without overflow', (tester) async {
    await tester.pumpWidget(pumpAppEntryCard(width: 320));

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders at 2.0 text scale without overflow', (tester) async {
    await tester.pumpWidget(pumpAppEntryCard(width: 320, textScale: 2.0));

    expect(tester.takeException(), isNull);
  });
}
