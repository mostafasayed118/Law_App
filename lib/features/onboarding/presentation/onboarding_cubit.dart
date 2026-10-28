import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/onboarding/onboarding_store.dart';

/// Presentation-layer seam over [OnboardingStore].
///
/// Keeps the onboarding screens free of data-layer imports; both the skip
/// control and the success action complete onboarding through [complete].
class OnboardingCubit extends Cubit<void> {
  OnboardingCubit(this._store) : super(null);

  final OnboardingStore _store;

  Future<void> complete() => _store.markCompleted();
}
