import 'dart:async';

import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:legalhub/data/supabase_wire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_org_api.dart';

part 'supabase_org_api_mapping.dart';

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

/// A PostgREST table SELECT: table name + columns → raw map rows, with an
/// optional server-side equality filter.
///
/// The second callable the impl injects (alongside [OrgRpcCaller]) for the
/// P3.2 membership-hydration SELECT. Same seam discipline: plain function
/// type for test injection, provider types confined to the production
/// binding below.
typedef OrgTableCaller =
    Future<List<Map<String, dynamic>>> Function(
      String table,
      String columns, {
      String? filterColumn,
      Object? filterValue,
    });

/// [SupabaseOrgApi] backed by the PostgREST client.
///
/// Like [SupabaseAuthApiImpl], this is a data-layer file whose only job is
/// holding the provider import: parameters in, plain maps/scalars out, and
/// PostgrestExceptions mapped to [SupabaseOrgException]s at the seam.
class SupabaseOrgApiImpl implements SupabaseOrgApi {
  SupabaseOrgApiImpl(this._rpcCaller, this._table);

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseOrgApiImpl.bind() =>
      SupabaseOrgApiImpl(_boundRpc, _boundTable);

  /// Shared seam binding ([SupabaseSeam.boundRpc]).
  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRpc(function, params);
  }

  /// Shared seam binding ([SupabaseSeam.boundFilteredTable]): an optional
  /// equality filter + a hard row cap, no ordering (the `memberships` read
  /// is scoped to the caller's `user_id`; no deterministic column is
  /// contractually meaningful) (audit 2026-09-21, P1).
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns, {
    String? filterColumn,
    Object? filterValue,
  }) {
    return SupabaseSeam.boundFilteredTable(
      table,
      columns,
      filterColumn: filterColumn,
      filterValue: filterValue,
    );
  }

  final OrgRpcCaller _rpcCaller;
  final OrgTableCaller _table;

  /// Every RPC read/write goes through here so the shared seam deadline
  /// ([SupabaseSeam.boundRpc]) can never cross this boundary as a raw
  /// [TimeoutException] (audit 2026-10-27, F3). A stalled transport is a
  /// typed unavailable; the existing `on PostgrestException` mapping on each
  /// method is untouched (PostgREST failures pass through unchanged).
  Future<PostgrestResponse<dynamic>> _rpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    try {
      return await _rpcCaller(function, params);
    } on TimeoutException {
      throw const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.providerUnavailable,
        message: orgRequestFailedMessage,
      );
    }
  }

  @override
  Future<String> createOrganization({required String name}) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        SupabaseRpcs.createOrganization,
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
      throw SupabaseOrgException(
        kind: _kindFor(e),
        message: orgRequestFailedMessage,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listMembers({
    required String organizationId,
  }) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        SupabaseRpcs.listOrgMembersMetadata,
        <String, dynamic>{'p_organization_id': organizationId},
      );
      final Object? data = response.data;
      if (data is! List<dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(
        kind: _kindFor(e),
        message: orgRequestFailedMessage,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listAssignableMembers({
    required String matterId,
  }) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        SupabaseRpcs.listMatterAssignableMembers,
        <String, dynamic>{'p_matter_id': matterId},
      );
      final Object? data = response.data;
      if (data is! List<dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(
        kind: _kindFor(e),
        message: orgRequestFailedMessage,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listMyMemberships({
    required String userId,
  }) async {
    try {
      // RLS-scoped: the memberships policy = own-row OR active-member, so it
      // can return co-members' rows. Filtering `user_id` server-side keeps
      // the caller's own rows inside the hard 200-row cap; the Dart
      // projection below stays as defense in depth. The embedded
      // organizations(name) join resolves for active memberships and is null
      // for suspended/removed ones (org row not visible) — the repository
      // mapper tolerates the null name (plan §6).
      final List<Map<String, dynamic>> rows = await _table(
        SupabaseTables.memberships,
        'organization_id, user_id, role, status, organizations(name)',
        filterColumn: 'user_id',
        filterValue: userId,
      );
      return rows
          .where((Map<String, dynamic> row) => row['user_id'] == userId)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(
        kind: _kindFor(e),
        message: orgRequestFailedMessage,
      );
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
        SupabaseRpcs.inviteMember,
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
      throw SupabaseOrgException(
        kind: _kindFor(e),
        message: orgRequestFailedMessage,
      );
    }
  }

  @override
  Future<void> changeMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  }) async {
    await _runVoidRpc(SupabaseRpcs.changeMemberRole, <String, dynamic>{
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
    await _runVoidRpc(SupabaseRpcs.suspendMembership, <String, dynamic>{
      'p_organization_id': organizationId,
      'p_user_id': userId,
    });
  }

  @override
  Future<void> reactivateMember({
    required String organizationId,
    required String userId,
  }) async {
    await _runVoidRpc(SupabaseRpcs.reactivateMembership, <String, dynamic>{
      'p_organization_id': organizationId,
      'p_user_id': userId,
    });
  }

  @override
  Future<void> removeMember({
    required String organizationId,
    required String userId,
  }) async {
    await _runVoidRpc(SupabaseRpcs.removeMembership, <String, dynamic>{
      'p_organization_id': organizationId,
      'p_user_id': userId,
    });
  }

  @override
  Future<String> resendInvitation({required String invitationId}) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        SupabaseRpcs.resendInvitation,
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
      throw SupabaseOrgException(
        kind: _kindFor(e),
        message: orgRequestFailedMessage,
      );
    }
  }

  @override
  Future<void> revokeInvitation({required String invitationId}) async {
    await _runVoidRpc(SupabaseRpcs.revokeInvitation, <String, dynamic>{
      'p_invitation_id': invitationId,
    });
  }

  @override
  Future<void> deleteMyAccount() async {
    await _runVoidRpc(SupabaseRpcs.deleteMyAccount, const <String, dynamic>{});
  }

  @override
  Future<String> acceptInvitation({required String token}) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpc(
        SupabaseRpcs.acceptInvitation,
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
      throw SupabaseOrgException(
        kind: _kindFor(e),
        message: orgRequestFailedMessage,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> readOrgAudit({
    required String organizationId,
  }) async {
    try {
      final PostgrestResponse<dynamic> response = await _readOrgAuditRpc(
        organizationId,
      );
      final Object? data = response.data;
      if (data is! List<dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(
        kind: _kindFor(e),
        message: orgRequestFailedMessage,
      );
    }
  }

  /// Calls the parameterized `read_org_audit` and falls back to the live
  /// zero-argument signature when the former is not installed yet
  /// (`PGRST202` / `42883` / an explicit function-or-signature-not-found
  /// message). Any other failure propagates to the caller's typed mapping.
  Future<PostgrestResponse<dynamic>> _readOrgAuditRpc(
    String organizationId,
  ) async {
    try {
      return await _rpc(SupabaseRpcs.readOrgAudit, <String, dynamic>{
        'p_organization_id': organizationId,
      });
    } on PostgrestException catch (e) {
      if (!_isFunctionNotFound(e)) {
        rethrow;
      }
      return _rpc(SupabaseRpcs.readOrgAudit, const <String, dynamic>{});
    }
  }

  /// True when PostgREST reports that the called function (or that exact
  /// signature) is not installed — the live-DB compatibility fallback trigger.
  bool _isFunctionNotFound(PostgrestException e) {
    if (e.code == PostgrestCodes.schemaCacheMiss ||
        e.code == PostgrestCodes.undefinedFunction) {
      return true;
    }
    final String message = e.message.toLowerCase();
    return message.contains('could not find the function') ||
        (message.contains('function') && message.contains('does not exist'));
  }

  Future<void> _runVoidRpc(String function, Map<String, dynamic> params) async {
    try {
      await _rpc(function, params);
    } on PostgrestException catch (e) {
      throw SupabaseOrgException(
        kind: _kindFor(e),
        message: orgRequestFailedMessage,
      );
    }
  }
}
