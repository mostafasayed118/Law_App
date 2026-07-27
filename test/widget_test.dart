import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/main.dart';

void main() {
  testWidgets('launches a blank scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const LegalHubApp());

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });
}
