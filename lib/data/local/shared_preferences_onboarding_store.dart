import 'package:legalhub/core/onboarding/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesOnboardingStore implements OnboardingStore {
  const SharedPreferencesOnboardingStore(this._preferences);

  static const String _completedKey = 'legalhub.onboarding_completed_v1';
  final SharedPreferences _preferences;

  @override
  Future<bool> hasCompleted() async =>
      _preferences.getBool(_completedKey) ?? false;

  @override
  Future<void> markCompleted() async {
    await _preferences.setBool(_completedKey, true);
  }
}
