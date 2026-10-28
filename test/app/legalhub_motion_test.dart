import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_motion.dart';

void main() {
  test('motion tokens are the approved values', () {
    expect(LegalHubMotion.durationFast, const Duration(milliseconds: 200));
    expect(LegalHubMotion.durationBase, const Duration(milliseconds: 300));
    expect(LegalHubMotion.debounce, const Duration(milliseconds: 300));
    expect(LegalHubMotion.curveStandard, Curves.easeOut);
  });
}
