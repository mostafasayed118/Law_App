import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/persistence/in_memory_onboarding_store.dart';
import 'package:legalhub/features/onboarding/presentation/onboarding_cubit.dart';

void main() {
  group('OnboardingCubit complete', () {
    test('marks the onboarding store completed', () async {
      final InMemoryOnboardingStore store = InMemoryOnboardingStore();
      final OnboardingCubit cubit = OnboardingCubit(store);
      addTearDown(cubit.close);

      expect(await store.hasCompleted(), isFalse);

      await cubit.complete();

      expect(await store.hasCompleted(), isTrue);
    });
  });
}
