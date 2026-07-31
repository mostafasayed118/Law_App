import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/auth/domain/sign_up_gateway.dart';
import 'package:legalhub/features/auth/domain/sign_up_request.dart';
import 'package:legalhub/features/auth/presentation/sign_up_cubit.dart';

void main() {
  group('SignUpCubit', () {
    test('starts in the empty state', () {
      final SignUpCubit cubit = SignUpCubit(_AlwaysSucceedsGateway());
      addTearDown(cubit.close);

      expect(cubit.state, const ViewEmpty<void>());
    });

    blocTest<SignUpCubit, ViewState<void>>(
      'emits [loading, success] when the gateway succeeds',
      setUp: () => _capturingGateway = _CapturingGateway(),
      build: () => SignUpCubit(_capturingGateway),
      act: (SignUpCubit cubit) => cubit.submit(_request),
      expect: () => <ViewState<void>>[
        const ViewLoading<void>(),
        const ViewSuccess<void>(null),
      ],
      verify: (_) {
        // The cubit handed the gateway exactly the request the screen built,
        // proving the VO flows through the seam (not constructed and dropped).
        expect(_capturingGateway.received, _request);
      },
    );

    blocTest<SignUpCubit, ViewState<void>>(
      'emits [loading, error] when the gateway fails',
      build: () => SignUpCubit(_AlwaysFailsGateway(_failure)),
      act: (SignUpCubit cubit) => cubit.submit(_request),
      expect: () => <ViewState<void>>[
        const ViewLoading<void>(),
        ViewError<void>(_failure),
      ],
      verify: (_) {
        // Privacy-by-design guard: the failure's diagnostic context was built
        // from SignUpRequest.toRedactedMap; password/phone/email never reach
        // the error surface in clear text.
        final Map<String, Object?> context = _failure.context;
        expect(context['password'], '[REDACTED]');
        expect(context['phone'], '[REDACTED]');
        expect(context['email'], '[REDACTED]');
        // Name is not a sensitive key and is retained.
        expect(context['name'], _request.name);
      },
    );

    blocTest<SignUpCubit, ViewState<void>>(
      'ignores a duplicate submit while one is in flight',
      setUp: () => _countingGateway = _CountingGateway(),
      build: () => SignUpCubit(_countingGateway),
      act: (SignUpCubit cubit) async {
        // Fire two submits back-to-back without awaiting between them. The
        // second must be ignored because the first is still loading.
        final Future<void> first = cubit.submit(_request);
        await cubit.submit(_request);
        await first;
      },
      expect: () => <ViewState<void>>[
        const ViewLoading<void>(),
        const ViewSuccess<void>(null),
      ],
      verify: (_) {
        expect(_countingGateway.calls, 1);
      },
    );

    blocTest<SignUpCubit, ViewState<void>>(
      'resetToEmpty re-enables submission after an error',
      build: () => SignUpCubit(_AlwaysFailsGateway(_failure)),
      act: (SignUpCubit cubit) async {
        await cubit.submit(_request);
        cubit.resetToEmpty();
      },
      expect: () => <ViewState<void>>[
        const ViewLoading<void>(),
        ViewError<void>(_failure),
        const ViewEmpty<void>(),
      ],
    );

    blocTest<SignUpCubit, ViewState<void>>(
      'resetToEmpty is a no-op when not in an error state',
      build: () => SignUpCubit(_AlwaysSucceedsGateway()),
      act: (SignUpCubit cubit) async {
        await cubit.submit(_request);
        cubit.resetToEmpty();
      },
      expect: () => <ViewState<void>>[
        const ViewLoading<void>(),
        const ViewSuccess<void>(null),
      ],
    );
  });
}

// A failure whose context is built from the request's redacted map, exactly as
// a real gateway should build it.
final AppError _failure = AppError(
  code: 'sign_up_failed',
  userMessage: 'Sign up failed',
  context: _request.toRedactedMap(),
);

const SignUpRequest _request = SignUpRequest(
  name: 'Amira Hassan',
  email: 'amira@example.com',
  phone: '+201234567890',
  password: 'super-secret-123',
);

// Holds gateway instances across the blocTest build/verify boundary so the
// tests can assert behavior without reaching into the Cubit's private field.
late _CapturingGateway _capturingGateway;
late _CountingGateway _countingGateway;

class _AlwaysSucceedsGateway implements SignUpGateway {
  @override
  Future<Result<void>> submit(SignUpRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return Result<void>.success(null);
  }
}

class _AlwaysFailsGateway implements SignUpGateway {
  _AlwaysFailsGateway(this.error);

  final AppError error;

  @override
  Future<Result<void>> submit(SignUpRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return Result<void>.failure(error);
  }
}

class _CapturingGateway implements SignUpGateway {
  SignUpRequest? received;

  @override
  Future<Result<void>> submit(SignUpRequest request) async {
    received = request;
    return Result<void>.success(null);
  }
}

class _CountingGateway implements SignUpGateway {
  int calls = 0;

  @override
  Future<Result<void>> submit(SignUpRequest request) async {
    calls += 1;
    // Delay so the in-flight submit overlaps the second call.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return Result<void>.success(null);
  }
}
