import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/observability/app_log.dart';

/// Serializes a cubit's writes and maps the gateway result to presentation
/// copy without losing the in-flight case.
///
/// A `null` return means success. Before this gate, an in-flight write also
/// returned null, so a second tap that lost the race looked like success and
/// the caller popped/dismissed as if the write had landed. [run] returns
/// [busyError] instead, which the sheets render like any other typed refusal.
///
/// Only a closed cubit keeps the old null return: its caller can no longer
/// observe anything, and emitting state after close is illegal.
class WriteGate {
  /// The typed failure returned when a write is already in flight.
  static const AppError busyError = AppError(
    code: 'busy',
    userMessage: 'An action is already in progress.',
  );

  bool _inFlight = false;

  /// Runs [write] unless another write is still in flight.
  ///
  /// Returns null on success after [onSuccess] (the list reload) completes,
  /// [busyError] when a write is already running, the gateway's [AppError] on
  /// failure, and null when the cubit closed mid-write.
  Future<AppError?> run<T>({
    required bool Function() isClosed,
    required Future<Result<T>> Function() write,
    required Future<void> Function() onSuccess,
  }) async {
    if (isClosed()) {
      return null;
    }
    if (_inFlight) {
      return busyError;
    }
    _inFlight = true;
    final Result<T> result;
    try {
      result = await write();
    } finally {
      // A thrown gateway must not leave the gate closed forever: the next
      // tap has to be able to run. The original error still propagates.
      _inFlight = false;
    }
    if (isClosed()) {
      return null;
    }
    switch (result) {
      case Success<T>():
        try {
          await onSuccess();
        } on Object catch (error) {
          // The write already committed. A refresh/read-back failure here
          // must not surface as a failed write, or the user retries and
          // duplicates it (audit 2026-10-28, create-sheet tests).
          AppLog.diagnostic('WriteGate: post-write refresh failed: $error');
        }
        return null;
      case Failure<T>(error: final AppError error):
        return error;
    }
  }
}
