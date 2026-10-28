import 'package:supabase_flutter/supabase_flutter.dart';

/// PostgREST/SQLSTATE codes shared by the data-seam classifiers.
abstract final class PostgrestCodes {
  static const String validation = '23514';
  static const String uniqueViolation = '23505';
  static const String undefinedFunction = '42883';
  static const String schemaCacheMiss = 'PGRST202';
  static const String invalidResponse = 'PGRST116';
}

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

/// Maps a PostgREST failure to a two-kind seam enum (denied vs unknown).
///
/// The six read-seam `_kindFor` clones were byte-identical except for the
/// enum type they returned (audit 2026-09-27, Q-Q1 — filed as five, six
/// found): the denial RULE already lives in [isPostgrestDenial] (H-7), and
/// this finishes the job — the match-once logic lives here, each impl
/// supplies only its own enum values. The three extended classifiers named
/// above keep their private `_kindFor` (behavior differs — see doc).
T postgrestKindFor<T>(
  PostgrestException e, {
  required T denied,
  required T unknown,
}) {
  return isPostgrestDenial(e) ? denied : unknown;
}
