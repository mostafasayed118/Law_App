import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/profile/domain/account_gateway.dart';
import 'account_deletion_state.dart';

/// The account-deletion flow: typed confirmation, explicit refusal handling,
/// and a `done` stage set ONLY after the RPC succeeds (ADR-0011).
class AccountDeletionCubit extends Cubit<AccountDeletionState> {
  AccountDeletionCubit(this._gateway) : super(const AccountDeletionState());

  final AccountGateway _gateway;

  void confirmationChanged(String value) {
    if (!isClosed) {
      emit(state.copyWith(confirmation: value, clearError: true));
    }
  }

  Future<bool> delete() async {
    if (isClosed || !state.canSubmit) {
      return false;
    }
    emit(
      state.copyWith(stage: AccountDeletionStage.deleting, clearError: true),
    );
    final Result<void> result = await _gateway.deleteAccount();
    if (isClosed) {
      return false;
    }
    switch (result) {
      case Success<void>():
        emit(const AccountDeletionState(stage: AccountDeletionStage.done));
        return true;
      case Failure<void>(error: final AppError error):
        emit(
          state.copyWith(
            stage: AccountDeletionStage.confirming,
            lastError: error,
          ),
        );
        return false;
    }
  }
}
