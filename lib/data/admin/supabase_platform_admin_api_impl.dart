import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_platform_admin_api.dart';

/// A PostgREST RPC call: function name + named params → response.
///
/// Kept a plain function type so tests inject a closure and the impl is the
/// only file that ever touches provider types (the production binding below
/// adapts the real client). Mirrors the organization seam's `OrgRpcCaller`.
typedef PlatformAdminRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabasePlatformAdminApi] backed by the PostgREST client.
///
/// A data-layer file whose only job is holding the provider import:
/// parameters in, plain map rows/scalars out, and PostgrestExceptions mapped
/// to [SupabasePlatformAdminException]s at the seam.
class SupabasePlatformAdminApiImpl implements SupabasePlatformAdminApi {
  SupabasePlatformAdminApiImpl(this._rpc);

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabasePlatformAdminApiImpl.bind() =>
      SupabasePlatformAdminApiImpl(_boundRpc);
  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    // rpc<T> builders implement Future<dynamic> (T = the data type), so the
    // awaited value is the full PostgrestResponse at runtime — cast, not
    // wrap, so errors and status flow through unchanged.
    final dynamic response = await Supabase.instance.client.rpc<dynamic>(
      function,
      params: params,
    );
    return response as PostgrestResponse<dynamic>;
  }

  final PlatformAdminRpcCaller _rpc;

  @override
  Future<List<Map<String, dynamic>>> listOrganizations() async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        'list_organizations_metadata',
        const <String, dynamic>{},
      );
      final Object? data = response.data;
      if (data is! List<dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabasePlatformAdminException(
        kind: _kindFor(e),
        message: e.message,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listMembers() async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        'list_members_metadata',
        const <String, dynamic>{},
      );
      final Object? data = response.data;
      if (data is! List<dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabasePlatformAdminException(
        kind: _kindFor(e),
        message: e.message,
      );
    }
  }

  @override
  Future<void> suspendMembership({
    required String organizationId,
    required String userId,
  }) => _runVoidRpc('suspend_membership_platform', <String, dynamic>{
    'p_organization_id': organizationId,
    'p_user_id': userId,
  });

  @override
  Future<void> reactivateMembership({
    required String organizationId,
    required String userId,
  }) => _runVoidRpc('reactivate_membership_platform', <String, dynamic>{
    'p_organization_id': organizationId,
    'p_user_id': userId,
  });

  @override
  Future<void> deleteDemoAccount({required String userId}) => _runVoidRpc(
    'delete_demo_account',
    <String, dynamic>{'p_user_id': userId},
  );

  @override
  Future<List<Map<String, dynamic>>> readPlatformAudit() async {
    try {
      return _rowsFrom(await _rpc('read_platform_audit', const <String, dynamic>{}));
    } on PostgrestException catch (e) {
      throw SupabasePlatformAdminException(kind: _kindFor(e), message: e.message);
    } on Object {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the auth/storage
      // impls' defensive-catch precedent).
      throw const SupabasePlatformAdminException(
        kind: SupabasePlatformAdminFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> readOrgAudit(String organizationId) async {
    try {
      return _rowsFrom(await _rpc('read_org_audit', <String, dynamic>{
        'p_organization_id': organizationId,
      }));
    } on PostgrestException catch (e) {
      throw SupabasePlatformAdminException(kind: _kindFor(e), message: e.message);
    } on Object {
      throw const SupabasePlatformAdminException(
        kind: SupabasePlatformAdminFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Extracts the plain map rows from an RPC response, skipping any
  /// non-map entries (the list-shaped RPCs' shared shape guard).
  List<Map<String, dynamic>> _rowsFrom(PostgrestResponse<dynamic> response) {
    final Object? data = response.data;
    if (data is! List<dynamic>) {
      return const <Map<String, dynamic>>[];
    }
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<void> _runVoidRpc(String function, Map<String, dynamic> params) async {
    try {
      await _rpc(function, params);
    } on PostgrestException catch (e) {
      throw SupabasePlatformAdminException(
        kind: _kindFor(e),
        message: e.message,
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind.
  /// Message fragments are the stable RPC raise texts; everything else is
  /// [SupabasePlatformAdminFailureKind.unknown] with the message preserved.
  SupabasePlatformAdminFailureKind _kindFor(PostgrestException e) {
    final String message = e.message.toLowerCase();
    if (message.contains('permission denied') ||
        message.contains('cannot delete your own account')) {
      return SupabasePlatformAdminFailureKind.denied;
    }
    return SupabasePlatformAdminFailureKind.unknown;
  }
}
