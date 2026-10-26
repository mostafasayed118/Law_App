import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/messaging/domain/message.dart';

/// Immutable state of the thread-detail surface (sixth §14 un-deferral,
/// realtime slice D-RT5; write + live-delivery surface realtime push slice
/// D-LV1/D-LV4).
///
/// [messages] holds the read-path load lifecycle using the shared
/// [ViewState] vocabulary (loading / success / empty / error+retry).
/// [sending] disables the composer while a send is in flight; [sendError]
/// surfaces a failed send inline on the composer (cleared on the next
/// send). The write surface is **insert-only** — there is deliberately no
/// edit/delete state (D-LV1: no edit/delete/attachments/read-receipts).
class MessageThreadDetailState extends Equatable {
  const MessageThreadDetailState({
    this.messages = const ViewLoading<List<Message>>(),
    this.sending = false,
    this.sendError,
  });

  final ViewState<List<Message>> messages;

  /// True while a send is in flight (the composer's button is disabled).
  final bool sending;

  /// A failed send's typed error, cleared on the next send attempt. The
  /// composer maps it to localized copy at render time.
  final AppError? sendError;

  static const Object _unset = Object();

  MessageThreadDetailState copyWith({
    ViewState<List<Message>>? messages,
    bool? sending,
    Object? sendError = _unset,
  }) {
    return MessageThreadDetailState(
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      sendError: identical(sendError, _unset)
          ? this.sendError
          : sendError as AppError?,
    );
  }

  @override
  List<Object?> get props => <Object?>[messages, sending, sendError];
}
