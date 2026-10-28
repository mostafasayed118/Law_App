/// Provider-neutral realtime delivery seam for `messages` INSERTs (seventh
/// §14 un-deferral, realtime push slice D-LV4).
///
/// The seam is the only surface the message gateway's live path talks to:
/// a per-thread postgres_changes subscription in, typed events out.
/// Provider types (RealtimeChannel) never cross this boundary — the impl's
/// binding is the only file that touches them (the established seam
/// discipline).
library;

/// A delivered raw `messages` row or a channel-recovery signal, in the
/// order the provider produced them.
sealed class SupabaseMessageRealtimeEvent {
  const SupabaseMessageRealtimeEvent();
}

/// A delivered INSERT row for the subscribed thread (the full new record).
class SupabaseMessageRealtimeInsert extends SupabaseMessageRealtimeEvent {
  const SupabaseMessageRealtimeInsert(this.row);

  final Map<String, dynamic> row;
}

/// The channel recovered after an error/system message; the consumer should
/// re-backfill via the shipped read so no delivered row is missed.
class SupabaseMessageRealtimeReconnected extends SupabaseMessageRealtimeEvent {
  const SupabaseMessageRealtimeReconnected();
}

/// A bound postgres_changes subscription handle: [close] tears the channel
/// down. The concrete binding is provider-typed and lives only behind
/// [MessageRealtimeBinder].
abstract interface class MessageRealtimeSubscriptionHandle {
  Future<void> close();
}

/// Opens one postgres_changes INSERT subscription for a thread and routes
/// delivered rows to [onInsert]. A channel error/system message (the
/// delivery surface is gone) routes to [onChannelError] — the impl then
/// reconnects and emits [SupabaseMessageRealtimeReconnected]. Returns a
/// handle the impl keeps for teardown.
typedef MessageRealtimeBinder =
    Future<MessageRealtimeSubscriptionHandle> Function({
      required String threadId,
      required void Function(Map<String, dynamic> row) onInsert,
      required void Function(Object error) onChannelError,
    });

/// Messages realtime delivery surface backed by the Supabase Realtime
/// client.
///
/// D-LV3/D-LV4: **Realtime RLS** makes postgres_changes adhere to the
/// underlying table's SELECT policy, so the existing
/// `messages_select_assigned` (the read slice) IS the delivery gate; the
/// publication membership (`09_realtime_push.sql`) is the enablement. The
/// per-thread `thread_id=eq.…` filter narrows delivery to the open thread.
abstract interface class SupabaseMessageRealtimeApi {
  /// Subscribes to postgres_changes INSERTs on the `messages` table filtered
  /// to one thread, returning a broadcast stream of typed events. The impl
  /// owns the channel lifecycle (reconnect on error/system) and [close]
  /// tears it down. An unknown/under-privileged thread simply delivers
  /// nothing (the same RLS gate as the read).
  Stream<SupabaseMessageRealtimeEvent> watchMessages(String threadId);

  /// Tears down the active subscription and closes the stream.
  Future<void> close();
}
