/// The single request deadline every Supabase call shares: RPCs, table
/// reads, storage operations, and Edge Function invokes.
const Duration kSupabaseRequestTimeout = Duration(seconds: 15);
