/// Anchored RFC-4122 UUID shape check (8-4-4-4-12 hex digits).
///
/// Shared by the discovery directory (`Attorney.hasRealId`) and the booking
/// attorney-reference guard (`normalizeAttorneyRef`): both need the exact
/// same shape test, and a divergence would let a synthetic `atty-*` id reach
/// the real booking RPC from one path only.
final RegExp _uuidShape = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// True when [value] is exactly a UUID (no surrounding text).
bool isValidUuid(String value) => _uuidShape.hasMatch(value);
