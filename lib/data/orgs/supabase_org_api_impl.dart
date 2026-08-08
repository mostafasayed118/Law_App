import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_org_api.dart';

/// A PostgREST RPC call: function name + named params → response.
///
/// Kept a plain function type so tests inject a closure and the impl is the
/// only file that ever touches provider types (the production binding below
/// adapts the real client).
typedef OrgRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// A PostgREST table SELECT: table name + columns → raw map rows.
///
/// The second callable the impl injects (alongside [OrgRpcCaller]) for the
/// P3.2 membership-hydration SELECT. Same seam discipline: plain function
/// type for test injection, provider types confined to the production
/// binding below.
typedef OrgTableCaller =
    Future<List<Map<String, dynamic>>> Function(String table, String columns);

/// [SupabaseOrgApi] backed by the PostgREST client.
///
/// Like [SupabaseAuthApiImpl], this is a data-layer file whose only job is
/// holding the provider import: parameters in, plain maps/scalars out, and
/// PostgrestExceptions mapped to [SupabaseOrgException]s at the seam.
class SupabaseOrgApiImpl implements SupabaseOrgApi {
  SupabaseOrgApiImpl(this._rpc, this._table);

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseOrgApiImpl.bind() =>
      SupabaseOrgApiImpl(_boundRpc, _boundTable);
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

  /// Binds a table SELECT to the app-level client. The builder's `select`
  /// resolves to the raw row list (PostgrestList) — no cast needed.
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return Supabase.instance.client.from(table).select(columns);
  }

  final OrgRpcCaller _rpc;
  final OrgTableCaller _table;

  @override
  Future<String> createOrganization({required String name}) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        'create_organization',
        <String, dynamic>{'p_name': name},
      );
      final Object? id = response.data;
      if (id is! String || id.isEmpty) {
        throw SupabaseOrgException(
          kind: SupabaseOrgFailureKind.unknown,
          message: 'create_organization returned no id.',
        );
      }
      return id;
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(kind: _kindFor(e), message: e.message);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listMembers({
    required String organizationId,
  }) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        'list_org_members_metadata',
        <String, dynamic>{'p_organization_id': organizationId},
      );
      final Object? data = response.data;
      if (data is! List<dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(kind: _kindFor(e), message: e.message);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listMyMemberships() async {
    try {
      // RLS-scoped: memberships policy = own-row OR active-member; the
      // embedded organizations(name) join resolves for active memberships
      // and is null for suspended/removed ones (org row not visible) — the
      // repository mapper tolerates the null name (plan §6).
      return await _table(
        'memberships',
        'organization_id, role, status, organizations(name)',
      );
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(kind: _kindFor(e), message: e.message);
    }
  }

  @override
  Future<String> inviteMember({
    required String organizationId,
    required String email,
    required String role,
  }) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        'invite_member',
        <String, dynamic>{
          'p_organization_id': organizationId,
          'p_email': email,
          'p_role': role,
        },
      );
      final Object? token = response.data;
      if (token is! String || token.isEmpty) {
        throw SupabaseOrgException(
          kind: SupabaseOrgFailureKind.unknown,
          message: 'invite_member returned no token.',
        );
      }
      return token;
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(kind: _kindFor(e), message: e.message);
    }
  }

  @override
  Future<void> changeMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  }) async {
    await _runVoidRpc('change_member_role', <String, dynamic>{
      'p_organization_id': organizationId,
      'p_user_id': userId,
      'p_role': role,
    });
  }

  @override
  Future<void> suspendMember({
    required String organizationId,
    required String userId,
  }) async {
    await _runVoidRpc('suspend_membership', <String, dynamic>{
      'p_organization_id': organizationId,
      'p_user_id': userId,
    });
  }

  @override
  Future<void> reactivateMember({
    required String organizationId,
    required String userId,
  }) async {
    await _runVoidRpc('reactivate_membership', <String, dynamic>{
      'p_organization_id': organizationId,
      'p_user_id': userId,
    });
  }

  @override
  Future<void> removeMember({
    required String organizationId,
    required String userId,
  }) async {
    await _runVoidRpc('remove_membership', <String, dynamic>{
      'p_organization_id': organizationId,
      'p_user_id': userId,
    });
  }

  @override
  Future<String> resendInvitation({required String invitationId}) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        'resend_invitation',
        <String, dynamic>{'p_invitation_id': invitationId},
      );
      final Object? token = response.data;
      if (token is! String || token.isEmpty) {
        throw SupabaseOrgException(
          kind: SupabaseOrgFailureKind.unknown,
          message: 'resend_invitation returned no token.',
        );
      }
      return token;
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(kind: _kindFor(e), message: e.message);
    }
  }

  @override
  Future<void> revokeInvitation({required String invitationId}) async {
    await _runVoidRpc('revoke_invitation', <String, dynamic>{
      'p_invitation_id': invitationId,
    });
  }

  @override
  Future<void> deleteMyAccount() async {
    await _runVoidRpc('delete_my_account', const <String, dynamic>{});
  }

  @override
  Future<String> acceptInvitation({required String token}) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        'accept_invitation',
        <String, dynamic>{'p_token': token},
      );
      final Object? membershipId = response.data;
      if (membershipId is! String || membershipId.isEmpty) {
        throw SupabaseOrgException(
          kind: SupabaseOrgFailureKind.unknown,
          message: 'accept_invitation returned no membership id.',
        );
      }
      return membershipId;
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(kind: _kindFor(e), message: e.message);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> readOrgAudit({
    required String organizationId,
  }) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        'read_org_audit',
        <String, dynamic>{'p_organization_id': organizationId},
      );
      final Object? data = response.data;
      if (data is! List<dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(kind: _kindFor(e), message: e.message);
    }
  }

  Future<void> _runVoidRpc(String function, Map<String, dynamic> params) async {
    try {
      await _rpc(function, params);
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(kind: _kindFor(e), message: e.message);
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind.
  /// Message fragments are the stable RPC raise texts; everything else is
  /// [SupabaseOrgFailureKind.unknown] with the message preserved.
  SupabaseOrgFailureKind _kindFor(PostgrestException e) {
    final String message = e.message.toLowerCase();
    if (message.contains('permission denied') ||
        message.contains('cannot remove yourself')) {
      return SupabaseOrgFailureKind.denied;
    }
    if (message.contains('user already has a membership')) {
      return SupabaseOrgFailureKind.duplicateMember;
    }
    if (message.contains('retain at least one active partner')) {
      return SupabaseOrgFailureKind.lastPartner;
    }
    if (message.contains('organization name is required')) {
      return SupabaseOrgFailureKind.invalidName;
    }
    if (message.contains('invalid invitation')) {
      return SupabaseOrgFailureKind.invalidInvitation;
    }
    // Invitation-targeted RPCs use the same undifferentiated denial: an
    // unknown id and a non-pending invite both read as "invalid invitation"
    // (non-enumerating; matches the token surface).
    if (message.contains('invitation not found') ||
        message.contains('only pending invitations')) {
      return SupabaseOrgFailureKind.invalidInvitation;
    }
    return SupabaseOrgFailureKind.unknown;
  }
}
