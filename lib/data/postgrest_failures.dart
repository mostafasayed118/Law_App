import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared classification of a PostgREST failure at the data seam.
///
/// The RLS-denial rule used to be copy-pasted into every api impl's `_kindFor`
/// (audit 2026-09-21, H-7): six of those copies were byte-identical, so a
/// provider-side wording change would have needed six coordinated edits and a
/// miss would have silently degraded a denial to `unknown` — i.e. a denial
/// rendered as a retryable error. It lives here once.
///
/// Deliberately NOT applied to the three seams whose classifiers extend the
/// rule with domain phrases of their own — forcing them onto this helper would
/// change their behavior:
/// - `supabase_platform_admin_api_impl` — adds `cannot delete your own account`
///   and does not match `row-level security`;
/// - `supabase_org_api_impl` — adds `cannot remove yourself` plus duplicate /
///   membership arms;
/// - `supabase_matter_write_api_impl` — classifies only domain validation
///   phrases (`ownerForbidden`, `assigneeInvalid`, `validation`).
///
/// Both phrases are pinned per feature by the api-impl tests (`permission
/// denied` and `new row violates row-level security policy`).
bool isPostgrestDenial(PostgrestException e) {
  final String message = e.message.toLowerCase();
  return message.contains('permission denied') ||
      message.contains('row-level security');
}
