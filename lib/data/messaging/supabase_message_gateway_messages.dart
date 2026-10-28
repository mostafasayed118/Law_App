part of 'supabase_message_gateway.dart';

/// The message read/write/live group of [SupabaseMessageGateway] — the
/// same method bodies moved verbatim; the class applies this mixin so the
/// [MessageGateway] interface stays satisfied.
mixin _SupabaseMessageMethods on _SupabaseMessageBase {
  Future<Result<List<Message>>> fetchMessages(String threadId) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.fetchMessages(
        threadId,
      );
      // The bounded read fetches the NEWEST kSupabaseListRowCap rows
      // (`sent_at` DESC — a cap must keep the newest end of the history,
      // `list_query_guards.dart`). Reverse the mapped list to
      // chronological (oldest first) so the detail screen's top-to-bottom
      // render and the live-append path keep their ascending contract.
      // Pinned by the gateway test "reverses the newest-first capped
      // payload to chronological order".
      final List<Message> messages = rows.map(_messageFromRow).toList();
      return Result<List<Message>>.success(
        List<Message>.unmodifiable(messages.reversed),
      );
    } on SupabaseMessageException catch (e) {
      return Result<List<Message>>.failure(_mapMessageFailure(e));
    } on FormatException catch (e) {
      // Provider drift (unexpected body/author/sent_at shape) surfaces
      // loudly, never as a silently wrong message.
      return Result<List<Message>>.failure(
        AppError(
          code: 'message_body_read_failed',
          userMessage: 'Unable to load messages. Please try again.',
          messageKey: AppMessageKey.errUnableToLoadMessagesPleaseTryAgain,
          technicalMessage: e.message,
        ),
      );
    }
  }

  /// Maps one raw message row to the [Message] VO.
  ///
  /// Every cast below is guarded above (id/thread_id/author_display_name/
  /// body/sent_at), so a malformed row surfaces as a typed FormatException →
  /// AppError, never a raw TypeError across the boundary.
  Message _messageFromRow(Map<String, dynamic> row) {
    final Object? id = row['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('Message row has no id');
    }
    final Object? author = row['author_display_name'];
    if (author is! String || author.isEmpty) {
      throw FormatException('Message row has no author_display_name');
    }
    final Object? body = row['body'];
    if (body is! String || body.isEmpty) {
      throw FormatException('Message row has no body');
    }
    final Object? sentAt = row['sent_at'];
    if (sentAt is! String || sentAt.isEmpty) {
      throw FormatException('Message row has no sent_at');
    }
    return Message(
      id: id,
      authorDisplayName: author,
      body: body,
      sentAt: DateTime.parse(sentAt).toLocal(),
    );
  }

  /// Maps a provider failure to a redaction-safe [AppError]. The technical
  /// message is the provider's own (denial/availability text) — message
  /// content never crosses into errors.
  AppError _mapFailure(SupabaseMessageException e) {
    return _messageFailureFor(
      e,
      codePrefix: 'message_read',
      deniedMessage: 'You do not have permission to view these threads.',
      unavailableMessage:
          'Threads are temporarily unavailable. Please try again.',
      failedMessage: 'Unable to load threads. Please try again.',
      deniedKey: AppMessageKey.errYouDoNotHavePermissionToViewThese3,
      unavailableKey:
          AppMessageKey.errThreadsAreTemporarilyUnavailablePleaseTryAgain,
      failedKey: AppMessageKey.errUnableToLoadThreadsPleaseTryAgain,
    );
  }

  Future<Result<Message>> sendMessage(
    String threadId,
    String body, {
    String? authorDisplayName,
  }) async {
    try {
      // D-SM2: the audited `send_message` RPC returns the persisted row
      // (audit follow-up 2026-09-27 — previously the id only, resolved
      // through a follow-up fetchMessages re-read). The [Message] VO maps
      // from the RPC response directly, so the row carries the server's own
      // stored author (profiles, D-RT4) and sent_at with NO second
      // round-trip — never a fabricated VO. `authorDisplayName` stays in
      // the domain contract (the fake's seam) but is intentionally unused
      // on the real path: the RPC derives the stored author in-function.
      //
      // A malformed RPC row surfaces loudly through the shared
      // `_messageFromRow` guard (provider drift, never a silently wrong
      // sent message). The live channel (D-LV4) still delivers the row if
      // it landed, so the consumer's dedupe-by-id recovers the visible
      // append.
      final Map<String, dynamic> row = await _api.sendMessage(threadId, body);
      return Result<Message>.success(_messageFromRow(row));
    } on SupabaseMessageException catch (e) {
      return Result<Message>.failure(_mapSendFailure(e));
    } on FormatException catch (e) {
      // Provider drift in the returned row surfaces loudly, never
      // as a silently wrong sent message.
      return Result<Message>.failure(
        AppError(
          code: 'message_send_failed',
          userMessage: 'Unable to send the message. Please try again.',
          messageKey: AppMessageKey.errUnableToSendTheMessagePleaseTryAgain,
          technicalMessage: e.message,
        ),
      );
    }
  }

  Stream<MessageRealtimeEvent> watchMessages(String threadId) {
    // D-LV4: raw delivered events map to the domain events the cubit
    // drives. A malformed live row (provider drift) is dropped (null
    // filtered) — a live event must never crash the stream listener, and
    // the next reconnect backfill re-reads through the loud fetch path if
    // the drift persists.
    return _realtimeApi
        .watchMessages(threadId)
        .map(_liveEventFromRow)
        .where((MessageRealtimeEvent? event) => event != null)
        .cast<MessageRealtimeEvent>();
  }

  MessageRealtimeEvent? _liveEventFromRow(SupabaseMessageRealtimeEvent event) {
    return switch (event) {
      SupabaseMessageRealtimeInsert(row: final Map<String, dynamic> row) =>
        _liveInsertFromRow(row),
      SupabaseMessageRealtimeReconnected() => const MessageLiveReconnected(),
    };
  }

  MessageRealtimeEvent? _liveInsertFromRow(Map<String, dynamic> row) {
    try {
      return MessageLiveInsert(_messageFromRow(row));
    } on FormatException {
      return null;
    }
  }

  /// Maps a provider failure for the send path to a redaction-safe
  /// [AppError]. Distinct `message_send_*` codes keep the write surface's
  /// failures separable from the reads' (D-LV1); the technical message is
  /// the provider's own — message content never crosses into errors.
  AppError _mapSendFailure(SupabaseMessageException e) {
    return _messageFailureFor(
      e,
      codePrefix: 'message_send',
      deniedMessage:
          'You do not have permission to send messages on this thread.',
      unavailableMessage:
          'Sending is temporarily unavailable. Please try again.',
      failedMessage: 'Unable to send the message. Please try again.',
      deniedKey: AppMessageKey.errYouDoNotHavePermissionToSendMessages,
      unavailableKey:
          AppMessageKey.errSendingIsTemporarilyUnavailablePleaseTryAgain,
      failedKey: AppMessageKey.errUnableToSendTheMessagePleaseTryAgain,
    );
  }

  /// Maps a provider failure for the messages read to a redaction-safe
  /// [AppError]. Distinct `message_body_read_*` codes keep the detail
  /// surface's failures separable from the thread-list's (D-RT5); the
  /// technical message is the provider's own — message content never
  /// crosses into errors.
  AppError _mapMessageFailure(SupabaseMessageException e) {
    return _messageFailureFor(
      e,
      codePrefix: 'message_body_read',
      deniedMessage: 'You do not have permission to view these messages.',
      unavailableMessage:
          'Messages are temporarily unavailable. Please try again.',
      failedMessage: 'Unable to load messages. Please try again.',
      deniedKey: AppMessageKey.errYouDoNotHavePermissionToViewThese,
      unavailableKey:
          AppMessageKey.errMessagesAreTemporarilyUnavailablePleaseTryAgain,
      failedKey: AppMessageKey.errUnableToLoadMessagesPleaseTryAgain,
    );
  }
}
