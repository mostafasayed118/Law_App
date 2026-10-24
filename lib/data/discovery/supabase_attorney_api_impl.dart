import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_attorney_api.dart';

/// A PostgREST RPC call: function name + named params → response.
typedef AttorneyRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabaseAttorneyApi] backed by the PostgREST client.
///
/// A data-layer file whose only job is holding the provider import: RPC in,
/// plain rows out, and PostgrestExceptions mapped to
/// [SupabaseAttorneyException]s at the seam. The RPC contracts come from the
/// discovery migration (`list_attorney_profiles`, `get_attorney_profile`, and
/// the owner-only create/update/deactivate trio).
class SupabaseAttorneyApiImpl implements SupabaseAttorneyApi {
  SupabaseAttorneyApiImpl({AttorneyRpcCaller? rpcCaller})
    : _rpcCaller = rpcCaller ?? _boundRpc;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseAttorneyApiImpl.bind() => SupabaseAttorneyApiImpl();

  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRpc(function, params);
  }

  final AttorneyRpcCaller _rpcCaller;

  @override
  Future<List<Map<String, dynamic>>> listAttorneys({
    String query = '',
    bool includeInactive = false,
    int limit = 50,
  }) {
    return _guard(() async {
      final PostgrestResponse<dynamic> response = await _rpcCaller(
        'list_attorney_profiles',
        <String, dynamic>{
          'p_query': query,
          'p_include_inactive': includeInactive,
          'p_limit': limit,
        },
      );
      final Object? data = response.data;
      if (data == null) {
        return const <Map<String, dynamic>>[];
      }
      if (data is! List<dynamic>) {
        throw const SupabaseAttorneyException(
          kind: SupabaseAttorneyFailureKind.unknown,
          message: 'list_attorney_profiles returned a non-list payload.',
        );
      }
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
      for (final dynamic row in data) {
        if (row is! Map<String, dynamic>) {
          throw const SupabaseAttorneyException(
            kind: SupabaseAttorneyFailureKind.unknown,
            message: 'list_attorney_profiles returned a malformed row.',
          );
        }
        rows.add(row);
      }
      return rows;
    });
  }

  @override
  Future<Map<String, dynamic>> getAttorney(String id) {
    return _guard(() async {
      final PostgrestResponse<dynamic> response = await _rpcCaller(
        'get_attorney_profile',
        <String, dynamic>{'p_id': id},
      );
      final Map<String, dynamic>? row = _singleRow(response.data);
      if (row == null) {
        throw const SupabaseAttorneyException(
          kind: SupabaseAttorneyFailureKind.notFound,
          message: 'Attorney profile not found.',
        );
      }
      return row;
    });
  }

  @override
  Future<String> createAttorney({
    required String displayName,
    required List<String> specialties,
    required List<String> languages,
    String? headline,
    String? bio,
    String? city,
    int? yearsExperience,
    String? avatarUrl,
  }) {
    return _guard(() async {
      final PostgrestResponse<dynamic> response = await _rpcCaller(
        'create_attorney_profile',
        _writeParams(
          displayName: displayName,
          specialties: specialties,
          languages: languages,
          headline: headline,
          bio: bio,
          city: city,
          yearsExperience: yearsExperience,
          avatarUrl: avatarUrl,
        ),
      );
      final Object? data = response.data;
      if (data is String && data.isNotEmpty) {
        return data;
      }
      throw const SupabaseAttorneyException(
        kind: SupabaseAttorneyFailureKind.unknown,
        message: 'create_attorney_profile returned no id.',
      );
    });
  }

  @override
  Future<void> updateAttorney(
    String id, {
    required String displayName,
    required List<String> specialties,
    required List<String> languages,
    String? headline,
    String? bio,
    String? city,
    int? yearsExperience,
    String? avatarUrl,
  }) {
    return _guard(() async {
      await _rpcCaller('update_attorney_profile', <String, dynamic>{
        'p_id': id,
        ..._writeParams(
          displayName: displayName,
          specialties: specialties,
          languages: languages,
          headline: headline,
          bio: bio,
          city: city,
          yearsExperience: yearsExperience,
          avatarUrl: avatarUrl,
        ),
      });
    });
  }

  @override
  Future<void> deactivateAttorney(String id) {
    return _guard(() async {
      await _rpcCaller('deactivate_attorney_profile', <String, dynamic>{
        'p_id': id,
      });
    });
  }

  Map<String, dynamic> _writeParams({
    required String displayName,
    required List<String> specialties,
    required List<String> languages,
    String? headline,
    String? bio,
    String? city,
    int? yearsExperience,
    String? avatarUrl,
  }) => <String, dynamic>{
    'p_display_name': displayName,
    'p_headline': headline,
    'p_bio': bio,
    'p_specialties': specialties,
    'p_languages': languages,
    'p_city': city,
    'p_years_experience': yearsExperience,
    'p_avatar_url': avatarUrl,
  };

  /// Accepts the two shapes a `returns public.attorney_profiles` RPC can
  /// produce across PostgREST versions: one object or a single-row list.
  Map<String, dynamic>? _singleRow(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is List<dynamic> && data.length == 1) {
      final Object? first = data.first;
      return first is Map<String, dynamic> ? first : null;
    }
    return null;
  }

  /// Runs one RPC through the seam's single failure mapping: typed exceptions
  /// pass through, Postgrest failures classify through [_kindFor], and any
  /// other transport failure becomes a typed unavailable.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on SupabaseAttorneyException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseAttorneyException(kind: _kindFor(e), message: e.message);
    } on Object {
      throw const SupabaseAttorneyException(
        kind: SupabaseAttorneyFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Classifies a Postgrest failure. `23514` is the validation gate
  /// (`check_violation`); the denial rule is the shared [isPostgrestDenial];
  /// the RPC's explicit `raise exception 'attorney profile not found'` and
  /// `'display name is required'` carry their stable text.
  SupabaseAttorneyFailureKind _kindFor(PostgrestException e) {
    if (e.code == '23514') {
      return SupabaseAttorneyFailureKind.validation;
    }
    final String message = e.message.toLowerCase();
    if (message.contains('not found')) {
      return SupabaseAttorneyFailureKind.notFound;
    }
    if (message.contains('required') || message.contains('invalid')) {
      return SupabaseAttorneyFailureKind.validation;
    }
    return postgrestKindFor(
      e,
      denied: SupabaseAttorneyFailureKind.denied,
      unknown: SupabaseAttorneyFailureKind.unknown,
    );
  }
}
