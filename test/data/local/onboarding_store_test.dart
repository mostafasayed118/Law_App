import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/local/in_memory_onboarding_store.dart';
import 'package:legalhub/data/local/shared_preferences_onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('in-memory store starts uncompleted and persists completion', () async {
    final InMemoryOnboardingStore store = InMemoryOnboardingStore();

    expect(await store.hasCompleted(), isFalse);
    await store.markCompleted();
    expect(await store.hasCompleted(), isTrue);
  });

  test('shared preferences store round-trips the completion flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final SharedPreferencesOnboardingStore store =
        SharedPreferencesOnboardingStore(preferences);

    expect(await store.hasCompleted(), isFalse);
    await store.markCompleted();
    expect(await store.hasCompleted(), isTrue);
    expect(
      await SharedPreferencesOnboardingStore(preferences).hasCompleted(),
      isTrue,
    );
  });
}
