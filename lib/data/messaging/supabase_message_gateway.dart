import '../../core/errors/app_error.dart';
import '../../core/errors/result.dart';
import '../../features/messaging/domain/message.dart';
import '../../features/messaging/domain/message_gateway.dart';
import '../../features/messaging/domain/message_thread.dart';
import 'supabase_message_api.dart';

/// [MessageGateway] backed by the Supabase provider via [SupabaseMessageApi].
///
/// Domain mapping happens here (contract §5 pattern, same as
/// [SupabaseDocumentGateway]): raw rows from the seam become
/// [MessageThread] VOs, the `participants` text[] column maps to the VO's
/// `List<String>`, and typed [SupabaseMessageException]s become
/// [AppError]s. The `MessageThread` VO and all presentation are untouched —
/// this is the env-gated seam-compatible swap of plan T7 (D-MSR7). Threads
/// are **metadata only** (D-MSG1): no body/preview/attachment/sender column
/// is ever read, so the matrix §4 body row stays structurally unexercised.
///
/// **matterRef resolution (D-MSR4):** rows store `matter_id` ids only; the VO
/// is title-keyed by design (D-W2), so the title comes from the embedded
/// `matters(title)` select (PostgREST embed, the `listMyMemberships`
/// pattern — the messages policy guarantees the reader passes the matter
/// gate, so the embed resolves), falling back to the raw matter id when the
/// embed is absent (plan §9) — never a fabricated title.
class SupabaseMessageGateway implements MessageGateway {
  SupabaseMessageGateway(this._api);

  final SupabaseMessageApi _api;

  @override
  Future<Result<List<MessageThread>>> fetchThreads() async {
    try {
      final List<Map<String, dynamic>> rows = await _api.fetchMessageThreads();
      return Result<List<MessageThread>>.success(
        List<MessageThread>.unmodifiable(rows.map(_threadFromRow)),
      );
    } on SupabaseMessageException catch (e) {
      return Result<List<MessageThread>>.failure(_mapFailure(e));
    } on FormatException catch (e) {
      // Provider drift (unexpected participants/message_count/date shape)
      // surfaces loudly, never as a silently wrong thread.
      return Result<List<MessageThread>>.failure(
        AppError(
          code: 'message_read_failed',
          userMessage: 'Unable to load threads. Please try again.',
          technicalMessage: e.message,
        ),
      );
    }
  }

  /// Maps one raw thread row to the [MessageThread] VO.
  ///
  /// Every `as` cast below is guarded above (id/matter_id/title/
  /// last_activity_at/message_count/participants), so a malformed row
  /// surfaces as a typed FormatException → AppError, never a raw TypeError
  /// across the boundary.
  MessageThread _threadFromRow(Map<String, dynamic> row) {
    final Object? id = row['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('Thread row has no id');
    }
    final Object? matterId = row['matter_id'];
    if (matterId is! String || matterId.isEmpty) {
      throw FormatException('Thread row has no matter_id');
    }
    final Object? title = row['title'];
    if (title is! String || title.isEmpty) {
      throw FormatException('Thread row has no title');
    }
    final Object? messageCount = row['message_count'];
    if (messageCount is! int) {
      throw FormatException('Thread row has no message_count');
    }
    final Object? lastActivityAt = row['last_activity_at'];
    if (lastActivityAt is! String || lastActivityAt.isEmpty) {
      throw FormatException('Thread row has no last_activity_at');
    }
    return MessageThread(
      id: id,
      title: title,
      // D-MSR4: the embedded matters(title) join resolves under the same RLS
      // gate (the policy guarantees the reader passes the matter check); an
      // absent embed falls back to the raw matter id, never a fabricated
      // title (the listMyMemberships null-embed pattern).
      matterRef: _matterRefFromRow(row, matterId),
      participants: _participantsFromRow(row),
      lastActivityAt: DateTime.parse(lastActivityAt).toLocal(),
      messageCount: messageCount,
    );
  }

  /// Resolves the VO's title-keyed `matterRef` from the embedded
  /// `matters(title)` select, falling back to the raw matter id (D-MSR4).
  String _matterRefFromRow(Map<String, dynamic> row, String matterId) {
    final Object? matters = row['matters'];
    final Object? embeddedTitle = matters is Map<String, dynamic>
        ? matters['title']
        : null;
    return (embeddedTitle is String && embeddedTitle.isNotEmpty)
        ? embeddedTitle
        : matterId;
  }

  /// Maps the `participants` text[] column to the VO's `List<String>`.
  ///
  /// Guarded, never a bare cast: a present-but-non-list value (beyond schema
  /// drift) would otherwise surface as a raw TypeError instead of the typed
  /// FormatException the fetch catches. The returned list is unmodifiable —
  /// consumers must not mutate participants (the fake's determinism pin).
  List<String> _participantsFromRow(Map<String, dynamic> row) {
    final Object? participants = row['participants'];
    if (participants is! List) {
      throw FormatException('Thread row has no participants list');
    }
    return List<String>.unmodifiable(
      participants.map((Object? participant) {
        if (participant is String) {
          return participant;
        }
        throw FormatException('Thread participants contain a non-string value');
      }),
    );
  }

  @override
  Future<Result<List<Message>>> fetchMessages(String threadId) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.fetchMessages(
        threadId,
      );
      return Result<List<Message>>.success(
        List<Message>.unmodifiable(rows.map(_messageFromRow)),
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
    final (String code, String userMessage) = switch (e.kind) {
      SupabaseMessageFailureKind.denied => (
        'message_read_denied',
        'You do not have permission to view these threads.',
      ),
      SupabaseMessageFailureKind.providerUnavailable => (
        'message_read_unavailable',
        'Threads are temporarily unavailable. Please try again.',
      ),
      SupabaseMessageFailureKind.unknown => (
        'message_read_failed',
        'Unable to load threads. Please try again.',
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalMessage: e.message,
    );
  }

  /// Maps a provider failure for the messages read to a redaction-safe
  /// [AppError]. Distinct `message_body_read_*` codes keep the detail
  /// surface's failures separable from the thread-list's (D-RT5); the
  /// technical message is the provider's own — message content never
  /// crosses into errors.
  AppError _mapMessageFailure(SupabaseMessageException e) {
    final (String code, String userMessage) = switch (e.kind) {
      SupabaseMessageFailureKind.denied => (
        'message_body_read_denied',
        'You do not have permission to view these messages.',
      ),
      SupabaseMessageFailureKind.providerUnavailable => (
        'message_body_read_unavailable',
        'Messages are temporarily unavailable. Please try again.',
      ),
      SupabaseMessageFailureKind.unknown => (
        'message_body_read_failed',
        'Unable to load messages. Please try again.',
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalMessage: e.message,
    );
  }
}
