import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';

/// State of the platform-admin attorney directory (design §2).
///
/// - [attorneys] — the list load lifecycle (denied maps to unauthorized).
/// - [pending] — a write is in flight (the form disables Save).
/// - [actionError] — the last write failure, rendered inline; null when the
///   last write succeeded or none ran.
class AttorneyAdminState extends Equatable {
  const AttorneyAdminState({
    this.attorneys = const ViewLoading<List<Attorney>>(),
    this.pending = false,
    this.actionError,
  });

  final ViewState<List<Attorney>> attorneys;
  final bool pending;
  final AppError? actionError;

  AttorneyAdminState copyWith({
    ViewState<List<Attorney>>? attorneys,
    bool? pending,
    AppError? actionError,
    bool clearActionError = false,
  }) {
    return AttorneyAdminState(
      attorneys: attorneys ?? this.attorneys,
      pending: pending ?? this.pending,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }

  @override
  List<Object?> get props => <Object?>[attorneys, pending, actionError];
}
