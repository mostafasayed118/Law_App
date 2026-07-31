import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/form_fields/legalhub_text_field.dart';

void main() {
  Widget pumpField(Widget field) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Form(child: field)),
    );
  }

  // TextFormField does not expose obscureText (it is consumed internally to
  // build the TextField), so read it from the inner TextField it renders.
  TextField fieldOf(WidgetTester tester) => tester.widget<TextField>(
    find.descendant(
      of: find.byType(TextFormField),
      matching: find.byType(TextField),
    ),
  );

  group('LegalHubTextField', () {
    testWidgets('renders the hint and no label when label is omitted', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpField(
          LegalHubTextField(
            controller: TextEditingController(),
            hint: 'e.g. counsel@firm.com',
          ),
        ),
      );

      expect(find.text('e.g. counsel@firm.com'), findsOneWidget);
      expect(find.text('Email Address'), findsNothing);
    });

    testWidgets('renders the label above the field when supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpField(
          LegalHubTextField(
            controller: TextEditingController(),
            hint: 'e.g. counsel@firm.com',
            label: 'Email Address',
          ),
        ),
      );

      expect(find.text('Email Address'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('renders the prefix and suffix icons', (tester) async {
      await tester.pumpWidget(
        pumpField(
          LegalHubTextField(
            controller: TextEditingController(),
            hint: 'Full Name',
            prefixIcon: Icons.person_outline,
            suffixIcon: const Icon(Icons.check_circle_outline, size: 18),
          ),
        ),
      );

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('wires the validator into the enclosing form', (tester) async {
      await tester.pumpWidget(
        pumpField(
          LegalHubTextField(
            controller: TextEditingController(),
            hint: 'Email Address',
            validator: (String? value) =>
                (value == null || value.isEmpty) ? 'Required' : null,
          ),
        ),
      );

      final FormState form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'value');
      await tester.pump();

      expect(form.validate(), isTrue);
      await tester.pump();
      expect(find.text('Required'), findsNothing);
    });

    testWidgets('passes obscureText through to the text field', (tester) async {
      await tester.pumpWidget(
        pumpField(
          LegalHubTextField(
            controller: TextEditingController(),
            hint: 'Password',
            obscureText: true,
          ),
        ),
      );

      expect(fieldOf(tester).obscureText, isTrue);
    });
  });
}
