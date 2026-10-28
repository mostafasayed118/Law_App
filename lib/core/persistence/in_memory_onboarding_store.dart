import 'package:legalhub/core/persistence/onboarding_store.dart';

class InMemoryOnboardingStore implements OnboardingStore {
  InMemoryOnboardingStore({bool completed = false}) {
    _completed = completed;
  }

  bool _completed = false;

  @override
  Future<bool> hasCompleted() async => _completed;

  @override
  Future<void> markCompleted() async {
    _completed = true;
  }
}
