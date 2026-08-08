import 'message.dart';

/// A live-delivery event on a message thread (seventh §14 un-deferral,
/// realtime push slice D-LV4).
///
/// The cubit listens to [MessageGateway.watchMessages] and drives the
/// loaded list from these events: an insert appends the delivered row
/// (deduped by id), a reconnect signals the channel recovered so the cubit
/// re-backfills from the shipped `fetchMessages` read (D-LV4 — the backfill
/// IS the existing read, never a second fetch mechanism).
sealed class MessageRealtimeEvent {
  const MessageRealtimeEvent();
}

/// A delivered `messages` INSERT row for the subscribed thread.
class MessageLiveInsert extends MessageRealtimeEvent {
  const MessageLiveInsert(this.message);

  final Message message;
}

/// The channel recovered after an error/system message; the consumer should
/// re-backfill via the read path so no delivered row is missed.
class MessageLiveReconnected extends MessageRealtimeEvent {
  const MessageLiveReconnected();
}
