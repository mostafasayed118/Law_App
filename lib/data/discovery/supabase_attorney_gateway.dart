import '../../core/errors/app_error.dart';
import '../../core/errors/result.dart';
import '../../core/practice_area.dart';
import '../../features/discovery/domain/attorney.dart';
import '../../features/discovery/domain/attorney_admin_gateway.dart';
import '../../features/discovery/domain/attorney_gateway.dart';
import 'supabase_attorney_api.dart';

/// Attorney directory backed by the Supabase provider (design §2).
///
/// One class implements both the read seam and the platform-admin write seam:
/// the row mapping and failure vocabulary are identical, only the RPC set
/// differs. Domain mapping happens here (contract §5 pattern): raw rows become
/// [Attorney] VOs, `specialties` project onto the client [PracticeArea] enum,
/// `languages` become the display locale, and typed
/// [SupabaseAttorneyException]s become [AppError]s with the retryable/denied
/// classification preserved.
class SupabaseAttorneyGateway implements AttorneyGateway, AttorneyAdminGateway {
  SupabaseAttorneyGateway(this._api);

  final SupabaseAttorneyApi _api;

  @override
  Future<Result<List<Attorney>>> fetchAttorneys({String query = ''}) {
    return _read(() => _api.listAttorneys(query: query));
  }

  @override
  Future<Result<List<Attorney>>> fetchAll() {
    return _read(() => _api.listAttorneys(includeInactive: true, limit: 100));
  }

  @override
  Future<Result<Attorney>> fetchAttorney(String id) async {
    try {
      return Result<Attorney>.success(_fromRow(await _api.getAttorney(id)));
    } on SupabaseAttorneyException catch (e) {
      return Result<Attorney>.failure(_errorFor(e, write: false));
    } on FormatException catch (e) {
      return Result<Attorney>.failure(_drift(e));
    }
  }

  @override
  Future<Result<String>> create(AttorneyDraft draft) async {
    try {
      return Result<String>.success(
        await _api.createAttorney(
          displayName: draft.displayName,
          specialties: draft.specialties,
          languages: draft.languages,
          headline: draft.headline,
          bio: draft.bio,
          city: draft.city,
          yearsExperience: draft.yearsExperience,
          avatarUrl: draft.avatarUrl,
        ),
      );
    } on SupabaseAttorneyException catch (e) {
      return Result<String>.failure(_errorFor(e, write: true));
    } on FormatException catch (e) {
      return Result<String>.failure(_drift(e));
    }
  }

  @override
  Future<Result<void>> update(String id, AttorneyDraft draft) async {
    try {
      await _api.updateAttorney(
        id,
        displayName: draft.displayName,
        specialties: draft.specialties,
        languages: draft.languages,
        headline: draft.headline,
        bio: draft.bio,
        city: draft.city,
        yearsExperience: draft.yearsExperience,
        avatarUrl: draft.avatarUrl,
      );
      return const Result<void>.success(null);
    } on SupabaseAttorneyException catch (e) {
      return Result<void>.failure(_errorFor(e, write: true));
    } on FormatException catch (e) {
      return Result<void>.failure(_drift(e));
    }
  }

  @override
  Future<Result<void>> deactivate(String id) async {
    try {
      await _api.deactivateAttorney(id);
      return const Result<void>.success(null);
    } on SupabaseAttorneyException catch (e) {
      return Result<void>.failure(_errorFor(e, write: true));
    } on FormatException catch (e) {
      return Result<void>.failure(_drift(e));
    }
  }

  Future<Result<List<Attorney>>> _read(
    Future<List<Map<String, dynamic>>> Function() read,
  ) async {
    try {
      final List<Map<String, dynamic>> rows = await read();
      return Result<List<Attorney>>.success(
        List<Attorney>.unmodifiable(rows.map(_fromRow)),
      );
    } on SupabaseAttorneyException catch (e) {
      return Result<List<Attorney>>.failure(_errorFor(e, write: false));
    } on FormatException catch (e) {
      return Result<List<Attorney>>.failure(_drift(e));
    }
  }

