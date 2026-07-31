import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/form_fields/password_field.dart';

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

  group('PasswordField', () {
    testWidgets('starts obscured with the visibility toggle', (tester) async {
      await tester.pumpWidget(
        pumpField(
          PasswordField(controller: TextEditingController(), hint: 'Password'),
        ),
      );

      expect(find.text('Password'), findsOneWidget);
      expect(fieldOf(tester).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });

    testWidgets('toggle reveals then re-obscures the value', (tester) async {
      await tester.pumpWidget(
        pumpField(
          PasswordField(controller: TextEditingController(), hint: 'Password'),
        ),
      );

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(fieldOf(tester).obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(fieldOf(tester).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('wires the validator into the enclosing form', (tester) async {
      await tester.pumpWidget(
        pumpField(
          PasswordField(
            controller: TextEditingController(),
            hint: 'Password',
            validator: (String? value) =>
                (value == null || value.isEmpty) ? 'Required' : null,
          ),
        ),
      );

      final FormState form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'hunter2');
      await tester.pump();

      expect(form.validate(), isTrue);
      await tester.pump();
      expect(find.text('Required'), findsNothing);
    });

    testWidgets('renders the label row with a trailing widget', (tester) async {
      await tester.pumpWidget(
        pumpField(
          PasswordField(
            controller: TextEditingController(),
            hint: 'Password',
            label: 'New Password',
            trailing: const Text('Forgot Password?'),
          ),
        ),
      );

      // LabelledField renders the label uppercased.
      expect(find.text('NEW PASSWORD'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
    });
  });
}
