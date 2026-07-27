import '../errors/result.dart';

/// Base contract for focused, asynchronous domain operations.
abstract interface class UseCase<Output, Input> {
  Future<Result<Output>> call(Input input);
}

class NoInput {
  const NoInput();
}
