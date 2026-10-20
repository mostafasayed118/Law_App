import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/billing/domain/payment_mode.dart';

void main() {
  group('PaymentMode', () {
    test('defaults to disabled with no PAYMENTS_MODE define', () {
      expect(PaymentMode.fromEnvironment(), PaymentMode.disabled);
    });

    test('parses known values case-insensitively', () {
      expect(PaymentMode.parse('demo'), PaymentMode.demo);
      expect(PaymentMode.parse('DEMO'), PaymentMode.demo);
      expect(PaymentMode.parse(' live '), PaymentMode.live);
      expect(PaymentMode.parse('LiVe'), PaymentMode.live);
      expect(PaymentMode.parse('disabled'), PaymentMode.disabled);
      expect(PaymentMode.parse('DISABLED'), PaymentMode.disabled);
    });

    test('unknown or empty values map to disabled', () {
      expect(PaymentMode.parse(''), PaymentMode.disabled);
      expect(PaymentMode.parse('production'), PaymentMode.disabled);
      expect(PaymentMode.parse('true'), PaymentMode.disabled);
    });
  });
}
