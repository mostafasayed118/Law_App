import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/shared/widgets/app_section_header.dart';

// AppSectionHeader is the C2 consolidation: the search _GroupSection
// (titleMedium w700 primary) and the matter-details _WorkspaceBlock
// (titleSmall w700) previously duplicated this Column(start) → Text(w700)
// + spaceSm + content shape. These tests pin the shared contract — the
// default emphasis style, the titleStyle override, the content spread, and
// RTL at narrow width.
void main() {
  Widget pumpSectionHeader({
    String title = 'Section',
    List<Widget> children = const <Widget>[],
    TextStyle? titleStyle,
    TextDirection direction = TextDirection.ltr,
    double width = 800,
  }) {
    return MaterialApp(
      theme: LegalHubTheme.light,
      home: Scaffold(
        body: Directionality(
          textDirection: direction,
          child: SizedBox(
            width: width,
            child: AppSectionHeader(
              title: title,
              titleStyle: titleStyle,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the title with the default emphasis style', (
    tester,
  ) async {
    await tester.pumpWidget(pumpSectionHeader(title: 'Documents'));

    final Text text = tester.widget<Text>(find.text('Documents'));
    expect(text.style?.fontWeight, FontWeight.w700);
    expect(text.style?.color, LegalHubTheme.light.colorScheme.primary);
  });

  testWidgets('applies the titleStyle override', (tester) async {
    await tester.pumpWidget(
      pumpSectionHeader(
        title: 'Files',
        titleStyle: LegalHubTheme.light.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final Text text = tester.widget<Text>(find.text('Files'));
    expect(
      text.style?.fontSize,
      LegalHubTheme.light.textTheme.titleSmall?.fontSize,
    );
    expect(text.style?.color, isNot(LegalHubTheme.light.colorScheme.primary));
  });

  testWidgets('renders the content children under the header', (tester) async {
    await tester.pumpWidget(
      pumpSectionHeader(
        title: 'Messages',
        children: <Widget>[
          const Text('row one'),
          const SizedBox(height: 8),
          const Text('row two'),
        ],
      ),
    );

    expect(find.text('row one'), findsOneWidget);
    expect(find.text('row two'), findsOneWidget);
  });

  testWidgets('no overflow at 320px under RTL with long Arabic title', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpSectionHeader(
        title: 'مستندات هذا الملف القانوني الطويلة',
        children: const <Widget>[Text('المحتوى')],
        direction: TextDirection.rtl,
        width: 320,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppSectionHeader), findsOneWidget);
  });
}
