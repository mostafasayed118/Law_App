import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/sign_up_gateway.dart';
import '../domain/sign_up_request.dart';

/// Owns the sign-up submission lifecycle.
///
/// Emits the canonical [ViewState] vocabulary so the screen can render
/// loading/success/error via the shared [ViewStateView], mirroring
/// [PasswordRecoveryCubit]. It depends only on the domain [SignUpGateway]
/// seam; it never touches transport or parsing details, and it routes
/// failures through [AppError] so the diagnostic surface stays redacted.
///
/// Privacy contract: on failure the caller supplies an [AppError] whose
/// `context` is built from [SignUpRequest.toRedactedMap]; the password and PII
/// never reach diagnostics in clear text.
class SignUpCubit extends Cubit<ViewState<void>> {
  SignUpCubit(this._gateway) : super(const ViewEmpty<void>());

  final SignUpGateway _gateway;

  Future<void> submit(SignUpRequest request) async {
    // Guard against duplicate submissions: ignore a submit while one is in
    // flight or already succeeded. A retry re-enters from the error state.
    if (state is ViewLoading<void> || state is ViewSuccess<void>) {
      return;
    }
    emit(const ViewLoading<void>());
    final Result<void> result = await _gateway.submit(request);
    if (!isClosed) {
      switch (result) {
        case Success<void>():
          emit(const ViewSuccess<void>(null));
        case Failure<void>(error: final error):
          emit(ViewError<void>(error));
      }
    }
  }

  /// Re-enables submission after an error so the user can retry.
  void resetToEmpty() {
    if (!isClosed && state is ViewError<void>) {
      emit(const ViewEmpty<void>());
    }
  }
}
