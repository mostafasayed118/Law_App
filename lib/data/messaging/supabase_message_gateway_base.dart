part of 'supabase_message_gateway.dart';

/// The gateway's shared Supabase seam fields, split out of the main
/// class so the message group can live in a library-private mixin while
/// reading the exact same instances.
class _SupabaseMessageBase {
  _SupabaseMessageBase(this._api, this._realtimeApi);

  final SupabaseMessageApi _api;
  final SupabaseMessageRealtimeApi _realtimeApi;
}

/// Shared failure-mapper core for the three message-gateway mappers
/// (`_mapFailure`, `_mapSendFailure`, `_mapMessageFailure` — audit
/// 2026-09-27, Q-Q2): the switch shape and the kind mapping are identical,
/// only the code prefix and the user-facing copy differ per scope, so each
/// mapper supplies those and the match-once logic lives here. The technical
/// message is the provider's own — message content never crosses into
/// errors.
AppError _messageFailureFor(
  SupabaseMessageException e, {
  required String codePrefix,
  required String deniedMessage,
  required String unavailableMessage,
  required String failedMessage,
  required AppMessageKey deniedKey,
  required AppMessageKey unavailableKey,
  required AppMessageKey failedKey,
}) {
  final (
    String code,
    String userMessage,
    AppErrorKind kind,
    AppMessageKey key,
  ) = switch (e.kind) {
    SupabaseMessageFailureKind.denied => (
      '${codePrefix}_denied',
      deniedMessage,
      AppErrorKind.denied,
      deniedKey,
    ),
    SupabaseMessageFailureKind.providerUnavailable => (
      '${codePrefix}_unavailable',
      unavailableMessage,
      AppErrorKind.unavailable,
      unavailableKey,
    ),
    SupabaseMessageFailureKind.unknown => (
      '${codePrefix}_failed',
      failedMessage,
      AppErrorKind.unknown,
      failedKey,
    ),
  };
  return AppError(
    code: code,
    userMessage: userMessage,
    messageKey: key,
    kind: kind,
    technicalMessage: e.message,
  );
}
