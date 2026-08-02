import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/shared/widgets/directional_icon.dart';

// DirectionalIcon mirrors direction-carrying icons under RTL (INSTRUCTIONS
// §4.5: verify RTL mirroring intentionally). In LTR it must render exactly
// the plain icon — pixel-for-pixel the same widget the screens previously
// built — and under RTL the mirrored variant.
void main() {
  Widget pumpDirectionalIcon(TextDirection direction) {
    return Directionality(
      textDirection: direction,
      child: const DirectionalIcon(
        icon: Icons.arrow_forward,
        mirroredIcon: Icons.arrow_back,
      ),
    );
  }

  testWidgets('renders the plain icon under LTR', (tester) async {
    await tester.pumpWidget(pumpDirectionalIcon(TextDirection.ltr));

    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('renders the mirrored icon under RTL', (tester) async {
    await tester.pumpWidget(pumpDirectionalIcon(TextDirection.rtl));

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
  });

  testWidgets('forwards size and color to the rendered Icon', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: const DirectionalIcon(
          icon: Icons.chevron_right,
          mirroredIcon: Icons.chevron_left,
          size: 18,
          color: Colors.blue,
        ),
      ),
    );

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
    expect(icon.size, 18);
    expect(icon.color, Colors.blue);
  });
}
