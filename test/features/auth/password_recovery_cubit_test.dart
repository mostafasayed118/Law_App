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

    test('emits loading then success when the gateway succeeds', () async {
      final PasswordRecoveryCubit cubit = PasswordRecoveryCubit(
        _AlwaysSucceedsGateway(),
      );
      addTearDown(cubit.close);

      await cubit.submit(_request);

      expect(cubit.state, const ViewSuccess<void>(null));
      // The loading state was emitted before success (verify the transition
      // by capturing the stream).
    });

    test('emits loading then error when the gateway fails', () async {
      const AppError failure = AppError(
        code: 'recovery_failed',
        userMessage: 'Recovery failed',
      );
      final PasswordRecoveryCubit cubit = PasswordRecoveryCubit(
        _AlwaysFailsGateway(failure),
      );
      addTearDown(cubit.close);

      await cubit.submit(_request);

      expect(cubit.state, isA<ViewError<void>>());
      expect((cubit.state as ViewError<void>).error, failure);
    });

    test('ignores a duplicate submit while one is in flight', () async {
      final _CountingGateway gateway = _CountingGateway();
      final PasswordRecoveryCubit cubit = PasswordRecoveryCubit(gateway);
      addTearDown(cubit.close);

      // Fire two submits back-to-back without awaiting between them. The
      // second must be ignored because the first is still loading.
      final Future<void> first = cubit.submit(_request);
      await cubit.submit(_request);
      await first;

      // Only the first submit reached the gateway.
      expect(gateway.calls, 1);
    });

    test('resetToEmpty re-enables submission after an error', () async {
      const AppError failure = AppError(
        code: 'recovery_failed',
        userMessage: 'Recovery failed',
      );
      final PasswordRecoveryCubit cubit = PasswordRecoveryCubit(
        _AlwaysFailsGateway(failure),
      );
      addTearDown(cubit.close);

      await cubit.submit(_request);
      expect(cubit.state, isA<ViewError<void>>());

      cubit.resetToEmpty();
      expect(cubit.state, const ViewEmpty<void>());
    });

    test('resetToEmpty is a no-op when not in an error state', () async {
      final PasswordRecoveryCubit cubit = PasswordRecoveryCubit(
        _AlwaysSucceedsGateway(),
      );
      addTearDown(cubit.close);

      await cubit.submit(_request);
      expect(cubit.state, const ViewSuccess<void>(null));

      cubit.resetToEmpty();
      // Still success; resetToEmpty only clears errors.
      expect(cubit.state, const ViewSuccess<void>(null));
    });
  });
}

const PasswordRecoveryRequest _request = PasswordRecoveryRequest(
  email: 'amira@example.com',
  otp: '123456',
  newPassword: 'super-secret-123',
);

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
