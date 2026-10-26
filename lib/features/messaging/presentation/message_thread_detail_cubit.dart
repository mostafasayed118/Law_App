import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_realtime_event.dart';
import 'message_thread_detail_state.dart';

/// Owns the thread-detail surface (sixth §14 un-deferral, realtime slice
/// D-RT5; write + live-delivery surface realtime push slice D-LV1/D-LV4).
///
/// [load] fetches the tapped thread's message rows on screen open (the
/// screen wires it after first frame, matching the thread-list/matter
/// pattern). [subscribe] opens the live INSERT channel (D-LV4): delivered
/// rows append to the loaded list (deduped by id), and a reconnect signal
/// re-backfills via the shipped [MessageGateway.fetchMessages] read —
/// never a second fetch mechanism. [send] is the insert-only write path
/// (D-LV1): on success the returned row appends (the live channel may also
/// deliver it — dedupe handles the double-add); on failure the composer
/// shows the error inline. Widgets render [MessageThreadDetailState] and
/// dispatch intents; they never call the gateway directly.
class MessageThreadDetailCubit extends Cubit<MessageThreadDetailState> {
  MessageThreadDetailCubit(this._gateway)
    : super(const MessageThreadDetailState());

  final MessageGateway _gateway;

  /// The server-mirrored body cap (`send_message` validation).
  static const int maxMessageLength = 2000;

  /// In-flight guard — the same contract as the thread-list cubit's `load`:
  /// the initial state IS loading, so the flag distinguishes "loading in
  /// flight" from "not loaded yet"; duplicate calls while in flight are
  /// ignored.
  bool _loading = false;

  StreamSubscription<MessageRealtimeEvent>? _live;
  String? _threadId;

  /// Live rows delivered while the list is not loaded (error/loading/
  /// empty): buffered and merged into the next successful load instead of
  /// dropped. Bounded — a backfill re-reads the thread anyway, so the
  /// buffer is a loss-window shrinker, never a store.
  final List<Message> _pendingLive = <Message>[];
  static const int _maxPendingLive = 100;

