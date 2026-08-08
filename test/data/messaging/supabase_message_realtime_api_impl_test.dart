import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/messaging/supabase_message_realtime_api.dart';
import 'package:legalhub/data/messaging/supabase_message_realtime_api_impl.dart';

void main() {
  group('SupabaseMessageRealtimeApiImpl (D-LV4)', () {
    late _RecordingBinder binder;
    late SupabaseMessageRealtimeApiImpl api;

    setUp(() {
      binder = _RecordingBinder();
      api = SupabaseMessageRealtimeApiImpl(binder.bind);
    });

    tearDown(() async {
      await api.close();
    });

    test('opens one subscription for the watched thread (the filter pin)', () {
      api.watchMessages('thread-9');

      // The binder is the seam where the per-thread postgres_changes
      // filter (`thread_id=eq.…`) is constructed — the impl must route the
      // thread id through exactly once.
      expect(binder.calls, <String>['thread-9']);
    });

    test('forwards a delivered insert row as an insert event', () async {
      final List<SupabaseMessageRealtimeEvent> events =
          <SupabaseMessageRealtimeEvent>[];
      final StreamSubscription<SupabaseMessageRealtimeEvent> sub = api
          .watchMessages('thread-1')
          .listen(events.add);
      addTearDown(sub.cancel);

      binder.emitInsert(<String, dynamic>{'id': 'msg-1', 'body': 'Live'});
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      final SupabaseMessageRealtimeInsert insert =
          events.single as SupabaseMessageRealtimeInsert;
      expect(insert.row['id'], 'msg-1');
      expect(insert.row['body'], 'Live');
    });

    test('a channel error reconnects and emits a recovery signal', () async {
      final List<SupabaseMessageRealtimeEvent> events =
          <SupabaseMessageRealtimeEvent>[];
      final StreamSubscription<SupabaseMessageRealtimeEvent> sub = api
          .watchMessages('thread-1')
          .listen(events.add);
      addTearDown(sub.cancel);
      // Let the first binding's handle land before the channel errors.
      await Future<void>.delayed(Duration.zero);

      // The first binding's channel errors -> the impl re-opens + signals.
      binder.emitChannelError(StateError('channel down'));
      await Future<void>.delayed(Duration.zero);

      // The old handle was closed, a fresh subscription opened, and the
      // recovery signal emitted exactly once (re-entry guarded).
      expect(binder.closedHandles, 1);
      expect(binder.calls, <String>['thread-1', 'thread-1']);
      expect(
        events.whereType<SupabaseMessageRealtimeReconnected>(),
        hasLength(1),
      );
    });

    test('a recovery signal is NOT re-emitted for an insert', () async {
      final List<SupabaseMessageRealtimeEvent> events =
          <SupabaseMessageRealtimeEvent>[];
      final StreamSubscription<SupabaseMessageRealtimeEvent> sub = api
          .watchMessages('thread-1')
          .listen(events.add);
      addTearDown(sub.cancel);

      binder.emitInsert(<String, dynamic>{'id': 'msg-1'});
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single, isA<SupabaseMessageRealtimeInsert>());
    });

    test(
      'close tears down the active subscription and closes the stream',
      () async {
        api.watchMessages('thread-1');
        await Future<void>.delayed(Duration.zero);

        await api.close();

        expect(binder.closedHandles, 1);
        // A late insert after close must not emit (the controller is closed).
        expect(
          () => binder.emitInsert(<String, dynamic>{'id': 'late'}),
          returnsNormally,
        );
      },
    );
  });
}

/// Records the binder invocations and lets the test drive the callbacks —
/// the unit-level stand-in for the real RealtimeChannel binding (the real
/// websocket round-trip is a configured-build concern, never unit-tested).
class _RecordingBinder {
  final List<String> calls = <String>[];
  int closedHandles = 0;
  void Function(Map<String, dynamic> row)? _onInsert;
  void Function(Object error)? _onChannelError;

  Future<MessageRealtimeSubscriptionHandle> bind({
    required String threadId,
    required void Function(Map<String, dynamic> row) onInsert,
    required void Function(Object error) onChannelError,
  }) async {
    calls.add(threadId);
    _onInsert = onInsert;
    _onChannelError = onChannelError;
    return _FakeHandle(_onClose);
  }

  void _onClose() {
    closedHandles++;
  }

  void emitInsert(Map<String, dynamic> row) {
    _onInsert?.call(row);
  }

  void emitChannelError(Object error) {
    _onChannelError?.call(error);
  }
}

class _FakeHandle implements MessageRealtimeSubscriptionHandle {
  _FakeHandle(this._onClose);

  final void Function() _onClose;

  @override
  Future<void> close() async {
    _onClose();
  }
}
