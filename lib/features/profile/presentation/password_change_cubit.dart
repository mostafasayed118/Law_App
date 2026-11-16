import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/profile/domain/password_gateway.dart';
import 'password_change_state.dart';

/// Changes the password on the current session without signing out.
class PasswordChangeCubit extends Cubit<PasswordChangeState> {
  PasswordChangeCubit(this._gateway) : super(const PasswordChangeState());

  final PasswordGateway _gateway;

  void newPasswordChanged(String value) {
    if (!isClosed) {
      emit(state.copyWith(newPassword: value, clearError: true));
    }
  }

  void confirmationChanged(String value) {
    if (!isClosed) {
      emit(state.copyWith(confirmation: value));
    }
  }

  /// Assumes the screen already ran `LegalHubValidators.strongPassword` and the
  /// confirmation match check. The cubit owns the call and its failure arms.
  Future<bool> submit() async {
    if (isClosed || state.saving) {
      return false;
    }
    emit(state.copyWith(saving: true, clearError: true));
    final Result<void> result = await _gateway.changePassword(
      state.newPassword,
    );
    if (isClosed) {
      return false;
    }
    switch (result) {
      case Success<void>():
        emit(
          state.copyWith(
            saving: false,
            changed: true,
            newPassword: '',
            confirmation: '',
          ),
        );
        return true;
      case Failure<void>(error: final AppError error):
        emit(state.copyWith(saving: false, lastError: error));
        return false;
    }
  }

  void acknowledgeError() {
    if (!isClosed && state.lastError != null) {
      emit(state.copyWith(clearError: true));
    }
  }
}
