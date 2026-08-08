import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/message.dart';
import '../domain/message_gateway.dart';
import 'message_thread_detail_state.dart';

/// Owns the thread-detail surface (sixth §14 un-deferral, realtime slice
/// D-RT5).
///
/// [load] fetches the tapped thread's message rows on screen open (the
/// screen wires it after first frame, matching the thread-list/matter
/// pattern). This is the **read-path surface** — the first place message
/// bodies cross the presentation boundary (the D-MSG1 consummation, scoped
/// to the real read path). Widgets render
/// [MessageThreadDetailState] and dispatch intents; they never call the
/// gateway directly.
class MessageThreadDetailCubit extends Cubit<MessageThreadDetailState> {
  MessageThreadDetailCubit(this._gateway)
    : super(const MessageThreadDetailState());

  final MessageGateway _gateway;

  /// In-flight guard — the same contract as the thread-list cubit's `load`:
  /// the initial state IS loading, so the flag distinguishes \"loading in
  /// flight\" from \"not loaded yet\"; duplicate calls while in flight are
  /// ignored.
  bool _loading = false;

  /// Loads one thread's messages. The initial state is already loading, so
  /// the first open never re-emits a redundant loading frame; a retry after
  /// an error re-enters loading. An empty list maps to [ViewEmpty]; a
  /// failure to [ViewError].
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
            messages: messages.isEmpty
                ? const ViewEmpty<List<Message>>()
                : ViewSuccess<List<Message>>(messages),
          ),
        );
      case Failure<List<Message>>(error: final AppError error):
        emit(state.copyWith(messages: ViewError<List<Message>>(error)));
    }
  }
}
