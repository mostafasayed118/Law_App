/// Device-local first-run onboarding completion flag.
///
/// The router starts on `/onboarding` until this returns true; both the skip
/// control and the success action mark it completed. The SharedPreferences
/// implementation is the production store; the in-memory one keeps tests and
/// env-less runs deterministic.
abstract interface class OnboardingStore {
  Future<bool> hasCompleted();

  Future<void> markCompleted();
}
