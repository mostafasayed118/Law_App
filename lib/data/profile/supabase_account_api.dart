/// Provider-neutral seam for the two account mutations (ADR-0011).
library;

abstract interface class AccountApi {
  Future<void> updateDisplayName(String displayName);

  Future<void> deleteAccount();
}

class AccountApiException implements Exception {
  const AccountApiException(this.code, {this.message});

  /// The SQLSTATE or the stable exception name raised by migration 34.
  final String code;
  final String? message;

  @override
  String toString() => 'AccountApiException($code): $message';
}
