import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/home/presentation/widgets/home_cards.dart';

void main() {
  Widget pumpCard(Widget card) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: card)),
    );
  }

  group('SectionHeader', () {
    testWidgets('renders the title', (tester) async {
      await tester.pumpWidget(
        pumpCard(const SectionHeader(title: 'Practice Areas')),
      );

      expect(find.text('Practice Areas'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('renders the uppercased action and fires onAction', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        pumpCard(
          SectionHeader(
            title: 'Practice Areas',
            actionLabel: 'View All',
            onAction: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Practice Areas'), findsOneWidget);
      expect(find.text('VIEW ALL'), findsOneWidget);

      await tester.tap(find.text('VIEW ALL'));
      expect(tapped, isTrue);
    });

    // Audit U-3: the action used to set minimumSize: Size.zero +
    // tapTargetSize: shrinkWrap, shrinking the only "VIEW ALL" affordance to
    // the label height (~19px).
    testWidgets('the action has a 48px tap target (U-3)', (tester) async {
      await tester.pumpWidget(
        pumpCard(
          SectionHeader(
            title: 'Practice Areas',
            actionLabel: 'View All',
            onAction: () {},
          ),
        ),
      );

      final Finder action = find.ancestor(
        of: find.text('VIEW ALL'),
        matching: find.byType(TextButton),
      );
      final Size size = tester.getSize(action);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });
  });

  group('StatusChip', () {
    testWidgets('renders the label uppercased', (tester) async {
      await tester.pumpWidget(pumpCard(const StatusChip(label: 'Active Case')));

      expect(find.text('ACTIVE CASE'), findsOneWidget);
      expect(find.text('Active Case'), findsNothing);
    });
  });

  group('IdentityCard', () {
    testWidgets('renders the child and fires onTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        pumpCard(
          IdentityCard(
            child: const Text('Estate of H. Vance vs. City'),
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Estate of H. Vance vs. City'), findsOneWidget);

      await tester.tap(find.byType(IdentityCard));
      expect(tapped, isTrue);
    });
  });

  group('PracticeAreaCard', () {
    testWidgets('renders the icon and label and fires onTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        pumpCard(
          PracticeAreaCard(
            icon: Icons.gavel_outlined,
            label: 'Criminal',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.gavel_outlined), findsOneWidget);
      expect(find.text('Criminal'), findsOneWidget);

      await tester.tap(find.byType(PracticeAreaCard));
      expect(tapped, isTrue);
    });

    // Audit U-3: the card used a fixed 192 height, so a long practice-area
    // label wrapped past the bottom at large text scales. The height is now a
    // floor and the label truncates at two lines.
    testWidgets('does not overflow at 2.0 text scale with a long label', (
      tester,
    ) async {
      const String longLabel = 'Corporate governance and commercial law';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
                child: PracticeAreaCard(
                  icon: Icons.balance,
                  label: longLabel,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      final Text label = tester.widget<Text>(find.text(longLabel));
      expect(label.maxLines, 2);
      expect(label.overflow, TextOverflow.ellipsis);

      final Size size = tester.getSize(find.byType(PracticeAreaCard));
      expect(size.width, 160);
      expect(size.height, greaterThanOrEqualTo(192));
    });
  });
}
