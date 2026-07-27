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
