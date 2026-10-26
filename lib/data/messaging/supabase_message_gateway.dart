import 'dart:async';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_realtime_event.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'supabase_message_api.dart';
import 'supabase_message_realtime_api.dart';
part 'supabase_message_gateway_base.dart';
part 'supabase_message_gateway_messages.dart';

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
class SupabaseMessageGateway extends _SupabaseMessageBase
    with _SupabaseMessageMethods
    implements MessageGateway {
  SupabaseMessageGateway(super._api, super._realtimeApi);

  @override
  Future<Result<List<MessageThread>>> fetchThreads({String? matterId}) =>
      _runThreads(() => _api.fetchMessageThreads(matterId: matterId));

  @override
  Future<Result<List<MessageThread>>> searchThreads(
    String query, {
    int limit = 30,
  }) => _runThreads(() => _api.searchMessageThreads(query, limit: limit));

  /// Runs a thread read (full fetch or title-prefiltered search) through
  /// the identical mapping path. The search prefilter only shrinks the
  /// transfer — mapping and failure semantics never diverge between the
  /// two reads.
  Future<Result<List<MessageThread>>> _runThreads(
    Future<List<Map<String, dynamic>>> Function() read,
  ) async {
    try {
      final List<Map<String, dynamic>> rows = await read();
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
    // D-MSR4: the embedded matters(title) join resolves under the same RLS
    // gate (the policy guarantees the reader passes the matter check). Both
    // fields stay null when the embed is absent — the list surface then
    // renders no reverse link (the safe fallback, never a fabricated title).
    final String? matterTitle = _matterTitleFromRow(row);
    return MessageThread(
      id: id,
      title: title,
      matterRef: matterTitle ?? matterId,
      matterId: matterId,
      matterTitle: matterTitle,
      participants: _participantsFromRow(row),
      lastActivityAt: DateTime.parse(lastActivityAt).toLocal(),
      messageCount: messageCount,
    );
  }

  /// Resolves the embedded `matters(title)` value, or null when the embed is
  /// absent/empty (D-MSR4's fallback path).
  String? _matterTitleFromRow(Map<String, dynamic> row) {
    final Object? matters = row['matters'];
    final Object? embeddedTitle = matters is Map<String, dynamic>
        ? matters['title']
        : null;
    return (embeddedTitle is String && embeddedTitle.isNotEmpty)
        ? embeddedTitle
        : null;
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
}
