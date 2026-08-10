import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/shared/widgets/label_chip.dart';

// LabelChip is the E5 extraction: the matter status, document type, message
// count, and roster role/status chips previously duplicated this container
// and now delegate to it. These tests pin the shared contract — label
// render, background/foreground colors, the base-style-with-foreground
// merge, and the line clamp (1-line ellipsis vs the roster's null clamp).
void main() {
  Widget pumpLabelChip({
    String label = 'Active',
    Color background = const Color(0xFF123456),
    Color foreground = const Color(0xFF654321),
    TextStyle? style,
    int? maxLines = 1,
  }) {
    return MaterialApp(
      theme: LegalHubTheme.light,
      home: Scaffold(
        body: LabelChip(
          label: label,
          background: background,
          foreground: foreground,
          style: style,
          maxLines: maxLines,
        ),
      ),
    );
  }

  testWidgets('renders the label with the given colors', (tester) async {
    await tester.pumpWidget(
      pumpLabelChip(
        label: 'In review',
        background: const Color(0xFFAABBCC),
        foreground: const Color(0xFF001122),
      ),
    );

    expect(find.text('In review'), findsOneWidget);
    final Container container = tester.widget<Container>(
      find.byType(Container),
    );
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFAABBCC));

    final Text text = tester.widget<Text>(find.text('In review'));
    expect(text.style?.color, const Color(0xFF001122));
  });

  testWidgets('applies the base style and always overrides the foreground', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpLabelChip(
        style: LegalHubTheme.light.textTheme.labelLarge?.copyWith(
          letterSpacing: 0.3,
        ),
        foreground: const Color(0xFFFF0000),
      ),
    );

    final Text text = tester.widget<Text>(find.text('Active'));
    expect(text.style?.letterSpacing, 0.3);
    expect(text.style?.color, const Color(0xFFFF0000));
  });

  testWidgets('clamps to one line with ellipsis by default', (tester) async {
    await tester.pumpWidget(pumpLabelChip(label: 'A very long label'));

    final Text text = tester.widget<Text>(find.text('A very long label'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('null maxLines leaves the label unclamped (roster posture)', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpLabelChip(label: 'A very long label', maxLines: null),
    );

    final Text text = tester.widget<Text>(find.text('A very long label'));
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
  });
}