  /// Maps one raw `attorney_profiles` row to the [Attorney] VO.
  ///
  /// Required shapes are asserted explicitly (id, display name, status) so a
  /// malformed row surfaces as a typed `FormatException` rather than a raw
  /// cast error across the boundary.
  Attorney _fromRow(Map<String, dynamic> row) {
    final Object? id = row['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Attorney row has no id');
    }
    final Object? name = row['display_name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('Attorney row has no display_name');
    }
    final bool isActive = switch (row['status']) {
      'active' => true,
      'inactive' => false,
      _ => throw const FormatException('Attorney row has an unknown status'),
    };
    final List<String> specialties = _strings(row['specialties']);
    final List<String> languages = _strings(row['languages']);
    final Object? years = row['years_experience'];
    if (years != null && years is! int) {
      throw const FormatException('Attorney row has invalid years_experience');
    }
    return Attorney(
      id: id,
      name: name,
      practiceArea: _areaOf(specialties),
      locale: _localeOf(languages),
      bio: _stringOrEmpty(row['bio']),
      headline: _stringOrNull(row['headline']),
      city: _stringOrNull(row['city']),
      specialties: specialties,
      languages: languages,
      yearsExperience: years as int?,
      isActive: isActive,
    );
  }

  /// The first specialty that names a [PracticeArea], or null — never a
  /// fabricated area for a free-form specialty the client does not model.
  PracticeArea? _areaOf(List<String> specialties) {
    for (final String specialty in specialties) {
      final String token = specialty.trim().toLowerCase();
      for (final PracticeArea area in PracticeArea.values) {
        if (area.name == token) {
          return area;
        }
      }
    }
    return null;
  }

  /// Display locale from the languages list: short codes upper-cased
  /// (`EN / AR`), longer names left as written.
  String _localeOf(List<String> languages) {
    return languages
        .map(
          (String language) =>
              language.length <= 3 ? language.toUpperCase() : language,
        )
        .join(' / ');
  }

  List<String> _strings(Object? value) {
    if (value == null) {
      return const <String>[];
    }
    if (value is! List<dynamic>) {
      throw const FormatException('Attorney row has a non-list array column');
    }
    final List<String> values = <String>[];
    for (final dynamic item in value) {
      if (item is! String) {
        throw const FormatException('Attorney row has a non-string array item');
      }
      values.add(item);
    }
    return values;
  }

  String _stringOrEmpty(Object? value) => value is String ? value : '';

  String? _stringOrNull(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Maps a seam failure to a redaction-safe [AppError]. Profile content never
  /// crosses into errors; only the provider's own message crosses as the
  /// technical message.
  AppError _errorFor(SupabaseAttorneyException e, {required bool write}) {
    final String prefix = write ? 'attorney_write' : 'attorney_read';
    return switch (e.kind) {
      SupabaseAttorneyFailureKind.denied => AppError(
        code: '${prefix}_denied',
        userMessage: write
            ? 'You do not have permission to manage the directory.'
            : 'You do not have permission to view the directory.',
        kind: AppErrorKind.denied,
        technicalMessage: e.message,
      ),
      SupabaseAttorneyFailureKind.notFound => AppError(
        code: 'attorney_not_found',
        userMessage: 'Attorney not found.',
        technicalMessage: e.message,
      ),
      SupabaseAttorneyFailureKind.validation => AppError(
        code: 'attorney_write_invalid',
        userMessage: 'The profile details are invalid. Check them and retry.',
        technicalMessage: e.message,
      ),
      SupabaseAttorneyFailureKind.providerUnavailable => AppError(
        code: '${prefix}_unavailable',
        userMessage: 'The directory is temporarily unavailable. Try again.',
        kind: AppErrorKind.unavailable,
        technicalMessage: e.message,
      ),
      SupabaseAttorneyFailureKind.unknown => AppError(
        code: '${prefix}_failed',
        userMessage: 'Unable to load the directory. Please try again.',
        technicalMessage: e.message,
      ),
    };
  }

  /// Provider drift (unexpected row shape) surfaces loudly, never as a
  /// silently wrong profile.
  AppError _drift(FormatException e) => AppError(
    code: 'attorney_read_failed',
    userMessage: 'Unable to load the directory. Please try again.',
    technicalMessage: e.message,
  );
}
