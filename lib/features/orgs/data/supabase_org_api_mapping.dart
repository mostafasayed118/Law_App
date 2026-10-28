part of 'supabase_org_api_impl.dart';

/// The PostgrestException→failure-kind mapping of [SupabaseOrgApiImpl],
/// moved verbatim as a library-private top-level function (it reads no
/// instance state, so the class call sites resolve unchanged).
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
