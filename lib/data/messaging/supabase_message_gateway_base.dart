part of 'supabase_message_gateway.dart';

/// The gateway's shared Supabase seam fields, split out of the main
/// class so the message group can live in a library-private mixin while
/// reading the exact same instances.
class _SupabaseMessageBase {
  _SupabaseMessageBase(this._api, this._realtimeApi);

  final SupabaseMessageApi _api;
  final SupabaseMessageRealtimeApi _realtimeApi;
}
