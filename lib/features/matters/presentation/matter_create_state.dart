import 'package:equatable/equatable.dart';

import '../../../core/errors/app_error.dart';
import '../domain/matter_write_gateway.dart';

/// Immutable state of the matter-creation flow (F-01 step 2 client swap,
/// C-D6): the sealed `initial` / `submitting` / `success` / `failure`
/// lifecycle the form screen renders.
sealed class MatterCreateState extends Equatable {
  const MatterCreateState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The form is ready for input (the resting state before a submit).
class MatterCreateInitial extends MatterCreateState {
  const MatterCreateInitial();
}

/// A submit is in flight — the form is disabled and a progress indicator is
/// shown. A second submit while in flight is ignored by the cubit.
class MatterCreateSubmitting extends MatterCreateState {
  const MatterCreateSubmitting();
}

/// The matter was created; [createdMatter] carries the server's returned id.
///
/// Honest UX (R1): a created matter appears on the list only when the
/// caller's access lets them read it (an assigned-to-partner create IS
/// visible; an orphan create is not — the battery 13.16 pin), so the
/// success view never promises list visibility.
class MatterCreateSuccess extends MatterCreateState {
  const MatterCreateSuccess(this.createdMatter);

  final CreatedMatter createdMatter;

  @override
  List<Object?> get props => <Object?>[createdMatter];
}

/// The create was refused or failed; [error] carries the typed C-D2 kind.
/// A denial is never presented as empty success (AC-7).
class MatterCreateFailure extends MatterCreateState {
  const MatterCreateFailure(this.error);

  final AppError error;

  @override
  List<Object?> get props => <Object?>[error];
}
