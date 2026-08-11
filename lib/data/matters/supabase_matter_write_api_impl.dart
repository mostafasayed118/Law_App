import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_matter_write_api.dart';

/// A PostgREST RPC call: function name + named params → response.
///
/// The callable the impl injects for the audited create path — mirrors
/// `MessageRpcCaller` from the messaging seam (D-SM2). Plain function type
/// so tests inject a closure and the impl is the only file that ever touches
/// provider types.
typedef MatterWriteRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabaseMatterWriteApi] backed by the PostgREST client.
///
/// Like [SupabaseMessageApiImpl], this is a data-layer file whose only job is
/// holding the provider import: the `create_matter` RPC call in, the
/// persisted matter id out, and PostgrestExceptions mapped to typed
/// [SupabaseMatterWriteException]s at the seam. The RPC's in-function
/// refusals (F2-D1/F2-D2/F2-D4, validation) are mapped to their distinct
/// kinds by the stable message fragments.
class SupabaseMatterWriteApiImpl implements SupabaseMatterWriteApi {
  SupabaseMatterWriteApiImpl({MatterWriteRpcCaller? rpcCaller})
    : _rpcCaller = rpcCaller ?? _boundRpc;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseMatterWriteApiImpl.bind() => SupabaseMatterWriteApiImpl();

  /// Binds the audited `create_matter` RPC to the app-level client.
  /// postgrest 2.8.0 contract: `await rpc<T>()` resolves to the RAW
  /// decoded data (T), not a PostgrestResponse — the wrapper is only
  /// produced when a count is requested — so the production binding wraps
  /// the raw data into the seam's PostgrestResponse shape (the test stubs'
  /// own shape); PostgrestException still propagates unchanged (the
  /// `MessageRpcCaller._boundRpc` precedent).
  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    final dynamic data = await Supabase.instance.client.rpc<dynamic>(
      function,
      params: params,
    );
    return PostgrestResponse<dynamic>(data: data, count: 0);
  }

  final MatterWriteRpcCaller _rpcCaller;

  @override
  Future<String> createMatter({
    required String organizationId,
    required String title,
    required String practiceArea,
    String? assignedClientId,
    String? assignedAttorneyId,
  }) async {
    try {
      // C-D4: the audited `create_matter` RPC is the ONLY matter write path.
      // The params use the RPC's EXACT names; the server re-derives org
      // membership (F2-D1), the owner refusal (F2-D2), and the member guard
      // (F2-D4) in-function — no org pre-read, no client-side authorization
      // (F-11). The function returns the persisted matter id (uuid).
      final PostgrestResponse<dynamic> response =
          await _rpcCaller('create_matter', <String, dynamic>{
            'p_organization_id': organizationId,
            'p_title': title.trim(),
            'p_practice_area': practiceArea,
            'p_assigned_client_id': assignedClientId,
            'p_assigned_attorney_id': assignedAttorneyId,
          });
      final Object? id = response.data;
      if (id is! String || id.isEmpty) {
        throw const SupabaseMatterWriteException(
          kind: SupabaseMatterWriteFailureKind.unknown,
          message: 'create_matter returned no id.',
        );
      }
      return id;
    } on SupabaseMatterWriteException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseMatterWriteException(kind: _kindFor(e), message: e.message);
    } on Object {
      // Same defensive catch as the messaging impl: a non-Postgrest provider
      // failure is a typed unavailable, never a raw exception across the seam.
      throw const SupabaseMatterWriteException(
        kind: SupabaseMatterWriteFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind.
  ///
  /// The RPC's in-function `raise exception` refusals surface as Postgrest
  /// messages; the stable fragments are matched in refusal order (F2-D2
  /// before F2-D4 before the generic denial), so the client maps each
  /// server refusal to its own C-D2 kind. Everything else is unknown with
  /// the message preserved.
  SupabaseMatterWriteFailureKind _kindFor(PostgrestException e) {
    final String message = e.message.toLowerCase();
    if (message.contains('platform owner cannot be assigned')) {
      return SupabaseMatterWriteFailureKind.ownerForbidden;
    }
    if (message.contains('assigned client must be an active member') ||
        message.contains('assigned attorney must be an active member')) {
      return SupabaseMatterWriteFailureKind.assigneeInvalid;
    }
    if (message.contains('matter title is required')) {
      return SupabaseMatterWriteFailureKind.validation;
    }
    if (message.contains('permission denied') ||
        message.contains('row-level security')) {
      return SupabaseMatterWriteFailureKind.denied;
    }
    return SupabaseMatterWriteFailureKind.unknown;
  }
}
