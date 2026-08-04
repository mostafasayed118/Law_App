import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/message_gateway.dart';
import '../domain/message_thread.dart';
import 'message_state.dart';

/// Owns the thread-list surface (Phase 9, slice 9.1).
///
/// [load] fetches the synthetic thread-metadata list on screen open (the
/// screen wires it after first frame, matching the vault/discovery/matters
/// pattern). Thread metadata only — nothing but the D-MSG4 surface ever
/// crosses the [MessageGateway] boundary, and there is no message body
/// anywhere on the type (D-MSG1 body-less line). Widgets render
/// [MessageState] and dispatch intents; they never call the gateway directly.
class MessageCubit extends Cubit<MessageState> {
  MessageCubit(this._gateway) : super(const MessageState());

  final MessageGateway _gateway;

  /// In-flight guard. The initial state IS loading (the same contract as the
  /// vault/matter cubits' `load`), so the flag — not a state check —
  /// distinguishes "loading in flight" from "not loaded yet"; duplicate
  /// calls while a load is in flight are ignored.
  bool _loading = false;

  /// Loads the synthetic thread-metadata list. The initial state is already
  /// loading, so the first open never re-emits a redundant loading frame; a
  /// retry after an error re-enters loading. An empty list maps to
  /// [ViewEmpty]; a failure to [ViewError].
  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.threads is! ViewLoading<List<MessageThread>>) {
      emit(state.copyWith(threads: const ViewLoading<List<MessageThread>>()));
    }
    final Result<List<MessageThread>> result = await _gateway.fetchThreads();
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<MessageThread>>(
        value: final List<MessageThread> threads,
      ):
        emit(
          state.copyWith(
            threads: threads.isEmpty
                ? const ViewEmpty<List<MessageThread>>()
                : ViewSuccess<List<MessageThread>>(threads),
          ),
        );
      case Failure<List<MessageThread>>(error: final AppError error):
        emit(state.copyWith(threads: ViewError<List<MessageThread>>(error)));
    }
  }
}
