import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/video/presentation/join_gate.dart';

void main() {
  test('admits one join at a time and releases after end', () {
    final JoinGate gate = JoinGate();

    expect(gate.tryBegin(), isTrue);
    expect(gate.tryBegin(), isFalse);

    gate.end();

    expect(gate.tryBegin(), isTrue);
  });
}
