import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/profile/domain/account_gateway.dart';
import 'profile_edit_state.dart';

/// Saves the signed-in user's display name through the RPC-only write path.
class ProfileEditCubit extends Cubit<ProfileEditState> {
  ProfileEditCubit(this._gateway, {String initialName = ''})
    : super(ProfileEditState(name: initialName));

  final AccountGateway _gateway;

  void nameChanged(String value) {
    if (!isClosed) {
      emit(state.copyWith(name: value, clearError: true));
    }
  }

  /// Saves [state.name]. Length and character validation is duplicated
  /// server-side (migration 34); the screen validates before calling this, and
  /// the cubit still handles a server rejection as a typed error.
  Future<bool> save() async {
    if (isClosed || state.saving) {
      return false;
    }
    emit(state.copyWith(saving: true, clearError: true));
    final Result<void> result = await _gateway.updateDisplayName(state.name);
    if (isClosed) {
      return false;
    }
    switch (result) {
      case Success<void>():
        emit(state.copyWith(saving: false, saved: true));
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
