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
  });
}
