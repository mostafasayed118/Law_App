import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_admin_gateway.dart';
import 'fake_attorney_gateway.dart';

/// Development-only platform-admin directory implementation.
///
/// Registered **only when the Supabase env is absent**; a configured build
/// always binds the owner-only RPC gateway. Writes stay in memory for the
/// lifetime of the singleton so the admin surface is exercisable in an
/// env-less demo without ever reaching a real backend.
class FakeAttorneyAdminGateway implements AttorneyAdminGateway {
  final List<Attorney> _rows = List<Attorney>.of(
    FakeAttorneyGateway.syntheticAttorneys,
  );
  int _nextId = 1;

  static const AppError _notFound = AppError(
    code: 'attorney_not_found',
    userMessage: 'Attorney not found.',
  );

  @override
  Future<Result<List<Attorney>>> fetchAll() async {
    return Result<List<Attorney>>.success(List<Attorney>.unmodifiable(_rows));
  }

  @override
  Future<Result<String>> create(AttorneyDraft draft) async {
    final String id = 'atty-admin-${_nextId++}';
    _rows.add(_fromDraft(id, draft, isActive: true));
    return Result<String>.success(id);
  }

  @override
  Future<Result<void>> update(String id, AttorneyDraft draft) async {
    final int index = _rows.indexWhere(
      (Attorney attorney) => attorney.id == id,
    );
    if (index == -1) {
      return const Result<void>.failure(_notFound);
    }
    _rows[index] = _fromDraft(id, draft, isActive: _rows[index].isActive);
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> deactivate(String id) async {
    final int index = _rows.indexWhere(
      (Attorney attorney) => attorney.id == id,
    );
    if (index == -1) {
      return const Result<void>.failure(_notFound);
    }
    final Attorney current = _rows[index];
    _rows[index] = Attorney(
      id: current.id,
      name: current.name,
      practiceArea: current.practiceArea,
      locale: current.locale,
      bio: current.bio,
      headline: current.headline,
      city: current.city,
      specialties: current.specialties,
      languages: current.languages,
      yearsExperience: current.yearsExperience,
      isActive: false,
    );
    return const Result<void>.success(null);
  }

  Attorney _fromDraft(
    String id,
    AttorneyDraft draft, {
    required bool isActive,
  }) {
    final List<String> specialties = draft.specialties;
    return Attorney(
      id: id,
      name: draft.displayName,
      practiceArea: _areaOf(specialties),
      locale: draft.languages.join(' / '),
      bio: draft.bio ?? '',
      headline: draft.headline,
      city: draft.city,
      specialties: specialties,
      languages: draft.languages,
      yearsExperience: draft.yearsExperience,
      isActive: isActive,
    );
  }

  PracticeArea? _areaOf(List<String> specialties) {
    for (final PracticeArea area in PracticeArea.values) {
      if (specialties.contains(area.name)) {
        return area;
      }
    }
    return null;
  }
}
