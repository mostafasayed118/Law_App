import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/shared/widgets/app_tile.dart';

// AppTile is the E2 extraction: the search result tiles and the list-screen
// rows (matters, documents, messaging, approvals, tasks) previously
// duplicated this card shape and now delegate to it. These tests pin the
// shared contract — render, tap, the D-C2 nullable-onTap posture (no
// InkWell, no chevron), the chevron opt-out (D-MSG1), the leading override,
// and RTL safety.
void main() {
  Widget pumpAppTile({
    VoidCallback? onTap,
    bool showChevron = true,
    IconData? icon,
    Widget? leading,
    Widget? trailing,
    List<String> subtitles = const <String>['Tile subtitle'],
    TextDirection direction = TextDirection.ltr,
    double width = 400,
  }) {
    return MaterialApp(
      theme: LegalHubTheme.light,
      home: Directionality(
        textDirection: direction,
        child: SizedBox(
          width: width,
          child: AppTile(
            title: 'Tile title',
            subtitles: subtitles,
            icon: icon,
            leading: leading,
            trailing: trailing,
            onTap: onTap,
            showChevron: showChevron,
          ),
        ),
      ),
    );
  }

  testWidgets('renders icon avatar, title, and subtitle', (tester) async {
    await tester.pumpWidget(pumpAppTile(icon: Icons.folder_outlined));

    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    expect(find.text('Tile title'), findsOneWidget);
    expect(find.text('Tile subtitle'), findsOneWidget);
  });

  testWidgets('fires onTap and renders the chevron when tappable', (
    tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      pumpAppTile(icon: Icons.folder_outlined, onTap: () => taps++),
    );

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.byType(AppTile));
    expect(taps, 1);
  });

  testWidgets('null onTap renders no InkWell, no chevron (D-C2)', (
    tester,
  ) async {
    await tester.pumpWidget(pumpAppTile(icon: Icons.folder_outlined));

    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(
      find.descendant(of: find.byType(AppTile), matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  testWidgets('showChevron false keeps a tappable row chevron-free (D-MSG1)', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpAppTile(icon: Icons.forum_outlined, onTap: () {}, showChevron: false),
    );

    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(
      find.descendant(of: find.byType(AppTile), matching: find.byType(InkWell)),
      findsOneWidget,
    );
  });

  testWidgets('a custom leading overrides the icon', (tester) async {
    await tester.pumpWidget(
      pumpAppTile(
        icon: Icons.folder_outlined,
        leading: const Icon(Icons.block, size: 20),
      ),
    );

    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsNothing);
  });

  testWidgets('renders the trailing widget under the subtitle', (tester) async {
    await tester.pumpWidget(
      pumpAppTile(
        icon: Icons.folder_outlined,
        trailing: const Text('trailing chip'),
      ),
    );

    expect(find.text('trailing chip'), findsOneWidget);
  });

  testWidgets('uses the theme surface color', (tester) async {
    await tester.pumpWidget(pumpAppTile(icon: Icons.folder_outlined));

    final Material material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppTile),
        matching: find.byType(Material),
      ),
    );
    expect(
      material.color,
      LegalHubTheme.light.colorScheme.surfaceContainerLowest,
    );
  });

  testWidgets('renders under RTL and at 320px without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpAppTile(
        icon: Icons.folder_outlined,
        direction: TextDirection.rtl,
        width: 320,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Tile title'), findsOneWidget);
    expect(find.text('Tile subtitle'), findsOneWidget);
  });

  testWidgets('renders multiple subtitle lines (the invoice posture)', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpAppTile(
        icon: Icons.request_quote_outlined,
        subtitles: const <String>['USD 250 · Paid', 'matter-ref · Aug 8'],
        width: 320,
      ),
    );

    expect(find.text('USD 250 · Paid'), findsOneWidget);
    expect(find.text('matter-ref · Aug 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty subtitles render no metadata line', (tester) async {
    await tester.pumpWidget(
      pumpAppTile(icon: Icons.folder_outlined, subtitles: const <String>[]),
    );

    expect(find.text('Tile title'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget); // title only
  });
}
