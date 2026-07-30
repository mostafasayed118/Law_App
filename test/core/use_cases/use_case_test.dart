import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/use_cases/use_case.dart';

void main() {
  group('NoInput', () {
    test('is a stable sentinel that can be constructed as a const', () {
      const NoInput a = NoInput();
      const NoInput b = NoInput();
      expect(identical(a, b), isTrue);
    });
  });

  group('UseCase', () {
    test('call returns Result<Output> and is awaitable', () async {
      final _SucceedingUseCase useCase = _SucceedingUseCase();
      final Result<String> result = await useCase(const NoInput());
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 'ok');
    });

    test('a failing use case returns Failure<AppError>', () async {
      final _FailingUseCase useCase = _FailingUseCase();
      final Result<String> result = await useCase(const NoInput());
      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'use_case_failed');
    });
  });
}

class _SucceedingUseCase implements UseCase<String, NoInput> {
  @override
  Future<Result<String>> call(NoInput input) async =>
      Result<String>.success('ok');
}

class _FailingUseCase implements UseCase<String, NoInput> {
  @override
  Future<Result<String>> call(NoInput input) async => Result<String>.failure(
        const AppError(code: 'use_case_failed', userMessage: 'failed'),
      );
}
