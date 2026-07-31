import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/shared/widgets/form_fields/labelled_field.dart';

void main() {
  Widget pumpField(Widget field) {
    return MaterialApp(home: Scaffold(body: field));
  }

  group('LabelledField', () {
    testWidgets('renders the label uppercased above the child', (tester) async {
      await tester.pumpWidget(
        pumpField(
          LabelledField(label: 'Email Address', child: TextFormField()),
        ),
      );

      expect(find.text('EMAIL ADDRESS'), findsOneWidget);
      expect(find.text('Email Address'), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('renders the trailing widget in the label row', (tester) async {
      await tester.pumpWidget(
        pumpField(
          LabelledField(
            label: 'Password',
            trailing: const Text('Forgot Password?'),
            child: TextFormField(),
          ),
        ),
      );

      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
    });

    testWidgets('renders no trailing widget when trailing is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpField(LabelledField(label: 'Password', child: TextFormField())),
      );

      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsNothing);
    });
  });
}
