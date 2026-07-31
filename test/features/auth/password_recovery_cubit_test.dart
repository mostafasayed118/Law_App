import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/auth/domain/password_recovery_gateway.dart';
import 'package:legalhub/features/auth/domain/password_recovery_request.dart';
import 'package:legalhub/features/auth/presentation/password_recovery_cubit.dart';

void main() {
  group('PasswordRecoveryCubit', () {
    test('starts in the empty state', () {
      final PasswordRecoveryCubit cubit = PasswordRecoveryCubit(
        _AlwaysSucceedsGateway(),
      );
      addTearDown(cubit.close);

      expect(cubit.state, const ViewEmpty<void>());
    });

    blocTest<PasswordRecoveryCubit, ViewState<void>>(
      'emits [loading, success] when the gateway succeeds',
      build: () => PasswordRecoveryCubit(_AlwaysSucceedsGateway()),
      act: (PasswordRecoveryCubit cubit) => cubit.submit(_request),
      expect: () => <ViewState<void>>[
        const ViewLoading<void>(),
        const ViewSuccess<void>(null),
      ],
    );

    blocTest<PasswordRecoveryCubit, ViewState<void>>(
      'emits [loading, error] when the gateway fails',
      build: () => PasswordRecoveryCubit(_AlwaysFailsGateway(_failure)),
      act: (PasswordRecoveryCubit cubit) => cubit.submit(_request),
      expect: () => <ViewState<void>>[
        const ViewLoading<void>(),
        ViewError<void>(_failure),
      ],
    );

    blocTest<PasswordRecoveryCubit, ViewState<void>>(
      'ignores a duplicate submit while one is in flight',
      setUp: () => _countingGateway = _CountingGateway(),
      build: () => PasswordRecoveryCubit(_countingGateway),
      act: (PasswordRecoveryCubit cubit) async {
        // Fire two submits back-to-back without awaiting between them. The
        // second must be ignored because the first is still loading.
        final Future<void> first = cubit.submit(_request);
        await cubit.submit(_request);
        await first;
      },
      // A single [loading, success] pair proves the second submit emitted
      // nothing. The call-count verify below proves it never reached the
      // gateway.
      expect: () => <ViewState<void>>[
        const ViewLoading<void>(),
        const ViewSuccess<void>(null),
      ],
      verify: (_) {
        expect(_countingGateway.calls, 1);
      },
    );

    blocTest<PasswordRecoveryCubit, ViewState<void>>(
      'resetToEmpty re-enables submission after an error',
      build: () => PasswordRecoveryCubit(_AlwaysFailsGateway(_failure)),
      act: (PasswordRecoveryCubit cubit) async {
        await cubit.submit(_request);
        cubit.resetToEmpty();
      },
      expect: () => <ViewState<void>>[
        const ViewLoading<void>(),
        ViewError<void>(_failure),
        const ViewEmpty<void>(),
      ],
    );

    blocTest<PasswordRecoveryCubit, ViewState<void>>(
      'resetToEmpty is a no-op when not in an error state',
      build: () => PasswordRecoveryCubit(_AlwaysSucceedsGateway()),
      act: (PasswordRecoveryCubit cubit) async {
        await cubit.submit(_request);
        cubit.resetToEmpty();
      },
      // Only the submit pair appears: resetToEmpty on a success state emits
      // nothing, which is the no-op contract.
      expect: () => <ViewState<void>>[
        const ViewLoading<void>(),
        const ViewSuccess<void>(null),
      ],
    );
  });
}

const AppError _failure = AppError(
  code: 'recovery_failed',
  userMessage: 'Recovery failed',
);

const PasswordRecoveryRequest _request = PasswordRecoveryRequest(
  email: 'amira@example.com',
  otp: '123456',
  newPassword: 'super-secret-123',
);

// Holds the gateway instance across the blocTest build/verify boundary so the
// duplicate-submission test can assert the gateway was called exactly once
// without reaching into the Cubit's private field.
late _CountingGateway _countingGateway;

class _AlwaysSucceedsGateway implements PasswordRecoveryGateway {
  @override
  Future<Result<void>> reset(PasswordRecoveryRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return Result<void>.success(null);
  }
}

class _AlwaysFailsGateway implements PasswordRecoveryGateway {
  _AlwaysFailsGateway(this.error);

  final AppError error;

  @override
  Future<Result<void>> reset(PasswordRecoveryRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return Result<void>.failure(error);
  }
}

class _CountingGateway implements PasswordRecoveryGateway {
  int calls = 0;

  @override
  Future<Result<void>> reset(PasswordRecoveryRequest request) async {
    calls += 1;
    // Delay so the in-flight submit overlaps the second call.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return Result<void>.success(null);
  }
}
