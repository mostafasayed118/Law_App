import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/password_recovery_gateway.dart';
import '../domain/password_recovery_request.dart';

/// Owns the password-recovery submission lifecycle.
///
/// Emits the canonical [ViewState] vocabulary so the screen can render
/// loading/success/error via the shared [ViewStateView]. This is the first
/// feature consumer of the `ViewState` primitive (ADR-0004), converting it
/// from "retained by contract" to "retained by use."
///
/// Like [AuthCubit], it depends only on the domain [PasswordRecoveryGateway]
/// seam; it never touches transport or parsing details, and it routes
/// failures through [AppError] so the diagnostic surface stays redacted.
class PasswordRecoveryCubit extends Cubit<ViewState<void>> {
  PasswordRecoveryCubit(this._gateway) : super(const ViewEmpty<void>());

  final PasswordRecoveryGateway _gateway;

  Future<void> submit(PasswordRecoveryRequest request) async {
    // Guard against duplicate submissions: ignore a submit while one is in
    // flight or already succeeded. A retry re-enters from the error state.
    if (state is ViewLoading<void> || state is ViewSuccess<void>) {
      return;
    }
    emit(const ViewLoading<void>());
    final Result<void> result = await _gateway.reset(request);
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
