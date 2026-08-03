import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';

void main() {
  group('MessageThread VO (D-MSG4 shape)', () {
    test('is equatable on its synthetic metadata fields', () {
      final DateTime last = DateTime.utc(2026, 7, 28);
      final MessageThread a = _thread(last: last);
      final MessageThread b = _thread(last: last);
      final MessageThread c = MessageThread(
        id: 'thread-2',
        title: 'Consultation follow-up — demo',
        matterRef: 'Commercial lease consultation',
        participants: const <String>['Omar Farouk', 'Demo client'],
        lastActivityAt: last,
        messageCount: 8,
      );

      expect(a, equals(b));
      expect(a == c, isFalse);
    });

    test('pins the full field surface — no body/preview/text field can be '
        'added without failing (D-MSG1 body-less line, structural)', () {
      final MessageThread thread = _thread(last: DateTime.utc(2026, 7, 28));

      // props enumerates the ENTIRE field surface: id / title / matterRef /
      // participants / lastActivityAt / messageCount. The body-less line
      // (D-MSG1) is enforced structurally — any future body, last-message
      // text, or preview field must enter props or fail this pin, so the
      // messaging surface can never render message content.
      expect(thread.props, <Object?>[
        'thread-1',
        'Demo matter updates',
        'Demo acquisition review',
        const <String>['Layla Mansour', 'Demo client'],
        DateTime.utc(2026, 7, 28),
        12,
      ]);
    });
  });
}

MessageThread _thread({required DateTime last}) => MessageThread(
  id: 'thread-1',
  title: 'Demo matter updates',
  matterRef: 'Demo acquisition review',
  participants: const <String>['Layla Mansour', 'Demo client'],
  lastActivityAt: last,
  messageCount: 12,
);
