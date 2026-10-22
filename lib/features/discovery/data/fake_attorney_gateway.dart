import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/practice_area.dart';
import '../domain/attorney.dart';
import '../domain/attorney_gateway.dart';

/// Development-only attorney-directory implementation (design §2).
///
/// Serves a fixed synthetic list of professional, non-contact profiles. It
/// is registered **only when the Supabase env is absent** — a configured
/// build always binds the real gateway, so no synthetic row can appear in a
/// real directory. Ids deliberately use the non-UUID `atty-*` shape; the
/// booking guard and [Attorney.hasRealId] keep them away from real backends.
/// The list resolves immediately (no artificial delay) so cubit/widget tests
/// stay timing-independent.
class FakeAttorneyGateway implements AttorneyGateway {
  /// The fixed synthetic profile list served by [fetchAttorneys].
  static final List<Attorney> syntheticAttorneys = <Attorney>[
    Attorney(
      id: 'atty-1',
      name: 'Layla Mansour',
      practiceArea: PracticeArea.corporate,
      locale: 'EN / AR',
      bio: 'Corporate transactions and governance counsel.',
      headline: 'Corporate and governance counsel',
      city: 'Cairo',
      specialties: const <String>['corporate'],
      languages: const <String>['EN', 'AR'],
      yearsExperience: 12,
    ),
    Attorney(
      id: 'atty-2',
      name: 'Omar Farouk',
      practiceArea: PracticeArea.civil,
      locale: 'EN / AR',
      bio: 'Civil litigation and contracts.',
      headline: 'Civil litigation and contracts',
      city: 'Alexandria',
      specialties: const <String>['civil'],
      languages: const <String>['EN', 'AR'],
      yearsExperience: 9,
    ),
    Attorney(
      id: 'atty-3',
      name: 'Sara Khalil',
      practiceArea: PracticeArea.criminal,
      locale: 'AR / EN',
      bio: 'Criminal defense and procedure.',
      headline: 'Criminal defense and procedure',
      city: 'Cairo',
      specialties: const <String>['criminal'],
      languages: const <String>['AR', 'EN'],
      yearsExperience: 15,
    ),
    Attorney(
      id: 'atty-4',
      name: 'Youssef Haddad',
      practiceArea: PracticeArea.family,
      locale: 'AR / EN',
      bio: 'Family law and personal status matters.',
      headline: 'Family law and personal status',
      city: 'Giza',
      specialties: const <String>['family'],
      languages: const <String>['AR', 'EN'],
      yearsExperience: 7,
    ),
    Attorney(
      id: 'atty-5',
      name: 'Maya Adel',
      practiceArea: PracticeArea.corporate,
      locale: 'EN',
      bio: 'Startup formation and advisory work.',
      headline: 'Startup formation and advisory',
      city: 'Cairo',
      specialties: const <String>['corporate'],
      languages: const <String>['EN'],
      yearsExperience: 5,
    ),
  ];

  /// The error returned for an unknown id — the same shape as the real
  /// gateway's not-found failure, so the profile surface renders identically.
  static const AppError _notFound = AppError(
    code: 'attorney_not_found',
    userMessage: 'Attorney not found.',
  );

  @override
  Future<Result<List<Attorney>>> fetchAttorneys({String query = ''}) async {
    final String needle = query.trim().toLowerCase();
    final List<Attorney> rows = needle.isEmpty
        ? syntheticAttorneys
        : syntheticAttorneys
              .where((Attorney attorney) => _matches(attorney, needle))
              .toList(growable: false);
    return Result<List<Attorney>>.success(List<Attorney>.unmodifiable(rows));
  }

  @override
  Future<Result<Attorney>> fetchAttorney(String id) async {
    for (final Attorney attorney in syntheticAttorneys) {
      if (attorney.id == id && attorney.isActive) {
        return Result<Attorney>.success(attorney);
      }
    }
    return const Result<Attorney>.failure(_notFound);
  }

  bool _matches(Attorney attorney, String needle) {
    return attorney.name.toLowerCase().contains(needle) ||
        (attorney.headline?.toLowerCase().contains(needle) ?? false) ||
        (attorney.city?.toLowerCase().contains(needle) ?? false) ||
        (attorney.practiceArea?.name.contains(needle) ?? false) ||
        attorney.specialties.any(
          (String value) => value.toLowerCase().contains(needle),
        );
  }
}
