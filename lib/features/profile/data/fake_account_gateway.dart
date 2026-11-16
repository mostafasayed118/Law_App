import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/profile/domain/account_errors.dart';
import 'package:legalhub/features/profile/domain/account_gateway.dart';

/// Demo account seam. Mirrors every server guard in migration 34, because a
/// fake that is more permissive than the RPC would let the UI ship a flow the
/// server refuses (ADR-0011).
class FakeAccountGateway implements AccountGateway {
  FakeAccountGateway({
    this.platformOwner = false,
    this.lastActivePartner = false,
    this.rejectUpdates = false,
  });

  final bool platformOwner;
  final bool lastActivePartner;
  final bool rejectUpdates;

  String displayName = 'Demo user';
  int updateCalls = 0;
  int deleteCalls = 0;
  bool deleted = false;

  @override
  Future<Result<void>> updateDisplayName(String name) async {
    updateCalls++;
    if (rejectUpdates) {
      return const Result<void>.failure(AccountErrors.invalidName);
    }
    final String trimmed = name.trim();
    if (trimmed.length < 2 ||
        trimmed.length > 120 ||
        trimmed.contains(RegExp(r'[\r\n\t]'))) {
      return const Result<void>.failure(AccountErrors.invalidName);
    }
    displayName = trimmed;
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> deleteAccount() async {
    deleteCalls++;
    if (platformOwner) {
      return const Result<void>.failure(AccountErrors.platformOwner);
    }
    if (lastActivePartner) {
      return const Result<void>.failure(AccountErrors.lastPartner);
    }
    deleted = true;
    return const Result<void>.success(null);
  }
}
