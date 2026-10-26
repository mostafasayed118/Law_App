import 'package:legalhub/core/contracts/network.dart';

Future<T> withRequestTimeout<T>(
  Future<T> future, {
  Duration timeout = kSupabaseRequestTimeout,
}) => future.timeout(timeout);
