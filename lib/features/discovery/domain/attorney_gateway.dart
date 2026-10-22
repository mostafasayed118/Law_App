import '../../../core/errors/result.dart';
import 'attorney.dart';

/// Attorney-discovery integration boundary (design §2).
///
/// The configured build binds the Supabase-backed implementation (the
/// member-scoped directory read through the audited RPCs); env-less builds
/// and all tests keep the credential-free fake. Failures arrive as
/// [Failure] with an `AppError`, never raw exceptions (§D.4).
abstract interface class AttorneyGateway {
  /// Active directory profiles whose name, headline, city, or specialties
  /// match [query] (case-insensitive substring; empty means no server-side
  /// narrowing). The client still applies its practice-area projection and
  /// free-text pass so a page of results keeps the same matching semantics.
  Future<Result<List<Attorney>>> fetchAttorneys({String query = ''});

  /// One profile by id. A missing (or, for a non-owner, inactive) row is a
  /// `attorney_not_found` failure rather than an empty success.
  Future<Result<Attorney>> fetchAttorney(String id);
}
