import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/result.dart';
import 'attorney.dart';

/// The platform-admin write surface for the attorney directory (design §2).
///
/// Writes are owner-only audited RPCs; the client sends only the editable
/// profile fields. A denial or validation refusal arrives as a [Failure]
/// with an `AppError` (never a silent empty success).
abstract interface class AttorneyAdminGateway {
  /// Every profile, active and inactive, for the admin surface.
  Future<Result<List<Attorney>>> fetchAll();

  /// Creates a profile and returns its server-generated id.
  Future<Result<String>> create(AttorneyDraft draft);

  /// Replaces the editable fields of [id].
  Future<Result<void>> update(String id, AttorneyDraft draft);

  /// Marks [id] inactive (the directory keeps the row for the admin listing).
  Future<Result<void>> deactivate(String id);
}

/// The editable fields of one attorney profile.
///
/// [displayName] is required (the server trims and bounds it); every other
/// field is optional and null when absent. [specialties] and [languages] are
/// already trimmed and de-duplicated by the caller.
class AttorneyDraft extends Equatable {
  const AttorneyDraft({
    required this.displayName,
    this.headline,
    this.bio,
    this.specialties = const <String>[],
    this.languages = const <String>[],
    this.city,
    this.yearsExperience,
    this.avatarUrl,
  });

  final String displayName;
  final String? headline;
  final String? bio;
  final List<String> specialties;
  final List<String> languages;
  final String? city;
  final int? yearsExperience;
  final String? avatarUrl;

  @override
  List<Object?> get props => <Object?>[
    displayName,
    headline,
    bio,
    specialties,
    languages,
    city,
    yearsExperience,
    avatarUrl,
  ];
}
