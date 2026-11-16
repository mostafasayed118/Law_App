import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/app_error.dart';

/// Stages of the deletion flow, so the UI can never show a success it has not
/// earned (ADR-0011).
enum AccountDeletionStage { idle, confirming, deleting, done }

class AccountDeletionState extends Equatable {
  const AccountDeletionState({
    this.confirmation = '',
    this.stage = AccountDeletionStage.idle,
    this.lastError,
  });

  final String confirmation;
  final AccountDeletionStage stage;
  final AppError? lastError;

  bool get canSubmit =>
      confirmation.trim().isNotEmpty && stage != AccountDeletionStage.deleting;

  /// True when the server refused because this account is the last active
  /// partner of an organization — a actionable, specific message.
  bool get isLastPartner => lastError?.code == 'account_deletion_last_partner';

  bool get isPlatformOwner =>
      lastError?.code == 'account_deletion_platform_owner';

  AccountDeletionState copyWith({
    String? confirmation,
    AccountDeletionStage? stage,
    AppError? lastError,
    bool clearError = false,
  }) {
    return AccountDeletionState(
      confirmation: confirmation ?? this.confirmation,
      stage: stage ?? this.stage,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => <Object?>[confirmation, stage, lastError];
}
