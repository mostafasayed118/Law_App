import 'package:equatable/equatable.dart';

import '../errors/app_error.dart';

/// Shared async state vocabulary for Cubits and placeholder screens.
sealed class ViewState<T> extends Equatable {
  const ViewState();
}

final class ViewLoading<T> extends ViewState<T> {
  const ViewLoading();

  @override
  List<Object?> get props => const <Object?>[];
}

final class ViewSuccess<T> extends ViewState<T> {
  const ViewSuccess(this.data);

  final T data;

  @override
  List<Object?> get props => <Object?>[data];
}

final class ViewEmpty<T> extends ViewState<T> {
  const ViewEmpty();

  @override
  List<Object?> get props => const <Object?>[];
}

final class ViewError<T> extends ViewState<T> {
  const ViewError(this.error);

  final AppError error;

  @override
  List<Object?> get props => <Object?>[error];
}

final class ViewOffline<T> extends ViewState<T> {
  const ViewOffline();

  @override
  List<Object?> get props => const <Object?>[];
}

final class ViewUnauthorized<T> extends ViewState<T> {
  const ViewUnauthorized();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Selects the [ViewState] arm for a failed load from the error's typed
/// [AppError.kind].
///
/// A denial renders [ViewUnauthorized] (no retry — retrying cannot help) and a
/// transport outage renders [ViewOffline] (retryable); everything else keeps
/// the generic [ViewError]. Before this, every failure became a generic error
/// with a retry button that could never succeed on a denial, and the two
/// variants had no producers anywhere in `lib/` (audit 2026-09-21, M-1).
ViewState<T> viewStateForFailure<T>(AppError error) => switch (error.kind) {
  AppErrorKind.denied => ViewUnauthorized<T>(),
  AppErrorKind.unavailable => ViewOffline<T>(),
  AppErrorKind.unknown => ViewError<T>(error),
};
