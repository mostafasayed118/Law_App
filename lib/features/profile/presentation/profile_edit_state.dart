import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/app_error.dart';

/// State of the display-name editor (ADR-0011).
class ProfileEditState extends Equatable {
  const ProfileEditState({
    this.name = '',
    this.saving = false,
    this.saved = false,
    this.lastError,
  });

  final String name;
  final bool saving;
  final bool saved;
  final AppError? lastError;

  ProfileEditState copyWith({
    String? name,
    bool? saving,
    bool? saved,
    AppError? lastError,
    bool clearError = false,
  }) {
    return ProfileEditState(
      name: name ?? this.name,
      saving: saving ?? this.saving,
      saved: saved ?? (this.saved && lastError == null && !clearError),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => <Object?>[name, saving, saved, lastError];
}
