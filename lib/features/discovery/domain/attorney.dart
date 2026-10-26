import 'package:equatable/equatable.dart';

import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/core/validation/uuid.dart';

/// One attorney-directory profile (design §2).
///
/// Carries **professional, non-contact data only**: a stable id, a display
/// name, an optional headline/bio/city, specialties and languages, years of
/// experience, and the active flag. No phone, email, address, credential
/// number, or availability anywhere on the type — the directory is a
/// platform-managed listing, not a verified credential statement.
///
/// [id] stays a [String] because env-less demo builds serve synthetic
/// `atty-*` rows; [hasRealId] distinguishes those from persisted UUID rows
/// so presentation can keep a synthetic id from reaching a real backend.
///
/// [practiceArea] is a client-side projection of [specialties] (the first
/// specialty matching a [PracticeArea] token). A server row with no
/// recognized specialty leaves it null — honest, never a fabricated area.
class Attorney extends Equatable {
  const Attorney({
    required this.id,
    required this.name,
    this.practiceArea,
    this.locale = '',
    this.bio = '',
    this.headline,
    this.city,
    this.specialties = const <String>[],
    this.languages = const <String>[],
    this.yearsExperience,
    this.isActive = true,
  });

  final String id;
  final String name;

  /// The first recognized specialty as an area, or null when none matches.
  final PracticeArea? practiceArea;

  /// Display locale string, e.g. "EN / AR" (derived from [languages] for
  /// server rows).
  final String locale;

  final String bio;
  final String? headline;
  final String? city;
  final List<String> specialties;
  final List<String> languages;
  final int? yearsExperience;

  /// False for a deactivated profile. The public directory exposes active
  /// rows only; the platform-admin listing includes both.
  final bool isActive;

  /// True only when [id] is a real UUID — never for a synthetic `atty-*` id.
  bool get hasRealId => isValidUuid(id);

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    practiceArea,
    locale,
    bio,
    headline,
    city,
    specialties,
    languages,
    yearsExperience,
    isActive,
  ];
}
