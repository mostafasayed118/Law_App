import 'app_error.dart';

/// Explicit success/failure boundary used by data and domain layers.
sealed class Result<T> {
  const Result._();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(AppError error) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  T? get valueOrNull => switch (this) {
    Success<T>(value: final value) => value,
    Failure<T>() => null,
  };
  AppError? get errorOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(error: final error) => error,
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value) : super._();

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error) : super._();

  final AppError error;
}
