import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/deep_link/pending_accept_invite_store.dart';

void main() {
  group('PendingAcceptInviteStore', () {
    test('starts without a pending token', () {
      final PendingAcceptInviteStore store = PendingAcceptInviteStore();

      expect(store.hasPendingToken, isFalse);
      expect(store.takePendingToken(), isNull);
    });

    test('a buffered token is consumed once and cleared', () {
      final PendingAcceptInviteStore store = PendingAcceptInviteStore()
        ..setPendingToken('one-time-token');

      expect(store.hasPendingToken, isTrue);
      expect(store.takePendingToken(), 'one-time-token');
      // Single-delivery contract: the one-time token must not re-appear on a
      // later screen visit.
      expect(store.hasPendingToken, isFalse);
      expect(store.takePendingToken(), isNull);
    });

    test('a newer token supersedes an older pending one', () {
      final PendingAcceptInviteStore store = PendingAcceptInviteStore()
        ..setPendingToken('older-token')
        ..setPendingToken('newer-token');

      expect(store.takePendingToken(), 'newer-token');
    });

    test('buffering after a consume starts a fresh window', () {
      final PendingAcceptInviteStore store = PendingAcceptInviteStore()
        ..setPendingToken('first-token');
      expect(store.takePendingToken(), 'first-token');

      store.setPendingToken('second-token');
      expect(store.takePendingToken(), 'second-token');
    });
  });
}
