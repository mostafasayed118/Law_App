import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/messaging/data/supabase_message_realtime_api.dart';
import 'package:legalhub/features/messaging/data/supabase_message_realtime_api_impl.dart';

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

    test(
      'switching threads closes the old handle and opens the new thread',
      () async {
        api.watchMessages('thread-a');
        await Future<void>.delayed(Duration.zero);
        api.watchMessages('thread-b');
        await Future<void>.delayed(Duration.zero);

        expect(binder.calls, <String>['thread-a', 'thread-b']);
        expect(binder.closedHandles, 1);
      },
    );

    test('a closed callback during an intentional switch does not reconnect '
        'the old thread', () async {
      // `realtime_client` reports the unsubscribe as a `closed` subscribe
      // status — an intentional teardown, not a channel error.
      binder.emitClosedOnClose = true;

      api.watchMessages('thread-a');
      await Future<void>.delayed(Duration.zero);
      api.watchMessages('thread-b');
      await Future<void>.delayed(Duration.zero);

      expect(binder.calls, <String>['thread-a', 'thread-b']);
    });

    test('an insert from the old binding is dropped after a switch', () async {
      final List<SupabaseMessageRealtimeEvent> events =
          <SupabaseMessageRealtimeEvent>[];
      final StreamSubscription<SupabaseMessageRealtimeEvent> sub = api
          .watchMessages('thread-a')
          .listen(events.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);

      api.watchMessages('thread-b');
      await Future<void>.delayed(Duration.zero);

      binder.bindings.first.onInsert(<String, dynamic>{'id': 'old'});
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<SupabaseMessageRealtimeInsert>(), isEmpty);
    });

    test('cancelling the last listener closes the channel', () async {
      final StreamSubscription<SupabaseMessageRealtimeEvent> sub = api
          .watchMessages('thread-a')
          .listen((_) {});
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      await Future<void>.delayed(Duration.zero);

      expect(binder.closedHandles, 1);
    });

    test('a closed status arriving after the last listener cancelled does not '
        'reconnect', () async {
      final StreamSubscription<SupabaseMessageRealtimeEvent> sub = api
          .watchMessages('thread-a')
          .listen((_) {});
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      await Future<void>.delayed(Duration.zero);

      // The provider's closed callback can land after the teardown.
      binder.bindings.first.onChannelError(StateError('closed'));
      await Future<void>.delayed(Duration.zero);

      expect(binder.calls, <String>['thread-a']);
    });

    test('a new listener after a cancel opens a fresh channel', () async {
      final StreamSubscription<SupabaseMessageRealtimeEvent> sub = api
          .watchMessages('thread-a')
          .listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await Future<void>.delayed(Duration.zero);

      final List<SupabaseMessageRealtimeEvent> events =
          <SupabaseMessageRealtimeEvent>[];
      final StreamSubscription<SupabaseMessageRealtimeEvent> resub = api
          .watchMessages('thread-a')
          .listen(events.add);
      addTearDown(resub.cancel);
      await Future<void>.delayed(Duration.zero);

      expect(binder.calls, <String>['thread-a', 'thread-a']);

      binder.emitInsert(<String, dynamic>{'id': 'fresh'});
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
    });
  });
}

/// Records one binding per `bind` call and lets the test drive the captured
/// callbacks — the unit-level stand-in for the real RealtimeChannel binding
/// (the real websocket round-trip is a configured-build concern, never
/// unit-tested).
class _RecordingBinder {
  final List<String> calls = <String>[];
  final List<_Binding> bindings = <_Binding>[];
  int closedHandles = 0;

  /// Models `realtime_client`'s `unsubscribe → closed` subscribe callback,
  /// the intentional teardown F6 misread as a channel error.
  bool emitClosedOnClose = false;

  Future<MessageRealtimeSubscriptionHandle> bind({
    required String threadId,
    required void Function(Map<String, dynamic> row) onInsert,
    required void Function(Object error) onChannelError,
  }) async {
    calls.add(threadId);
    final _Binding binding = _Binding(
      threadId: threadId,
      onInsert: onInsert,
      onChannelError: onChannelError,
      binder: this,
    );
    bindings.add(binding);
    return _FakeHandle(binding);
  }

  void emitInsert(Map<String, dynamic> row) {
    bindings.last.onInsert(row);
  }

  void emitChannelError(Object error) {
    bindings.last.onChannelError(error);
  }
}

/// One captured binding: its thread scope, the callbacks the impl handed the
/// provider, and the binder that counts its teardown.
class _Binding {
  _Binding({
    required this.threadId,
    required this.onInsert,
    required this.onChannelError,
    required this.binder,
  });

  final String threadId;
  final void Function(Map<String, dynamic> row) onInsert;
  final void Function(Object error) onChannelError;
  final _RecordingBinder binder;
}

class _FakeHandle implements MessageRealtimeSubscriptionHandle {
  _FakeHandle(this._binding);

  final _Binding _binding;

  @override
  Future<void> close() async {
    _binding.binder.closedHandles++;
    if (_binding.binder.emitClosedOnClose) {
      _binding.onChannelError(StateError('closed'));
    }
  }
}
