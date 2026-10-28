import 'dart:async';

import 'package:legalhub/core/supabase/supabase_wire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_message_realtime_api.dart';

/// [SupabaseMessageRealtimeApi] backed by the Supabase Realtime client.
///
/// Like the other impls, this is a data-layer file whose only job is holding
/// the provider import: the channel binding is a static function the impl
/// injects, and the reconnect lifecycle is owned here. D-LV4: a channel
/// error/system message re-opens the subscription and emits
/// [SupabaseMessageRealtimeReconnected] so the consumer re-backfills via
/// the shipped `fetchMessages` read. HONEST LIMIT: the real reconnect path
/// is a configured-build concern — unit tests exercise the lifecycle with
/// an injected binding, never a live websocket (review Q4).
class SupabaseMessageRealtimeApiImpl implements SupabaseMessageRealtimeApi {
  SupabaseMessageRealtimeApiImpl(this._binder) {
    _events = StreamController<SupabaseMessageRealtimeEvent>.broadcast(
      // F6: the last listener leaving is an intentional teardown, not a
      // channel error — close the channel instead of leaving it bound to a
      // screen that is gone (and never re-open it from its `closed` status).
      onCancel: () => unawaited(_closeActiveHandle()),
    );
  }

  /// Binds to the app-level client after `Supabase.initialize`.
  factory SupabaseMessageRealtimeApiImpl.bind() =>
      SupabaseMessageRealtimeApiImpl(_boundBinder);

  final MessageRealtimeBinder _binder;

  late final StreamController<SupabaseMessageRealtimeEvent> _events;
  MessageRealtimeSubscriptionHandle? _handle;
  String? _threadId;
  String? _openingThreadId;
  bool _closed = false;
  bool _reconnecting = false;
  bool _switching = false;

  /// Binding epoch: bumped on every intentional teardown. A callback captured
  /// by an older epoch (the replaced binding's inserts, or the `closed`
  /// subscribe status `realtime_client` reports for an unsubscribe) belongs
  /// to a dead subscription and must never reconnect or deliver.
  int _epoch = 0;

  @override
  Stream<SupabaseMessageRealtimeEvent> watchMessages(String threadId) {
    if (_closed) {
      return _events.stream;
    }
    if (_threadId != threadId) {
      final bool isFirstOpen = _threadId == null;
      _threadId = threadId;
      if (isFirstOpen) {
        _open(threadId);
      } else {
        // Thread switch: tear down the previous channel before opening the
        // new one. Previously the old channel leaked and the new thread
        // never received live events (stale-thread bug).
        unawaited(_switchThread(threadId));
      }
    } else if (_handle == null &&
        _openingThreadId == null &&
        !_reconnecting &&
        !_switching) {
      // The channel was torn down (the last listener cancelled): a fresh
      // listener needs a fresh channel for the same thread.
      _open(threadId);
    }
    return _events.stream;
  }

  Future<void> _switchThread(String threadId) async {
    _switching = true;
    try {
      await _closeActiveHandle();
    } finally {
      _switching = false;
    }
    if (!_closed && _threadId == threadId) {
      _open(threadId);
    }
  }

  /// Closes the active handle (if any) and advances the epoch so the closed
  /// channel's late callbacks are recognised as dead.
  Future<void> _closeActiveHandle() async {
    _epoch++;
    final MessageRealtimeSubscriptionHandle? handle = _handle;
    _handle = null;
    await handle?.close();
  }

  /// Opens the subscription for one thread. The binding resolves
  /// asynchronously; the handle lands when the channel is set up.
  void _open(String threadId) {
    _openingThreadId = threadId;
    final int epoch = _epoch;
    unawaited(
      _binder(
        threadId: threadId,
        onInsert: (Map<String, dynamic> row) {
          if (!_closed && _epoch == epoch && _threadId == threadId) {
            _events.add(SupabaseMessageRealtimeInsert(row));
          }
        },
        onChannelError: (Object error) => _onChannelError(threadId, epoch),
      ).then(
        (MessageRealtimeSubscriptionHandle handle) {
          if (_openingThreadId == threadId) {
            _openingThreadId = null;
          }
          if (_closed || _epoch != epoch || _threadId != threadId) {
            // The binding landed for a thread that is no longer open.
            unawaited(handle.close());
            return;
          }
          _handle = handle;
        },
        onError: (Object error) {
          if (_openingThreadId == threadId) {
            _openingThreadId = null;
          }
          if (!_closed && _epoch == epoch && _threadId == threadId) {
            _onChannelError(threadId, epoch);
          }
        },
      ),
    );
  }

  /// A channel error/system message: tear down, re-open, and signal the
  /// consumer to re-backfill. Guarded against re-entry so one error cycle
  /// never loops on itself; an intentional teardown is never an error.
  void _onChannelError(String threadId, int epoch) {
    if (_closed ||
        _reconnecting ||
        _switching ||
        _epoch != epoch ||
        _threadId != threadId) {
      return;
    }
    _reconnecting = true;
    unawaited(_reconnect(threadId));
  }

  Future<void> _reconnect(String threadId) async {
    await _closeActiveHandle();
    if (_closed || _threadId != threadId) {
      _reconnecting = false;
      return;
    }
    _open(threadId);
    _events.add(const SupabaseMessageRealtimeReconnected());
    _reconnecting = false;
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _closeActiveHandle();
    await _events.close();
  }

  /// Binds one postgres_changes INSERT subscription for a thread to the
  /// app-level realtime client. The typed `thread_id=eq.…` filter (D-LV4)
  /// narrows delivery to the open thread; RLS (Realtime RLS, D-LV3) gates
  /// which rows the caller may receive at all. `subscribe`'s callback
  /// surfaces channel errors/closes — the impl's reconnect trigger.
  static Future<MessageRealtimeSubscriptionHandle> _boundBinder({
    required String threadId,
    required void Function(Map<String, dynamic> row) onInsert,
    required void Function(Object error) onChannelError,
  }) async {
    final RealtimeChannel channel = Supabase.instance.client.channel(
      'postgres_changes:messages:$threadId',
    );
    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: SupabaseTables.messages,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'thread_id',
          value: threadId,
        ),
        callback: (PostgresChangePayload payload) {
          onInsert(payload.newRecord);
        },
      )
      ..subscribe((RealtimeSubscribeStatus status, Object? error) {
        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.closed) {
          onChannelError(error ?? StateError('channel closed ($status)'));
        }
      });
    return _ChannelHandle(channel);
  }
}

/// Closes the bound channel (the only provider-typed teardown path).
class _ChannelHandle implements MessageRealtimeSubscriptionHandle {
  _ChannelHandle(this._channel);

  final RealtimeChannel _channel;

  @override
  Future<void> close() async {
    await _channel.unsubscribe();
  }
}