  /// Loads one thread's messages. The initial state is already loading, so
  /// the first open never re-emits a redundant loading frame; a retry after
  /// an error re-enters loading. An empty list maps to [ViewEmpty]; a
  /// failure to [ViewError]. Also the reconnect **backfill** path (D-LV4):
  /// the shipped read IS the backfill, so a recovered channel re-reads the
  /// thread and any row missed during the outage lands in the list.
  Future<void> load(String threadId) async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.messages is! ViewLoading<List<Message>>) {
      emit(state.copyWith(messages: const ViewLoading<List<Message>>()));
    }
    final Result<List<Message>> result = await _gateway.fetchMessages(threadId);
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<Message>>(value: final List<Message> messages):
        emit(
          state.copyWith(
            messages: messages.isEmpty && _pendingLive.isEmpty
                ? const ViewEmpty<List<Message>>()
                : ViewSuccess<List<Message>>(_mergePending(messages)),
          ),
        );
      case Failure<List<Message>>(error: final AppError error):
        emit(
          state.copyWith(messages: viewStateForFailure<List<Message>>(error)),
        );
    }
  }

  /// Subscribes to live INSERT delivery for the open thread (D-LV4). Calling
  /// again for the same thread is a no-op; switching threads (or closing)
  /// cancels the previous subscription first.
  Future<void> subscribe(String threadId) async {
    if (isClosed) {
      return;
    }
    if (_live != null && _threadId == threadId) {
      return;
    }
    await unsubscribe();
    _threadId = threadId;
    // A new subscription is a new thread context — stale buffered rows
    // belong to the previous thread. (Re-subscribing the same thread
    // early-returns above and keeps the buffer.)
    _pendingLive.clear();
    _live = _gateway.watchMessages(threadId).listen(_onLiveEvent);
  }

  /// Cancels the live subscription. Safe to call when none is open.
  Future<void> unsubscribe() async {
    await _live?.cancel();
    _live = null;
  }

  void _onLiveEvent(MessageRealtimeEvent event) {
    switch (event) {
      case MessageLiveInsert(message: final Message message):
        _appendLive(message);
      case MessageLiveReconnected():
        final String? threadId = _threadId;
        if (threadId != null) {
          // D-LV4: the channel recovered — re-backfill via the shipped read.
          unawaited(load(threadId));
        }
    }
  }

  /// Appends a delivered/sent row to the loaded list, deduped by id (the
  /// writer's own send arrives on the live channel too — the double-add is
  /// the expected case). A delivered row before the list is loaded is
  /// buffered (bounded, deduped) and merged into the next successful load
  /// instead of dropped until backfill.
  void _appendLive(Message message) {
    if (isClosed) {
      return;
    }
    final ViewState<List<Message>> current = state.messages;
    if (current is! ViewSuccess<List<Message>>) {
      _bufferLive(message);
      return;
    }
    final List<Message> messages = current.data;
    if (messages.any((Message m) => m.id == message.id)) {
      return;
    }
    emit(
      state.copyWith(
        messages: ViewSuccess<List<Message>>(<Message>[...messages, message]),
      ),
    );
  }

  /// Buffers one live row for the next successful load (dedupe by id,
  /// oldest-evicted past the cap).
  void _bufferLive(Message message) {
    if (_pendingLive.any((Message m) => m.id == message.id)) {
      return;
    }
    if (_pendingLive.length >= _maxPendingLive) {
      _pendingLive.removeAt(0);
    }
    _pendingLive.add(message);
  }

  /// Merges buffered live rows into a freshly fetched list (dedupe by id —
  /// the backfill may already contain them), then drains the buffer.
  List<Message> _mergePending(List<Message> fetched) {
    if (_pendingLive.isEmpty) {
      return fetched;
    }
    final Set<String> ids = fetched.map((Message m) => m.id).toSet();
    final List<Message> merged = <Message>[...fetched];
    for (final Message pending in _pendingLive) {
      if (ids.add(pending.id)) {
        merged.add(pending);
      }
    }
    _pendingLive.clear();
    return merged;
  }

  /// Sends one message on the thread (D-LV1, insert-only). While in flight
  /// the composer disables; a failure surfaces [MessageThreadDetailState.sendError]
  /// inline and the composer keeps the draft for a retry.
  Future<void> send(
    String threadId,
    String body, {
    String? authorDisplayName,
  }) async {
    if (state.sending || isClosed) {
      return;
    }
    // Batch B client guard (mirrors the send_message RPC validation):
    // whitespace-only never hits the gateway (the composer already
    // disables it); oversized surfaces sendError without a round-trip.
    final String trimmed = body.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (trimmed.length > maxMessageLength) {
      emit(
        state.copyWith(
          sendError: const AppError(
            code: 'message_too_long',
            userMessage:
                'Message is too long (max $maxMessageLength characters).',
            messageKey:
                AppMessageKey.errMessageIsTooLongMaxMaxMessageLengthCharacters,
            messageArgs: <String, Object?>{
              'maxMessageLength': maxMessageLength,
            },
          ),
        ),
      );
      return;
    }
    emit(state.copyWith(sending: true, sendError: null));
    final Result<Message> result = await _gateway.sendMessage(
      threadId,
      trimmed,
      authorDisplayName: authorDisplayName,
    );
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<Message>(value: final Message message):
        // One emit: clear the in-flight flag and append the persisted row
        // (deduped by id — the live channel may deliver the same row again;
        // env-less runs have no live channel, so this append is what makes
        // the composer visible there).
        emit(_appendedSendState(message));
      case Failure<Message>(error: final AppError error):
        emit(state.copyWith(sending: false, sendError: error));
    }
  }

  /// The post-send state: the persisted row appended to a loaded list (when
  /// not already present), with the in-flight flag cleared. When the list
  /// is not loaded the row joins the live buffer instead of vanishing.
  MessageThreadDetailState _appendedSendState(Message message) {
    final ViewState<List<Message>> current = state.messages;
    if (current is ViewSuccess<List<Message>> &&
        !current.data.any((Message m) => m.id == message.id)) {
      return state.copyWith(
        messages: ViewSuccess<List<Message>>(<Message>[
          ...current.data,
          message,
        ]),
        sending: false,
        sendError: null,
      );
    }
    if (current is! ViewSuccess<List<Message>>) {
      _bufferLive(message);
    }
    return state.copyWith(sending: false, sendError: null);
  }

  @override
  Future<void> close() async {
    await unsubscribe();
    await super.close();
  }
}
