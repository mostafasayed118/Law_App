import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/message.dart';

/// Immutable state of the thread-detail surface (sixth §14 un-deferral,
/// realtime slice D-RT5).
///
/// [messages] holds the read-path load lifecycle using the shared
/// [ViewState] vocabulary (loading / success / empty / error+retry). There
/// is deliberately no composer, no send/reply, and no pagination state — the
/// smallest read-only surface (D-RT5: no write grant in this slice).
class MessageThreadDetailState extends Equatable {
  const MessageThreadDetailState({
    this.messages = const ViewLoading<List<Message>>(),
  });

  final ViewState<List<Message>> messages;

  MessageThreadDetailState copyWith({ViewState<List<Message>>? messages}) {
    return MessageThreadDetailState(messages: messages ?? this.messages);
  }

  @override
  List<Object?> get props => <Object?>[messages];
}
