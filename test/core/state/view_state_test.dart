import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';

/// Pins the failure → [ViewState] mapping (audit 2026-09-21, M-1).
///
/// Before the typed [AppErrorKind] existed, every failed load became a generic
/// [ViewError] with a retry button: a denial offered a retry that could never
/// succeed, and the offline/unauthorized variants had no producers anywhere in
/// `lib/` (only the widget tests constructed them).
void main() {
  AppError errorOf(AppErrorKind kind) =>
      AppError(code: 'stub_code', userMessage: 'stub message', kind: kind);

  test('a denied failure renders the unauthorized arm (not retryable)', () {
    expect(
      viewStateForFailure<List<String>>(errorOf(AppErrorKind.denied)),
      isA<ViewUnauthorized<List<String>>>(),
    );
  });

  test('an unavailable failure renders the offline arm (retryable)', () {
    expect(
      viewStateForFailure<List<String>>(errorOf(AppErrorKind.unavailable)),
      isA<ViewOffline<List<String>>>(),
    );
  });

  test('an unclassified failure keeps the generic error arm, carrying it', () {
    final AppError appError = errorOf(AppErrorKind.unknown);
    final ViewState<List<String>> state = viewStateForFailure<List<String>>(
      appError,
    );

    expect(state, isA<ViewError<List<String>>>());
    expect((state as ViewError<List<String>>).error, appError);
  });

  test(
    'kind defaults to unknown, so existing constructions keep their arm',
    () {
      const AppError legacy = AppError(code: 'legacy', userMessage: 'legacy');

      expect(legacy.kind, AppErrorKind.unknown);
      expect(viewStateForFailure<void>(legacy), isA<ViewError<void>>());
    },
  );
}
