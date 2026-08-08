import 'dart:async';

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
  SupabaseMessageRealtimeApiImpl(this._binder);

  /// Binds to the app-level client after `Supabase.initialize`.
  factory SupabaseMessageRealtimeApiImpl.bind() =>
      SupabaseMessageRealtimeApiImpl(_boundBinder);

  final MessageRealtimeBinder _binder;

  final StreamController<SupabaseMessageRealtimeEvent> _events =
      StreamController<SupabaseMessageRealtimeEvent>.broadcast();
  MessageRealtimeSubscriptionHandle? _handle;
  String? _threadId;
  bool _closed = false;
  bool _reconnecting = false;

  @override
  Stream<SupabaseMessageRealtimeEvent> watchMessages(String threadId) {
    if (_threadId == null) {
      _threadId = threadId;
      _open(threadId);
    }
    return _events.stream;
  }

  /// Opens the subscription for one thread. The binding resolves
  /// asynchronously; the handle lands when the channel is set up.
  void _open(String threadId) {
    unawaited(
      _binder(
        threadId: threadId,
        onInsert: (Map<String, dynamic> row) {
          if (!_closed) {
            _events.add(SupabaseMessageRealtimeInsert(row));
          }
        },
        onChannelError: (Object error) => _onChannelError(threadId),
      ).then((MessageRealtimeSubscriptionHandle handle) {
        _handle = handle;
      }),
    );
  }

  /// A channel error/system message: tear down, re-open, and signal the
  /// consumer to re-backfill. Guarded against re-entry so one error cycle
  /// never loops on itself.
  void _onChannelError(String threadId) {
    if (_closed || _reconnecting) {
      return;
    }
    _reconnecting = true;
    unawaited(_reconnect(threadId));
  }

  Future<void> _reconnect(String threadId) async {
    await _handle?.close();
    _handle = null;
    _open(threadId);
    _events.add(const SupabaseMessageRealtimeReconnected());
    _reconnecting = false;
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _handle?.close();
    _handle = null;
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
        table: 'messages',
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
