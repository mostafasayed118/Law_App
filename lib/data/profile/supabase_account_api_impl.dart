import 'package:legalhub/data/profile/supabase_account_api.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [AccountApi] backed by the two RPCs in migration 34.
class SupabaseAccountApiImpl implements AccountApi {
  SupabaseAccountApiImpl({AccountRpcCaller? rpcCaller})
    : _rpcCaller = rpcCaller ?? _boundRpc;

  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) => SupabaseSeam.boundRpc(function, params);

  final AccountRpcCaller _rpcCaller;

  @override
  Future<void> updateDisplayName(String displayName) async {
    try {
      await _rpcCaller('update_my_profile', <String, dynamic>{
        'p_display_name': displayName,
      });
    } on PostgrestException catch (e) {
      throw AccountApiException(e.code ?? '', message: e.message);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _rpcCaller('delete_my_account', const <String, dynamic>{});
    } on PostgrestException catch (e) {
      throw AccountApiException(e.code ?? '', message: e.message);
    }
  }
}

typedef AccountRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );
