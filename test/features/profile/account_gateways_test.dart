import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/profile/data/fake_account_gateway.dart';
import 'package:legalhub/features/profile/data/fake_password_gateway.dart';
import 'package:legalhub/features/profile/domain/account_errors.dart';
import 'package:legalhub/features/profile/domain/password_gateway.dart';

/// The fakes are the demo posture, so their guards are pinned as tightly as the
/// RPCs in migration 34: a fake more permissive than the server would let the
/// UI ship a flow the server refuses.
void main() {
  group('FakeAccountGateway.updateDisplayName', () {
    test('trims a valid name', () async {
      final FakeAccountGateway gateway = FakeAccountGateway();
      final Result<void> result = await gateway.updateDisplayName(
        '  اسم جديد  ',
      );
      expect(result, isA<Success<void>>());
      expect(gateway.displayName, 'اسم جديد');
    });

    test('refuses short, long and control-character names', () async {
      final FakeAccountGateway gateway = FakeAccountGateway();
      for (final String name in <String>['x', 'ا' * 121, 'abc\ndef']) {
        final Result<void> result = await gateway.updateDisplayName(name);
        expect(result, isA<Failure<void>>(), reason: 'name: $name');
        expect(
          (result as Failure<void>).error.code,
          AccountErrors.invalidNameCode,
        );
      }
    });
  });

  group('FakeAccountGateway.deleteAccount', () {
    test('reports success for a normal member', () async {
      final FakeAccountGateway gateway = FakeAccountGateway();
      expect(await gateway.deleteAccount(), isA<Success<void>>());
      expect(gateway.deleted, isTrue);
    });

    test('last active partner gets the specific refusal', () async {
      final FakeAccountGateway gateway = FakeAccountGateway(
        lastActivePartner: true,
      );
      final Result<void> result = await gateway.deleteAccount();
      expect(
        (result as Failure<void>).error.code,
        AccountErrors.lastPartnerCode,
      );
      expect(gateway.deleted, isFalse);
    });

    test('platform owner gets the specific refusal', () async {
      final FakeAccountGateway gateway = FakeAccountGateway(
        platformOwner: true,
      );
      final Result<void> result = await gateway.deleteAccount();
      expect(
        (result as Failure<void>).error.code,
        AccountErrors.platformOwnerCode,
      );
      expect(gateway.deleted, isFalse);
    });
  });

  group('FakePasswordGateway', () {
    test('records the call and succeeds', () async {
      final FakePasswordGateway gateway = FakePasswordGateway();
      expect(
        await gateway.changePassword('new-password'),
        isA<Success<void>>(),
      );
      expect(gateway.calls, 1);
      expect(gateway.lastPassword, 'new-password');
    });

    test('a refused change is a retryable failure', () async {
      final FakePasswordGateway gateway = FakePasswordGateway(reject: true);
      final Result<void> result = await gateway.changePassword('new-password');
      expect((result as Failure<void>).error.kind, isNotNull);
    });
  });
}
