import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/message_thread.dart';

/// Immutable state of the thread-list surface (Phase 9, slice 9.1).
///
/// [threads] holds the thread-metadata load lifecycle using the shared
/// [ViewState] vocabulary (loading / success / empty / error+retry). There is
/// deliberately no filter or search field (scope note §3 — client-side list
/// only) — the smallest surface that satisfies the AC-2 body-less line
/// (D-MSG1).
class MessageState extends Equatable {
  const MessageState({this.threads = const ViewLoading<List<MessageThread>>()});

  final ViewState<List<MessageThread>> threads;

  MessageState copyWith({ViewState<List<MessageThread>>? threads}) {
    return MessageState(threads: threads ?? this.threads);
  }

  @override
  List<Object?> get props => <Object?>[threads];
}
